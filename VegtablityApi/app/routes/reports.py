from fastapi import APIRouter, Query, HTTPException, Request
from typing import Optional, List, Dict, Any
from app.services.report_service import report_service

router = APIRouter(prefix="/reports", tags=["Executive Reports & Analytics"])

def extract_database(request: Request, database: Optional[str] = None) -> Optional[str]:
    """استخراج قاعدة البيانات المستهدفة إما من الباراميتر أو من اسم الدومين الفرعي (Subdomain)"""
    if database and database.strip():
        return database.strip()
    
    # فحص الـ Host header للتعرف على الدومين الفرعي مثلا washa.vegtablity.cc
    host = request.headers.get("host", "").lower()
    if "washa" in host:
        return "WashaDB"
    elif "jawhara" in host:
        return "JawharaDB"
    elif "zatter" in host:
        return "zatterDB"
    elif "oman" in host:
        return "OmanCustmerDB"
    elif "vegtablity" in host or "veg" in host:
        return "VegtablityDB"
    
    return None

@router.get("/databases")
async def get_databases():
    """قائمة قواعد البيانات المدعومة"""
    return report_service.get_databases_list()

@router.get("/dashboard-summary")
async def get_dashboard_summary(
    request: Request,
    database: Optional[str] = Query(None, description="Database name/alias e.g. WashaDB, washa"),
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)")
):
    """ملخص المؤشرات والـ KPIs للداشبورد الرئيسية"""
    db = extract_database(request, database)
    try:
        return report_service.get_dashboard_summary(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading dashboard summary: {str(e)}")

@router.get("/product-profits")
async def get_product_profits(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(..., description="Start date (YYYY-MM-DD)"),
    end_date: str = Query(..., description="End date (YYYY-MM-DD)"),
    order_by: str = Query("ProfitDESC", description="ProfitDESC, SalesDESC, MarginDESC, NameASC")
):
    """تقرير أرباح وهوامش ربح الأصناف"""
    db = extract_database(request, database)
    try:
        return report_service.get_product_profits(database=db, start_date=start_date, end_date=end_date, order_by=order_by)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading product profits: {str(e)}")

@router.get("/invoice-profits")
async def get_invoice_profits(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير أرباح وهوامش الفواتير"""
    db = extract_database(request, database)
    try:
        return report_service.get_invoice_profits(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading invoice profits: {str(e)}")

@router.get("/sales-trends")
async def get_sales_trends(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...),
    period_type: str = Query("Daily", description="Daily, Monthly, Weekly")
):
    """تقرير ومنحنيات حركة المبيعات"""
    db = extract_database(request, database)
    try:
        return report_service.get_sales_trends(database=db, start_date=start_date, end_date=end_date, period_type=period_type)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading sales trends: {str(e)}")

@router.get("/top-customers")
async def get_top_customers(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير كبار العملاء مبيعاً"""
    db = extract_database(request, database)
    try:
        return report_service.get_top_customers(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading top customers: {str(e)}")

@router.get("/aging-debt")
async def get_aging_debt(
    request: Request,
    database: Optional[str] = Query(None),
    as_of_date: Optional[str] = Query(None)
):
    """تقرير أعمار الديون والفواتير غير المسددة"""
    db = extract_database(request, database)
    try:
        return report_service.get_aging_debt(database=db, as_of_date=as_of_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading aging debt: {str(e)}")

@router.get("/inventory-valuation")
async def get_inventory_valuation(
    request: Request,
    database: Optional[str] = Query(None)
):
    """تقرير جرد وتقييم المخزون"""
    db = extract_database(request, database)
    try:
        return report_service.get_inventory_valuation(database=db)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading inventory valuation: {str(e)}")

@router.get("/slow-moving-stock")
async def get_slow_moving_stock(
    request: Request,
    database: Optional[str] = Query(None),
    threshold_days: int = Query(30)
):
    """تقرير الأصناف الراكدة"""
    db = extract_database(request, database)
    try:
        return report_service.get_slow_moving_stock(database=db, threshold_days=threshold_days)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading slow moving stock: {str(e)}")

@router.get("/expenses-analysis")
async def get_expenses_analysis(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير تحليل المصروفات"""
    db = extract_database(request, database)
    try:
        return report_service.get_expenses_analysis(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading expenses analysis: {str(e)}")

@router.get("/customer-sales")
async def get_customer_sales(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...),
    partner_id: int = Query(0)
):
    """تقرير ملخص مبيعات العملاء"""
    db = extract_database(request, database)
    try:
        return report_service.get_customer_profitability(database=db, start_date=start_date, end_date=end_date, top_n=50)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading customer sales: {str(e)}")

@router.get("/category-profits")
async def get_category_profits(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير أرباح التصنيفات وهامش الربح لكل تصنيف"""
    db = extract_database(request, database)
    try:
        return report_service.get_category_profits(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading category profits: {str(e)}")

@router.get("/cashier-performance")
async def get_cashier_performance(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير أداء ومبيعات وخصومات الكاشير والمستخدمين"""
    db = extract_database(request, database)
    try:
        return report_service.get_cashier_performance(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading cashier performance: {str(e)}")

@router.get("/payment-methods")
async def get_payment_methods(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير تحليل طرق الدفع والمقبوضات"""
    db = extract_database(request, database)
    try:
        return report_service.get_payment_methods_breakdown(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading payment methods breakdown: {str(e)}")

@router.get("/customer-profitability")
async def get_customer_profitability(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...),
    top_n: int = Query(50)
):
    """تقرير ربحية العملاء ومعدل الربح لكل عميل"""
    db = extract_database(request, database)
    try:
        return report_service.get_customer_profitability(database=db, start_date=start_date, end_date=end_date, top_n=top_n)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading customer profitability: {str(e)}")

@router.get("/executive-pnl")
async def get_executive_pnl(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير ملخص الأرباح والخسائر التنفيذي (إجمالي المبيعات، تكلفة البضاعة، مجمل الربح، المصروفات، الهالك، وصافي الربح)"""
    db = extract_database(request, database)
    try:
        return report_service.get_executive_pnl_summary(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading executive PnL summary: {str(e)}")

@router.get("/wastage-analysis")
async def get_wastage_analysis(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير الهالك والتوالف وخسائر المواد"""
    db = extract_database(request, database)
    try:
        return report_service.get_wastage_analysis(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading wastage analysis: {str(e)}")

@router.get("/shifts-analytics")
async def get_shifts_analytics(
    request: Request,
    database: Optional[str] = Query(None),
    start_date: str = Query(...),
    end_date: str = Query(...)
):
    """تقرير حركة ومطابقة الورديات والكاشير"""
    db = extract_database(request, database)
    try:
        return report_service.get_shifts_analytics(database=db, start_date=start_date, end_date=end_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error loading shifts analytics: {str(e)}")

