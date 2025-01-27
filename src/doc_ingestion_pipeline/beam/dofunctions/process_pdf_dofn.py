import asyncio
import datetime
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, Optional

import aiohttp
import apache_beam as beam
from llama_index.core.node_parser import HierarchicalNodeParser, get_leaf_nodes
from llama_index.core.schema import Document
from llama_index.readers.file import PDFReader

from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn


class GenerateChunksDoFn(BaseDoFn):

    def __init__(self, logger_name: str):
        super().__init__(logger_name)

    def setup(self):
        from pathlib import Path

        import apache_beam as beam
        from llama_index.core.node_parser import HierarchicalNodeParser, get_leaf_nodes
        from llama_index.core.schema import Document
        from llama_index.readers.file import PDFReader

        from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn

        super().setup()

    @BaseDoFn.gauge
    def process(self, element: Dict[str, str], *args, **kwargs):

        pdf_path = Path(element["pdf_path"])
        documents = PDFReader().load_data(pdf_path)
        document = Document(text="\n\n".join([doc.text for doc in documents]))
        node_parser = HierarchicalNodeParser.from_defaults(chunk_sizes=[2048, 512, 128])

        nodes = node_parser.get_nodes_from_documents([document])
        leaf_nodes = get_leaf_nodes(nodes)
        parent_nodes = [leaf.parent_node for leaf in leaf_nodes]
        records = [
            {"child_chunk": cc, "parent_chunk": pc}
            for cc, pc in zip(leaf_nodes, parent_nodes)
        ]
        yield from records
