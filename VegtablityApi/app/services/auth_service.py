from typing import Optional
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP

class AuthService:
    def _enrich_invoice_delete_permissions(self, cursor, user_data: dict) -> dict:
        if not user_data:
            return user_data
        if "CanDeleteSalesInvoice" in user_data and "CanDeletePurchaseInvoice" in user_data:
            return user_data

        can_sales = bool(user_data.get("CanDeleteSalesInvoice", False))
        can_purchase = bool(user_data.get("CanDeletePurchaseInvoice", False))
        role_id = int(user_data.get("RoleID") or 0)
        if role_id > 0:
            try:
                cursor.execute(SP.PERMISSION_GET_BY_ROLE, (role_id,))
                p_cols = [c[0] for c in cursor.description] if cursor.description else []
                for p_row in cursor.fetchall():
                    perm = dict(zip(p_cols, p_row))
                    form = str(perm.get("FormName") or "").strip().lower()
                    can_del = bool(perm.get("CanDelete", False))
                    if can_del:
                        if form in ("sales", "invoicedashboard"):
                            can_sales = True
                        if form in ("purchases", "invoicedashboard"):
                            can_purchase = True
            except Exception:
                pass
        user_data["CanDeleteSalesInvoice"] = can_sales
        user_data["CanDeletePurchaseInvoice"] = can_purchase
        return user_data

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
                return self._enrich_invoice_delete_permissions(cursor, user_data)
            return None
        finally:
            conn.close()

    def get_user_by_id(self, user_id: int, database: Optional[str] = None):
        conn = get_db_connection(database)
        cursor = conn.cursor()

        try:
            cursor.execute(SP.USER_GET_ALL)
            columns = [column[0] for column in cursor.description]
            for row in cursor.fetchall():
                item = dict(zip(columns, row))
                if item.get("UserID") == user_id:
                    return self._enrich_invoice_delete_permissions(cursor, item)
            return None
        finally:
            conn.close()
