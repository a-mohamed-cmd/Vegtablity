from fastapi import APIRouter, Query, HTTPException, Body
from typing import Optional, Dict, Any
from app.services.update_service import update_service

router = APIRouter(prefix="/updates", tags=["App Auto-Updates"])

@router.get("/check")
async def check_for_updates(
    platform: str = Query(..., description="Platform: 'android', 'windows_flutter', or 'wpf'"),
    flavor: str = Query("washa", description="Flavor: 'washa', 'jawhara', 'vegtablity', 'zatter', 'oman'"),
    current_version: str = Query("1.0.0", description="Current app semantic version e.g. 1.0.0"),
    version_code: Optional[int] = Query(None, description="Android version code if applicable")
):
    """
    فحص توفر إصدار جديد لتطبيقات النظام (Android, Windows Flutter, WPF Desktop)
    """
    return update_service.check_update(
        platform=platform,
        flavor=flavor,
        current_version=current_version,
        current_version_code=version_code
    )

@router.get("/manifest")
async def get_all_manifest():
    """
    عرض كامل سجل ومواصفات التحديثات لكافة المنصات
    """
    return update_service._load_manifest()

@router.post("/publish")
async def publish_version_update(
    platform: str = Body(..., embed=True),
    flavor: str = Body(..., embed=True),
    update_info: Dict[str, Any] = Body(..., embed=True)
):
    """
    نشر أو تعديل بيانات إصدار جديد في السيرفر
    """
    success = update_service.publish_update(platform, flavor, update_info)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to save update manifest")
    return {"status": "success", "message": f"Successfully updated release info for {platform}/{flavor}"}
