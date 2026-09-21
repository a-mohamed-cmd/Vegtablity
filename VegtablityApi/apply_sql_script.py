import pyodbc
import os
import re

server = r".\SQLEXPRESS"
database = "VegtablityDB"
user = "mohamed"
password = "125630"

conn_str = (
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={server};"
    f"DATABASE={database};"
    f"UID={user};"
    f"PWD={password};"
    "TrustServerCertificate=yes;"
)

sql_file_path = r"d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql"

print(f"Connecting to {database} on {server}...")
conn = pyodbc.connect(conn_str, autocommit=True)
cursor = conn.cursor()

# Ensure Schema Reports exists
try:
    cursor.execute("IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Reports') EXEC('CREATE SCHEMA [Reports]')")
    print("Schema [Reports] ensured.")
except Exception as e:
    print(f"Schema Reports error: {e}")

# Ensure Schema HR exists
try:
    cursor.execute("IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'HR') EXEC('CREATE SCHEMA [HR]')")
    print("Schema [HR] ensured.")
except Exception as e:
    print(f"Schema HR error: {e}")

with open(sql_file_path, "r", encoding="utf-8", errors="ignore") as f:
    sql_text = f.read()

# Split batches by GO
batches = re.split(r'^\s*GO\s*$', sql_text, flags=re.MULTILINE | re.IGNORECASE)

print(f"Total SQL batches to execute: {len(batches)}")

success_count = 0
error_count = 0

for i, batch in enumerate(batches):
    stmt = batch.strip()
    if not stmt:
        continue
    # Skip USE statements that might switch to master or other db
    if re.match(r'^\s*USE\s+', stmt, flags=re.IGNORECASE):
        continue
    try:
        cursor.execute(stmt)
        success_count += 1
    except Exception as e:
        # print first line of failed stmt
        first_line = stmt.split('\n')[0][:80]
        # print(f"Batch {i} Error on '{first_line}': {e}")
        error_count += 1

print(f"Execution complete: {success_count} batches executed successfully, {error_count} skipped/errors.")
conn.close()
