import asyncio
import json
from datetime import date
from pathlib import Path
from typing import Dict, List

from google.cloud import storage
from langchain_google_vertexai import VertexAIEmbeddings
from llama_index.core.node_parser import SentenceWindowNodeParser
from llama_index.readers.file import PDFReader

from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn
from doc_ingestion_pipeline.databases.vector_store import AlloyDB
from doc_ingestion_pipeline.llm.extract_topics import OpenAITopicExtractor
from doc_ingestion_pipeline.models.configs import AlloyTableConfig
from doc_ingestion_pipeline.models.connections import AlloyDBConnection
from doc_ingestion_pipeline.utils.app_logging import LoggerHandler


class DownloadPdfDoFn(BaseDoFn):
    def __init__(self, logger_hanlder: LoggerHandler, app_configs: dict):
        super().__init__(logger_hanlder)
        self.app_configs = app_configs

    def setup(self):
        super().setup()
        self.storage_client = storage.Client(self.app_configs["GCP_PROJECT"])

    def process(self, element, *args, **kwargs):
        today = date.today().strftime("%Y-%m-%d")
        bucket_name = self.app_configs["PDF_BUCKET_REPOSITORY"]
        bucket = self.storage_client.get_bucket(bucket_name)
        blobs = list(bucket.list_blobs(prefix=today))
        self.logger.info("Downloading pdfs...")
        local_paths = []
        for blob in blobs[1:]:
            file_name = blob.name.replace(f"{today}/", "")
            local_path = f"assets/pdf/{file_name}"
            blob.download_to_filename(local_path)
            self.logger.info(f"Downloaded {file_name} from {bucket_name} bucket.")
            local_paths.append(local_path)

        self.logger.info(f"PDFs downloaded successfully !")
        yield {"pdf_paths": local_paths}


class GenerateChunksDoFn(BaseDoFn):

    def __init__(self, logger_handler: LoggerHandler):
        super().__init__(logger_handler)

    def setup(self):
        super().setup()

    @BaseDoFn.gauge
    def process(self, element: Dict[str, List[str]], *args, **kwargs):
        chunks = []
        for pdf_path in element["pdf_paths"]:
            path = Path(pdf_path)
            self.logger.info(f"Reading pdf at '{element}'...")
            documents = PDFReader().load_data(path)

            node_parser = SentenceWindowNodeParser.from_defaults(
                window_size=5,
                window_metadata_key="window",
                original_text_metadata_key="original_text",
            )
            nodes = node_parser.get_nodes_from_documents(documents)

            for node in nodes:

                metadata = node.metadata
                chunk = {
                    "id": node.id_,
                    "text": metadata["window"],
                    "source_doc": metadata["file_name"],
                    "page_number": int(metadata["page_label"]),
                }
                chunks.append(chunk)

        yield from chunks


class ExtractPageTopicDoFn(BaseDoFn):
    def __init__(self, logger_hanlder: LoggerHandler, app_configs: dict):
        self.topic_extractor = OpenAITopicExtractor(logger_hanlder, app_configs)
        super().__init__(logger_hanlder)

    def setup(self):
        super().setup()

    @BaseDoFn.gauge
    def process(self, element: Dict[str, List[str]], *args, **kwargs):
        chunk = element.copy()
        topics = self.topic_extractor.extract_topics(chunk["text"])
        chunk["topics"] = topics
        yield chunk


class WriteOnAlloyDbFn(BaseDoFn):
    def __init__(
        self,
        logger_hanlder: LoggerHandler,
        app_configs: dict,
        env: str = "DEV",
        batch_size: int = 10,
    ):
        super().__init__(logger_hanlder)
        self.app_configs = app_configs
        self.env = env
        self.batch_size = batch_size
        self._batch: List[dict] = []

    def setup(self):
        connection_configs = self.app_configs["CONNECTIONS"]["ALLOYDB"][self.env]
        connection = AlloyDBConnection(**connection_configs)

        vectordb_configs = self.app_configs["VECTOR_STORE"]
        self.embedding_dim = vectordb_configs["EMBEDDING_DIMENSION"]
        self.metadata_cols = vectordb_configs["METADATA_COLUMNS"]
        self.id_column = vectordb_configs["ID_COLUMN"]
        self.content_column = vectordb_configs["CONTENT_COLUMN"]
        self.embedding_column = vectordb_configs["EMBEDDING_COLUMN"]

        embedding_model = VertexAIEmbeddings(
            model_name=vectordb_configs["EMBEDDING_MODEL"],
            project=self.app_configs["GCP_PROJECT"],
        )
        self.alloydb_handler = AlloyDB(
            connection, embedding_model, openai_key=self.app_configs["OPENAI_API_KEY"]
        )
        super().setup()

    async def __add_records_batch(self, records: List[Dict]):
        if not records:
            return

        async with self.alloydb_handler as db:
            table_config = AlloyTableConfig(
                vector_size=self.embedding_dim,
                metadata_columns=self.metadata_cols,
                metadata_json_column="metadata",
                id_column=self.id_column,
                content_column=self.content_column,
                embedding_column=self.embedding_column,
            )
            await db.init_vector_storage_table(
                table="bot-brain", table_config=table_config
            )

            ids = [record["id"] for record in records]
            texts = [record["text"] for record in records]
            metadatas = [record["metadata"] for record in records]

            await db.add_records(
                table="bot-brain", contents=texts, metadata=metadatas, ids=ids
            )

    @BaseDoFn.gauge
    def process(self, element: Dict[str, str], *args, **kwargs):
        try:
            self.logger.info(f" Writting element on AlloyDB: {element}")
            metadata = {col: element[col] for col in self.metadata_cols}

            record = {
                "id": element["id"],
                "text": element["text"],
                "metadata": metadata,
            }

            self._batch.append(record)

            if len(self._batch) >= self.batch_size:
                asyncio.run(self.__add_records_batch(self._batch))
                self._batch = []

            yield element

        except Exception as e:
            self.logger.error(f"Error processing element {element}: {str(e)}")
            raise

    def finish_bundle(self):
        # Process any remaining records in the batch
        if self._batch:
            try:
                asyncio.run(self.__add_records_batch(self._batch))
                self._batch = []
            except Exception as e:
                self.logger.error(f"Error processing final batch: {str(e)}")
                raise
