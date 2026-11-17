import re
from typing import Any, Tuple


_ODBC_NOISE_RE = re.compile(
    r"(?:\(\s*'[0-9A-Za-z]+'\s*,\s*['\"])|"
    r"(?:\[[0-9A-Za-z]+\]\s*)|"
    r"(?:\[Microsoft\]\s*)|"
    r"(?:\[ODBC[^\]]*\]\s*)|"
    r"(?:\[SQL Server\]\s*)|"
    r"(?:\(\s*-?\d+\s*\)\s*)|"
    r"(?:\(\s*SQLExec(?:Direct)?W?\s*\))",
    flags=re.IGNORECASE,
)

_TRAILING_BOILERPLATE_RE = re.compile(
    r"(?:The statement has been terminated\.?|"
    r"The transaction ended in the trigger\. The batch has been aborted\.?|"
    r"تم إنهاء المعاملة في المشغل\.?|"
    r"تم إيقاف الدفعة\.?)",
    flags=re.IGNORECASE,
)


def _extract_last_traceback_line(text: str) -> str:
    if "Traceback (most recent call last):" not in text:
        return text
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return text
    last = lines[-1]
    if ":" in last:
        _, _, remainder = last.partition(":")
        if remainder.strip():
            return remainder.strip()
    return last


def clean_db_error_message(raw_error: Any) -> Tuple[str, int]:
    """
    تحويل أخطاء قاعدة البيانات (pyodbc / SQL Server / Traceback) إلى رسالة عربية واضحة للمستخدم
    مع إرجاع أنسب كود HTTP (400 / 403 / 503 / 500).
    """
    if raw_error is None:
        return "حدث خطأ غير متوقع في قاعدة البيانات.", 500

    # إذا كان pyodbc.Error يحتوي على args = (sqlstate, message)
    args = getattr(raw_error, "args", None)
    if args and isinstance(args, (tuple, list)) and len(args) >= 2 and isinstance(args[1], str):
        raw_text = f"[{args[0]}] {args[1]}"
    else:
        raw_text = str(raw_error)

    raw_text = _extract_last_traceback_line(raw_text).strip()
    lower = raw_text.lower()

    # أخطاء الاتصال والشبكة وانقطاع قاعدة البيانات
    if (
        "[08001]" in lower
        or "[08s01]" in lower
        or "tcp provider" in lower
        or "named pipes provider" in lower
        or "could not open a connection to sql server" in lower
        or "server was not found" in lower
        or "login failed for user" in lower
        or "cannot open database" in lower
        or "(18456)" in lower
        or "(4060)" in lower
    ):
        return "تعذر الاتصال بخادم قاعدة البيانات، يرجى التأكد من تشغيل الخادم واستقرار الشبكة.", 503

    # مهلة الاستعلام (Timeout)
    if "[hyt00]" in lower or "[hyt01]" in lower or "query timeout expired" in lower or "(-2)" in lower:
        return "انتهت مهلة تنفيذ العملية في قاعدة البيانات، يرجى المحاولة مرة أخرى.", 504

    # تعارض تزامن (Deadlock)
    if "(1205)" in lower or "deadlocked on lock resources" in lower:
        return "النظام مزدحم حالياً بسبب عملية متزامنة، يرجى إعادة المحاولة بعد لحظة.", 409

    # خطأ مفاتيح الربط (Foreign Key / Reference Constraint 547)
    if "(547)" in lower or "reference constraint" in lower or "foreign key constraint" in lower:
        if "delete statement conflicted" in lower or "statement conflicted with the reference" in lower:
            return "لا يمكن حذف هذا السجل لأنه مرتبط ببيانات أو عمليات أخرى في النظام.", 400
        return "لا يمكن إتمام العملية لوجود بيانات مرجعية غير مطابقة أو مرتبطة بسجلات أخرى.", 400

    # تكرار قيمة فريدة (2627 / 2601)
    if (
        "(2627)" in lower
        or "(2601)" in lower
        or "violation of unique key" in lower
        or "violation of primary key" in lower
        or "duplicate key" in lower
    ):
        return "البيانات المدخلة مكررة وموجودة مسبقاً (مثل الكود أو الباركود أو الرقم). يرجى المراجعة.", 400

    # حقل إلزامي فارغ (515)
    if "(515)" in lower or "cannot insert the value null" in lower:
        return "توجد حقول إلزامية لم يتم تعبئتها، يرجى التأكد من إدخال جميع البيانات المطلوبة.", 400

    # تجاوز طول النص (2628 / 8152)
    if "(2628)" in lower or "(8152)" in lower or "string or binary data would be truncated" in lower:
        return "النص المدخل أطول من الحد الأقصى المسموح به لهذا الحقل.", 400

    # أخطاء التحويل الرقمي أو التاريخ أو تجاوز القيم (8114 / 8115 / 245 / 242 / 241)
    if (
        "(8115)" in lower
        or "(8114)" in lower
        or "(245)" in lower
        or "(242)" in lower
        or "(241)" in lower
        or "arithmetic overflow" in lower
        or "conversion failed when converting" in lower
    ):
        return "توجد قيمة رقمية أو تاريخ غير صالح أو يتجاوز الحد المسموح به.", 400

    # أخطاء الصلاحيات على مستوى SQL Server (229 / 262)
    if "(229)" in lower or "(262)" in lower or "permission was denied on the object" in lower:
        return "لا تملك صلاحية كافية في قاعدة البيانات لتنفيذ هذا الإجراء.", 403

    # أخطاء الكيانات أو الأعمدة غير المطبقة في قاعدة البيانات (207 / 208 / 2812)
    if "(2812)" in lower or "could not find stored procedure" in lower:
        return "الإجراء المطلوب غير مثبّت في قاعدة البيانات، يرجى تحديث قاعدة البيانات أولاً.", 500
    if "(208)" in lower or "invalid object name" in lower or "(207)" in lower or "invalid column name" in lower:
        return "بنية قاعدة البيانات غير محدثة لهذه العملية، يرجى تشغيل سكربت تحديث قاعدة البيانات.", 500

    # استخراج الرسالة المخصصة القادمة من RAISERROR / THROW (مثل خطأ 50000)
    if "[sql server]" in lower or "[odbc" in lower or "(50000)" in lower or "sqlexec" in lower:
        cleaned = _ODBC_NOISE_RE.sub(" ", raw_text)
        cleaned = _TRAILING_BOILERPLATE_RE.sub("", cleaned)
        cleaned = cleaned.strip(" []()'\"\r\n\t.;:")
        # دمج المسافات الزائدة
        cleaned = re.sub(r"\s{2,}", " ", cleaned).strip()
        if cleaned:
            return cleaned, 400
        return "تعذر إتمام العملية في قاعدة البيانات، يرجى مراجعة البيانات والمحاولة مرة أخرى.", 400

    # تنظيف أي زوائد تقنية متبقية في الرسالة
    cleaned = _TRAILING_BOILERPLATE_RE.sub("", raw_text).strip()
    if not cleaned:
        return "حدث خطأ غير متوقع في قاعدة البيانات.", 500
    return cleaned, 500
