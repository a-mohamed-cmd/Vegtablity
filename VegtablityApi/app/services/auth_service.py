from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP
from app.core.security import hash_password_net_style

class AuthService:
    def authenticate_user(self, username: str, password: str):
        # The password is currently saved without a hash in the database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Calling [Security].[sp_User_Login]
            cursor.execute(SP.USER_LOGIN, (username, password))
            row = cursor.fetchone()
            
            if row:
                columns = [column[0] for column in cursor.description]
                user_data = dict(zip(columns, row))
                return user_data
            return None
        finally:
            conn.close()
