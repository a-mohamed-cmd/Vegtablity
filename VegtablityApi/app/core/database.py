import pyodbc
import os
from dotenv import load_dotenv

load_dotenv()

# Database Configuration
# Using the settings provided by the user
DB_SERVER = os.getenv("DB_SERVER", r"192.168.43.129\SQLEXPRESS")
DB_NAME = os.getenv("DB_NAME", "VegtablityDB")
#DB_SERVER = os.getenv("DB_SERVER", r".\SQLEXPRESS")
#DB_NAME = os.getenv("DB_NAME", "WashaDB")
DB_USER = os.getenv("DB_USER", "mohamed")
DB_PASSWORD = os.getenv("DB_PASSWORD", "125630")

def get_db_connection():
    # Construct connection string with SQL Server Authentication
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={DB_SERVER};"
        f"DATABASE={DB_NAME};"
        f"UID={DB_USER};"
        f"PWD={DB_PASSWORD};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(connection_string)
