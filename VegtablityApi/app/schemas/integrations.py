from pydantic import BaseModel
from typing import Optional


class ProviderConfigSaveRequest(BaseModel):
    ProviderID: int
    EnvironmentMode: str = "Sandbox"
    BaseUrl: Optional[str] = None
    MerchantID: Optional[str] = None
    PublicKey: Optional[str] = None
    SecretKeyEncrypted: Optional[str] = None
    WebhookSecret: Optional[str] = None
    CallbackUrl: Optional[str] = None
    DefaultCurrency: str = "KWD"
    CommissionPercent: float = 0.0
    FixedFee: float = 0.0
    AutoSendLinkOnInvoiceSave: bool = False
    PrintQrOnPos80mm: bool = True
    PrintQrOnPos58mm: bool = False
    PrintQrOnWpfInvoice: bool = False
    AutoSendWhatsApp: bool = True
    AutoSendSms: bool = False
    LinkExpiryHours: int = 24
    EnableConsolidatedLinks: bool = True
    DeductCommissionOnShiftClose: bool = False
    EnableGatewayRefunds: bool = False
    AllowPartialRefunds: bool = True
    AutoPostRefundJournalEntry: bool = True
    RefundChargeOnCustomer: bool = False
    ServiceChargeOnCustomer: bool = False
    ConnectionStatus: str = "Disconnected"
    StatusMessageAr: Optional[str] = None


class CreatePaymentLinkRequest(BaseModel):
    InvID: int
    PartnerID: Optional[int] = None
    ProviderID: int
    ProviderCode: str
    ExternalChargeID: Optional[str] = None
    ExternalInvoiceID: Optional[str] = None
    PaymentUrl: Optional[str] = None
    QrCodePayload: Optional[str] = None
    Amount: float
    CurrencyCode: str = "KWD"
    CustomerName: Optional[str] = None
    CustomerPhone: Optional[str] = None
    CustomerEmail: Optional[str] = None
    SendViaWhatsApp: bool = True
    SendViaSms: bool = False
    SendViaEmail: bool = False
    PrintQrMode: Optional[str] = "80mm"
    CreatedByUserID: Optional[int] = 1
    ShiftID: Optional[int] = None
    Notes: Optional[str] = None
    IsConsolidated: bool = False
    ConsolidatedInvoicesCsv: Optional[str] = None


class PaymentLinkRefundRequest(BaseModel):
    LinkID: int
    RefundAmount: float
    RefundReason: Optional[str] = "Customer Request"
    UserID: Optional[int] = 1


class TalabatOrderActionRequest(BaseModel):
    OrderToken: str
    OrderCode: str
    Action: str  # 'Accept', 'Reject', 'Prepared'
    PrepTimeMinutes: int = 15
    RejectionReason: Optional[str] = "ITEM_UNAVAILABLE"
    UserID: int = 1

