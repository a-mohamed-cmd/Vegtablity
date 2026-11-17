from pydantic import BaseModel
from typing import Optional

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    username: str
    user_id: int
    role_name: Optional[str] = "admin"
    can_refund_payment_gateway: bool = False
    can_delete_sales_invoice: bool = False
    can_delete_purchase_invoice: bool = False


class CurrentUserResponse(BaseModel):
    user_id: int
    username: str
    role_name: Optional[str] = "admin"
    can_refund_payment_gateway: bool = False
    can_delete_sales_invoice: bool = False
    can_delete_purchase_invoice: bool = False
