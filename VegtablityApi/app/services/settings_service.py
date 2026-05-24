from app.core.database import get_db_connection
import base64

class SettingsService:
    def get_company_settings(self) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # Stored procedure: [Settings].[sp_CompanySettings_Get]
            cursor.execute("{CALL [Settings].[sp_CompanySettings_Get]}")
            
            # Fetch the columns
            columns = [column[0] for column in cursor.description]
            row = cursor.fetchone()
            
            if row:
                data = dict(zip(columns, row))
                # Format binary logo to Base64 string if it exists
                # The binary logo column is typically 'Logo' or 'CompanyLogo' in the database.
                # We will handle any bytes column dynamically.
                formatted_data = {}
                for key, value in data.items():
                    if isinstance(value, bytes):
                        # Convert binary data to base64 string
                        formatted_data[key] = base64.b64encode(value).decode('utf-8')
                    else:
                        formatted_data[key] = value
                return formatted_data
            
            return {}
        finally:
            conn.close()

    def save_printer_settings(self, settings: dict) -> bool:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # Stored procedure: [Settings].[sp_PrinterSettings_Save]
            cursor.execute(
                "{CALL [Settings].[sp_PrinterSettings_Save] (?, ?, ?, ?, ?)}",
                (
                    settings.get("MachineHWID"),
                    settings.get("ConnectionType"),
                    settings.get("IPAddress"),
                    settings.get("Port"),
                    settings.get("BluetoothDevice")
                )
            )
            conn.commit()
            return True
        except Exception as e:
            print(f"Error saving printer settings to DB: {e}")
            raise e
        finally:
            conn.close()

    def get_printer_settings(self, machine_hwid: str) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # Stored procedure: [Settings].[sp_PrinterSettings_Get]
            cursor.execute(
                "{CALL [Settings].[sp_PrinterSettings_Get] (?)}",
                (machine_hwid,)
            )
            
            # Fetch the columns
            columns = [column[0] for column in cursor.description]
            row = cursor.fetchone()
            
            if row:
                return dict(zip(columns, row))
            
            return {}
        except Exception as e:
            print(f"Error fetching printer settings from DB: {e}")
            raise e
        finally:
            conn.close()

