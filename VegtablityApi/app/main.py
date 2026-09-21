import os
from fastapi import FastAPI, APIRouter
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.routes import auth, invoices, partners, products, purchase_quotes, shifts, sales_quotes, security, settings, vouchers, accounts, inventory, license_control, recipes, discounts, updates, reports
from app.routes.invoices import create_invoice

app = FastAPI(title="Vegtablity POS & Management API", version="1.0.0")

# ... (Middleware stays same)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files mount for In-App Auto-Updates (APKs, Installers, Zips)
static_updates_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "updates")
os.makedirs(static_updates_dir, exist_ok=True)
app.mount("/static/updates", StaticFiles(directory=static_updates_dir), name="updates_static")

# Include Routers
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(reports.router, tags=["Executive Reports"])
app.include_router(accounts.router, prefix="/accounts", tags=["Accounts"])
app.include_router(partners.router, prefix="/partners", tags=["Partners"])
app.include_router(products.router, prefix="/products", tags=["Products"])
app.include_router(invoices.router, prefix="/invoices", tags=["Invoices"])
app.include_router(purchase_quotes.router, prefix="/purchase-quotes", tags=["Purchase Quotations"])
app.include_router(sales_quotes.router, prefix="/sales-quotes", tags=["Sales Quotations"])
app.include_router(shifts.router, prefix="/shifts", tags=["Shifts"])
app.include_router(security.router, prefix="/security", tags=["Security"])
app.include_router(settings.router, prefix="/settings", tags=["Settings"])
app.include_router(vouchers.router, prefix="/vouchers", tags=["Vouchers"])
app.include_router(inventory.router, prefix="/inventory", tags=["Inventory"])
app.include_router(license_control.router, prefix="/ctrl", tags=["License Control"])
app.include_router(recipes.router, prefix="/recipes", tags=["Recipes"])
app.include_router(discounts.router)
app.include_router(updates.router)

# Alias / Compatibility router for Flutter Mobile POS client (/sales/invoice)
sales_compat_router = APIRouter(prefix="/sales", tags=["Sales Invoices Compatible"])
sales_compat_router.add_api_route("/invoice", create_invoice, methods=["POST"])
app.include_router(sales_compat_router)

# Mount Flutter Web Application if static/web exists
static_web_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "web")
os.makedirs(static_web_dir, exist_ok=True)

index_file = os.path.join(static_web_dir, "index.html")

@app.get("/")
async def serve_spa_root():
    if os.path.exists(index_file):
        return FileResponse(
            index_file,
            media_type="text/html",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0"
            }
        )
    return {
        "message": "Welcome to Vegtablity POS & Management API",
        "docs": "/docs",
        "web_status": "Ready for Flutter Web build in static/web"
    }

@app.get("/index.html")
async def serve_spa_index():
    if os.path.exists(index_file):
        return FileResponse(
            index_file,
            media_type="text/html",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0"
            }
        )
    return {"message": "Not Found"}

if os.path.exists(static_web_dir):
    app.mount("/", StaticFiles(directory=static_web_dir, html=False), name="web_app")



