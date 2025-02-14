from typing import List

from pydantic import BaseModel


class PdfMetadata(BaseModel):
    pdf_name: str
    topics: List[str]
    page: int
    section: str
    text: str
