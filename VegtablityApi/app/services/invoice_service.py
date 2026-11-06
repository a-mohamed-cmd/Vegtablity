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

    def search_invoices_by_phone(self, phone: str) -> dict:
        clean_phone = (phone or "").strip().replace(" ", "").replace("-", "").replace("+", "")
        if not clean_phone:
            return {
                "phone": "",
                "customer_name": "",
                "customer_address": "",
                "total_count": 0,
                "total_amount": 0.0,
                "invoices": [],
            }

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            try:
                cursor.execute(SP.INVOICE_SEARCH_BY_PHONE, (clean_phone,))
            except Exception:
                # Fallback direct SQL query if the stored procedure was not created yet
                cursor.execute("""
                    SELECT 
                        h.InvID,
                        h.InvType,
                        h.InvDate,
                        h.PartnerID,
                        h.WarehouseID,
                        h.TotalAmount,
                        h.Discount,
                        h.NetAmount,
                        h.PaidAmount,
                        h.Remainder,
                        h.UserID,
                        h.Notes,
                        h.IsPosted,
                        h.ReferenceNo,
                        h.PaymentAccountID,
                        h.ShiftID,
                        p.PartnerName,
                        p.Phone AS PartnerPhone,
                        p.Address AS PartnerAddress,
                        w.WarehouseName,
                        u.FullName AS UserName,
                        acc.AccountName AS PaymentAccountName,
                        acc.AccountCode AS PaymentAccountCode,
                        temp.CustomerName AS TempCustomerName,
                        temp.Phone AS TempPhone,
                        temp.Address AS TempAddress,
                        temp.DeliveryDate AS TempDeliveryDate,
                        temp.DeliveryTime AS TempDeliveryTime,
                        ISNULL((SELECT COUNT(*) FROM [Sales].[InvoiceDetails] d WHERE d.InvID = h.InvID), 0) AS ItemsCount
                    FROM [Sales].[InvoiceHeader] h
                    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
                    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
                    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
                    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
                    LEFT JOIN [Sales].[TempOrderInfo] temp ON h.InvID = temp.InvID
                    WHERE REPLACE(REPLACE(REPLACE(ISNULL(temp.Phone, ''), ' ', ''), '-', ''), '+', '') LIKE '%' + ? + '%'
                       OR REPLACE(REPLACE(REPLACE(ISNULL(p.Phone, ''), ' ', ''), '-', ''), '+', '') LIKE '%' + ? + '%'
                    ORDER BY h.InvDate DESC, h.InvID DESC
                """, (clean_phone, clean_phone))

            while cursor.description is None:
                if not cursor.nextset():
                    break

            invoices = []
            if cursor.description is not None:
                columns = [column[0] for column in cursor.description]
                for row in cursor.fetchall():
                    invoices.append(dict(zip(columns, row)))

            customer_name = ""
            customer_address = ""

            # Extract latest non-empty customer name & address from invoices (already ordered newest first)
            for inv in invoices:
                t_name = str(inv.get("TempCustomerName") or "").strip()
                p_name = str(inv.get("PartnerName") or "").strip()
                t_addr = str(inv.get("TempAddress") or "").strip()
                p_addr = str(inv.get("PartnerAddress") or "").strip()

                if not customer_name:
                    if t_name:
                        customer_name = t_name
                    elif p_name and p_name not in ("نقدي عام", "سند مباشر", "General Cash"):
                        customer_name = p_name

                if not customer_address:
                    if t_addr:
                        customer_address = t_addr
                    elif p_addr:
                        customer_address = p_addr

                if customer_name and customer_address:
                    break

            # If still missing name/address, check Partners table directly by phone
            if not customer_name or not customer_address:
                try:
                    cursor.execute("""
                        SELECT TOP 1 PartnerName, Address
                        FROM [Sales].[Partners]
                        WHERE REPLACE(REPLACE(REPLACE(ISNULL(Phone, ''), ' ', ''), '-', ''), '+', '') LIKE '%' + ? + '%'
                        ORDER BY PartnerID DESC
                    """, (clean_phone,))
                    p_row = cursor.fetchone()
                    if p_row:
                        if not customer_name and p_row[0]:
                            p_n = str(p_row[0]).strip()
                            if p_n not in ("نقدي عام", "سند مباشر", "General Cash"):
                                customer_name = p_n
                        if not customer_address and p_row[1]:
                            customer_address = str(p_row[1]).strip()
                except Exception:
                    pass

            total_amount = round(sum(float(inv.get("NetAmount") or 0.0) for inv in invoices), 3)

            return {
                "phone": clean_phone,
                "customer_name": customer_name,
                "customer_address": customer_address,
                "total_count": len(invoices),
                "total_amount": total_amount,
                "invoices": invoices,
            }
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

        # ✨ استخدام ShiftID القادم من الجوال/التطبيق مباشرة دون استعلامات إضافية
        active_shift_id = invoice.ShiftID or _shift_service.get_active_shift_id(user_id)

        # التحقق الآمن من وجود PartnerID و WarehouseID (حماية لعمليات المزامنة الأوفلاين)
        resolved_partner_id = invoice.PartnerID
        cursor.execute("SELECT 1 FROM [Sales].[Partners] WHERE PartnerID = ?", (resolved_partner_id,))
        if not cursor.fetchone():
            cursor.execute("SELECT TOP 1 PartnerID FROM [Sales].[Partners] ORDER BY PartnerID ASC")
            fb_partner = cursor.fetchone()
            if fb_partner:
                resolved_partner_id = fb_partner[0]

        resolved_warehouse_id = invoice.WarehouseID
        cursor.execute("SELECT 1 FROM [Settings].[Warehouses] WHERE WarehouseID = ?", (resolved_warehouse_id,))
        if not cursor.fetchone():
            cursor.execute("SELECT TOP 1 WarehouseID FROM [Settings].[Warehouses] ORDER BY WarehouseID ASC")
            fb_wh = cursor.fetchone()
            if fb_wh:
                resolved_warehouse_id = fb_wh[0]

        try:
            cursor.execute(SP.INVOICE_SAVE_XML, (
                invoice.InvID or 0,
                invoice.InvType,
                invoice.InvDate,
                resolved_partner_id,
                resolved_warehouse_id,
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

            inv_id = None
            while True:
                if cursor.description is not None:
                    row = cursor.fetchone()
                    if row and row[0] is not None:
                        try:
                            candidate_id = int(row[0])
                            if candidate_id > 0:
                                inv_id = candidate_id
                        except (ValueError, TypeError):
                            pass
                if not cursor.nextset():
                    break

            if not inv_id or inv_id <= 0:
                raise Exception("Failed to save invoice — no valid InvID returned from database")

            # ✅ حفظ تقسيم طرق الدفع (PaymentSplits) إذا وُجدت
            if invoice.PaymentSplits is not None:
                # حذف أي تقسيمات سابقة إن وُجدت لمنع التكرار عند التعديل
                cursor.execute("DELETE FROM [Sales].[InvoicePaymentSplits] WHERE InvID = ?", (inv_id,))
                for split in invoice.PaymentSplits:
                    cursor.execute(SP.INVOICE_SPLITS_SAVE, (inv_id, split.PaymentAccountID, split.Amount))

            conn.commit()
            return int(inv_id)
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

