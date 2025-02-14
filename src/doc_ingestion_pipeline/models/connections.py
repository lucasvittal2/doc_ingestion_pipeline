from pydantic import BaseModel


class CloudSQLConnection(BaseModel):
    connection_name: str
    engine: str
    ip_address: str
    db_user: str
    db_password: str
    db_name: str
    use_private_ip: bool
    plugin: str


class AlloyDBConnection(BaseModel):
    region: str
    cluster: str
    instance: str
    database: str
    table_name: str
    project_id: str
    db_schema: str
    db_user: str
    db_password: str
    db_port: int
    db_host: str
