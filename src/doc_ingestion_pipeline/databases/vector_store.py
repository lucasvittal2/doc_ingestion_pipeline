import asyncio
import gc
import logging
import uuid
from typing import Any, List, Union

import aiohttp
from langchain_core.documents import Document
from langchain_core.embeddings.embeddings import Embeddings
from langchain_google_alloydb_pg import AlloyDBEngine, AlloyDBLoader, AlloyDBVectorStore
from langchain_google_vertexai import VertexAIEmbeddings

from doc_ingestion_pipeline.models.configs import AlloyTableConfig
from doc_ingestion_pipeline.models.connections import AlloyDBConnection


class AlloyDB:
    def __init__(self, connection: AlloyDBConnection, embedding_model: Embeddings):
        self.engine: Union[AlloyDBEngine, None] = None
        self.connection = connection
        self.embedding_model = embedding_model
        self.db_schema = connection.db_schema
        self.vector_store: Union[AlloyDBVectorStore, None] = None
        self.loop = asyncio.get_event_loop()

    async def __aenter__(self):
        """Async context manager for initializing resources."""

        self.engine = await AlloyDBEngine.afrom_instance(
            project_id=self.connection.project_id,
            region=self.connection.region,
            cluster=self.connection.cluster,
            instance=self.connection.instance,
            database=self.connection.database,
            user=self.connection.db_user,
            password=self.connection.db_password,
        )

        return self

    async def __aexit__(self, exc_type, exc_value, traceback):
        """Async context manager for cleaning up resources."""
        await self.__close_all_sessions_and_connections()

        logging.info("Closed all connections related with AlloyDB.")

    @staticmethod
    async def __close_all_sessions_and_connections():
        """Close all open aiohttp sessions and their connections."""

        sessions = [
            obj for obj in gc.get_objects() if isinstance(obj, aiohttp.ClientSession)
        ]

        if not sessions:
            logging.info("No open ClientSession objects found.")
            return

        for session in sessions:

            logging.info(f"Found ClientSession: {session}")

            if not session.closed:

                # Close the session
                await session.close()
                logging.info(f"Closed ClientSession: {session} .")

                # Close its connector explicitly if still open
                connector = session.connector
                if connector and not connector.closed:
                    await connector.close()
                    logging.info(f"Closed Connector: {connector} .")
            else:
                logging.info(f"ClientSession {session} is already closed.")

    async def init_vector_storage_table(
        self, table: str, table_config: AlloyTableConfig
    ) -> None:
        """Initialize the vector storage table."""
        try:
            self.vector_store = await AlloyDBVectorStore.create(
                engine=self.engine,
                table_name=table,
                schema_name=self.connection.db_schema,
                embedding_service=self.embedding_model,
                id_column=table_config.id_column,
                content_column=table_config.content_column,
                embedding_column=table_config.embedding_column,
                metadata_columns=table_config.metadata_columns,
                metadata_json_column=table_config.metadata_json_column,
            )
            logging.info(f"Initialized vector storage table: {table}")
        except Exception as err:
            logging.error(f"Failed to initialize vector storage: {err}")
            raise

    async def add_records(
        self, table: str, contents: List[str], metadata: List[dict], ids: List[Any]
    ) -> None:
        """Add documents to the vector store."""
        if self.vector_store is None:
            raise Exception(
                "Initialize the vector storage table before call this function, otherwise you'll not be able to adding records !"
            )
        if len(contents) != len(metadata):
            raise ValueError("Contents and metadata lists should have same lengths")

        try:
            documents = [
                Document(page_content=content, metadata=meta)
                for content, meta in zip(contents, metadata)
            ]

            await self.vector_store.aadd_texts(contents, metadatas=metadata, ids=ids)
            logging.info(f"Added {len(documents)} documents successfully.")
        except Exception as err:
            logging.error(f"Failed to add documents: {err}")
            raise err

    async def search_documents(self, query: str, filter: str = "") -> List[Document]:
        """Search documents in the vector store."""
        if self.vector_store is None:
            raise Exception(
                "Initialize the vector storage table before call this function, otherwise you'll not be able to search documents !"
            )
        try:
            docs = await self.vector_store.asimilarity_search(query, filter=filter)
            logging.info(f"Found {len(docs)} documents for query: {query}")
            return docs
        except Exception as err:
            logging.error(f"Failed to search documents: {err}")
            raise err


if __name__ == "__main__":
    import warnings

    from doc_ingestion_pipeline.utils.file_handling import read_yaml

    warnings.filterwarnings("ignore")

    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - [DOC-INGESTION-PIPELINE] - %(levelname)s:  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[logging.StreamHandler()],
    )

    async def main():
        # Load configurations
        app_config = read_yaml("assets/configs/app-configs.yaml")
        connection_config = app_config["CONNECTIONS"]["ALLOYDB"]["DEV"]
        connection = AlloyDBConnection(**connection_config)

        # Create embedding model
        embedding_model = VertexAIEmbeddings(
            model_name="textembedding-gecko@latest", project="bot-especialist-dev"
        )

        # Initialize vector store
        db = AlloyDB(connection, embedding_model)
        async with db:
            table_config = AlloyTableConfig(
                vector_size=768,
                metadata_columns=[
                    "name",
                    "category",
                    "price_usd",
                    "quantity",
                    "sku",
                    "image_url",
                ],
                metadata_json_column="metadata",
                id_column="product_id",
                content_column="description",
                embedding_column="embed",
            )
            await db.init_vector_storage_table(
                table="products", table_config=table_config
            )

            # Query vector store
            query = "I'd like a laptop."
            docs = await db.search_documents(query)
            print(docs)
            descriptions = ["High-performance gaming laptop"]
            metadata = [
                {
                    "name": "Eletronics",
                    "category": "Super Laptop",
                    "price_usd": 1500,
                    "quantity": 10,
                    "sku": "SKU12445",
                    "image_url": "",
                }
            ]
            await db.add_records(
                table="products", contents=descriptions, metadata=metadata, ids=[51]
            )

    asyncio.run(main())
