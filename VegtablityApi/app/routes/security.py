from fastapi import APIRouter, HTTPException, status
from app.schemas.security import LicenseCheckRequest
from app.services.security_service import SecurityService

router = APIRouter()

@router.post("/check-license", response_model=dict)
async def check_license(request: LicenseCheckRequest):
    service = SecurityService()
    try:
        return service.check_license(request.MachineHWID)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"خطأ أثناء التحقق من الترخيص: {str(e)}"
        )
