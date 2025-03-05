import json
import os

import functions_framework
from google.oauth2 import service_account
from googleapiclient.discovery import build


@functions_framework.http
def trigger_ingestion_pipeline_http(request):
    # Handle CORS preflight requests
    if request.method == "OPTIONS":
        return (
            "",
            204,
            {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Max-Age": "3600",
            },
        )

    if request.method != "POST":
        return ("Method Not Allowed", 405)

    try:
        PROJECT_ID = "the-bot-specialist-dev"
        TEMPLATE_PATH = "gs://doc-ingestion-pipeline-dev-150030916493/templates/doc_ingestion_template"
        REGION = "us-central1"
        DATAFLOW_JOB_NAME = "doc-ingestion-pipeline-dev-JOB"

        credentials = None
        if os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
            credentials = service_account.Credentials.from_service_account_file(
                os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
            )

        dataflow = build("dataflow", "v1b3", credentials=credentials)

        body = {
            "jobName": DATAFLOW_JOB_NAME,
            "parameters": {},  # Add parameters if needed
            "environment": {
                "tempLocation": "gs://doc-ingestion-pipeline-dev-150030916493/tmp",
                "zone": os.environ.get("DATAFLOW_ZONE", "us-central1-a"),
                "network": "projects/the-bot-specialist-dev/global/networks/default",
                "subnetwork": "regions/us-central1/subnetworks/default-subnet",
            },
        }

        request_job = (
            dataflow.projects()
            .locations()
            .templates()
            .launch(
                projectId=PROJECT_ID, location=REGION, gcsPath=TEMPLATE_PATH, body=body
            )
        )
        response = request_job.execute()
        return (json.dumps(response), 200, {"Content-Type": "application/json"})
    except Exception as e:
        return (
            json.dumps({"error": str(e)}),
            500,
            {"Content-Type": "application/json"},
        )
