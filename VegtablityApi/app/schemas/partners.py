from pydantic import BaseModel
from typing import Optional, List

class Partner(BaseModel):
    PartnerID: int
    PartnerName: str
    PartnerType: str # Customer or Supplier
    Phone: Optional[str] = None
    Address: Optional[str] = None
    CurrentBalance: Optional[float] = 0.0
    AccountID: Optional[int] = None
    AccountCode: Optional[str] = None

class PartnerSearchResponse(BaseModel):
    partners: List[Partner]
