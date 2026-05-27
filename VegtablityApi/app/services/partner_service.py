from app.core.database import get_db_connection
from typing import List, Dict, Any
from app.core.db_procedures import StoredProcedures as SP

class PartnerService:
    def get_partners(self, partner_type: str, search_text: str = ""):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            if search_text:
                cursor.execute(SP.PARTNER_SEARCH, (partner_type, search_text))
            else:
                cursor.execute(SP.PARTNER_GET_ALL, (partner_type,))
            
            columns = [column[0] for column in cursor.description]
            partners = []
            for row in cursor.fetchall():
                partners.append(dict(zip(columns, row)))
            
            # Ensure float conversion for balance if needed
            for p in partners:
                if 'CurrentBalance' in p and p['CurrentBalance'] is not None:
                    p['CurrentBalance'] = float(p['CurrentBalance'])
                else:
                    p['CurrentBalance'] = 0.0

            return partners
        finally:
            conn.close()

    def get_active_purchase_partners(self) -> List[dict]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PURCHASE_ACTIVE_PARTNERS)
            columns = [column[0] for column in cursor.description]
            partners = []
            for row in cursor.fetchall():
                partners.append(dict(zip(columns, row)))
            for p in partners:
                p['PartnerType'] = 'Supplier'
                if 'CurrentBalance' in p and p['CurrentBalance'] is not None:
                    p['CurrentBalance'] = float(p['CurrentBalance'])
                else:
                    p['CurrentBalance'] = 0.0
            return partners
        finally:
            conn.close()

    def get_active_sales_partners(self) -> List[dict]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SALES_ACTIVE_PARTNERS)
            columns = [column[0] for column in cursor.description]
            partners = []
            for row in cursor.fetchall():
                partners.append(dict(zip(columns, row)))
            for p in partners:
                p['PartnerType'] = 'Customer'
                if 'CurrentBalance' in p and p['CurrentBalance'] is not None:
                    p['CurrentBalance'] = float(p['CurrentBalance'])
                else:
                    p['CurrentBalance'] = 0.0
            return partners
        finally:
            conn.close()

