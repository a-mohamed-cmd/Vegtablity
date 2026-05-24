from pydantic import BaseModel

class LicenseCheckRequest(BaseModel):
    MachineHWID: str
