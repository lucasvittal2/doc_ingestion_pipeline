# [*CAUTION*] BEAM AND PYTHON VERSIONS SHOULD MATCH COMPOSER 2 IMAGE VERSION.
ARG BEAM_IMAGE
ARG BEAM_VERSION
ARG BEAM_IMAGE_VERSION=${BEAM_IMAGE}:${BEAM_VERSION}

# First stage: Build the wheel
FROM ${BEAM_IMAGE_VERSION} AS builder

ARG BEAM_VERSION
ENV PYTHONUNBUFFERED=1
WORKDIR /doc_ingestion_pipeline

# Copy only the specific subdirectories from the source code
COPY src/doc_ingestion_pipeline/beam ./doc_ingestion_pipeline/beam
COPY src/doc_ingestion_pipeline/databases ./doc_ingestion_pipeline/databases
COPY src/doc_ingestion_pipeline/llm ./doc_ingestion_pipeline/llm
COPY src/doc_ingestion_pipeline/models ./doc_ingestion_pipeline/models
COPY src/doc_ingestion_pipeline/utils ./doc_ingestion_pipeline/utils
COPY src/doc_ingestion_pipeline/__init__.py ./doc_ingestion_pipeline/__init__.py

# Copy setup.py for building the wheel
COPY src/setup.py ./


# Install only the required dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir build setuptools wheel

# Build the distribution (sdist and wheel)
RUN python setup.py sdist bdist_wheel

# Second stage: Final image
FROM ${BEAM_IMAGE_VERSION}

WORKDIR /doc_ingestion_pipeline

# Copy the built wheel and prompt from the builder stage
COPY --from=builder /doc_ingestion_pipeline/dist /doc_ingestion_pipeline/dist
COPY --from=builder /opt/apache/beam /opt/apache/beam

#Create local pdf repository
RUN mkdir -p assets/pdf
RUN mkdir -p assets/configs

#Copy config file
COPY assets/configs/app-configs.yaml ./assets/configs/app-configs.yaml

#set openaikey


# Install the built wheel
RUN pip install --no-cache-dir /doc_ingestion_pipeline/dist/*.whl

# Set the PYTHONPATH environment variable to point to the root module directory
ENV PYTHONPATH="/doc_ingestion_pipeline:${PYTHONPATH}"

# Verify installation (this ensures the module was installed correctly)
RUN python -c "import doc_ingestion_pipeline; print(doc_ingestion_pipeline.__file__)"

# Set the entrypoint for the container
ENTRYPOINT ["/opt/apache/beam/boot"]
