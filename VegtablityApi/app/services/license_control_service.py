import pyodbc
from app.core.database import DB_SERVER, DB_USER, DB_PASSWORD
from app.core.db_procedures_controls import ControlStoredProcedures as SP

class LicenseControlService:
    def authenticate_server_user(self, username: str, password: str) -> bool:
        """
        Attempts to open a connection to the SQL Server instance using the provided credentials
        to verify if the login is correct.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE=master;"
            f"UID={username};"
            f"PWD={password};"
            "TrustServerCertificate=yes;"
        )
        try:
            conn = pyodbc.connect(connection_string)
            conn.close()
            return True
        except Exception:
            return False

    def get_databases(self):
        """
        Retrieves the names of all online databases available on the server.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE=master;"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        try:
            cursor.execute(SP.CTRL_GET_DATABASES)
            rows = cursor.fetchall()
            return [row[0] for row in rows]
        finally:
            cursor.close()
            conn.close()

    def get_licenses(self, db_name: str):
        """
        Retrieves all licenses registered under [Security].[DeviceLicenses] for a specific database.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE={db_name};"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        try:
            cursor.execute(SP.CTRL_LICENSE_GETALL)
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        finally:
            cursor.close()
            conn.close()

    def save_license(self, db_name: str, payload: dict):
        """
        Saves (inserts or updates) a license record inside [Security].[DeviceLicenses] in the target database.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE={db_name};"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        try:
            license_id = int(payload.get("LicenseID", 0))
            machine_name = payload.get("MachineName")
            machine_hwid = payload.get("MachineHWID")
            license_key = payload.get("LicenseKey")
            is_active = 1 if payload.get("IsActive") else 0
            expiry_date = payload.get("ExpiryDate")
            
            cursor.execute(SP.CTRL_LICENSE_SAVE, (license_id, machine_name, machine_hwid, license_key, is_active, expiry_date))
            conn.commit()
            return True
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def delete_license(self, db_name: str, license_id: int):
        """
        Deletes a license record by LicenseID in the target database.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE={db_name};"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        try:
            cursor.execute(SP.CTRL_LICENSE_DELETE, (license_id,))
            conn.commit()
            return True
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def get_company_settings(self, db_name: str):
        """
        Retrieves company and system settings from [Settings].[CompanySettings] for a specific database.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE={db_name};"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        try:
            cursor.execute(SP.CTRL_COMPANY_SETTINGS_GET)
            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if row:
                res = dict(zip(columns, row))
                for k, v in list(res.items()):
                    if isinstance(v, (bytes, bytearray)):
                        res[k] = None
                    elif isinstance(v, (bool, int, float, str)) or v is None:
                        pass
                    else:
                        res[k] = str(v)
                return res
            return {}
        finally:
            cursor.close()
            conn.close()

    def save_company_settings(self, db_name: str, payload: dict):
        """
        Updates company & system settings in [Settings].[CompanySettings] for a specific database.
        """
        connection_string = (
            f"DRIVER={{ODBC Driver 17 for SQL Server}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE={db_name};"
            f"UID={DB_USER};"
            f"PWD={DB_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        try:
            def _parse_bool(val):
                if val is None:
                    return None
                return 1 if (val is True or val == 1 or str(val).lower() in ("true", "1")) else 0

            production_mode = _parse_bool(payload.get("ProductionMode"))
            use_custom = _parse_bool(payload.get("UseCustomInvoiceDesign"))
            use_detailed = _parse_bool(payload.get("UseDetailedInvoiceDesign"))
            unified_search = _parse_bool(payload.get("UnifiedPartnerSearch"))
            company_name = payload.get("CompanyName")
            currency_symbol = payload.get("CurrencySymbol")
            address = payload.get("Address")
            phone = payload.get("Phone")
            email = payload.get("Email")
            enable_daily_orders = _parse_bool(payload.get("EnableDailyOrders"))
            delivery_system_mode = payload.get("DeliverySystemMode")

            cursor.execute(SP.CTRL_COMPANY_SETTINGS_SAVE, (
                production_mode, use_custom, use_detailed, unified_search,
                company_name, currency_symbol, address, phone, email,
                enable_daily_orders, delivery_system_mode
            ))
            conn.commit()
            return True
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()
