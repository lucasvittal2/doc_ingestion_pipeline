import datetime
import time
import traceback

import apache_beam as beam
from apache_beam.metrics import Metrics


class BaseDoFn(beam.DoFn):
    def __init__(self, logger_name: str):
        super().__init__()
        self.logger_name = logger_name
