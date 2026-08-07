from typing import List, Dict, Any
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP

class DiscountService:
    def get_all_discounts(self) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PRODUCT_DISCOUNTS_GET_ALL)
            columns = [col[0] for col in cursor.description]
            rows = cursor.fetchall()
            result = []
            for row in rows:
                item = dict(zip(columns, row))
                if item.get("CreatedDate"):
                    item["CreatedDate"] = str(item["CreatedDate"])
                result.append(item)
            return result
        finally:
            cursor.close()
            conn.close()

    def get_active_discounts_for_pos(self) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PRODUCT_DISCOUNTS_GET_ACTIVE_FOR_POS)
            columns = [col[0] for col in cursor.description]
            rows = cursor.fetchall()
            return [dict(zip(columns, row)) for row in rows]
        finally:
            cursor.close()
            conn.close()

    def get_products_for_discounts(self) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PRODUCTS_GET_FOR_DISCOUNTS)
            columns = [col[0] for col in cursor.description]
            rows = cursor.fetchall()
            return [dict(zip(columns, row)) for row in rows]
        finally:
            cursor.close()
            conn.close()

    def get_product_ids_for_discount(self, discount_id: int) -> List[int]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PRODUCT_DISCOUNTS_GET_PRODUCT_IDS, (discount_id,))
            rows = cursor.fetchall()
            return [row[0] for row in rows]
        finally:
            cursor.close()
            conn.close()

    def save_discount(self, payload: dict) -> int:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            discount_id = payload.get("DiscountID", 0) or 0
            discount_name = payload.get("DiscountName", "")
            discount_type = payload.get("DiscountType", 1)
            discount_value = payload.get("DiscountValue", 0.0)
            min_qty = payload.get("MinQuantity", 1.0)
            is_active = 1 if payload.get("IsActive", True) else 0

            product_ids = payload.get("ProductIDs", [])
            xml_items = "".join([f'<Product ProductID="{pid}"/>' for pid in product_ids])
            xml_payload = f"<Products>{xml_items}</Products>" if xml_items else None

            cursor.execute(SP.PRODUCT_DISCOUNTS_SAVE_XML, (discount_id, discount_name, discount_type, discount_value, min_qty, is_active, xml_payload))
            row = cursor.fetchone()
            saved_id = row[0] if row else discount_id
            conn.commit()
            return saved_id
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def delete_discount(self, discount_id: int) -> bool:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PRODUCT_DISCOUNTS_DELETE, (discount_id,))
            conn.commit()
            return True
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

