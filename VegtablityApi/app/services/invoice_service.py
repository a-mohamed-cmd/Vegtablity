import xml.etree.ElementTree as ET
from app.core.database import get_db_connection
from app.schemas.invoices import InvoiceCreate
from app.core.db_procedures import StoredProcedures as SP
from app.services.shift_service import ShiftService as _ShiftService

_shift_service = _ShiftService()


class InvoiceService:
    def get_all_invoices(self, inv_type: str = "Sales", search_text: str = None, shift_id: int = None):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.INVOICE_GET_ALL_POS,
                (inv_type, shift_id)
            )
            columns = [column[0] for column in cursor.description]
            results = []
            for row in cursor.fetchall():
                results.append(dict(zip(columns, row)))
            
            # Filter search if present
            if search_text:
                search_text = search_text.lower()
                results = [r for r in results if search_text in str(r.get('PartnerName', '')).lower() or search_text in str(r.get('InvID', '')).lower()]
                
            return results
        finally:
            conn.close()

    def pay_invoice(self, inv_id: int, payment_amount: float, payment_account_id: int = None, user_id: int = 1) -> bool:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # 1. Resolve default cash PaymentAccountID if None
            if payment_account_id is None:
                cursor.execute("SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = 30 AND IsTransactional = 1")
                row = cursor.fetchone()
                if row:
                    payment_account_id = row[0]
                else:
                    cursor.execute("""
                        SELECT TOP 1 AccountID 
                        FROM [Accounting].[ChartOfAccounts] 
                        WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1
                    """)
                    row = cursor.fetchone()
                    if row:
                        payment_account_id = row[0]
                    else:
                        cursor.execute("SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE IsTransactional = 1")
                        row = cursor.fetchone()
                        payment_account_id = row[0] if row else 1

            # 2. Call sp_Invoice_AddPayment_pos
            cursor.execute(
                SP.INVOICE_ADD_PAYMENT,
                (inv_id, payment_amount, payment_account_id, user_id)
            )
            conn.commit()
            return True
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    def get_invoice_details(self, inv_id: int):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # جلب الرأس
            cursor.execute(SP.INVOICE_GET_BY_ID, (inv_id,))
            header_row = cursor.fetchone()
            if not header_row:
                return None
            
            columns = [column[0] for column in cursor.description]
            header = dict(zip(columns, header_row))
            
            # جلب التفاصيل
            cursor.execute(SP.INVOICE_DETAILS_GET, (inv_id,))
            detail_columns = [column[0] for column in cursor.description]
            details = []
            for d_row in cursor.fetchall():
                details.append(dict(zip(detail_columns, d_row)))
            
            # جلب تفاصيل تقسيم الدفع
            try:
                cursor.execute(SP.INVOICE_SPLITS_GET, (inv_id,))
                split_columns = [column[0] for column in cursor.description]
                splits = []
                for s_row in cursor.fetchall():
                    splits.append(dict(zip(split_columns, s_row)))
                header['PaymentSplits'] = splits
            except Exception:
                header['PaymentSplits'] = []
            
            header['Details'] = details
            return header
        finally:
            conn.close()

    def get_payment_splits(self, inv_id: int) -> list:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.INVOICE_SPLITS_GET, (inv_id,))
            columns = [column[0] for column in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        except Exception:
            return []
        finally:
            conn.close()

    def get_daily_orders(self, delivery_date: str):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.TEMPORDER_GETDAILYDELIVERIES, (delivery_date,))
            columns = [column[0] for column in cursor.description]
            orders = []
            for row in cursor.fetchall():
                ord_dict = dict(zip(columns, row))
                # Fetch details/items for this order/invoice
                cursor.execute(SP.INVOICE_DETAILS_GET, (ord_dict["InvID"],))
                detail_columns = [col[0] for col in cursor.description]
                details = []
                for d_row in cursor.fetchall():
                    details.append(dict(zip(detail_columns, d_row)))
                ord_dict["Details"] = details
                orders.append(ord_dict)
            return orders
        finally:
            conn.close()

    def save_invoice(self, invoice: InvoiceCreate, user_id: int):
        # Build XML for details
        root = ET.Element("Details")
        for detail in invoice.Details:
            ET.SubElement(root, "Item", {
                "ProductID": str(detail.ProductID),
                "UnitPrice": f"{detail.UnitPrice:.2f}",
                "Quantity": f"{detail.Quantity:.2f}",
                "TotalPrice": f"{detail.TotalPrice:.2f}",
                "CostPrice": f"{detail.CostPrice:.2f}"
            })
        details_xml = ET.tostring(root, encoding='unicode')

        conn = get_db_connection()
        cursor = conn.cursor()

        # Resolve fallback PaymentAccountID if PaidAmount > 0 and PaymentAccountID is None
        resolved_payment_account_id = invoice.PaymentAccountID
        if invoice.PaymentSplits and len(invoice.PaymentSplits) > 0 and resolved_payment_account_id is None:
            resolved_payment_account_id = invoice.PaymentSplits[0].PaymentAccountID

        if invoice.PaidAmount > 0 and resolved_payment_account_id is None:
            cursor.execute("SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = 30 AND IsTransactional = 1")
            fallback_row = cursor.fetchone()
            if fallback_row:
                resolved_payment_account_id = fallback_row[0]
            else:
                cursor.execute("""
                    SELECT TOP 1 AccountID 
                    FROM [Accounting].[ChartOfAccounts] 
                    WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1
                """)
                fallback_row2 = cursor.fetchone()
                if fallback_row2:
                    resolved_payment_account_id = fallback_row2[0]
                else:
                    cursor.execute("SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE IsTransactional = 1")
                    fallback_row3 = cursor.fetchone()
                    resolved_payment_account_id = fallback_row3[0] if fallback_row3 else 1

        # ✨ جلب ShiftID من الكاش مباشرة (صفر roundtrip إضافي)
        active_shift_id = _shift_service.get_active_shift_id(user_id)
        try:
            cursor.execute(SP.INVOICE_SAVE_XML, (
                invoice.InvType,
                invoice.InvDate,
                invoice.PartnerID,
                invoice.WarehouseID,
                invoice.TotalAmount,
                invoice.Discount,
                invoice.NetAmount,
                invoice.PaidAmount,
                invoice.Remainder,
                user_id,
                invoice.Notes,
                invoice.IsPosted,
                invoice.ReferenceNo,
                resolved_payment_account_id,
                active_shift_id,
                details_xml,
                invoice.TempCustomerName,
                invoice.TempPhone,
                invoice.TempAddress,
                invoice.TempDeliveryDate,
                invoice.TempDeliveryTime,
            ))
            
            row = cursor.fetchone()
            if not row:
                raise Exception("Failed to save invoice")
            
            inv_id = row[0]

            # ✅ حفظ تقسيم طرق الدفع (PaymentSplits) إذا وُجدت
            if invoice.PaymentSplits and len(invoice.PaymentSplits) > 0:
                for split in invoice.PaymentSplits:
                    cursor.execute(SP.INVOICE_SPLITS_SAVE, (inv_id, split.PaymentAccountID, split.Amount))

            conn.commit()
            return inv_id
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

