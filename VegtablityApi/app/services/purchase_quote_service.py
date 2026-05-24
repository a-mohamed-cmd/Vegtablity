import xml.etree.ElementTree as ET
from app.core.database import get_db_connection
from app.schemas.purchase_quotes import PurchaseQuoteCreate

class PurchaseQuoteService:
    def get_all_quotes(self, search_text: str = None):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("{CALL [Purchases].[sp_PurchaseQuote_GetAll] (?)}", (search_text,))
            columns = [column[0] for column in cursor.description]
            results = []
            for row in cursor.fetchall():
                results.append(dict(zip(columns, row)))
            return results
        finally:
            conn.close()

    # save_quote removed as per user request to disable sp_PurchaseQuote_Save and mobile quote creation.

    def get_quote_details(self, quote_id: int) -> list:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("EXEC [Purchases].[sp_PurchaseQuote_GetDetails] @PurchaseQuoteID=?", (quote_id,))
            columns = [column[0] for column in cursor.description]
            results = []
            for row in cursor.fetchall():
                results.append(dict(zip(columns, row)))
            return results
        finally:
            conn.close()

