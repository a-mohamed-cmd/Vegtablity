from typing import List, Dict, Any
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP

class AccountService:
    def get_revenue_accounts(self) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.ACCOUNT_REVENUE)
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        finally:
            conn.close()

    def get_expense_accounts(self) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.ACCOUNT_EXPENSES)
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        finally:
            conn.close()

    def get_general_partner(self) -> Dict[str, Any]:
        """جلب بيانات العميل الثابت 'سند مباشر' - يُستدعى مرة واحدة ويُخزّن في الـ Flutter"""
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SP_GET_PARTNER_GENERAL)
            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if not row:
                raise Exception("العميل الثابت 'سند مباشر' غير موجود. يرجى تنفيذ سكريبت إنشاءه.")
            return dict(zip(columns, row))
        finally:
            conn.close()
