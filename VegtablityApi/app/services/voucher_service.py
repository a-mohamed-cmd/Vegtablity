import xml.etree.ElementTree as ET
from typing import Dict, Any
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP


class VoucherService:

    def get_unpaid_invoices(self, partner_id: int, inv_type: str):
        """جلب الفواتير المُرحّلة وغير المسدّدة بالكامل للشريك"""
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.VOUCHER_GET_UNPAID_INVOICES,
                (partner_id, inv_type)
            )
            columns = [col[0] for col in cursor.description]
            results = []
            for row in cursor.fetchall():
                row_dict = dict(zip(columns, row))
                # تحويل الأرقام العشرية لـ float
                for key in ('TotalAmount', 'Discount', 'NetAmount', 'PaidAmount',
                            'VoucherPaidAmount', 'Remainder'):
                    if key in row_dict and row_dict[key] is not None:
                        row_dict[key] = float(row_dict[key])
                results.append(row_dict)
            return results
        finally:
            cursor.close()
            conn.close()

    def bulk_pay(self, partner_id: int, voucher_type: str, total_amount: float,
                 account_id: int, user_id: int, shift_id: int,
                 description: str, allocations: list):
        """
        سداد جماعي وإنشاء سند قبض/صرف في حالة غير مرحّلة.
        allocations: [{"InvID": int, "Amount": float}, ...]
        """
        # بناء XML للتوزيع
        root = ET.Element("Allocations")
        for alloc in allocations:
            item = ET.SubElement(root, "Item")
            item.set("InvID",  str(alloc["InvID"]))
            item.set("Amount", f"{float(alloc['Amount']):.3f}")
        xml_str = ET.tostring(root, encoding="unicode")

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.VOUCHER_BULK_PAYMENT, (
                partner_id,
                voucher_type,
                total_amount,
                account_id,
                user_id,
                shift_id,
                description,
                xml_str
            ))
            
            # Advance to the actual result set if there are triggers/messages
            while cursor.description is None:
                if not cursor.nextset():
                    break
                    
            if cursor.description is None:
                raise Exception("لم يقم الإجراء المُخزن بإرجاع بيانات السند (قد يكون هناك خطأ داخلي)")

            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if not row:
                raise Exception("لم يتم إنشاء السند")
            voucher = dict(zip(columns, row))
            # تحويل الأرقام
            if 'Amount' in voucher and voucher['Amount'] is not None:
                voucher['Amount'] = float(voucher['Amount'])
            conn.commit()
            return voucher
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()

    def get_accounts_for_voucher(self):
        """جلب الحسابات التشغيلية (صندوق/بنك) لاستخدامها في السندات"""
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT AccountID, AccountCode, AccountName
                FROM [Accounting].[ChartOfAccounts]
                WHERE IsTransactional = 1
                  AND (AccountName LIKE N'%صندوق%' OR AccountName LIKE N'%بنك%'
                       OR AccountName LIKE N'%كاش%')
                ORDER BY AccountCode
            """)
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        finally:
            cursor.close()
            conn.close()

    def get_voucher_allocations(self, voucher_id: int):
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT v.InvID, v.Amount, h.InvDate
                FROM [Accounting].[VoucherAllocations] v
                LEFT JOIN [Sales].[InvoiceHeader] h ON v.InvID = h.InvID
                WHERE v.VoucherID = ?
            """, (voucher_id,))
            columns = [col[0] for col in cursor.description]
            results = []
            for row in cursor.fetchall():
                row_dict = dict(zip(columns, row))
                if 'Amount' in row_dict and row_dict['Amount'] is not None:
                    row_dict['Amount'] = float(row_dict['Amount'])
                results.append(row_dict)
            return results
        finally:
            cursor.close()
            conn.close()

    def save_general_voucher(
        self,
        voucher_type: str,
        total_amount: float,
        account_id: int,
        user_id: int,
        shift_id: int = None,
        description: str = None,
        payment_method: str = 'Cash'
    ) -> Dict[str, Any]:
        """
        حفظ سند عام حر باستخدام الإجراء الجديد الذي يجلب معرّف العميل داخلياً.
        account_id: حساب الإيراد / المصروف المختار
        payment_method: AccountID لحساب الصندوق/البنك (NVARCHAR في الـ SP)
        """
        from datetime import datetime
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.VOUCHER_GENERAL_SAVE, (
                voucher_type,
                datetime.now(), # VoucherDate
                account_id,     # حساب الإيراد/المصروف
                total_amount,
                description,
                payment_method, # AccountID لحساب الصندوق
                user_id,
                shift_id        # رقم الوردية
            ))
            
            while cursor.description is None:
                if not cursor.nextset():
                    break
                    
            if cursor.description is None:
                raise Exception("لم يقم الإجراء المُخزن بإرجاع بيانات السند (قد يكون هناك خطأ داخلي)")

            columns = [col[0] for col in cursor.description]
            row = cursor.fetchone()
            if not row:
                raise Exception("لم يتم إنشاء السند")
            voucher = dict(zip(columns, row))
            
            if 'Amount' in voucher and voucher['Amount'] is not None:
                voucher['Amount'] = float(voucher['Amount'])

            conn.commit()
            return voucher
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()
            conn.close()
