from app.core.database import get_db_connection
from app.schemas.shift import ShiftOpenRequest, ShiftSummaryResponse

class ShiftService:
    def open_shift(self, user_id: int, request: ShiftOpenRequest) -> int:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # We use an OUTPUT parameter trick with pyodbc, or just call it and SELECT
            sql = """
            DECLARE @ShiftID INT;
            EXEC [Sales].[sp_Shift_Open] @UserID=?, @StartingCash=?, @ShiftID=@ShiftID OUTPUT;
            SELECT @ShiftID AS ShiftID;
            """
            cursor.execute(sql, (user_id, request.StartingCash))
            row = cursor.fetchone()
            conn.commit()
            if row and row.ShiftID:
                return row.ShiftID
            return 0
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def get_active_shift(self, user_id: int) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            sql = "EXEC [Sales].[sp_Shift_GetActive] @UserID=?"
            cursor.execute(sql, (user_id,))
            row = cursor.fetchone()
            if row:
                return {
                    "ShiftID": row.ShiftID,
                    "UserID": row.UserID,
                    "StartTime": row.StartTime,
                    "StartingCash": float(row.StartingCash),
                    "Status": row.Status
                }
            return None
        finally:
            conn.close()

    def close_shift(self, shift_id: int, ending_cash: float):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            sql = "EXEC [Sales].[sp_Shift_Close] @ShiftID=?, @EndingCash=?"
            cursor.execute(sql, (shift_id, ending_cash))
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def get_shift_summary(self, shift_id: int) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            sql = "EXEC [Sales].[sp_Shift_GetSummary] @ShiftID=?"
            cursor.execute(sql, (shift_id,))
            row = cursor.fetchone()
            if row:
                return {
                    "ShiftID": row.ShiftID,
                    "UserID": row.UserID,
                    "UserName": row.UserName,
                    "StartTime": row.StartTime,
                    "EndTime": row.EndTime,
                    "StartingCash": float(row.StartingCash),
                    "Status": row.Status,
                    "TotalSales": float(row.TotalSales),
                    "TotalPurchases": float(row.TotalPurchases),
                    "SalesCount": int(row.SalesCount),
                    "PurchasesCount": int(row.PurchasesCount),
                    "TotalPaidSales": float(row.TotalPaidSales),
                    "TotalRemainder": float(row.TotalRemainder),
                    "TotalPaidPurchases": float(row.TotalPaidPurchases),
                    "TotalPurchasesRemainder": float(row.TotalPurchasesRemainder),
                }
            return None
        finally:
            conn.close()
