from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class InvoiceDetail(BaseModel):
    ProductID: int
    UnitPrice: float
    Quantity: float
    TotalPrice: float
    CostPrice: float

class PaymentSplitItem(BaseModel):
    PaymentAccountID: int
    Amount: float

class InvoiceCreate(BaseModel):
    InvType: str # Sales or Purchase
    InvDate: datetime
    PartnerID: int
    WarehouseID: int
    TotalAmount: float
    Discount: float
    NetAmount: float
    PaidAmount: float
    Remainder: float
    Notes: Optional[str] = ""
    IsPosted: bool = False
    ReferenceNo: Optional[str] = None
    PaymentAccountID: Optional[int] = None
    TempCustomerName: Optional[str] = None
    TempPhone: Optional[str] = None
    TempAddress: Optional[str] = None
    TempDeliveryDate: Optional[str] = None
    TempDeliveryTime: Optional[str] = None
    Details: List[InvoiceDetail]
    PaymentSplits: Optional[List[PaymentSplitItem]] = None


class InvoiceResponse(BaseModel):
    InvID: int
    message: str
