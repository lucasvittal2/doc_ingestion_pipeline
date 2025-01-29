from typing import Any, Dict, List

import openai
from langchain.output_parsers import CommaSeparatedListOutputParser
from langchain.prompts.prompt import PromptTemplate
from langchain_openai import ChatOpenAI

from doc_ingestion_pipeline.models.data import PdfMetadata
from doc_ingestion_pipeline.utils.app_logging import LoggerHandler
from doc_ingestion_pipeline.utils.file_handling import read_yaml


class OpenAITopicExtractor:
    def __init__(self, logger: LoggerHandler, app_configs: dict):
        self.client = None  # Do not initialize here
        self.logger = logger.get_logger()
        self.prompt_text = app_configs["PROMPTS"]["TOPIC_EXTRACTION"]

        llm_configs = app_configs["LLM"]["TOPIC_EXTRACTION"]
        self.LLM_TEMPERATURE = llm_configs["TEMPERATURE"]
        self.LLM_MODEL = llm_configs["MODEL"]

    def setup(self):
        """Initialize OpenAI client after pickling"""
        self.client = openai.OpenAI()

    def extract_topics(self, text: str) -> List[str]:
        if self.client is None:
            self.setup()  # Ensure client is initialized

        output_parser = CommaSeparatedListOutputParser()
        format_instructions = output_parser.get_format_instructions()
        prompt = PromptTemplate(
            template=str(self.prompt_text),
            input_variables=["text"],
            partial_variables={"format_instructions": format_instructions},
        )
        model = ChatOpenAI(temperature=0)
        chain = prompt | model | output_parser

        topics = list(set(chain.invoke({"text": text})))
        self.logger.info(
            f"Text generated successfully using OpenAI LLM {self.LLM_MODEL} model."
        )
        filtered_topics = [topic for topic in topics if "Keywords:" not in topic]
        return filtered_topics


if __name__ == "__main__":
    from dotenv import load_dotenv

    load_dotenv(".env")
    logger = LoggerHandler("[TEST]", "console", "INFO")
    test_text = """
    The area of Rio de Janeiro and the South American coastal strip of what is now Brazil was settled by Arawak and Carib indigenous peoples before the arrival of the Spanish seafarer Vincent Yáñez Pinzón in the 1500s. A few months after the Spanish discoverer, the Portuguese sailor Pedro Alvarez Cabral visited the newly discovered world of South America and sailed with his crew off the coast of what is now Rio de Janeiro. This gave Portugal and Spain the power to settle their colonies, which prohibited other European nations from colonising the newly discovered world. In 1502, Portuguese explorers reach the coast of what is now Rio de Janeiro, and in 1530 they collaborate with European nations to establish 15 administrative districts. 25 years later, hundreds of French colonists settled the islands of Guanabara Bay and created the colony of La France Antarctique.

    Exactly 10 years after the establishment of the French colony in 1565, the Portuguese monarchy, headed by the Portuguese warlord Estácio de Sá, seizes the territory of La France Antarctique and establishes the city of Sã Sebastião do Rio de Janeiro. The battle between the Portuguese and the French colony lasted two years, as long as it took for the French colony to withdraw from the area of the newly established city. Sebastian I of Portugal builds the Portuguese fortress of São Tiago da Misericórdia in São Sebastião do Rio de Janeiro after his victory and attack on the French fortress of Uruçú-mirim on the former hill of Morro do Castelo. In the second half of the 17th century, São Sebastião do Rio de Janeiro becomes the seat of government of the Portuguese administrative units, home to more than half of the Indians and African slaves who profit the Portuguese colony by extracting sugar from sugar cane plantations.
    """
    app_configs = read_yaml("assets/configs/app-configs.yaml")
    topic_extractor = OpenAITopicExtractor(logger, app_configs)
    topics = topic_extractor.extract_topics(test_text)
    print(topics)
