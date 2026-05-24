from app.core.database import get_db_connection
from typing import List
from app.schemas.sales_quotes import SalesQuoteResponse, SalesQuoteDetailResponse

class SalesQuoteService:
    def get_quotes_paged(self, search: str = None) -> List[dict]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            sql = "EXEC [Sales].[sp_Quotations_GetPaged] @PageNumber=1, @PageSize=100, @SearchText=?"
            cursor.execute(sql, (search if search else "",))
            
            # The SP first returns TotalCount, then the actual rows
            # We need to skip the first result set and move to the second one
            
            # Skip TotalCount
            if cursor.description and cursor.description[0][0] == 'TotalCount':
                cursor.nextset()
            
            rows = cursor.fetchall()
            quotes = []
            for row in rows:
                quotes.append({
                    "QuoteID": row.QuoteID,
                    "PartnerID": row.PartnerID,
                    "QuoteDate": row.QuoteDate,
                    "ExpiryDate": row.ExpiryDate,
                    "IsActive": row.IsActive,
                    "Notes": row.Notes,
                    "PartnerName": row.PartnerName
                })
            return quotes
        finally:
            conn.close()

    def get_quote_details(self, quote_id: int) -> List[dict]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            sql = "EXEC [Sales].[sp_QuotationDetails_GetByQuoteID] @QuoteID=?, @PageNumber=1, @PageSize=1000"
            cursor.execute(sql, (quote_id,))
            
            # Skip TotalCount
            if cursor.description and cursor.description[0][0] == 'TotalCount':
                cursor.nextset()
                
            rows = cursor.fetchall()
            details = []
            for row in rows:
                details.append({
                    "QuoteDetailID": row.QuoteDetailID,
                    "QuoteID": row.QuoteID,
                    "ProductID": row.ProductID,
                    "QuotedPrice": float(row.QuotedPrice),
                    "ProductName": row.ProductName,
                    "Barcode": row.Barcode,
                    "UnitName": row.UnitName
                })
            return details
        finally:
            conn.close()
