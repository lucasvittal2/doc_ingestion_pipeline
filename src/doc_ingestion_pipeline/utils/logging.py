import logging


class LoggerHandler:
    def _init_(
        self, logger_name: str, logging_type: str, log_level: str = "INFO"
    ) -> None:
        """
        Instantiate LoggerHandler Class for Beam
        :param logger_name: log name, e.g. siamese_model
        :param logging_type: logging type, e.g. console
        :param log_level: integer value representing log level, default INFO = 20
        :return: None
        """
        self._log_level_map = {
            "DEBUG": logging.DEBUG,
            "INFO": logging.INFO,
            "WARNING": logging.WARNING,
            "ERROR": logging.ERROR,
            "CRITICAL": logging.CRITICAL,
        }

        self.logger_name = logger_name
        self.logging_type = logging_type
        self.log_level = self._log_level_map[log_level]
        self.format = (
            "[%(asctime)s] {%(filename)s:%(lineno)d} %(levelname)s - %(message)s"
        )

        self._configure_logging()

    def _configure_logging(self):
        logging.basicConfig(format=self.format, level=self.log_level, force=True)

    def get_logger(self) -> logging.Logger:
        """
        Get a Logger
        :return: Configured logging.Logger
        """
        logger = logging.getLogger(self.logger_name)
        if not logger.hasHandlers():
            if self.logging_type == "console":
                ch = logging.StreamHandler()
                ch.setLevel(self.log_level)
                formatter = logging.Formatter(self.format)
                ch.setFormatter(formatter)
                logger.addHandler(ch)
        logger.setLevel(self.log_level)
        return logger
