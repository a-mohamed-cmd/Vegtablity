import xml.etree.ElementTree as ET
from app.core.database import get_db_connection
from app.schemas.invoices import InvoiceCreate

class InvoiceService:
    def get_all_invoices(self, inv_type: str = "Sales", search_text: str = None, shift_date: str = None):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            # Fallback to early date if no shift date is specified
            if not shift_date:
                shift_date = "1900-01-01"

            # Call the new sp_Invoice_GetAll_Pos stored procedure
            cursor.execute(
                "EXEC [Sales].[sp_Invoice_GetAll_Pos] @InvType=?, @shiftDate=?",
                (inv_type, shift_date)
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

            # 2. Call sp_Invoice_AddPayment
            cursor.execute(
                "EXEC [Sales].[sp_Invoice_AddPayment] @InvID=?, @PaymentAmount=?, @PaymentAccountID=?, @UserID=?",
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
            cursor.execute("{CALL [Sales].[sp_Invoice_GetByID] (?)}", (inv_id,))
            header_row = cursor.fetchone()
            if not header_row:
                return None
            
            columns = [column[0] for column in cursor.description]
            header = dict(zip(columns, header_row))
            
            # جلب التفاصيل
            cursor.execute("{CALL [Sales].[sp_InvoiceDetails_GetByInvID] (?)}", (inv_id,))
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
        try:
            # 1. Save Header and Details using XML in one call
            # We declare @InvID as a local variable in T-SQL to pass as an OUTPUT parameter,
            # which is the most robust way to execute SPs with OUTPUT parameters in pyodbc.
            cursor.execute("""
                DECLARE @InvID INT = 0;
                EXEC [Sales].[sp_Invoice_Save_XML] 
                    @InvID = @InvID OUTPUT,
                    @InvType = ?,
                    @InvDate = ?,
                    @PartnerID = ?,
                    @WarehouseID = ?,
                    @TotalAmount = ?,
                    @Discount = ?,
                    @NetAmount = ?,
                    @PaidAmount = ?,
                    @Remainder = ?,
                    @UserID = ?,
                    @Notes = ?,
                    @IsPosted = ?,
                    @ReferenceNo = ?,
                    @PaymentAccountID = ?,
                    @DetailsXml = ?;
            """, (
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
