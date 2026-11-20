"""Dedicated isolated gateway client for MyFatoorah API v2 (Vegtablity ERP & POS)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple


class MyFatoorahGateway:
    """Isolated MyFatoorah API v2 client aligned with Tap Payments architecture."""

    SANDBOX_BASE_URL = "https://apitest.myfatoorah.com"
    LIVE_KUWAIT_BASE_URL = "https://api.myfatoorah.com"

    @classmethod
    def resolve_base_url(cls, provider_cfg: Dict[str, Any]) -> str:
        configured = str(provider_cfg.get("BaseUrl") or "").strip().rstrip("/")
        if configured:
            return configured
        env_mode = str(provider_cfg.get("EnvironmentMode") or "Sandbox").strip().lower()
        return cls.LIVE_KUWAIT_BASE_URL if env_mode == "live" else cls.SANDBOX_BASE_URL

    @staticmethod
    def _headers(secret: str) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {secret}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    @staticmethod
    def extract_error_details(raw_text: str) -> str:
        """Extracts MyFatoorah ValidationErrors and Message cleanly without raw JSON clutter."""
        if not raw_text:
            return ""
        try:
            data = json.loads(raw_text)
        except Exception:
            return raw_text.strip()

        if not isinstance(data, dict):
            return raw_text.strip()

        parts: List[str] = []
        msg = str(data.get("Message") or data.get("message") or "").strip()
        if msg:
            parts.append(msg)

        val_errors = data.get("ValidationErrors")
        if isinstance(val_errors, list):
            for err in val_errors:
                if isinstance(err, dict):
                    name = str(err.get("Name") or "").strip()
                    detail = str(err.get("Error") or "").strip()
                    if detail:
                        parts.append(f"{name}: {detail}" if name else detail)

        fields = data.get("FieldsErrors")
        if isinstance(fields, list):
            for err in fields:
                if isinstance(err, dict):
                    name = str(err.get("Name") or "").strip()
                    detail = str(err.get("Error") or "").strip()
                    if detail:
                        parts.append(f"{name}: {detail}" if name else detail)

        return " | ".join(parts) if parts else raw_text.strip()

    def _post_v2(
        self,
        provider_cfg: Dict[str, Any],
        endpoint: str,
        payload: Dict[str, Any],
        timeout: int = 20,
    ) -> Tuple[Dict[str, Any], str]:
        secret = str(provider_cfg.get("SecretKeyEncrypted") or "").strip()
        if not secret:
            raise ValueError("المفتاح السري (API Token) لبوابة MyFatoorah غير مسجل في الإعدادات.")

        url = f"{self.resolve_base_url(provider_cfg)}/v2/{endpoint.lstrip('/')}"
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=self._headers(secret),
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw_text = resp.read().decode("utf-8", errors="ignore")
                data = json.loads(raw_text) if raw_text else {}
                return data, raw_text
        except urllib.error.HTTPError as http_err:
            err_body = http_err.read().decode("utf-8", errors="ignore")
            detail = self.extract_error_details(err_body)
            raise ValueError(f"❌ خطأ من بوابة MyFatoorah ({http_err.code}): {detail or err_body}") from http_err

    def initiate_payment(
        self,
        provider_cfg: Dict[str, Any],
        invoice_amount: float = 1.0,
        currency_iso: str = "KWD",
    ) -> Dict[str, Any]:
        """Calls POST /v2/InitiatePayment to verify connectivity and inspect enabled payment methods."""
        payload = {
            "InvoiceAmount": round(float(invoice_amount or 1.0), 3),
            "CurrencyIso": currency_iso or "KWD",
        }
        data, raw_text = self._post_v2(provider_cfg, "InitiatePayment", payload, timeout=15)
        if data.get("IsSuccess") is False:
            raise ValueError(self.extract_error_details(raw_text) or "فشل الاتصال ببوابة MyFatoorah.")
        methods = (data.get("Data") or {}).get("PaymentMethods") or []
        return {"IsSuccess": True, "PaymentMethods": methods, "RawJson": raw_text}

    def create_payment_link(
        self,
        provider_cfg: Dict[str, Any],
        inv_id: int,
        amount: float,
        currency: str,
        customer_name: str,
        phone_digits: str,
        description: str,
        callback_url: str,
        notification_option: str = "LNK",
        payment_method_id: Optional[int] = None,
        expiry_hours: int = 72,
    ) -> Dict[str, Any]:
        """Calls POST /v2/SendPayment (default) or POST /v2/ExecutePayment when PaymentMethodId is given."""
        expiry_dt = (datetime.utcnow() + timedelta(hours=expiry_hours)).strftime("%Y-%m-%dT%H:%M:%S")
        body: Dict[str, Any] = {
            "CustomerName": (customer_name or "عميل نقدي").strip(),
            "DisplayCurrencyIso": currency or "KWD",
            "MobileCountryCode": "+965",
            "CustomerMobile": phone_digits,
            "InvoiceValue": round(float(amount), 3),
            "Language": "ar",
            "CustomerReference": f"INV_{inv_id}",
            "UserDefinedField": (description or f"INV_{inv_id}")[:200],
            "ExpiryDate": expiry_dt,
            "CallBackUrl": callback_url,
            "ErrorUrl": callback_url,
        }

        if payment_method_id:
            body["PaymentMethodId"] = int(payment_method_id)
            endpoint = "ExecutePayment"
        else:
            body["NotificationOption"] = notification_option or "LNK"
            endpoint = "SendPayment"

        data, raw_text = self._post_v2(provider_cfg, endpoint, body, timeout=20)
        if data.get("IsSuccess") is False:
            detail = self.extract_error_details(raw_text)
            raise ValueError(f"❌ تعذر إنشاء رابط الدفع في MyFatoorah: {detail or 'خطأ غير معروف'}")

        d_obj = data.get("Data") or {}
        inv_ext_id = str(d_obj.get("InvoiceId") or "")
        pay_url = d_obj.get("InvoiceURL") or d_obj.get("PaymentURL")
        if not pay_url or not inv_ext_id:
            detail = self.extract_error_details(raw_text)
            raise ValueError(f"❌ لم تُعد MyFatoorah رابط دفع صالحاً: {detail or raw_text}")

        return {
            "ExternalChargeID": inv_ext_id,
            "ExternalInvoiceID": inv_ext_id,
            "PaymentUrl": pay_url,
            "RawJson": raw_text,
        }

    def get_payment_status(
        self,
        provider_cfg: Dict[str, Any],
        external_id: str,
        key_type: str = "InvoiceId",
    ) -> Tuple[str, str]:
        """Calls POST /v2/GetPaymentStatus and maps InvoiceStatus + InvoiceTransactions to system status."""
        data, raw_text = self._post_v2(
            provider_cfg,
            "GetPaymentStatus",
            {"Key": str(external_id), "KeyType": key_type},
            timeout=15,
        )
        if data.get("IsSuccess") is False:
            return "Pending", raw_text

        d_obj = data.get("Data") or {}
        inv_status = str(d_obj.get("InvoiceStatus") or "").strip().upper()
        txs = d_obj.get("InvoiceTransactions") or []

        has_success_tx = any(
            str(tx.get("TransactionStatus") or "").strip().upper() in ("SUCCSS", "SUCCESS", "PAID", "CAPTURED")
            for tx in txs
            if isinstance(tx, dict)
        )
        has_failed_only = bool(txs) and all(
            str(tx.get("TransactionStatus") or "").strip().upper() in ("FAILED", "ERROR", "DECLINED")
            for tx in txs
            if isinstance(tx, dict)
        )

        if inv_status in ("PAID", "CAPTURED", "SUCCESS") or has_success_tx:
            return "Paid", raw_text
        if inv_status == "REFUNDED":
            return "Refunded", raw_text
        if inv_status in ("PARTIALLYREFUNDED", "PARTIALLY_REFUNDED"):
            return "PartiallyRefunded", raw_text
        if inv_status in ("CANCELED", "CANCELLED", "EXPIRED"):
            return "Expired", raw_text
        if inv_status in ("FAILED", "DECLINED") or has_failed_only:
            return "Failed", raw_text
        return "Pending", raw_text

    def make_refund(
        self,
        provider_cfg: Dict[str, Any],
        link: Dict[str, Any],
        refund_amount: float,
        reason: str,
    ) -> str:
        """Calls POST /v2/MakeRefund and returns RefundId/RefundReference or raises detailed error."""
        ext_invoice_id = str(link.get("ExternalInvoiceID") or link.get("ExternalChargeID") or "").strip()
        if not ext_invoice_id or ext_invoice_id.startswith("MYFATOORAH_"):
            raise ValueError("رقم الفاتورة الخارجي في MyFatoorah غير صالح للاسترداد (ربما أُنشئ في وضع المحاكاة).")

        body = {
            "KeyType": "InvoiceId",
            "Key": ext_invoice_id,
            "RefundChargeOnCustomer": bool(provider_cfg.get("RefundChargeOnCustomer")),
            "ServiceChargeOnCustomer": bool(provider_cfg.get("ServiceChargeOnCustomer")),
            "Amount": round(float(refund_amount), 3),
            "Comment": (reason or "إرجاع مبلغ للعميل")[:200],
        }
        data, raw_text = self._post_v2(provider_cfg, "MakeRefund", body, timeout=20)
        if data.get("IsSuccess") is False:
            raise ValueError(self.extract_error_details(raw_text) or "Refused by MyFatoorah MakeRefund")

        d_obj = data.get("Data") or {}
        refund_id = d_obj.get("RefundId") or d_obj.get("RefundReference") or d_obj.get("Key")
        return str(refund_id or f"MF_REF_{link.get('LinkID')}")

    def get_refund_status(
        self,
        provider_cfg: Dict[str, Any],
        key: str,
        key_type: str = "InvoiceId",
    ) -> Dict[str, Any]:
        """Calls POST /v2/GetRefundStatus to inspect refund lifecycle at MyFatoorah."""
        data, raw_text = self._post_v2(
            provider_cfg,
            "GetRefundStatus",
            {"Key": str(key), "KeyType": key_type},
            timeout=15,
        )
        return {"Data": data.get("Data") or {}, "RawJson": raw_text}

    @staticmethod
    def _flatten_dict(obj: Dict[str, Any], prefix: str = "") -> Dict[str, str]:
        flat: Dict[str, str] = {}
        for k, v in obj.items():
            full_key = f"{prefix}.{k}" if prefix else str(k)
            if isinstance(v, dict):
                flat.update(MyFatoorahGateway._flatten_dict(v, full_key))
            elif v is None:
                flat[full_key] = ""
            else:
                flat[full_key] = str(v)
        return flat

    @classmethod
    def verify_webhook_signature(
        cls,
        webhook_secret: str,
        payload: Dict[str, Any],
        signature_header: Optional[str],
    ) -> bool:
        """Verifies MyFatoorah-Signature HMAC-SHA256 Base64 header when WebhookSecret is configured."""
        secret = (webhook_secret or "").strip()
        if not secret:
            return True
        if not signature_header:
            return False

        d_obj = payload.get("Data")
        if not isinstance(d_obj, dict):
            return False

        flat = cls._flatten_dict(d_obj)
        candidates: List[str] = []

        # Official alphabetical key=value serialization (MyFatoorah Webhook V2)
        sorted_items = sorted(flat.items(), key=lambda kv: kv[0])
        candidates.append(",".join(f"{k}={v}" for k, v in sorted_items))

        # Refund-specific documented key order
        refund_keys = ["Refund.Id", "Refund.Status", "Amount.ValueInBaseCurrency", "ReferencedInvoice.Id"]
        if any(k in flat for k in refund_keys):
            candidates.append(",".join(f"{k}={flat.get(k, '')}" for k in refund_keys))

        sig_bytes = signature_header.strip()
        for msg in candidates:
            digest = hmac.new(secret.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).digest()
            computed = base64.b64encode(digest).decode("ascii")
            if hmac.compare_digest(computed, sig_bytes):
                return True
        return False

    @staticmethod
    def parse_webhook_event(payload: Dict[str, Any]) -> Tuple[str, str]:
        """Extracts (external_invoice_id, target_status) from MyFatoorah V2 or flat webhook payloads."""
        event_name = str(
            (payload.get("Event") or {}).get("Name")
            if isinstance(payload.get("Event"), dict)
            else payload.get("Event") or ""
        ).upper()
        d_obj = payload.get("Data") if isinstance(payload.get("Data"), dict) else payload

        # Support both nested V2 objects (Invoice.Id, ReferencedInvoice.Id) and flat properties (InvoiceId)
        inv_obj = d_obj.get("Invoice") if isinstance(d_obj.get("Invoice"), dict) else {}
        tx_obj = d_obj.get("Transaction") if isinstance(d_obj.get("Transaction"), dict) else {}
        ref_inv_obj = d_obj.get("ReferencedInvoice") if isinstance(d_obj.get("ReferencedInvoice"), dict) else {}
        refund_obj = d_obj.get("Refund") if isinstance(d_obj.get("Refund"), dict) else {}

        ext_id = str(
            inv_obj.get("Id")
            or ref_inv_obj.get("Id")
            or d_obj.get("InvoiceId")
            or d_obj.get("ReferencedInvoiceId")
            or ""
        ).strip()

        if "REFUND" in event_name or refund_obj:
            rf_status = str(refund_obj.get("Status") or d_obj.get("RefundStatus") or "").upper()
            if rf_status == "REFUNDED":
                return ext_id, "Refunded"
            return ext_id, "Pending"

        st = str(
            tx_obj.get("Status")
            or inv_obj.get("Status")
            or d_obj.get("TransactionStatus")
            or d_obj.get("InvoiceStatus")
            or ""
        ).upper()

        if st in ("SUCCSS", "SUCCESS", "PAID", "CAPTURED"):
            return ext_id, "Paid"
        if st in ("CANCELED", "CANCELLED", "EXPIRED"):
            return ext_id, "Expired"
        if st in ("FAILED", "ERROR", "DECLINED"):
            return ext_id, "Failed"
        return ext_id, "Pending"
