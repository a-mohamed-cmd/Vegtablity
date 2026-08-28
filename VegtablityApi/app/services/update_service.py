import json
import os
from typing import Optional, Dict, Any

MANIFEST_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "updates_manifest.json")

class UpdateService:
    def __init__(self):
        self._manifest_cache: Optional[Dict[str, Any]] = None

    def _load_manifest(self) -> Dict[str, Any]:
        if not os.path.exists(MANIFEST_PATH):
            return {}
        try:
            with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                content = f.read()
                return json.loads(content, strict=False)
        except Exception as e:
            print(f"Error loading updates manifest: {e}")
            return {}


    def _save_manifest(self, data: Dict[str, Any]) -> bool:
        try:
            os.makedirs(os.path.dirname(MANIFEST_PATH), exist_ok=True)
            with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            self._manifest_cache = data
            return True
        except Exception as e:
            print(f"Error saving updates manifest: {e}")
            return False

    @staticmethod
    def _parse_version(v_str: str):
        """تحويل رقم الإصدار مثل 1.0.5 أو 2.4.0.1 إلى tuple رقمي موحد بـ 4 أرقام للمقارنة الدقيقة"""
        try:
            clean = v_str.strip().lstrip("vV")
            nums = [int(x) for x in clean.split(".") if x.isdigit()]
            while len(nums) < 4:
                nums.append(0)
            return tuple(nums[:4])
        except Exception:
            return (0, 0, 0, 0)

    def check_update(
        self,
        platform: str,
        flavor: str,
        current_version: str,
        current_version_code: Optional[int] = None
    ) -> Dict[str, Any]:
        manifest = self._load_manifest()

        p_key = platform.strip().lower()
        if p_key in ["windows", "win", "flutter_windows"]:
            p_key = "windows_flutter"

        f_key = flavor.strip().lower()
        if "washa" in f_key:
            f_key = "washa"
        elif "jawhara" in f_key:
            f_key = "jawhara"
        elif "zatter" in f_key:
            f_key = "zatter"
        elif "oman" in f_key:
            f_key = "oman"
        elif "license" in f_key or "manager" in f_key or "admin" in f_key:
            f_key = "license_manager"
        elif "vegtablity" in f_key or "veg" in f_key:
            f_key = "vegtablity"


        platform_manifest = manifest.get(p_key, {})
        flavor_info = platform_manifest.get(f_key)

        if not flavor_info:
            return {
                "has_update": False,
                "platform": p_key,
                "flavor": f_key,
                "current_version": current_version,
                "message": f"No update configuration found for platform '{p_key}' and flavor '{f_key}'"
            }

        latest_version = flavor_info.get("latest_version", "1.0.0")
        target_version_code = flavor_info.get("version_code")

        has_update = False
        if current_version_code is not None and target_version_code is not None:
            has_update = target_version_code > current_version_code
        else:
            has_update = self._parse_version(latest_version) > self._parse_version(current_version)

        return {
            "has_update": has_update,
            "platform": p_key,
            "flavor": f_key,
            "current_version": current_version,
            "latest_version": latest_version,
            "version_code": target_version_code,
            "min_supported_version": flavor_info.get("min_supported_version"),
            "is_mandatory": flavor_info.get("is_mandatory", False),
            "download_url": flavor_info.get("download_url"),
            "file_size_mb": flavor_info.get("file_size_mb"),
            "installer_name": flavor_info.get("installer_name"),
            "release_notes": flavor_info.get("release_notes", "")
        }

    def publish_update(self, platform: str, flavor: str, info: Dict[str, Any]) -> bool:
        manifest = self._load_manifest()
        p_key = platform.strip().lower()
        f_key = flavor.strip().lower()

        if p_key not in manifest:
            manifest[p_key] = {}

        manifest[p_key][f_key] = info
        return self._save_manifest(manifest)

update_service = UpdateService()
