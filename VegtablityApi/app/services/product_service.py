from typing import List, Dict, Any
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP

class ProductService:
    def get_products(self, search_text: str = ""):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            if search_text:
                cursor.execute(SP.PRODUCT_SEARCH, (search_text,))
            else:
                cursor.execute(SP.PRODUCT_GET_ALL)
            
            columns = [column[0] for column in cursor.description]
            products = []
            for row in cursor.fetchall():
                products.append(dict(zip(columns, row)))
            
            # Ensure price formatting and clean mapping
            for p in products:
                p['PurchasePrice'] = float(p.get('PurchasePrice', 0.0))
                p['SalePrice'] = float(p.get('SalePrice', 0.0))
                p['StockQuantity'] = 0.0 # Placeholder for future stock logic if needed
                
            return products
        finally:
            conn.close()

    def get_product_by_barcode(self, barcode: str):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PRODUCT_GET_BY_BARCODE, (barcode,))
            columns = [column[0] for column in cursor.description]
            row = cursor.fetchone()
            if row:
                product = dict(zip(columns, row))
                # Ensure price formatting and clean mapping
                product['PurchasePrice'] = float(product.get('PurchasePrice', 0.0))
                product['SalePrice'] = float(product.get('SalePrice', 0.0))
                product['StockQuantity'] = 0.0
                return product
            return None
        finally:
            conn.close()

