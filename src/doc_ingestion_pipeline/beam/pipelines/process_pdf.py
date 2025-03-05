import json
import os
from typing import List

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.transforms.display import DisplayDataItem

from doc_ingestion_pipeline.beam.dofunctions import process_pdf_dofn as dofn
from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn
from doc_ingestion_pipeline.utils.app_logging import LoggerHandler


class ProcessPDFPipelineOptions(PipelineOptions):

    @classmethod
    def _add_argparse_args(cls, parser) -> None:
        parser.add_argument(
            "--bucket",
            type=str,
            required=True,
            help="Bucket where pdf file path were uploaded",
        )


class ProcessPdfPipeline(BaseDoFn, beam.Pipeline):
    def __init__(self, logger_handler: LoggerHandler, app_configs: dict):

        self.app_configs = app_configs
        self.logger_handler = logger_handler
        self.logger = logger_handler.get_logger()
        self.OPENAI_API_KEY = app_configs["OPENAI_API_KEY"]

    def display_data(self) -> List[DisplayDataItem]:
        return [
            DisplayDataItem(
                self.__class__.__name__, key="class_name", label="Class name"
            ),
            DisplayDataItem(
                "Process Pdf Beam Pipeline", key="description", label="Description"
            ),
        ]

    def run(self, num_shards=5, argv=None):
        pipeline_options = PipelineOptions(argv)
        custom_options = pipeline_options.view_as(ProcessPDFPipelineOptions)
        os.environ["OPENAI_API_KEY"] = self.OPENAI_API_KEY

        try:
            self.logger.info("Starting Process Pdf Beam Pipeline...")
            with beam.Pipeline(options=pipeline_options) as pipeline:

                obtain_pdf_from_gcs = (
                    pipeline
                    | "trigger pipeline" >> beam.Create(["START"])
                    | "download_pdf"
                    >> beam.ParDo(
                        dofn.DownloadPdfDoFn(self.logger_handler, self.app_configs)
                    )
                )

                transform_pdf_in_chunks = (
                    obtain_pdf_from_gcs
                    | "ingest and create chunks"
                    >> beam.ParDo(dofn.GenerateChunksDoFn(self.logger_handler))
                )

                extract_topics = (
                    transform_pdf_in_chunks
                    | "topic extraction"
                    >> beam.ParDo(
                        dofn.ExtractPageTopicDoFn(
                            logger_hanlder=self.logger_handler,
                            app_configs=self.app_configs,
                        )
                    )
                )

                write_on_alloydb = extract_topics | "write on alloy db" >> beam.ParDo(
                    dofn.WriteOnAlloyDbFn(
                        self.logger_handler,
                        self.app_configs,
                    )
                )

        except Exception as err:
            self.logger.error(f"Error to retrieve pdf: \n\n{err}\n\n")
            raise err


if __name__ == "__main__":
    from doc_ingestion_pipeline.utils.file_handling import get_gcp_secrets

    app_configs = get_gcp_secrets("150030916493", "doc-ingestion-pipeline-secrets")
    logger_handler = LoggerHandler(
        logger_name="PDF-INGESTION-PIPELINE", logging_type="gcp_console"
    )
    process_pdf_pipeline = ProcessPdfPipeline(logger_handler, app_configs)
    process_pdf_pipeline.run()
