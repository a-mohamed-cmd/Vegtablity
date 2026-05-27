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
                cursor.execute("""
                    SELECT TOP 1 AccountID 
                    FROM [Accounting].[ChartOfAccounts] 
                    WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1
                """)
                row = cursor.fetchone()
                if row:
                    payment_account_id = row[0]
                else:
                    # Fallback to any transactional account
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
            
            header['Details'] = details
            return header
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
                invoice.PaymentAccountID,
                active_shift_id,
                details_xml
            ))
            
            row = cursor.fetchone()
            if not row:
                raise Exception("Failed to save invoice")
            
            inv_id = row[0]
            conn.commit()
            return inv_id
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()
