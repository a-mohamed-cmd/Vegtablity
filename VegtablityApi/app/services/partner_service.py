from app.core.database import get_db_connection
from typing import List

class PartnerService:
    def get_partners(self, partner_type: str, search_text: str = ""):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            if search_text:
                cursor.execute("{CALL [Sales].[sp_Partner_Search] (?, ?)}", (partner_type, search_text))
            else:
                cursor.execute("{CALL [Sales].[sp_Partner_GetAll] (?)}", (partner_type,))
            
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
            cursor.execute("EXEC [Purchases].[sp_PurchaseQuote_GetActivePartners]")
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
            cursor.execute("EXEC [Sales].[sp_SalesQuote_GetActivePartners]")
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

