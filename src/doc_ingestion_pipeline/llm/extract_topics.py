from typing import List

import openai

from doc_ingestion_pipeline.models.data import PdfMetadata
from doc_ingestion_pipeline.utils.logging import LoggerHandler


class OpenAITopicExtractor:

    def __init__(self, logger: LoggerHandler, app_configs: dict):
        self.client = openai.OpenAI()
        self.logger = logger.get_logger()
        self.prompt = app_configs["PROMPTS"]["TOPIC_EXTRACTION"]

        llm_configs = app_configs["LLM"]["TOPIC_EXTRACTION"]
        self.LLM_TEMPERATURE = llm_configs["TEMPERATURE"]
        self.LLM_MODEL = llm_configs["MODEL"]

    def generate_topics(self, text: str) -> List[str]:
        response = self.client.chat.completions.create(
            model=self.LLM_MODEL,
            messages=[
                {"role": "user", "content": self.prompt},
            ],
            temperature=self.LLM_TEMPERATURE,
        )
        topics = response.choices[0].message.content
        self.logger.info(
            f"Text generated succefully using OpenAI LLM {self.LLM_MODEL} model."
        )
        return topics
