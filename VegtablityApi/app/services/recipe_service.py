from typing import List, Dict, Any, Optional
import xml.etree.ElementTree as ET
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP

class RecipeService:
    def get_all_recipes(self) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.RECIPE_GET_ALL)
            columns = [column[0] for column in cursor.description]
            recipes = []
            for row in cursor.fetchall():
                recipe = dict(zip(columns, row))
                recipe['TotalCost'] = float(recipe.get('TotalCost', 0.0))
                recipes.append(recipe)
            return recipes
        finally:
            conn.close()

    def get_recipe_by_product(self, product_id: int, warehouse_id: Optional[int] = None) -> Dict[str, Any]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.RECIPE_GET_BY_PRODUCT, (product_id, warehouse_id))
            
            # Result set 1: Recipe Header
            header_columns = [column[0] for column in cursor.description]
            header_row = cursor.fetchone()
            if not header_row:
                return {}
            header = dict(zip(header_columns, header_row))
            header['TotalCost'] = float(header.get('TotalCost', 0.0))

            # Result set 2: Ingredients
            cursor.nextset()
            details = []
            if cursor.description:
                detail_columns = [column[0] for column in cursor.description]
                for row in cursor.fetchall():
                    detail = dict(zip(detail_columns, row))
                    detail['Qty'] = float(detail.get('Qty', 0.0))
                    detail['UnitCost'] = float(detail.get('UnitCost', 0.0))
                    detail['LineCost'] = float(detail.get('LineCost', 0.0))
                    details.append(detail)
            
            header['Details'] = details
            return header
        finally:
            conn.close()

    def save_recipe(self, product_id: int, notes: str, details: List[Dict[str, Any]], warehouse_id: Optional[int] = None) -> int:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            root = ET.Element("Details")
            for item in details:
                detail_elem = ET.SubElement(root, "Detail")
                ET.SubElement(detail_elem, "IngredientProductID").text = str(item.get("IngredientProductID"))
                ET.SubElement(detail_elem, "Qty").text = str(item.get("Qty", 1.0))
                ET.SubElement(detail_elem, "Cost").text = str(item.get("Cost", 0.0))
            
            details_xml = ET.tostring(root, encoding="utf-8").decode("utf-8")
            cursor.execute(SP.RECIPE_SAVE_XML, (product_id, notes or "", details_xml, warehouse_id))
            row = cursor.fetchone()
            conn.commit()
            return row[0] if row else 0
        finally:
            conn.close()

    def delete_recipe(self, recipe_id: int) -> bool:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.RECIPE_DELETE, (recipe_id,))
            conn.commit()
            return True
        finally:
            conn.close()
