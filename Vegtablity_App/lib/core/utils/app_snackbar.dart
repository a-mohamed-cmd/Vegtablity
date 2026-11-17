import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// مفتاح عالمي لـ ScaffoldMessenger لعرض رسائل الـ SnapMessage من أي شاشة بأمان
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// محوّل أخطاء قاعدة البيانات والشبكة إلى رسائل مفهومة للمستخدم
class DbErrorHelper {
  static final RegExp _odbcNoiseRegex = RegExp(
    r"(?:\(\s*'[0-9A-Za-z]+'\s*,\s*['\x22])"
    r"|(?:\[[0-9A-Za-z]+\]\s*)"
    r"|(?:\[Microsoft\]\s*)"
    r"|(?:\[ODBC[^\]]*\]\s*)"
    r"|(?:\[SQL Server\]\s*)"
    r"|(?:\(\s*-?\d+\s*\)\s*)"
    r"|(?:\(\s*SQLExec(?:Direct)?W?\s*\))",
    caseSensitive: false,
  );

  static final RegExp _trailingBoilerplateRegex = RegExp(
    r"(?:The statement has been terminated\.?"
    r"|The transaction ended in the trigger\. The batch has been aborted\.?"
    r"|تم إنهاء المعاملة في المشغل\.?"
    r"|تم إيقاف الدفعة\.?)",
    caseSensitive: false,
  );

  static String format(
    dynamic error, {
    bool isArabic = true,
    String? fallback,
  }) {
    if (error == null) {
      return fallback ??
          (isArabic ? 'حدث خطأ غير متوقع.' : 'An unexpected error occurred.');
    }

    String raw = '';
    int? statusCode;

    if (error is DioException) {
      statusCode = error.response?.statusCode;

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return isArabic
            ? 'انتهت مهلة الاتصال بالخادم، يرجى التأكد من سرعة الشبكة والمحاولة مرة أخرى.'
            : 'Connection timed out. Please try again.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return isArabic
            ? 'تعذر الاتصال بالخادم، يرجى التأكد من تشغيل السيرفر والاتصال بالشبكة.'
            : 'Cannot connect to the server. Please check your network.';
      }
      if (error.type == DioExceptionType.cancel) {
        return isArabic ? 'تم إلغاء العملية.' : 'Request was cancelled.';
      }

      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'] ?? data['message'] ?? data['error'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          raw = detail.toString();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        raw = data;
      }

      if (raw.isEmpty) {
        if (statusCode == 401) {
          return isArabic
              ? 'انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول.'
              : 'Session expired. Please login again.';
        }
        if (statusCode == 403) {
          return isArabic
              ? 'عذراً، لا تملك الصلاحية الكافية لتنفيذ هذه العملية.'
              : 'You do not have permission to perform this action.';
        }
        if (statusCode == 404) {
          return isArabic
              ? 'السجل أو البيانات المطلوبة غير موجودة.'
              : 'Requested record was not found.';
        }
        if (statusCode == 408 || statusCode == 504) {
          return isArabic
              ? 'انتهت مهلة تنفيذ العملية في قاعدة البيانات.'
              : 'Database operation timed out.';
        }
        if (statusCode == 503 || statusCode == 502) {
          return isArabic
              ? 'تعذر الاتصال بخادم قاعدة البيانات حالياً.'
              : 'Database service is currently unavailable.';
        }
        raw = error.message ?? error.toString();
      }
    } else {
      raw = error.toString();
    }

    // استخراج آخر سطر مفيد إذا كان هناك Python Traceback
    if (raw.contains('Traceback (most recent call last):')) {
      final lines = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        final last = lines.last;
        final colonIdx = last.indexOf(':');
        raw = colonIdx >= 0 && last.substring(colonIdx + 1).trim().isNotEmpty
            ? last.substring(colonIdx + 1).trim()
            : last;
      }
    }

    // إزالة البادئات التقنية الشائعة
    raw = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    raw = raw.replaceFirst(RegExp(r'^DioException[^:]*:\s*'), '').trim();

    final lower = raw.toLowerCase();

    // ترجمة أخطاء SQL Server / ODBC الشائعة
    if (lower.contains('[08001]') ||
        lower.contains('[08s01]') ||
        lower.contains('tcp provider') ||
        lower.contains('could not open a connection to sql server') ||
        lower.contains('server was not found') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup')) {
      return isArabic
          ? 'تعذر الاتصال بخادم قاعدة البيانات، يرجى التأكد من الشبكة وتوافر السيرفر.'
          : 'Unable to reach the database server. Please check connection.';
    }

    if (lower.contains('[hyt00]') ||
        lower.contains('[hyt01]') ||
        lower.contains('timeout expired')) {
      return isArabic
          ? 'انتهت مهلة تنفيذ العملية في قاعدة البيانات، يرجى المحاولة مرة أخرى.'
          : 'Database operation timed out.';
    }

    if (lower.contains('(1205)') ||
        lower.contains('deadlocked on lock resources')) {
      return isArabic
          ? 'النظام مزدحم حالياً بعملية متزامنة، يرجى إعادة المحاولة بعد لحظة.'
          : 'System is busy due to a concurrent operation. Please retry.';
    }

    if (lower.contains('(547)') ||
        lower.contains('reference constraint') ||
        lower.contains('foreign key constraint')) {
      if (lower.contains('delete statement conflicted') ||
          lower.contains('statement conflicted with the reference')) {
        return isArabic
            ? 'لا يمكن حذف هذا السجل لأنه مرتبط ببيانات أو عمليات أخرى في النظام.'
            : 'Cannot delete record because it is referenced by other records.';
      }
      return isArabic
          ? 'لا يمكن إتمام العملية لوجود بيانات مرجعية غير مطابقة أو مرتبطة بسجلات أخرى.'
          : 'Operation violates data reference constraints.';
    }

    if (lower.contains('(2627)') ||
        lower.contains('(2601)') ||
        lower.contains('violation of unique key') ||
        lower.contains('violation of primary key') ||
        lower.contains('duplicate key')) {
      return isArabic
          ? 'البيانات المدخلة مكررة وموجودة مسبقاً، يرجى المراجعة.'
          : 'Duplicate data already exists. Please review your input.';
    }

    if (lower.contains('(515)') ||
        lower.contains('cannot insert the value null')) {
      return isArabic
          ? 'توجد حقول إلزامية لم يتم تعبئتها، يرجى استكمال كافة البيانات المطلوبة.'
          : 'Required fields are missing.';
    }

    if (lower.contains('(2628)') ||
        lower.contains('(8152)') ||
        lower.contains('string or binary data would be truncated')) {
      return isArabic
          ? 'النص المدخل أطول من الحد الأقصى المسموح به لهذا الحقل.'
          : 'Entered text exceeds the maximum allowed length.';
    }

    if (lower.contains('(8115)') ||
        lower.contains('(8114)') ||
        lower.contains('(245)') ||
        lower.contains('(242)') ||
        lower.contains('(241)') ||
        lower.contains('arithmetic overflow') ||
        lower.contains('conversion failed')) {
      return isArabic
          ? 'توجد قيمة رقمية أو تاريخ غير صالح أو يتجاوز الحد المسموح به.'
          : 'Invalid numeric or date value.';
    }

    if (lower.contains('(229)') ||
        lower.contains('(262)') ||
        lower.contains('permission was denied')) {
      return isArabic
          ? 'لا تملك الصلاحية الكافية في قاعدة البيانات لتنفيذ هذا الإجراء.'
          : 'Insufficient database permissions.';
    }

    if (lower.contains('(2812)') ||
        lower.contains('could not find stored procedure') ||
        lower.contains('(208)') ||
        lower.contains('invalid object name') ||
        lower.contains('(207)') ||
        lower.contains('invalid column name')) {
      return isArabic
          ? 'قاعدة البيانات بحاجة لتحديث السكربت لإتمام هذه العملية.'
          : 'Database schema needs to be updated for this operation.';
    }

    // تنظيف رسالة RAISERROR من بقايا ODBC
    String cleaned = raw
        .replaceAll(_odbcNoiseRegex, ' ')
        .replaceAll(_trailingBoilerplateRegex, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // إزالة علامات الأقواس الزائدة في البداية/النهاية
    cleaned = cleaned.replaceAll(RegExp(r'^[\[\]\(\)\x27\x22\s]+|[\[\]\(\)\x27\x22\s]+$'), '');

    if (cleaned.isEmpty ||
        cleaned.toLowerCase().contains('status code of 500') ||
        cleaned.toLowerCase().contains('this exception was thrown because')) {
      return fallback ??
          (isArabic
              ? 'حدث خطأ أثناء تنفيذ العملية في قاعدة البيانات، يرجى المحاولة مرة أخرى.'
              : 'Database error occurred while processing the request.');
    }

    return cleaned;
  }
}

/// عارض SnapMessage (SnackBar عائم ومنظم) لعرض رسائل الأخطاء والتنبيهات والنجاح
class AppSnackBar {
  static void show(
    BuildContext? context,
    String message, {
    bool isError = false,
    bool isWarning = false,
    Duration? duration,
  }) {
    final messenger = (context != null && context.mounted)
        ? ScaffoldMessenger.maybeOf(context)
        : rootScaffoldMessengerKey.currentState;
    final targetMessenger = messenger ?? rootScaffoldMessengerKey.currentState;
    if (targetMessenger == null) return;

    final Color bgColor = isError
        ? const Color(0xFFB91C1C)
        : (isWarning ? const Color(0xFFD97706) : const Color(0xFF047857));
    final IconData iconData = isError
        ? Icons.error_outline_rounded
        : (isWarning
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded);

    bool isRtl = true;
    if (context != null && context.mounted) {
      isRtl = Directionality.of(context) == TextDirection.rtl;
    }

    targetMessenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bgColor,
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: duration ??
              Duration(seconds: isError ? 5 : (isWarning ? 4 : 3)),
          content: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Icon(iconData, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: isRtl ? 'إغلاق' : 'Close',
            textColor: Colors.white70,
            onPressed: () {
              targetMessenger.hideCurrentSnackBar();
            },
          ),
        ),
      );
  }

  static void showError(
    BuildContext? context,
    dynamic error, {
    String? prefix,
    bool? isArabic,
  }) {
    bool rtl = isArabic ?? true;
    if (isArabic == null && context != null && context.mounted) {
      rtl = Localizations.localeOf(context).languageCode == 'ar';
    }
    final formatted = DbErrorHelper.format(error, isArabic: rtl);
    final finalMsg =
        (prefix != null && prefix.trim().isNotEmpty && !formatted.contains(prefix.trim()))
            ? '$prefix: $formatted'
            : formatted;
    show(context, finalMsg, isError: true);
  }

  static void showSuccess(BuildContext? context, String message) {
    show(context, message, isError: false, isWarning: false);
  }

  static void showWarning(BuildContext? context, String message) {
    show(context, message, isError: false, isWarning: true);
  }
}
