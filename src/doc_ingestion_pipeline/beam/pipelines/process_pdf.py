from typing import List

import apache_beam as beam
from apache_beam.io import WriteToBigQuery
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.transforms.display import DisplayDataItem

from doc_ingestion_pipeline.beam.dofunctions import process_pdf_dofn as dofn
from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn
from doc_ingestion_pipeline.utils.app_logging import LoggerHandler
from doc_ingestion_pipeline.utils.file_handling import read_yaml


class ProcessPDFPipelineOptions(PipelineOptions):

    @classmethod
    def _add_argparse_args(cls, parser) -> None:
        parser.add_argument(
            "--bucket",
            type=str,
            required=True,
            help="Bucket where pdf file path were uploaded",
        )

        parser.add_argument(
            "--pub_sub_topic",
            type=str,
            required=True,
            help="Pub/Sub topic for PDF upload events",
        )
        parser.add_argument(
            "--deadletter_file",
            type=str,
            required=True,
            help="Deadletter BigQuery Table",
        )


class ProcessPdfPipeline(BaseDoFn, beam.Pipeline):
    def __init__(self, logger_handler: LoggerHandler, app_configs: dict):

        super().__init__(logger_handler)
        self.app_configs = app_configs
        self.logger_handler = logger_handler

    def display_data(self) -> List[DisplayDataItem]:
        return [
            DisplayDataItem(
                self.__class__.__name__, key="class_name", label="Class name"
            ),
            DisplayDataItem(
                "Process Pdf Beam Pipeline", key="description", label="Description"
            ),
        ]

    def run(self, argv=None):
        pipeline_options = PipelineOptions(argv)
        custom_options = pipeline_options.view_as(ProcessPDFPipelineOptions)

        try:
            self.logger.info("Starting Process Pdf Beam Pipeline...")
            with beam.Pipeline(options=pipeline_options) as pipeline:

                obtain_pdf_from_gcs = (
                    pipeline
                    | "emit GCS event"
                    >> beam.io.ReadFromPubSub(custom_options.pub_sub_topic)
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
                            loggger_hanlder=self.logger_handler,
                            app_configs=self.app_configs,
                        )
                    )
                    | "write to AlloyDB"
                    >> beam.ParDo(  # Add this step
                        dofn.WriteOnAlloyDbFn(
                            loggger_hanlder=self.logger_handler,
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
    from dotenv import load_dotenv

    load_dotenv(".env")

    app_configs = read_yaml("assets/configs/app-configs.yaml")
    logger_handler = LoggerHandler(
        logger_name="[PDF-INGESTION_PIPELINE]", logging_type="gcp_console"
    )
    process_pdf_pipeline = ProcessPdfPipeline(logger_handler, app_configs)
    process_pdf_pipeline.run()
