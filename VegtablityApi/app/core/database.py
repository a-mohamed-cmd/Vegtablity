import pyodbc
import os
from dotenv import load_dotenv

load_dotenv()

# Database Configuration
# Using the settings provided by the user
#DB_SERVER = os.getenv("DB_SERVER", r"192.168.43.129\SQLEXPRESS")
#DB_NAME = os.getenv("DB_NAME", "VegtablityDB")
DB_SERVER = os.getenv("DB_SERVER", r".\SQLEXPRESS")
DB_NAME = os.getenv("DB_NAME", "WashaDB")
DB_USER = os.getenv("DB_USER", "mohamed")
DB_PASSWORD = os.getenv("DB_PASSWORD", "125630")

DATABASE_ALIASES = {
    "washa": "WashaDB",
    "washadb": "WashaDB",
    "jawhara": "JawharaDB",
    "jawharadb": "JawharaDB",
    "vegtablity": "VegtablityDB",
    "vegtablitydb": "VegtablityDB",
    "veg": "VegtablityDB",
    "zatter": "zatterDB",
    "zatterdb": "zatterDB",
    "oman": "OmanCustmerDB",
    "omancustmerdb": "OmanCustmerDB",
    "omancustomerdb": "OmanCustmerDB",
}

def resolve_db_name(catalog: str = None) -> str:
    if not catalog or not catalog.strip():
        return DB_NAME
    cleaned = catalog.strip().lower()
    return DATABASE_ALIASES.get(cleaned, catalog.strip())

def get_db_connection(catalog: str = None):
    target_db = resolve_db_name(catalog)
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={DB_SERVER};"
        f"DATABASE={target_db};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(connection_string)

