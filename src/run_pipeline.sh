#!/bin/bash

 python src/doc_ingestion_pipeline/beam/pipelines/process_pdf.py \
    --bucket "test" \
    --pub_sub_topic "test"\
    --gcp_project "bot-especialist-dev"\
    --output_file "test" \
    --deadletter_file "test" \
    --streaming
