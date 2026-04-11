## helping debug the git issue we are having with copying iceberg tables to ducklake
# git issue URL: https://github.com/duckdb/ducklake/issues/837

import boto3
import json
import os
from urllib.parse import quote
from urllib.request import Request, urlopen

from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def list_tables(db_name="db3"):
    client = boto3.client('glue')
    paginator = client.get_paginator("get_tables")

    table_names = []
    for page in paginator.paginate(DatabaseName=db_name):
        for table in page["TableList"]:
            table_names.append(table["Name"])

    for table_name in table_names:
        print(table_name)

    return table_names


def _resolve_region(session):
    return (
        session.region_name
        or os.getenv("AWS_REGION")
        or os.getenv("AWS_DEFAULT_REGION")
        or "us-east-1"
    )


def _resolve_catalog(session):
    configured_catalog = os.getenv("GLUE_ICEBERG_CATALOG")
    if configured_catalog:
        return configured_catalog

    sts_client = session.client("sts", region_name=_resolve_region(session))
    return sts_client.get_caller_identity()["Account"]


def _signed_get_json(session, url):
    creds = session.get_credentials()
    if creds is None:
        raise RuntimeError("No AWS credentials found for SigV4 request")

    frozen_creds = creds.get_frozen_credentials()
    region = _resolve_region(session)
    aws_request = AWSRequest(method="GET", url=url, headers={"Accept": "application/json"})
    SigV4Auth(frozen_creds, "glue", region).add_auth(aws_request)

    headers = dict(aws_request.headers.items())
    request = Request(url=url, headers=headers, method="GET")
    with urlopen(request, timeout=30) as response:
        body = response.read().decode("utf-8")
        if not body:
            return {}
        return json.loads(body)


def _extract_schema_fields(metadata):
    schemas = metadata.get("schemas", []) if isinstance(metadata, dict) else []
    current_schema_id = metadata.get("current-schema-id") if isinstance(metadata, dict) else None

    if current_schema_id is not None:
        for schema in schemas:
            if schema.get("schema-id") == current_schema_id:
                return current_schema_id, schema.get("fields", [])

    if schemas:
        first_schema = schemas[0]
        return first_schema.get("schema-id"), first_schema.get("fields", [])

    return current_schema_id, []


def extended_load_tables(table_names, db_name="db3"):
    if not table_names:
        print(f"No tables found in namespace {db_name}")
        return []

    session = boto3.session.Session()
    region = _resolve_region(session)
    catalog = _resolve_catalog(session)
    endpoint = os.getenv("GLUE_ICEBERG_ENDPOINT", f"https://glue.{region}.amazonaws.com")

    namespace = quote(db_name, safe="")
    catalog_path = quote(catalog, safe="")

    table_details = []
    for table_name in table_names:
        quoted_table = quote(table_name, safe="")

        candidate_urls = [
            f"{endpoint}/extensions/v1/catalogs/{catalog_path}/namespaces/{namespace}/tables/{quoted_table}",
            f"{endpoint}/iceberg/extensions/v1/catalogs/{catalog_path}/namespaces/{namespace}/tables/{quoted_table}",
        ]

        table_payload = None
        last_error = None
        selected_url = None
        for url in candidate_urls:
            try:
                table_payload = _signed_get_json(session, url)
                selected_url = url
                break
            except Exception as ex:
                last_error = ex

        if table_payload is None:
            print(f"Failed to load {db_name}.{table_name}: {last_error}")
            continue

        metadata = table_payload.get("metadata", {})
        metadata_location = table_payload.get("metadata-location")
        current_schema_id, fields = _extract_schema_fields(metadata)

        print(f"\n{db_name}.{table_name}")
        if selected_url:
            print("  rest-call: GET")
            print(f"    {selected_url}")
            print("  auth: AWS SigV4 (service=glue)")
        print(f"  metadata-location: {metadata_location}")
        print(f"  current-schema-id: {current_schema_id}")
        if fields:
            print("  schema-fields:")
            for field in fields:
                field_name = field.get("name")
                field_type = field.get("type")
                field_required = field.get("required")
                print(
                    f"    - id={field.get('id')} name={field_name} type={field_type} required={field_required}"
                )
        else:
            print("  schema-fields: []")

        table_details.append(
            {
                "namespace": db_name,
                "table": table_name,
                "metadata-location": metadata_location,
                "current-schema-id": current_schema_id,
                "schema-fields": fields,
                "raw-response": table_payload,
            }
        )

    return table_details

if __name__ == "__main__":    
    db_name = os.getenv("GLUE_DB_NAME", "db3")
    names = list_tables(db_name=db_name)
    extended_load_tables(names, db_name=db_name)