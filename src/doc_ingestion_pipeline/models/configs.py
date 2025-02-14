from typing import List

from pydantic import BaseModel


class AlloyTableConfig(BaseModel):
    vector_size: int
    metadata_columns: List[str]
    metadata_json_column: str
    content_column: str
    id_column: str
    embedding_column: str
