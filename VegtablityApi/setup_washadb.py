import pyodbc
import re

server = r".\SQLEXPRESS"
user = "mohamed"
password = "125630"

master_conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE=master;UID={user};PWD={password};TrustServerCertificate=yes;"

print("Ensuring database WashaDB exists...")
conn = pyodbc.connect(master_conn_str, autocommit=True)
cursor = conn.cursor()
try:
    cursor.execute("IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'WashaDB') CREATE DATABASE [WashaDB]")
    print("Database [WashaDB] is ready.")
except Exception as e:
    print(f"Database creation status: {e}")
conn.close()

# Now apply SQLVegtablity.sql to WashaDB
washa_conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE=WashaDB;UID={user};PWD={password};TrustServerCertificate=yes;"
washa_conn = pyodbc.connect(washa_conn_str, autocommit=True)
w_cursor = washa_conn.cursor()

# Ensure schemas
for sc in ['Reports', 'HR', 'Settings', 'Sales', 'Inventory', 'Accounting', 'Security']:
    try:
        w_cursor.execute(f"IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '{sc}') EXEC('CREATE SCHEMA [{sc}]')")
    except Exception:
        pass

sql_file_path = r"d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql"
with open(sql_file_path, "r", encoding="utf-8", errors="ignore") as f:
    sql_text = f.read()

batches = re.split(r'^\s*GO\s*$', sql_text, flags=re.MULTILINE | re.IGNORECASE)
success = 0
for b in batches:
    stmt = b.strip()
    if not stmt or re.match(r'^\s*USE\s+', stmt, flags=re.IGNORECASE):
        continue
    try:
        w_cursor.execute(stmt)
        success += 1
    except Exception:
        pass

print(f"WashaDB setup complete: {success} batches executed.")
washa_conn.close()
