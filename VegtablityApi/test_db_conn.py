import pyodbc

servers_to_test = [
    r"192.168.43.129\SQLEXPRESS",
    r".\SQLEXPRESS",
    r"localhost\SQLEXPRESS",
    r"(localdb)\MSSQLLocalDB",
    r"."
]

databases_to_test = ["WashaDB", "VegtablityDB", "master"]
auth_modes = [
    ("SQL Auth mohamed", "UID=mohamed;PWD=125630;"),
    ("Windows Auth", "Trusted_Connection=yes;"),
    ("SQL Auth sa", "UID=sa;PWD=125630;"),
]

for srv in servers_to_test:
    for auth_name, auth_str in auth_modes:
        conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={srv};{auth_str};TrustServerCertificate=yes;"
        try:
            conn = pyodbc.connect(conn_str, timeout=2)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sys.databases")
            dbs = [row[0] for row in cursor.fetchall()]
            print(f"SUCCESS: Server='{srv}', Auth='{auth_name}' -> Databases found: {dbs}")
            conn.close()
        except Exception as e:
            # print(f"FAIL: {srv} | {auth_name} -> {e}")
            pass
