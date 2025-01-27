from typing import List

import apache_beam as beam
from apache_beam.io import WriteToBigQuery
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.transforms.display import DisplayDataItem

from doc_ingestion_pipeline.beam.dofunctions import process_pdf_dofn as dofn
from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn


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
            help="Topic to transmit the pdf upload event to pipeline",
        )
        parser.add_argument(
            "--gcp_project", type=str, required=True, help="project where pipeline runs"
        )
        parser.add_argument(
            "--output_file",
            type=str,
            required=True,
            help="File path to output processed data to ingest on BigQuery",
        )
        parser.add_argument(
            "--deadletter_file",
            type=str,
            required=True,
            help="Deadletter BigQuery Table",
        )


class ProcessPdfPipeline(BaseDoFn, beam.Pipeline):
    def __init__(self):
        super().__init__(logger_name="[PROCESS-PDF-PIPELINE]")

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

                transform_pdf_in_chunks = (
                    pipeline
                    | "emit GCS event"
                    >> beam.Create(
                        [
                            {
                                "pdf_path": "/home/acer/projects/doc_ingestion_pipeline/assets/fundamentals-data-engineering-robust-29-57.pdf"
                            }
                        ]
                    )
                    | "ingest pdf"
                    >> beam.ParDo(
                        dofn.GenerateChunksDoFn(logger_name="[DOC-INGESTION-PDF]")
                    )  # replace by correspondent do function
                    | "print results"
                    >> beam.Map(print)  # replace by correspondent do function
                )
                # generate_embeddings = (
                #     transform_pdf_in_chunks
                #     | "generate embeddings"
                #     >> (lambda x: x)  # replace by correspondent do function
                # )
                # write_on_alloydb = (
                #     generate_embeddings
                #     | "format table"
                #     >> (lambda x: x)  # replace by correspondent do function
                #     | "write on alloy db"
                #     >> (lambda x: x)  # replace by correspondent do function
                # )

                # deadletter_process_pdf = (
                #     write_on_alloydb
                #     | "Format Pdf processing Dead letter"
                #     >> beam.ParDo(lambda x: x)  # replace by correspondent do function
                #     | "Write ded summary on BigQuery"
                #     >> WriteToBigQuery()  # put parameters
                # )
        except Exception as err:
            self.logger.error(f"Error to retrieve pdf: \n\n{err}\n\n")
            raise err


if __name__ == "__main__":
    process_pdf_pipeline = ProcessPdfPipeline()
    process_pdf_pipeline.run()
