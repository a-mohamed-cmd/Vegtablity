from fastapi import FastAPI, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from app.routes import auth, invoices, partners, products, purchase_quotes, shifts, sales_quotes, security, settings, vouchers, accounts, inventory, license_control, recipes
from app.routes.invoices import create_invoice

app = FastAPI(title="Vegtablity POS API", version="1.0.0")

# ... (Middleware stays same)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Welcome to Vegtablity POS API"}

# Include Routers
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
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


# Alias / Compatibility router for Flutter Mobile POS client (/sales/invoice)
sales_compat_router = APIRouter(prefix="/sales", tags=["Sales Invoices Compatible"])
sales_compat_router.add_api_route("/invoice", create_invoice, methods=["POST"])
app.include_router(sales_compat_router)

