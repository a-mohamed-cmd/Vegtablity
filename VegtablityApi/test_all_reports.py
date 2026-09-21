import sys
import json
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from app.services.report_service import ReportService

service = ReportService()
db = "WashaDB"
s_date = "2020-01-01"
e_date = "2026-12-31"

print(f"=== TESTING ALL REPORT SERVICES FOR DATABASE '{db}' (WITH AUTOMATIC FALLBACK) ===")

tests = [
    ("Dashboard Summary", lambda: service.get_dashboard_summary(database=db, start_date=s_date, end_date=e_date)),
    ("Sales Trends", lambda: service.get_sales_trends(database=db, start_date=s_date, end_date=e_date, period_type="Daily")),
    ("Top Customers", lambda: service.get_top_customers(database=db, start_date=s_date, end_date=e_date, top_n=10)),
    ("Aging Debt", lambda: service.get_aging_debt(database=db, as_of_date=e_date)),
    ("Product Profits", lambda: service.get_product_profits(database=db, start_date=s_date, end_date=e_date, order_by="ProfitDESC")),
    ("Invoice Profits", lambda: service.get_invoice_profits(database=db, start_date=s_date, end_date=e_date)),
    ("Category Profits", lambda: service.get_category_profits(database=db, start_date=s_date, end_date=e_date)),
    ("Customer Profitability", lambda: service.get_customer_profitability(database=db, start_date=s_date, end_date=e_date, top_n=20)),
    ("Cashier Performance", lambda: service.get_cashier_performance(database=db, start_date=s_date, end_date=e_date)),
    ("Payment Methods", lambda: service.get_payment_methods_breakdown(database=db, start_date=s_date, end_date=e_date)),
    ("Inventory Valuation", lambda: service.get_inventory_valuation(database=db)),
    ("Slow Moving Stock", lambda: service.get_slow_moving_stock(database=db, threshold_days=30)),
    ("Expenses Analysis", lambda: service.get_expenses_analysis(database=db, start_date=s_date, end_date=e_date)),
    ("Executive PnL Summary", lambda: service.get_executive_pnl_summary(database=db, start_date=s_date, end_date=e_date)),
    ("Wastage Analysis", lambda: service.get_wastage_analysis(database=db, start_date=s_date, end_date=e_date)),
    ("Shifts Analytics", lambda: service.get_shifts_analytics(database=db, start_date=s_date, end_date=e_date)),
]

success_count = 0
failed_count = 0

for name, fn in tests:
    try:
        print(f"Testing {name}...", end=" ", flush=True)
        res = fn()
        count = len(res) if isinstance(res, list) else (1 if isinstance(res, dict) and res else 0)
        print(f"SUCCESS (Count: {count})", flush=True)
        success_count += 1
    except Exception as e:
        print(f"FAILED: {e}", flush=True)
        failed_count += 1

print(f"\n=== SUMMARY: {success_count} PASSED, {failed_count} FAILED ===", flush=True)
