from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List, Dict, Any
from app.core.database import get_db_connection, resolve_db_name
from app.core.db_procedures import StoredProcedures

class ReportService:
    @staticmethod
    def _row_to_dict(cursor, row):
        if not row:
            return {}
        columns = [column[0] for column in cursor.description]
        result = {}
        for col, val in zip(columns, row):
            if isinstance(val, (datetime, date)):
                result[col] = val.isoformat()
            elif isinstance(val, Decimal):
                result[col] = float(val)
            elif isinstance(val, (float, int, bool)) or val is None or isinstance(val, str):
                result[col] = val
            else:
                try:
                    result[col] = float(val)
                except (ValueError, TypeError):
                    result[col] = str(val)
        return result

    def get_databases_list(self) -> List[Dict[str, Any]]:
        """قائمة قواعد البيانات المتاحة مع المسميات والألوان للتبديل السريع"""
        return [
            {"id": "WashaDB", "name": "مغسلة وشا (Washa)", "code": "washa", "icon": "local_car_wash", "color": "#06B6D4"},
            {"id": "JawharaDB", "name": "شركة الجوهرة (Jawhara)", "code": "jawhara", "icon": "diamond", "color": "#8B5CF6"},
            {"id": "VegtablityDB", "name": "نظام الخضار والفواكه (Vegtablity)", "code": "veg", "icon": "eco", "color": "#10B981"},
            {"id": "zatterDB", "name": "مطاعم زعتر (Zatter)", "code": "zatter", "icon": "restaurant", "color": "#F59E0B"},
            {"id": "OmanCustmerDB", "name": "فرع سلطنة عمان (Oman)", "code": "oman", "icon": "public", "color": "#EC4899"},
        ]

    def get_dashboard_summary(self, database: Optional[str] = None, start_date: Optional[str] = None, end_date: Optional[str] = None) -> Dict[str, Any]:
        """ملخص المؤشرات التنفيذية للداشبورد الرئيسية عبر الإجراءات المخزنة"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            now = datetime.now()
            s_date = start_date.split()[0] if start_date else f"{now.year}-{now.month:02d}-01"
            e_date = end_date.split()[0] if end_date else now.strftime("%Y-%m-%d")

            # 1. Total Sales, Invoices Count, Paid vs Remaining via SP
            sales_stats = {}
            try:
                cursor.execute(StoredProcedures.REPORT_DASHBOARD_SALES_SUMMARY, (s_date, e_date))
                sales_row = cursor.fetchone()
                sales_stats = self._row_to_dict(cursor, sales_row) if sales_row else {}
            except Exception as e:
                print(f"Error executing REPORT_DASHBOARD_SALES_SUMMARY: {e}")

            # 2. Total Profit & Margin via SP
            profit_sum = 0.0
            margin_percent = 0.0
            p_rows = []
            try:
                cursor.execute(StoredProcedures.REPORT_PRODUCT_PROFITS, (s_date, e_date, 'ProfitDesc'))
                p_rows = cursor.fetchall()
            except Exception as e:
                print(f"Error executing REPORT_PRODUCT_PROFITS: {e}")

            if p_rows:
                cols = [c[0] for c in cursor.description]
                tot_rev = sum(float(r[cols.index('TotalRevenue')]) for r in p_rows if 'TotalRevenue' in cols and r[cols.index('TotalRevenue')] is not None)
                profit_sum = sum(float(r[cols.index('NetProfit')]) for r in p_rows if 'NetProfit' in cols and r[cols.index('NetProfit')] is not None)
                if tot_rev > 0:
                    margin_percent = round((profit_sum / tot_rev) * 100, 1)

            # 3. Total Unpaid Receivables via WPF's sp_Dashboard_GetCustomerDebts
            total_receivables = 0.0
            try:
                cursor.execute(StoredProcedures.DASHBOARD_GET_CUSTOMER_DEBTS)
                debts_rows = cursor.fetchall()
                if debts_rows:
                    cols = [c[0].lower() for c in cursor.description]
                    bal_idx = cols.index('balance') if 'balance' in cols else 2
                    total_receivables = sum(float(r[bal_idx]) for r in debts_rows if r[bal_idx] is not None and float(r[bal_idx]) > 0)
                else:
                    cursor.execute(StoredProcedures.REPORT_TOTAL_RECEIVABLES)
                    unpaid_row = cursor.fetchone()
                    total_receivables = float(unpaid_row[0]) if unpaid_row and unpaid_row[0] else 0.0
            except Exception as e:
                print(f"Error executing DASHBOARD_GET_CUSTOMER_DEBTS: {e}")
                try:
                    cursor.execute(StoredProcedures.REPORT_TOTAL_RECEIVABLES)
                    unpaid_row = cursor.fetchone()
                    total_receivables = float(unpaid_row[0]) if unpaid_row and unpaid_row[0] else 0.0
                except Exception as e2:
                    print(f"Error executing fallback REPORT_TOTAL_RECEIVABLES: {e2}")

            # 4. Inventory Total Value via SP
            inv_stats = {}
            try:
                cursor.execute(StoredProcedures.REPORT_INVENTORY_SUMMARY)
                inv_row = cursor.fetchone()
                inv_stats = self._row_to_dict(cursor, inv_row) if inv_row else {}
            except Exception as e:
                print(f"Error executing REPORT_INVENTORY_SUMMARY: {e}")

            # 1.1 Total Sales from JournalEntries (Revenue accounts)
            tot_sales_val = float(sales_stats.get('TotalSales', 0.0))
            try:
                cursor.execute("""
                    SELECT ISNULL(SUM(je.CreditAmount - je.DebitAmount), 0)
                    FROM [Accounting].[JournalEntries] je
                    INNER JOIN [Accounting].[ChartOfAccounts] a ON je.AccountID = a.AccountID
                    WHERE (a.AccountType = 'Revenue' OR a.AccountCode LIKE '4%')
                      AND CAST(je.EntryDate AS DATE) BETWEEN ? AND ?
                """, (s_date, e_date))
                j_row = cursor.fetchone()
                if j_row and j_row[0] is not None and float(j_row[0]) > 0:
                    tot_sales_val = float(j_row[0])
            except Exception as e:
                print(f"Error querying journal sales from JournalEntries: {e}")

            # Average ticket
            tot_invs = int(sales_stats.get('TotalInvoices', 0))
            avg_ticket = round(tot_sales_val / tot_invs, 2) if tot_invs > 0 else 0.0

            # Profit and Expenses calculation (خصم المصروفات من الأرباح بدقة)
            gross_profit = float(sales_stats.get('GrossProfit', profit_sum))
            total_expenses = float(sales_stats.get('TotalExpenses', 0.0))
            net_profit = float(sales_stats.get('NetProfit', gross_profit - total_expenses))
            if tot_sales_val > 0:
                margin_percent = round((net_profit / tot_sales_val) * 100, 1)

            return {
                "database": resolve_db_name(database),
                "start_date": s_date,
                "end_date": e_date,
                "total_sales": tot_sales_val,
                "gross_profit": round(gross_profit, 2),
                "total_expenses": round(total_expenses, 2),
                "total_profit": round(net_profit, 2),
                "profit_margin_percent": margin_percent,
                "total_invoices": tot_invs,
                "average_ticket": avg_ticket,
                "total_paid": float(sales_stats.get('TotalPaid', 0.0)),
                "total_credit": float(sales_stats.get('TotalCredit', 0.0)),
                "total_tax": 0.0,
                "total_discounts": float(sales_stats.get('TotalDiscounts', 0.0)),
                "total_receivables": round(total_receivables, 2),
                "inventory_items_count": int(inv_stats.get('TotalItemsCount', 0)),
                "inventory_cost_value": float(inv_stats.get('TotalCostValue', 0.0)),
                "inventory_sale_value": float(inv_stats.get('TotalSaleValue', 0.0)),
            }
        finally:
            cursor.close()
            conn.close()

    def get_product_profits(self, database: Optional[str], start_date: str, end_date: str, order_by: str = 'ProfitDesc') -> List[Dict[str, Any]]:
        """تقرير أرباح الأصناف عبر الإجراء المخزن [Reports].[sp_Report_ProductProfits]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            
            # Normalize order_by
            ob_clean = (order_by or "ProfitDesc").strip().upper()
            if "QTY" in ob_clean:
                norm_sp_order = "QtyDesc"
            elif "REVENUE" in ob_clean or "SALES" in ob_clean:
                norm_sp_order = "RevenueDesc"
            else:
                norm_sp_order = "ProfitDesc"

            cursor.execute(StoredProcedures.REPORT_PRODUCT_PROFITS, (s_date, e_date, norm_sp_order))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_invoice_profits(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير أرباح الفواتير عبر الإجراء المخزن [Reports].[sp_Report_InvoiceProfits]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_INVOICE_PROFITS, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_sales_trends(self, database: Optional[str], start_date: str, end_date: str, period_type: str = 'Daily') -> List[Dict[str, Any]]:
        """تقرير حركة المبيعات باليوم / الشهر عبر الإجراء المخزن [Reports].[sp_Report_SalesTrends]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_SALES_TRENDS, (s_date, e_date, period_type))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_top_customers(self, database: Optional[str], start_date: str, end_date: str, top_n: int = 10) -> List[Dict[str, Any]]:
        """تقرير كبار العملاء الأكثر مشتريات عبر الإجراء المخزن [Reports].[sp_Report_TopCustomers]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_TOP_CUSTOMERS, (s_date, e_date, top_n))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_aging_debt(self, database: Optional[str], as_of_date: Optional[str] = None) -> List[Dict[str, Any]]:
        """تقرير أعمار الديون والمستحقات الآجلة عبر الإجراء المخزن [Reports].[sp_Report_AgingDebt]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            target_date = as_of_date.split()[0] if as_of_date else datetime.now().strftime("%Y-%m-%d")
            cursor.execute(StoredProcedures.REPORT_AGING_DEBT, (target_date,))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_inventory_valuation(self, database: Optional[str]) -> List[Dict[str, Any]]:
        """تقرير تقييم المخزون الحالي عبر الإجراء المخزن [Reports].[sp_Report_InventoryValuation]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            cursor.execute(StoredProcedures.REPORT_INVENTORY_VALUATION)
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_slow_moving_stock(self, database: Optional[str], threshold_days: int = 30) -> List[Dict[str, Any]]:
        """تقرير الأصناف الراكدة عبر الإجراء المخزن [Reports].[sp_Report_SlowMovingStock]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            cursor.execute(StoredProcedures.REPORT_SLOW_MOVING_STOCK, (threshold_days,))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_expenses_analysis(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير تحليل بنود المصروفات التشغيلية عبر الإجراء المخزن [Reports].[sp_Report_ExpensesAnalysis]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_EXPENSES_ANALYSIS, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_category_profits(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير أرباح التصنيفات عبر الإجراء المخزن [Reports].[sp_Report_CategoryProfits]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_CATEGORY_PROFITS, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_cashier_performance(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير أداء ومبيعات الكاشير والمستخدمين عبر الإجراء المخزن [Reports].[sp_Report_CashierPerformance]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_CASHIER_PERFORMANCE, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_payment_methods_breakdown(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير تحليل طرق الدفع والمقبوضات عبر الإجراء المخزن [Reports].[sp_Report_PaymentMethodsBreakdown]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_PAYMENT_METHODS_BREAKDOWN, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_customer_profitability(self, database: Optional[str], start_date: str, end_date: str, top_n: int = 50) -> List[Dict[str, Any]]:
        """تقرير ربحية العملاء التفصيلي المشترك مع WPF عبر الإجراء المخزن [Sales].[sp_Report_CustomerSalesSummary] وسداد ورصيد العملاء من قيود اليومية"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_CUSTOMER_PROFITABILITY, (s_date, e_date, top_n))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_executive_pnl_summary(self, database: Optional[str], start_date: str, end_date: str) -> Dict[str, Any]:
        """تقرير ملخص الأرباح والخسائر التنفيذي عبر الإجراء المخزن [Reports].[sp_Report_ExecutivePnLSummary] مع التحقق من قيود اليومية"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            res = {}
            try:
                cursor.execute(StoredProcedures.REPORT_EXECUTIVE_PNL_SUMMARY, (s_date, e_date))
                row = cursor.fetchone()
                res = self._row_to_dict(cursor, row) if row else {}
            except Exception as e:
                print(f"Error executing REPORT_EXECUTIVE_PNL_SUMMARY: {e}")

            # التحقق من جلب الإيرادات والمصروفات مباشرة من قيود اليومية لضمان الدقة وفق معايير WPF
            try:
                cursor.execute("""
                    SELECT 
                        ISNULL(SUM(CASE WHEN a.AccountType = 'Revenue' OR a.AccountCode LIKE '4%' THEN (je.CreditAmount - je.DebitAmount) ELSE 0 END), 0) AS JournalRevenue,
                        ISNULL(SUM(CASE WHEN a.AccountType = 'COGS' OR a.AccountCode LIKE '51%' THEN (je.DebitAmount - je.CreditAmount) ELSE 0 END), 0) AS JournalCOGS,
                        ISNULL(SUM(CASE WHEN a.AccountType = 'Expenses' AND a.AccountCode NOT LIKE '51%' THEN (je.DebitAmount - je.CreditAmount) ELSE 0 END), 0) AS JournalExpenses
                    FROM [Accounting].[JournalEntries] je
                    INNER JOIN [Accounting].[ChartOfAccounts] a ON je.AccountID = a.AccountID
                    WHERE (a.AccountType IN ('Revenue', 'Expenses', 'COGS') OR a.AccountCode LIKE '4%' OR a.AccountCode LIKE '5%')
                      AND CAST(je.EntryDate AS DATE) BETWEEN ? AND ?
                """, (s_date, e_date))
                j_row = cursor.fetchone()
                if j_row:
                    j_rev = float(j_row[0]) if j_row[0] is not None else 0.0
                    j_cogs = float(j_row[1]) if j_row[1] is not None else 0.0
                    j_exp = float(j_row[2]) if j_row[2] is not None else 0.0

                    if j_rev > 0:
                        res['NetRevenue'] = j_rev
                        discounts = float(res.get('TotalDiscounts', 0.0))
                        res['GrossRevenue'] = j_rev + discounts
                    if j_cogs > 0:
                        res['CostOfGoodsSold'] = j_cogs
                    if j_exp > 0:
                        res['OperatingExpenses'] = j_exp

                    # إعادة حساب هوامش ومجمل وصافي الربح بدقة
                    net_rev = float(res.get('NetRevenue', 0.0))
                    cogs = float(res.get('CostOfGoodsSold', 0.0))
                    gross_profit = net_rev - cogs
                    res['GrossProfit'] = round(gross_profit, 2)
                    res['GrossProfitMarginPercent'] = round((gross_profit / net_rev * 100), 1) if net_rev > 0 else 0.0
                    
                    op_exp = float(res.get('OperatingExpenses', 0.0))
                    wastage = float(res.get('WastageLoss', 0.0))
                    net_op_profit = gross_profit - op_exp - wastage
                    res['NetOperatingProfit'] = round(net_op_profit, 2)
                    res['NetProfitMarginPercent'] = round((net_op_profit / net_rev * 100), 1) if net_rev > 0 else 0.0
            except Exception as e2:
                print(f"Error checking journal entries in get_executive_pnl_summary: {e2}")

            return res
        finally:
            cursor.close()
            conn.close()

    def get_wastage_analysis(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير الهالك والتوالف عبر الإجراء المخزن [Reports].[sp_Report_WastageAnalysis]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_WASTAGE_ANALYSIS, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

    def get_shifts_analytics(self, database: Optional[str], start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """تقرير حركة وأرباح الورديات عبر الإجراء المخزن [Reports].[sp_Report_ShiftsAnalytics]"""
        conn = get_db_connection(database)
        cursor = conn.cursor()
        try:
            s_date = start_date.split()[0]
            e_date = end_date.split()[0]
            cursor.execute(StoredProcedures.REPORT_SHIFTS_ANALYTICS, (s_date, e_date))
            rows = cursor.fetchall()
            return [self._row_to_dict(cursor, r) for r in rows] if rows else []
        finally:
            cursor.close()
            conn.close()

report_service = ReportService()

