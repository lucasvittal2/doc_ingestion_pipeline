import json
import os
from typing import List

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.transforms.display import DisplayDataItem
from apache_beam.transforms.window import FixedWindows

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
            "--input_pub_sub_topic",
            type=str,
            required=True,
            help="Pub/Sub topic for PDF upload events",
        )
        parser.add_argument(
            "--output_pub_sub_topic",
            type=str,
            required=True,
            help="Pub/Sub topic for PDF upload events",
        )
        parser.add_argument(
            "--pub_sub_subscription",
            type=str,
            required=True,
            help="Pub Sub Subscription which transmits bucket upload event",
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

    def run(self, window_size=1.0, num_shards=5, argv=None):
        pipeline_options = PipelineOptions(argv)
        custom_options = pipeline_options.view_as(ProcessPDFPipelineOptions)
        os.environ["OPENAI_API_KEY"] = self.OPENAI_API_KEY

        try:
            self.logger.info("Starting Process Pdf Beam Pipeline...")
            with beam.Pipeline(options=pipeline_options) as pipeline:

                obtain_pdf_from_gcs = (
                    pipeline
                    | "emit GCS event"
                    >> beam.io.ReadFromPubSub(topic=custom_options.input_pub_sub_topic)
                    | "Window into" >> beam.WindowInto(FixedWindows(60))
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

                # Garantir que apenas um evento final seja enviado para cada PDF processado
                confirm_processing = (
                    write_on_alloydb
                    | "Apply windowing" >> beam.WindowInto(FixedWindows(1))
                    | "Extract source_doc"
                    >> beam.Map(
                        lambda doc: {
                            "source_doc": doc["source_doc"],
                            "status": "PDF_PROCESSED",
                        }
                    )
                    | "distinct" >> beam.Distinct()
                    | "Prepare final message"
                    >> beam.Map(lambda doc: json.dumps(doc).encode("utf-8"))
                    | "sign pipeline was finished"
                    >> beam.io.WriteToPubSub(topic=custom_options.output_pub_sub_topic)
                )

        except Exception as err:
            self.logger.error(f"Error to retrieve pdf: \n\n{err}\n\n")
            raise err


if __name__ == "__main__":

    app_configs = read_yaml("assets/configs/app-configs.yaml")
    logger_handler = LoggerHandler(
        logger_name="PDF-INGESTION-PIPELINE", logging_type="gcp_console"
    )
    process_pdf_pipeline = ProcessPdfPipeline(logger_handler, app_configs)
    process_pdf_pipeline.run()
