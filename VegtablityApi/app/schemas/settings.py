from pydantic import BaseModel
from typing import Optional

class CompanySettingsResponse(BaseModel):
    id: Optional[int] = None
    CompanyName: Optional[str] = None
    Address: Optional[str] = None
    Phone: Optional[str] = None
    Email: Optional[str] = None
    Logo: Optional[str] = None
    CurrencySymbol: Optional[str] = None
    IsActive: Optional[bool] = None

    class Config:
        from_attributes = True

class PrinterSettingsSaveRequest(BaseModel):
    MachineHWID: str
    ConnectionType: str
    IPAddress: Optional[str] = None
    Port: Optional[int] = 9100
    BluetoothDevice: Optional[str] = None

