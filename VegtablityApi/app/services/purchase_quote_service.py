import xml.etree.ElementTree as ET
from typing import List, Dict, Any
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP
from app.schemas.purchase_quotes import PurchaseQuoteCreate

class PurchaseQuoteService:
    def get_all_quotes(self, search_text: str = None):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PURCHASE_QUOTES_GET_ALL, (search_text,))
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
            cursor.execute(SP.PURCHASE_QUOTE_DETAILS, (quote_id,))
            columns = [column[0] for column in cursor.description]
            results = []
            for row in cursor.fetchall():
                results.append(dict(zip(columns, row)))
            return results
        finally:
            conn.close()

