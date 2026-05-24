from app.core.database import get_db_connection
import datetime

class SecurityService:
    def check_license(self, hwid: str) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT IsActive, ExpiryDate FROM [Security].[DeviceLicenses] WHERE MachineHWID = ?", (hwid,))
            row = cursor.fetchone()
            if row:
                is_active = bool(row[0])
                expiry_date = row[1]  # datetime or None
                
                is_expired = False
                if expiry_date:
                    today = datetime.date.today()
                    if isinstance(expiry_date, datetime.datetime):
                        expiry_date_val = expiry_date.date()
                    elif isinstance(expiry_date, datetime.date):
                        expiry_date_val = expiry_date
                    else:
                        expiry_date_val = datetime.datetime.strptime(str(expiry_date).split()[0], "%Y-%m-%d").date()
                    
                    if expiry_date_val < today:
                        is_expired = True
                
                is_licensed = is_active and not is_expired
                expiry_date_str = expiry_date.strftime("%Y-%m-%d") if expiry_date else None
                return {
                    "IsLicensed": is_licensed,
                    "ExpiryDate": expiry_date_str,
                    "IsActive": is_active,
                    "IsExpired": is_expired
                }
            return {
                "IsLicensed": False,
                "ExpiryDate": None,
                "IsActive": False,
                "IsExpired": False
            }
        finally:
            conn.close()
