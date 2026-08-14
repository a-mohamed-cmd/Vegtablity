from app.core.database import get_db_connection
from app.schemas.shift import ShiftOpenRequest, ShiftSummaryResponse
from app.core.db_procedures import StoredProcedures as SP

# ─── كاش الذاكرة الداخلية: user_id → ShiftID ───────────────────────────────
# يُعبأ عند فتح الوردية ويُمسح عند إغلاقها
_active_shift_cache: dict[int, int] = {}


class ShiftService:
    def open_shift(self, user_id: int, request: ShiftOpenRequest) -> int:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SHIFT_OPEN, (user_id, request.StartingCash))
            row = cursor.fetchone()
            conn.commit()
            if row and row.ShiftID:
                shift_id = row.ShiftID
                # ✨ تخزين ShiftID في الذاكرة عند فتح الوردية
                _active_shift_cache[user_id] = shift_id
                return shift_id
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
            cursor.execute(SP.SHIFT_GET_ACTIVE, (user_id,))
            row = cursor.fetchone()
            if row:
                shift_data = {
                    "ShiftID": row.ShiftID,
                    "UserID": row.UserID,
                    "StartTime": row.StartTime,
                    "StartingCash": float(row.StartingCash),
                    "Status": row.Status
                }
                if row.Status == 'Open':
                    _active_shift_cache[user_id] = row.ShiftID
                    return shift_data
            _active_shift_cache.pop(user_id, None)
            return None
        finally:
            conn.close()

    def get_active_shift_id(self, user_id: int) -> int | None:
        """
        ✨ يرجع ShiftID النشطة والمفتوحة فقط مباشرة من الداتابيز،
        مما يضمن عدم إرجاع أي وردية مغلقة أبداً.
        """
        shift = self.get_active_shift(user_id)
        if shift and shift.get("Status") == "Open":
            return shift["ShiftID"]
        _active_shift_cache.pop(user_id, None)
        return None

    def close_shift(self, shift_id: int, ending_cash: float):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SHIFT_CLOSE, (shift_id, ending_cash))
            conn.commit()
            # ✨ مسح الكاش بالكامل عند إغلاق الوردية
            user_ids_to_remove = [uid for uid, sid in _active_shift_cache.items() if sid == shift_id]
            for uid in user_ids_to_remove:
                _active_shift_cache.pop(uid, None)
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def get_shift_summary(self, shift_id: int) -> dict:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SHIFT_GET_SUMMARY, (shift_id,))
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
                    "TotalReceiptVouchers": float(row.TotalReceiptVouchers) if hasattr(row, 'TotalReceiptVouchers') and row.TotalReceiptVouchers is not None else 0.0,
                    "TotalPaymentVouchers": float(row.TotalPaymentVouchers) if hasattr(row, 'TotalPaymentVouchers') and row.TotalPaymentVouchers is not None else 0.0,
                    "Vouchers": self.get_shift_vouchers(shift_id),
                    "PaymentTotals": self.get_shift_payment_totals(shift_id)
                }
            return None
        finally:
            conn.close()

    def get_shift_payment_totals(self, shift_id: int) -> list:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SHIFT_GET_PAYMENT_TOTALS, (shift_id,))
            rows = cursor.fetchall()
            totals = []
            for row in rows:
                totals.append({
                    "AccountID": row.AccountID,
                    "AccountCode": row.AccountCode,
                    "PaymentMethodName": row.PaymentMethodName,
                    "InvType": row.InvType,
                    "TotalAmount": float(row.TotalAmount),
                    "SourceType": row.SourceType
                })
            return totals
        except Exception:
            return []
        finally:
            conn.close()

    def get_shift_vouchers(self, shift_id: int) -> list:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.SHIFT_GET_VOUCHERS, (shift_id,))
            rows = cursor.fetchall()
            vouchers = []
            for row in rows:
                vouchers.append({
                    "VoucherID": row.VoucherID,
                    "VoucherType": row.VoucherType,
                    "VoucherDate": row.VoucherDate,
                    "Amount": float(row.Amount),
                    "Description": row.Description,
                    "PartnerName": row.PartnerName,
                    "AccountName": row.AccountName
                })
            return vouchers
        except Exception as e:
            # If the SP doesn't exist yet, just return empty list to not crash
            return []
        finally:
            conn.close()

