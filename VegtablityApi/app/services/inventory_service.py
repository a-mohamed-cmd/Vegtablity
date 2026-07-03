import xml.etree.ElementTree as ET
from app.core.database import get_db_connection
from app.schemas.inventory import WastageSaveRequest, StockTakeSaveRequest
from app.core.db_procedures import StoredProcedures as SP
from app.services.shift_service import ShiftService as _ShiftService

_shift_service = _ShiftService()

class InventoryService:
    def save_wastage(self, wastage: WastageSaveRequest, user_id: int) -> int:
        # Build XML for Wastage Details
        root = ET.Element("Details")
        for detail in wastage.Details:
            ET.SubElement(root, "Item", {
                "ProductID": str(detail.ProductID),
                "Quantity": f"{detail.Quantity:.3f}",
                "CostPrice": f"{detail.CostPrice:.3f}",
                "StockBefore": f"{detail.StockBefore:.3f}"
            })
        details_xml = ET.tostring(root, encoding='unicode')

        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get Active Shift ID if any
        active_shift_id = _shift_service.get_active_shift_id(user_id)
        
        try:
            # Execute Stored Procedure
            cursor.execute(SP.WASTAGE_SAVE_XML, (
                wastage.WastageID,
                wastage.WastageDate,
                user_id,
                active_shift_id,
                wastage.WarehouseID,
                wastage.TotalValue,
                wastage.Notes,
                details_xml
            ))
            
            row = cursor.fetchone()
            if not row:
                raise Exception("Failed to save wastage draft")
            
            wastage_id = row[0]
            conn.commit()
            return wastage_id
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def save_stocktake(self, stocktake: StockTakeSaveRequest, user_id: int) -> int:
        # Build XML for StockTake Details
        root = ET.Element("Details")
        for detail in stocktake.Details:
            ET.SubElement(root, "Item", {
                "ProductID": str(detail.ProductID),
                "SystemQuantity": f"{detail.SystemQuantity:.3f}",
                "ActualQuantity": f"{detail.ActualQuantity:.3f}",
                "CostPrice": f"{detail.CostPrice:.3f}"
            })
        details_xml = ET.tostring(root, encoding='unicode')

        conn = get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Execute Stored Procedure
            cursor.execute(SP.STOCKTAKE_SAVE_XML, (
                stocktake.StockTakeID,
                stocktake.StockTakeDate,
                user_id,
                stocktake.WarehouseID,
                stocktake.TotalDifferenceValue,
                stocktake.Notes,
                details_xml
            ))
            
            row = cursor.fetchone()
            if not row:
                raise Exception("Failed to save stocktake draft")
            
            stocktake_id = row[0]
            conn.commit()
            return stocktake_id
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def get_product_stock_cost(self, product_id: int, warehouse_id: int) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # Get stock quantity
            cursor.execute(SP.PRODUCT_STOCK_GET, (product_id, warehouse_id))
            qty_row = cursor.fetchone()
            qty = float(qty_row[0]) if qty_row else 0.0
            
            # Get average cost
            cursor.execute(SP.PRODUCT_AVGCOST_GET, (product_id, warehouse_id))
            cost_row = cursor.fetchone()
            cost = float(cost_row[0]) if cost_row else 0.0
            
            return {
                "ProductID": product_id,
                "WarehouseID": warehouse_id,
                "StockQuantity": qty,
                "CostPrice": cost
            }
        finally:
            conn.close()

