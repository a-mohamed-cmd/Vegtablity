import json
import re
import urllib.error
import urllib.request
import urllib.parse
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, Dict, Any, List
from app.core.database import get_db_connection
from app.core.db_procedures import StoredProcedures as SP
from app.services.integrations.myfatoorah_gateway import MyFatoorahGateway


def _extract_db_error_message(ex: Exception) -> str:
    """Extracts readable SQL Server RAISERROR/validation message from pyodbc exceptions."""
    raw = str(ex)
    # Remove ODBC prefixes like [Microsoft][ODBC Driver 17 for SQL Server][SQL Server]
    cleaned = re.sub(r"\[[^\]]+\]", "", raw)
    # Remove trailing pyodbc metadata like (50000) (SQLExecDirectW)
    cleaned = re.sub(r"\(\d+\)\s*\(SQLExecDirectW\)", "", cleaned)
    cleaned = cleaned.strip(" ;:()\"'")
    return cleaned or raw


def _serialize_row(columns: list, row: tuple) -> dict:
    res = {}
    for col, val in zip(columns, row):
        if isinstance(val, (datetime, date)):
            res[col] = val.isoformat()
        elif isinstance(val, Decimal):
            res[col] = float(val)
        elif isinstance(val, (bytes, bytearray)):
            res[col] = None
        else:
            res[col] = val
    return res


class IntegrationService:
    """
    Isolated service for Payment Gateways (Tap, MyFatoorah, UPayments) and Delivery Platforms (Talabat, Jahez).
    All operations are fault-isolated so existing API routes and POS operations are never affected.
    """

    def get_providers(self, only_enabled: bool = False) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.INTEGRATION_GET_PROVIDERS, (1 if only_enabled else 0,))
            if not cursor.description:
                return []
            cols = [c[0] for c in cursor.description]
            return [_serialize_row(cols, r) for r in cursor.fetchall()]
        except Exception:
            return []
        finally:
            cursor.close()
            conn.close()

    def is_talabat_configured_and_active(self) -> bool:
        try:
            providers = self.get_providers(only_enabled=True)
            for p in providers:
                if str(p.get("ProviderCode", "")).upper() == "TALABAT":
                    return bool(
                        p.get("IsEnabledInCompany")
                        and p.get("IsConfigured")
                        and str(p.get("ConnectionStatus", "")) in ("SandboxVerified", "LiveVerified")
                    )
            return False
        except Exception:
            return False

    def save_provider_config(self, payload: dict) -> Dict[str, Any]:
        conn_status = str(payload.get("ConnectionStatus", ""))
        if conn_status not in ("SandboxVerified", "LiveVerified"):
            raise ValueError("لا يمكن حفظ إعدادات البوابة إلا بعد نجاح اختبار الاتصال (Test Connection).")

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.INTEGRATION_SAVE_PROVIDER_CONFIG,
                (
                    int(payload.get("ProviderID")),
                    payload.get("EnvironmentMode", "Sandbox"),
                    payload.get("BaseUrl"),
                    payload.get("MerchantID"),
                    payload.get("PublicKey"),
                    payload.get("SecretKeyEncrypted"),
                    payload.get("WebhookSecret"),
                    payload.get("CallbackUrl"),
                    payload.get("DefaultCurrency", "KWD"),
                    float(payload.get("CommissionPercent", 0)),
                    float(payload.get("FixedFee", 0)),
                    1 if payload.get("AutoSendLinkOnInvoiceSave") else 0,
                    1 if payload.get("PrintQrOnPos80mm", True) else 0,
                    1 if payload.get("PrintQrOnPos58mm", False) else 0,
                    1 if payload.get("PrintQrOnWpfInvoice", False) else 0,
                    1 if payload.get("AutoSendWhatsApp", True) else 0,
                    1 if payload.get("AutoSendSms", False) else 0,
                    int(payload.get("LinkExpiryHours", 24)),
                    1 if payload.get("EnableConsolidatedLinks", True) else 0,
                    1 if payload.get("DeductCommissionOnShiftClose", False) else 0,
                    1 if payload.get("EnableGatewayRefunds", False) else 0,
                    1 if payload.get("AllowPartialRefunds", True) else 0,
                    1 if payload.get("AutoPostRefundJournalEntry", True) else 0,
                    1 if payload.get("RefundChargeOnCustomer", False) else 0,
                    1 if payload.get("ServiceChargeOnCustomer", False) else 0,
                    conn_status,
                    payload.get("StatusMessageAr"),
                ),
            )
            row = cursor.fetchone()
            cols = [c[0] for c in cursor.description] if cursor.description else []
            conn.commit()
            return _serialize_row(cols, row) if row else {"status": "saved"}
        finally:
            cursor.close()
            conn.close()

    def get_payment_links(
        self,
        provider_code: Optional[str] = None,
        status: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        search_text: Optional[str] = None,
        page_number: int = 1,
        page_size: int = 25,
    ) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.PAYMENT_LINK_GET_FILTERED,
                (
                    provider_code,
                    status,
                    start_date,
                    end_date,
                    search_text,
                    max(1, int(page_number or 1)),
                    max(1, int(page_size or 25)),
                ),
            )
            if not cursor.description:
                return []
            cols = [c[0] for c in cursor.description]
            return [_serialize_row(cols, r) for r in cursor.fetchall()]
        except Exception:
            return []
        finally:
            cursor.close()
            conn.close()

    def get_payment_links_paged(
        self,
        provider_code: Optional[str] = None,
        status: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        search_text: Optional[str] = None,
        page_number: int = 1,
        page_size: int = 25,
    ) -> Dict[str, Any]:
        safe_page = max(1, int(page_number or 1))
        safe_size = max(1, min(200, int(page_size or 25)))
        rows = self.get_payment_links(
            provider_code=provider_code,
            status=status,
            start_date=start_date,
            end_date=end_date,
            search_text=search_text,
            page_number=safe_page,
            page_size=safe_size,
        )
        total_count = int(rows[0].get("TotalRecordsCount", len(rows))) if rows else 0
        summary_paid = float(rows[0].get("SummaryPaidAmount", 0)) if rows else 0.0
        summary_pending = float(rows[0].get("SummaryPendingAmount", 0)) if rows else 0.0
        summary_refunded = float(rows[0].get("SummaryRefundedAmount", 0)) if rows else 0.0
        return {
            "items": rows,
            "total_count": total_count,
            "summary_paid": summary_paid,
            "summary_pending": summary_pending,
            "summary_refunded": summary_refunded,
            "page_number": safe_page,
            "page_size": safe_size,
        }

    def get_invoice_quick_info(self, inv_id: int) -> Optional[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(SP.PAYMENT_LINK_GET_INVOICE_QUICK_INFO, (int(inv_id),))
            if not cursor.description:
                return None
            row = cursor.fetchone()
            if not row:
                return None
            cols = [c[0] for c in cursor.description]
            return _serialize_row(cols, row)
        except Exception:
            return None
        finally:
            cursor.close()
            conn.close()

    def _clean_phone_digits(self, phone: Optional[str]) -> str:
        if not phone:
            return "50000000"
        digits = "".join(ch for ch in str(phone) if ch.isdigit())
        if digits.startswith("00965"):
            digits = digits[5:]
        if digits.startswith("965") and len(digits) > 8:
            digits = digits[3:]
        return digits if digits else "50000000"

    def _request_gateway_payment_link(
        self,
        provider_cfg: Dict[str, Any],
        inv_id: int,
        amount: float,
        currency: str,
        customer_name: str,
        customer_phone: str,
        description: str,
    ) -> Dict[str, Any]:
        code = str(provider_cfg.get("ProviderCode", "TAP")).upper()
        secret = str(provider_cfg.get("SecretKeyEncrypted") or "").strip()
        base_url = str(provider_cfg.get("BaseUrl") or "").strip().rstrip("/")
        callback_url = str(provider_cfg.get("CallbackUrl") or f"https://vegtablity.local/api/integrations/webhooks/{code.lower()}").strip()
        phone_digits = self._clean_phone_digits(customer_phone)
        cust_name = (customer_name or "عميل نقدي").strip()

        if not secret:
            raise ValueError(f"المفتاح السري (Secret Key) لبوابة {provider_cfg.get('ProviderNameAr', code)} غير مسجل في الإعدادات.")

        if code == "TAP":
            url = f"{base_url or 'https://api.tap.company/v2'}/charges"
            body = {
                "amount": round(float(amount), 3),
                "currency": currency or "KWD",
                "customer_initiated": True,
                "threeDSecure": True,
                "description": description or f"فاتورة مبيعات رقم #{inv_id}",
                "reference": {"transaction": f"INV_{inv_id}", "order": f"ORD_{inv_id}"},
                "receipt": {"email": False, "sms": True},
                "customer": {
                    "first_name": cust_name,
                    "phone": {"country_code": "965", "number": phone_digits},
                },
                "source": {"id": "src_all"},
                "post": {"url": callback_url},
                "redirect": {"url": callback_url},
            }
            req = urllib.request.Request(
                url,
                data=json.dumps(body).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {secret}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw_text = resp.read().decode("utf-8", errors="ignore")
                data = json.loads(raw_text) if raw_text else {}
                tx_obj = data.get("transaction") or {}
                pay_url = tx_obj.get("url") or data.get("url")
                ext_id = data.get("id")
                return {
                    "ExternalChargeID": ext_id,
                    "ExternalInvoiceID": ext_id,
                    "PaymentUrl": pay_url,
                    "RawJson": raw_text,
                }

        elif code == "MYFATOORAH":
            return MyFatoorahGateway().create_payment_link(
                provider_cfg=provider_cfg,
                inv_id=inv_id,
                amount=amount,
                currency=currency or "KWD",
                customer_name=cust_name,
                phone_digits=phone_digits,
                description=description or f"Invoice #{inv_id}",
                callback_url=callback_url,
            )

        elif code == "UPAYMENTS":
            env_mode = str(provider_cfg.get("EnvironmentMode", "Sandbox")).lower()
            default_base = "https://uapi.upayments.com/api/v1" if env_mode == "live" else "https://sandboxapi.upayments.com/api/v1"
            url = f"{base_url or default_base}/charge"
            order_id = f"ORD_{inv_id}_{int(datetime.utcnow().timestamp())}"
            body = {
                "order": {
                    "id": order_id,
                    "reference": f"INV_{inv_id}",
                    "description": description or f"Invoice #{inv_id}",
                    "currency": currency or "KWD",
                    "amount": round(float(amount), 3),
                },
                "language": "ar",
                "paymentGateway": {"src": "create-invoice"},
                "reference": {"id": f"INV_{inv_id}"},
                "customer": {
                    "uniqueId": f"CUST_{inv_id}",
                    "name": cust_name,
                    "mobile": f"+965{phone_digits}",
                },
                "returnUrl": callback_url,
                "cancelUrl": callback_url,
                "notificationUrl": callback_url,
            }
            req = urllib.request.Request(
                url,
                data=json.dumps(body).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {secret}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw_text = resp.read().decode("utf-8", errors="ignore")
                data = json.loads(raw_text) if raw_text else {}
                d_obj = data.get("data") or data
                pay_url = d_obj.get("link")
                track_id = d_obj.get("trackId") or order_id
                return {
                    "ExternalChargeID": str(track_id),
                    "ExternalInvoiceID": str(track_id),
                    "PaymentUrl": pay_url,
                    "RawJson": raw_text,
                }

        ext_charge_id = f"{code}_{inv_id}_{int(datetime.utcnow().timestamp())}"
        return {
            "ExternalChargeID": ext_charge_id,
            "ExternalInvoiceID": ext_charge_id,
            "PaymentUrl": f"https://pay.vegtablity.local/{code.lower()}/{ext_charge_id}",
            "RawJson": "{}",
        }

    def create_payment_link(self, payload: dict) -> Dict[str, Any]:
        providers = self.get_providers(only_enabled=False)
        req_provider_id = payload.get("ProviderID")
        req_provider_code = str(payload.get("ProviderCode") or "").upper()

        matched_provider = None
        for p in providers:
            if req_provider_id and int(p.get("ProviderID", 0)) == int(req_provider_id):
                matched_provider = p
                break
            if req_provider_code and str(p.get("ProviderCode", "")).upper() == req_provider_code:
                matched_provider = p
                break

        if not matched_provider:
            for p in providers:
                if str(p.get("ProviderCategory", "")) == "PAYMENT_GATEWAY" and p.get("IsConfigured"):
                    matched_provider = p
                    break

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            inv_id = int(payload.get("InvID"))
            provider_id = int(matched_provider.get("ProviderID", payload.get("ProviderID", 1))) if matched_provider else int(payload.get("ProviderID", 1))
            provider_code = str(matched_provider.get("ProviderCode", req_provider_code or "TAP")).upper() if matched_provider else (req_provider_code or "TAP")
            currency = str(payload.get("CurrencyCode") or (matched_provider.get("DefaultCurrency") if matched_provider else "KWD") or "KWD")
            amount = float(payload.get("Amount", 0))
            cust_name = payload.get("CustomerName") or "عميل نقدي"
            cust_phone = payload.get("CustomerPhone") or ""
            notes = payload.get("Notes") or f"فاتورة مبيعات رقم #{inv_id}"

            payment_url = payload.get("PaymentUrl")
            ext_charge_id = payload.get("ExternalChargeID")
            ext_invoice_id = payload.get("ExternalInvoiceID")
            raw_json_str = json.dumps(payload, ensure_ascii=False)

            if not payment_url and matched_provider:
                gw_res = self._request_gateway_payment_link(
                    provider_cfg=matched_provider,
                    inv_id=inv_id,
                    amount=amount,
                    currency=currency,
                    customer_name=cust_name,
                    customer_phone=cust_phone,
                    description=notes,
                )
                payment_url = gw_res.get("PaymentUrl")
                ext_charge_id = gw_res.get("ExternalChargeID")
                ext_invoice_id = gw_res.get("ExternalInvoiceID") or ext_charge_id
                raw_json_str = gw_res.get("RawJson") or raw_json_str

            if not payment_url:
                raise ValueError("تعذر الحصول على رابط الدفع من البوابة؛ تأكد من صحة مفاتيح الربط واتصال الإنترنت.")

            cursor.execute(
                SP.PAYMENT_LINK_SAVE,
                (
                    inv_id,
                    payload.get("PartnerID"),
                    provider_id,
                    provider_code,
                    ext_charge_id,
                    ext_invoice_id or ext_charge_id,
                    payment_url,
                    payload.get("QrCodePayload", payment_url),
                    amount,
                    currency,
                    cust_name,
                    cust_phone,
                    payload.get("CustomerEmail"),
                    1 if payload.get("SendViaWhatsApp", True) else 0,
                    1 if payload.get("SendViaSms", False) else 0,
                    1 if payload.get("SendViaEmail", False) else 0,
                    payload.get("PrintQrMode", "80mm"),
                    payload.get("CreatedByUserID", 1),
                    payload.get("ShiftID"),
                    raw_json_str,
                    notes,
                    1 if payload.get("IsConsolidated", False) else 0,
                    payload.get("ConsolidatedInvoicesCsv"),
                ),
            )
            row = cursor.fetchone()
            cols = [c[0] for c in cursor.description] if cursor.description else []
            conn.commit()
            return _serialize_row(cols, row) if row else {"PaymentUrl": payment_url, "ExternalChargeID": ext_charge_id}
        except ValueError:
            conn.rollback()
            raise
        except urllib.error.HTTPError as http_err:
            conn.rollback()
            err_body = http_err.read().decode("utf-8", errors="ignore")
            raise ValueError(f"❌ خطأ من بوابة الدفع ({http_err.code}): {err_body}")
        except Exception as ex:
            conn.rollback()
            raise ValueError(_extract_db_error_message(ex))
        finally:
            cursor.close()
            conn.close()

    def update_payment_link_status(
        self, link_id: int = 0, external_charge_id: Optional[str] = None, new_status: str = "Paid", raw_json: Optional[str] = None
    ) -> Dict[str, Any]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.PAYMENT_LINK_UPDATE_STATUS,
                (link_id, external_charge_id, new_status, raw_json),
            )
            row = cursor.fetchone()
            cols = [c[0] for c in cursor.description] if cursor.description else []
            conn.commit()
            return _serialize_row(cols, row) if row else {"status": new_status}
        except Exception as ex:
            conn.rollback()
            raise ValueError(f"❌ توقف تحديث الحالة / القيد المحاسبي: {_extract_db_error_message(ex)}")
        finally:
            cursor.close()
            conn.close()

    def _get_payment_link_by_id(self, link_id: int) -> Optional[Dict[str, Any]]:
        rows = self.get_payment_links(search_text=str(link_id), page_number=1, page_size=50)
        for r in rows:
            if int(r.get("LinkID") or 0) == int(link_id):
                return r
        return None

    def _find_provider_for_link(self, link: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        providers = self.get_providers(only_enabled=False)
        prov_id = link.get("ProviderID")
        prov_code = str(link.get("ProviderCode") or "").upper()
        for p in providers:
            if prov_id and int(p.get("ProviderID") or 0) == int(prov_id):
                return p
            if prov_code and str(p.get("ProviderCode") or "").upper() == prov_code:
                return p
        return None

    def _check_gateway_status(self, provider_cfg: Dict[str, Any], external_id: str) -> str:
        code = str(provider_cfg.get("ProviderCode") or "").upper()
        secret = str(provider_cfg.get("SecretKeyEncrypted") or "").strip()
        base_url = str(provider_cfg.get("BaseUrl") or "").strip().rstrip("/")
        env_mode = str(provider_cfg.get("EnvironmentMode") or "Sandbox").lower()
        if not secret or not external_id:
            return "Pending"

        try:
            if code == "TAP":
                url = f"{base_url or 'https://api.tap.company/v2'}/charges/{urllib.parse.quote(external_id)}"
                req = urllib.request.Request(
                    url,
                    headers={"Authorization": f"Bearer {secret}", "Accept": "application/json"},
                    method="GET",
                )
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.loads(resp.read().decode("utf-8", errors="ignore") or "{}")
                    st = str(data.get("status") or "").upper()
                    if st == "CAPTURED":
                        return "Paid"
                    if st == "REFUNDED":
                        return "Refunded"
                    if st == "PARTIALLY_REFUNDED":
                        return "PartiallyRefunded"
                    if st in ("CANCELLED", "ABANDONED", "TIMEDOUT", "VOID"):
                        return "Expired"
                    if st in ("FAILED", "DECLINED", "RESTRICTED"):
                        return "Failed"
                    return "Pending"

            elif code == "MYFATOORAH":
                status, _ = MyFatoorahGateway().get_payment_status(provider_cfg, external_id)
                return status

            elif code == "UPAYMENTS":
                default_base = "https://uapi.upayments.com/api/v1" if env_mode == "live" else "https://sandboxapi.upayments.com/api/v1"
                url = f"{base_url or default_base}/get-payment-status/{urllib.parse.quote(external_id)}"
                req = urllib.request.Request(
                    url,
                    headers={"Authorization": f"Bearer {secret}", "Accept": "application/json"},
                    method="GET",
                )
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.loads(resp.read().decode("utf-8", errors="ignore") or "{}")
                    d_obj = data.get("data") or data
                    res_val = str(d_obj.get("result") or data.get("result") or "").upper()
                    if res_val in ("CAPTURED", "PAID", "SUCCESS"):
                        return "Paid"
                    if res_val in ("CANCELED", "CANCELLED", "EXPIRED"):
                        return "Expired"
                    if res_val in ("NOT CAPTURED", "FAILED"):
                        return "Failed"
                    return "Pending"
        except Exception:
            return "Pending"
        return "Pending"

    def refresh_payment_link_status(self, link_id: int) -> Dict[str, Any]:
        record = self._get_payment_link_by_id(link_id)
        if not record:
            raise ValueError("⚠️ لم يتم العثور على رابط الدفع المراد فحص حالته.")

        old_status = str(record.get("LinkStatus") or "Pending")
        cfg = self._find_provider_for_link(record)
        if not cfg:
            raise ValueError("⚠️ لم يتم العثور على إعدادات البوابة المرتبطة بهذا الرابط.")

        ext_id = str(record.get("ExternalChargeID") or record.get("ExternalInvoiceID") or "").strip()
        if not ext_id:
            return {
                "success": True,
                "link_id": link_id,
                "previous_status": old_status,
                "new_status": old_status,
                "changed": False,
                "message_ar": f"ℹ️ حالة الرابط #{link_id} الحالية: ({old_status}).",
            }

        new_status = self._check_gateway_status(cfg, ext_id)
        if new_status.lower() != old_status.lower():
            self.update_payment_link_status(
                link_id=link_id,
                external_charge_id=ext_id,
                new_status=new_status,
            )
            return {
                "success": True,
                "link_id": link_id,
                "previous_status": old_status,
                "new_status": new_status,
                "changed": True,
                "message_ar": f"✅ تم تحديث حالة الرابط #{link_id} إلى ({new_status}) وترحيل القيد المحاسبي بنجاح.",
            }

        return {
            "success": True,
            "link_id": link_id,
            "previous_status": old_status,
            "new_status": old_status,
            "changed": False,
            "message_ar": f"ℹ️ حالة الرابط #{link_id} لدى البوابة ما زالت ({old_status}).",
        }

    @staticmethod
    def _normalize_tap_refund_reason(reason: Optional[str]) -> str:
        txt = (reason or "").strip().lower()
        if any(k in txt for k in ("duplicate", "مكرر", "تكرار")):
            return "duplicate"
        if any(k in txt for k in ("fraud", "احتيال")):
            return "fraudulent"
        return "requested_by_customer"

    @staticmethod
    def _extract_gateway_error_details(raw_text: str) -> str:
        if not raw_text:
            return ""
        try:
            parsed = json.loads(raw_text)
        except Exception:
            return raw_text.strip()

        parts: List[str] = []
        if isinstance(parsed, dict):
            # Tap: {"errors": [{"code": "...", "description": "..."}]}
            errs = parsed.get("errors")
            if isinstance(errs, list):
                for item in errs:
                    if isinstance(item, dict):
                        desc = item.get("description") or item.get("message") or item.get("Message")
                        if desc:
                            parts.append(str(desc))
            elif isinstance(errs, dict):
                for k, v in errs.items():
                    if isinstance(v, list):
                        parts.extend(str(x) for x in v if x)
                    elif v:
                        parts.append(f"{k}: {v}")

            # MyFatoorah: {"Message": "...", "ValidationErrors": [{"Name": "...", "Error": "..."}]}
            val_errs = parsed.get("ValidationErrors")
            if isinstance(val_errs, list):
                for item in val_errs:
                    if isinstance(item, dict):
                        err = item.get("Error") or item.get("error") or item.get("Message")
                        name = item.get("Name") or item.get("name")
                        if err:
                            parts.append(f"{name}: {err}" if name else str(err))

            for key in ("Message", "message", "description", "error_description", "error", "detail"):
                val = parsed.get(key)
                if val and str(val).strip().lower() not in ("validation errors", "bad request"):
                    parts.append(str(val).strip())

        if not parts and isinstance(parsed, dict) and parsed.get("Message"):
            parts.append(str(parsed.get("Message")))

        unique_parts: List[str] = []
        for p in parts:
            p_clean = p.strip()
            if p_clean and p_clean not in unique_parts:
                unique_parts.append(p_clean)
        return " | ".join(unique_parts) if unique_parts else raw_text.strip()

    def _translate_gateway_refund_error(
        self,
        provider_code: str,
        http_status: Optional[int] = None,
        raw_text: str = "",
        fallback_exc: Optional[Exception] = None,
    ) -> str:
        code = (provider_code or "").upper()
        provider_names = {
            "TAP": "Tap Payments",
            "MYFATOORAH": "MyFatoorah",
            "UPAYMENTS": "UPayments",
        }
        gw_name = provider_names.get(code, code or "بوابة الدفع")
        detail = self._extract_gateway_error_details(raw_text)
        haystack = f"{detail} {raw_text} {fallback_exc or ''}".lower()

        if http_status == 401 or any(k in haystack for k in ("unauthorized", "invalid token", "invalid key", "authentication", "api key", "bearer")):
            return f"❌ فشل التحقق من مفتاح الربط السري (Secret Key) لبوابة {gw_name}؛ يرجى مراجعة المفتاح وبيئة التشغيل (Sandbox/Live) في إعدادات الربط."

        if http_status == 403 or any(k in haystack for k in ("permission", "not allowed", "not enabled", "forbidden", "privilege", "not authorized", "refund feature")):
            return f"⚠️ خدمة الاسترداد غير مفعّلة في حساب التاجر لدى بوابة {gw_name} أو أن الحساب لا يملك صلاحية تنفيذ الاسترداد."

        if any(k in haystack for k in ("already refunded", "fully refunded", "has already been refunded", "already reversed")):
            return f"ℹ️ تم استرداد كامل مبلغ هذه الفاتورة مسبقاً لدى بوابة {gw_name}."

        if any(k in haystack for k in ("exceed", "greater than", "remaining amount", "more than paid", "more than captured", "refundable amount", "over refund", "maximum refund")):
            return f"⚠️ مبلغ الاسترداد المطلوب يتجاوز الرصيد المتاح للاسترداد في هذه العملية لدى بوابة {gw_name}."

        if any(k in haystack for k in ("insufficient", "no enough balance", "not enough balance", "insufficient balance", "insufficient funds", "wallet balance")):
            return f"⚠️ الرصيد المتاح في حساب التاجر لدى بوابة {gw_name} غير كافٍ لتغطية مبلغ الاسترداد المطلوب."

        if any(k in haystack for k in ("not captured", "not paid", "no paid transaction", "cannot be refunded", "invalid status", "unpaid", "pending payment", "transaction is not")):
            return f"⚠️ لا يمكن استرداد هذه الفاتورة لدى بوابة {gw_name} لأن عملية الدفع غير محصلة أو غير مدفوعة بعد؛ يرجى فحص حالة الرابط أولاً."

        if http_status == 404 or any(k in haystack for k in ("charge not found", "invoice not found", "order not found", "invalid charge", "invalid invoice", "invalid order", "not found", "does not exist")):
            return f"⚠️ لم يتم العثور على معاملة الدفع الأصلية لدى بوابة {gw_name} (تحقق من رقم المرجع أو أن الرابط لم يُنشأ بوضع تجريبي/ببيئة مختلفة)."

        if any(k in haystack for k in ("currency",)):
            return f"⚠️ عملة طلب الاسترداد غير مطابقة لعملة معاملة الدفع الأصلية لدى بوابة {gw_name}."

        if http_status == 429 or any(k in haystack for k in ("too many requests", "rate limit", "throttle")):
            return f"⏳ تم إرسال طلبات متكررة لبوابة {gw_name} وتجاوز الحد المؤقت؛ يرجى الانتظار دقيقة ثم المحاولة مجدداً."

        if any(k in haystack for k in ("knet", "payment method", "settled", "expired", "days", "time limit", "window")):
            return f"⚠️ تعذر الاسترداد الآلي لدى بوابة {gw_name} بسبب انتهاء مهلة الاسترداد أو أن وسيلة الدفع لا تدعم الاسترداد المباشر."

        if any(k in haystack for k in ("timed out", "timeout", "connection", "name resolution", "getaddrinfo", "ssl", "network", "unreachable")):
            return f"🌐 تعذر الاتصال بخادم بوابة {gw_name} أو انتهت مهلة الاستجابة؛ يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى."

        if http_status in (500, 502, 503, 504):
            return f"🛠️ خادم بوابة {gw_name} غير متاح مؤقتاً (رمز {http_status})؛ يرجى المحاولة بعد قليل."

        if any(k in haystack for k in ("minimum", "min amount", "greater than 0", "must be positive", "amount must")):
            return f"⚠️ مبلغ الاسترداد المدخل غير مطابق للحد الأدنى المسموح به لدى بوابة {gw_name}."

        if any(k in haystack for k in ("reason", "comment", "validation", "required", "invalid")):
            return f"⚠️ رفضت بوابة {gw_name} بيانات طلب الاسترداد (راجع المبلغ أو سبب الاسترداد){': ' + detail if detail else '.'}"

        if detail:
            return f"❌ تعذر تنفيذ الاسترداد عبر بوابة {gw_name}: {detail}"

        return f"❌ تعذر تنفيذ الاسترداد عبر بوابة {gw_name}؛ يرجى مراجعة إعدادات البوابة وحالة العملية."

    def _process_gateway_refund(
        self,
        provider_cfg: Dict[str, Any],
        link: Dict[str, Any],
        refund_amount: float,
        reason: str,
    ) -> str:
        code = str(provider_cfg.get("ProviderCode") or "").upper()
        secret = str(provider_cfg.get("SecretKeyEncrypted") or "").strip()
        base_url = str(provider_cfg.get("BaseUrl") or "").strip().rstrip("/")
        env_mode = str(provider_cfg.get("EnvironmentMode") or "Sandbox").lower()
        ext_id = str(link.get("ExternalChargeID") or link.get("ExternalInvoiceID") or "").strip()
        payment_url = str(link.get("PaymentUrl") or "").strip()
        currency = str(link.get("CurrencyCode") or provider_cfg.get("DefaultCurrency") or "KWD")
        callback_url = str(provider_cfg.get("CallbackUrl") or f"https://vegtablity.local/api/integrations/webhooks/{code.lower()}").strip()

        if not ext_id or not secret:
            return f"REF_{link.get('LinkID')}_{int(datetime.utcnow().timestamp())}"

        if "pay.vegtablity.local" in payment_url.lower():
            raise ValueError("⚠️ هذا الرابط أُنشئ محلياً في وضع المحاكاة بدون معاملة دفع حقيقية لدى البوابة، لذا لا يمكن تنفيذ استرداد إلكتروني له.")

        try:
            if code == "TAP":
                url = f"{base_url or 'https://api.tap.company/v2'}/refunds"
                payload = {
                    "charge_id": ext_id,
                    "amount": round(float(refund_amount), 3),
                    "currency": currency,
                    "description": (reason or f"استرداد فاتورة رقم #{link.get('InvID')}").strip(),
                    "reason": self._normalize_tap_refund_reason(reason),
                    "reference": {"merchant": f"REF_LNK_{link.get('LinkID')}_INV_{link.get('InvID')}"},
                }
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json", "Accept": "application/json"},
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=20) as resp:
                    raw_resp = resp.read().decode("utf-8", errors="ignore")
                    data = json.loads(raw_resp or "{}")
                    tap_status = str(data.get("status") or "").upper()
                    if tap_status in ("DECLINED", "FAILED", "CANCELLED"):
                        raise ValueError(self._translate_gateway_refund_error(code, resp.status, raw_resp))
                    return str(data.get("id") or f"TAP_REF_{link.get('LinkID')}")

            elif code == "MYFATOORAH":
                return MyFatoorahGateway().make_refund(provider_cfg, link, refund_amount, reason)

            elif code == "UPAYMENTS":
                default_base = "https://uapi.upayments.com/api/v1" if env_mode == "live" else "https://sandboxapi.upayments.com/api/v1"
                url = f"{base_url or default_base}/create-refund"
                payload = {
                    "order_id": ext_id,
                    "total_price": round(float(refund_amount), 3),
                    "customer_first_name": link.get("CustomerName") or "Customer",
                    "customer_email": link.get("CustomerEmail") or "refund@vegtablity.local",
                    "customer_mobile_number": f"+965{self._clean_phone_digits(link.get('CustomerPhone'))}",
                    "reference_id": f"REF_{link.get('LinkID')}",
                    "notify_url": callback_url,
                }
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json", "Accept": "application/json"},
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=20) as resp:
                    raw_resp = resp.read().decode("utf-8", errors="ignore")
                    data = json.loads(raw_resp or "{}")
                    if data.get("status") is False:
                        raise ValueError(self._translate_gateway_refund_error(code, resp.status, raw_resp))
                    d_obj = data.get("data") or data
                    return str(
                        d_obj.get("refund_order_id")
                        or d_obj.get("refundOrderId")
                        or d_obj.get("refund_arn")
                        or d_obj.get("refundArn")
                        or f"UP_REF_{link.get('LinkID')}"
                    )

        except urllib.error.HTTPError as http_err:
            err_body = http_err.read().decode("utf-8", errors="ignore")
            raise ValueError(self._translate_gateway_refund_error(code, http_err.code, err_body))
        except ValueError:
            raise
        except Exception as ex:
            raise ValueError(self._translate_gateway_refund_error(code, None, str(ex), ex))

        return f"REF_{link.get('LinkID')}_{int(datetime.utcnow().timestamp())}"

    def can_user_refund_payment_gateway(self, user_id: int) -> bool:
        """
        التحقق من صلاحية المستخدم في تنفيذ الاسترداد المالي لبوابات الدفع قبل الاتصال بالبوابة.
        """
        if not user_id or user_id <= 0:
            return False

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            try:
                cursor.execute(SP.USER_CAN_REFUND_PAYMENT_GATEWAY, (user_id,))
                row = cursor.fetchone()
                return bool(row[0]) if row else False
            except Exception:
                # توافق مع قواعد البيانات عبر فحص صلاحية حذف (PaymentGatewayInvoices) من جدول صلاحيات الأدوار
                cursor.execute(SP.USER_GET_ALL)
                cols = [c[0] for c in cursor.description] if cursor.description else []
                for row in cursor.fetchall():
                    item = dict(zip(cols, row))
                    if int(item.get("UserID") or 0) == int(user_id):
                        if not bool(item.get("IsActive", True)):
                            return False
                        role_id = int(item.get("RoleID") or 0)
                        if role_id > 0:
                            cursor.execute(SP.PERMISSION_GET_BY_ROLE, (role_id,))
                            p_cols = [c[0] for c in cursor.description] if cursor.description else []
                            for p_row in cursor.fetchall():
                                perm = dict(zip(p_cols, p_row))
                                if str(perm.get("FormName") or "").strip().lower() == "paymentgatewayinvoices":
                                    return bool(perm.get("CanDelete", False))
                        return bool(item.get("CanRefundPaymentGateway", False))
                return False
        finally:
            conn.close()

    def refund_payment_link(self, link_id: int, refund_amount: float, reason: str, user_id: int = 1) -> Dict[str, Any]:
        if not user_id or user_id <= 0 or not self.can_user_refund_payment_gateway(user_id):
            raise PermissionError("⚠️ عذراً، لا تملك صلاحية استرداد مبالغ بوابات الدفع الإلكتروني.")

        record = self._get_payment_link_by_id(link_id)
        if not record:
            raise ValueError("⚠️ لم يتم العثور على رابط الدفع المراد استرداده.")

        cfg = self._find_provider_for_link(record)
        if not cfg or not cfg.get("EnableGatewayRefunds"):
            raise ValueError("⚠️ خاصية إرجاع المبالغ غير مفعلة لهذه البوابة في الإعدادات.")

        ext_ref_id = self._process_gateway_refund(cfg, record, refund_amount, reason)

        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.PAYMENT_LINK_RECORD_REFUND,
                (link_id, refund_amount, ext_ref_id, reason, user_id),
            )
            row = cursor.fetchone()
            cols = [c[0] for c in cursor.description] if cursor.description else []
            conn.commit()
            res = _serialize_row(cols, row) if row else {"status": "Refunded", "ExternalRefundID": ext_ref_id}
            res["message_ar"] = f"✅ تم تنفيذ إرجاع المبلغ ({refund_amount:.3f}) بنجاح (مرجع: {ext_ref_id})."
            return res
        except Exception as ex:
            conn.rollback()
            raise ValueError(f"❌ توقف تسجيل الاسترداد / القيد المحاسبي: {_extract_db_error_message(ex)}")
        finally:
            cursor.close()
            conn.close()

    # =========================================================================
    # Talabat POS Plugin & Middleware Order Operations
    # =========================================================================
    def get_talabat_orders(
        self, status: Optional[str] = None, start_date: Optional[str] = None, end_date: Optional[str] = None, search_text: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.TALABAT_ORDER_GET_FILTERED,
                (status, start_date, end_date, search_text),
            )
            if not cursor.description:
                return []
            cols = [c[0] for c in cursor.description]
            return [_serialize_row(cols, r) for r in cursor.fetchall()]
        except Exception:
            return []
        finally:
            cursor.close()
            conn.close()

    def save_or_update_talabat_order(self, payload: dict, auto_create_invoice: bool = False) -> Dict[str, Any]:
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                SP.TALABAT_ORDER_SAVE_OR_UPDATE,
                (
                    payload.get("OrderToken", ""),
                    payload.get("OrderCode", ""),
                    payload.get("ShortCode"),
                    payload.get("RemoteVendorId"),
                    payload.get("ExpeditionType", "delivery"),
                    payload.get("PaymentType", "ONLINE"),
                    float(payload.get("SubTotal", 0)),
                    float(payload.get("DeliveryFee", 0)),
                    float(payload.get("DiscountAmount", 0)),
                    float(payload.get("GrandTotal", 0)),
                    payload.get("CurrencyCode", "KWD"),
                    payload.get("OrderStatus", "Received"),
                    payload.get("CustomerName"),
                    payload.get("CustomerPhone"),
                    payload.get("DeliveryAddress"),
                    payload.get("Comments"),
                    payload.get("ItemsJson"),
                    payload.get("RawPayloadJson"),
                    payload.get("RejectionReason"),
                    int(payload.get("UserID", 1)),
                    1 if auto_create_invoice else 0,
                ),
            )
            row = cursor.fetchone()
            cols = [c[0] for c in cursor.description] if cursor.description else []
            conn.commit()
            return _serialize_row(cols, row) if row else {"status": "saved"}
        finally:
            cursor.close()
            conn.close()

