import datetime
import time
import traceback
from typing import Callable

import apache_beam as beam
import pytz  # type: ignore
from apache_beam.metrics import Metrics

from doc_ingestion_pipeline.utils.logging import LoggerHandler


class BaseDoFn(beam.DoFn):
    def __init__(self, logger_name: str):
        super().__init__()
        self.logger_name = logger_name
        self.logger = LoggerHandler(
            logger_name=self.logger_name, logging_type="console"
        ).get_logger()
        self.queue_size = 0
        self.time_zone = pytz.timezone("America/Sao_Paulo")

        namespace = self.__class__.__module__
        self.elements_processed = Metrics.counter(namespace, "elements_processed")
        self.elements_failed = Metrics.counter(namespace, "elements_failed")
        self.processing_time = Metrics.distribution(namespace, "processing_time_ms")
        self.current_queue_size = Metrics.gauge(namespace, "current_queue_size")
        self.unique_error_types = Metrics.string_set(namespace, "unique_error_types")

    def deadletter_pdf_process(self, element, exception):
        self.elements_failed.inc()
        self.unique_error_types.add(type(exception)._name_)
        self.logger.error(
            f"Unexpected error on element ID: {element}: {str(exception)}"
        )
        return {
            "pdf_id": element.get("pdf_id"),
            "pdf_name": element.get("pdf_name"),
            "number_pages": element.get("number_pages"),
            "aspectsList": element.get(
                "aspectsList", "This failed before the LLM call."
            ),
            "exceptionType": type(exception)._name_,
            "exceptionMessage": str(exception),
            "stackTrace": traceback.format_exc(),
            "timestamp": datetime.datetime.now(tz=self.time_zone).isoformat() + "Z",
        }

    @classmethod
    def gauge(cls, func: Callable) -> Callable:

        def wrapper(self, *args, **kwargs):
            start_time = time.time()
            self.queue_size += 1
            self.current_queue_size.set(self.queue_size)
            try:
                yield from func(self, *args, **kwargs)
            finally:
                self.queue_size = max(self.queue_size - 1, 0)
                self.current_queue_size.set(self.queue_size)
                end_time = time.time()
                elapsed_time_ms = (end_time - start_time) * 1000
                self.processing_time.update(elapsed_time_ms)

        return wrapper
