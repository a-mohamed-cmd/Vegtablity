from typing import Optional
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP

class AuthService:
    def authenticate_user(self, username: str, password: str, database: Optional[str] = None):
        # The password is validated via [Security].[sp_User_Login]
        conn = get_db_connection(database)
        cursor = conn.cursor()
        
        try:
            cursor.execute(SP.USER_LOGIN, (username, password))
            row = cursor.fetchone()
            
            if row:
                columns = [column[0] for column in cursor.description]
                user_data = dict(zip(columns, row))
                return user_data
            return None
        finally:
            conn.close()
