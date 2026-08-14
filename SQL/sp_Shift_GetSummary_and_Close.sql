-- ============================================================
-- SP 1: sp_Shift_GetSummary
-- جلب ملخص الوردية (المبيعات، المشتريات، الكاش المتوقع)
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetSummary];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetSummary]
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. تحديد ID حساب الصندوق الرئيسي (1101)
    DECLARE @CashAccountID INT;
    SELECT TOP 1 @CashAccountID = AccountID 
    FROM [Accounting].[ChartOfAccounts] 
    WHERE AccountCode = '1101';

    -- احتياطي في حال عدم وجود الكود 1101
    IF @CashAccountID IS NULL
    BEGIN
        SELECT TOP 1 @CashAccountID = AccountID 
        FROM [Accounting].[ChartOfAccounts] 
        WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1;
    END

    -- 2. جلب بيانات الوردية الأساسية والملخص المالي
    SELECT
        s.ShiftID,
        s.UserID,
        s.StartTime,
        s.EndTime,
        s.StartingCash,
        s.Status,
        u.FullName AS UserName,

        -- إجمالي المبيعات (NetAmount) في الوردية
        ISNULL((
            SELECT SUM(CAST(h.NetAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalSales,

        -- إجمالي المشتريات (NetAmount) في الوردية
        ISNULL((
            SELECT SUM(CAST(h.NetAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalPurchases,

        -- عدد فواتير المبيعات
        ISNULL((
            SELECT COUNT(*)
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.ShiftID = @ShiftID
        ), 0) AS SalesCount,

        -- عدد فواتير المشتريات
        ISNULL((
            SELECT COUNT(*)
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.ShiftID = @ShiftID
        ), 0) AS PurchasesCount,

        -- ✅ 1. مبيعات الكاش النقدية الفعلية لحساب الصندوق 1101 بالدرج
        ISNULL((
            SELECT SUM(CAST(PaidCash AS DECIMAL(18,3)))
            FROM (
                SELECT sp.Amount AS PaidCash
                FROM [Sales].[InvoicePaymentSplits] sp
                INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND sp.PaymentAccountID = @CashAccountID

                UNION ALL

                SELECT h.PaidAmount AS PaidCash
                FROM [Sales].[InvoiceHeader] h
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND h.PaidAmount > 0
                  AND (h.PaymentAccountID = @CashAccountID OR h.PaymentAccountID IS NULL)
                  AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
            ) CashSalesUnion
        ), 0) AS TotalPaidSales,

        -- المتبقي الآجل للمبيعات
        ISNULL((
            SELECT SUM(CAST(h.Remainder AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalRemainder,

        -- ✅ 2. مشتريات الكاش النقدية الفعلية من الصندوق 1101
        ISNULL((
            SELECT SUM(CAST(PaidCash AS DECIMAL(18,3)))
            FROM (
                SELECT sp.Amount AS PaidCash
                FROM [Sales].[InvoicePaymentSplits] sp
                INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
                WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
                  AND sp.PaymentAccountID = @CashAccountID

                UNION ALL

                SELECT h.PaidAmount AS PaidCash
                FROM [Sales].[InvoiceHeader] h
                WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
                  AND h.PaidAmount > 0
                  AND (h.PaymentAccountID = @CashAccountID OR h.PaymentAccountID IS NULL)
                  AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
            ) CashPurchasesUnion
        ), 0) AS TotalPaidPurchases,

        -- المتبقي الآجل للمشتريات
        ISNULL((
            SELECT SUM(CAST(h.Remainder AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalPurchasesRemainder,

        -- ✅ 3. إجمالي سندات القبض الكاش لحساب الصندوق 1101
        ISNULL((
            SELECT SUM(CAST(v.Amount AS DECIMAL(18,3)))
            FROM [Accounting].[Vouchers] v
            WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
              AND (v.AccountID = @CashAccountID OR v.AccountID IS NULL)
        ), 0) AS TotalReceiptVouchers,

        -- ✅ 4. إجمالي سندات الصرف الكاش لحساب الصندوق 1101
        ISNULL((
            SELECT SUM(CAST(v.Amount AS DECIMAL(18,3)))
            FROM [Accounting].[Vouchers] v
            WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
              AND (v.AccountID = @CashAccountID OR v.AccountID IS NULL)
        ), 0) AS TotalPaymentVouchers,

        -- ✅ 5. إجمالي التحصيلات غير النقدية (كي نت / فيزا / بنك) - أي حساب غير 1101
        ISNULL((
            SELECT SUM(CAST(PaidNonCash AS DECIMAL(18,3)))
            FROM (
                SELECT sp.Amount AS PaidNonCash
                FROM [Sales].[InvoicePaymentSplits] sp
                INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND sp.PaymentAccountID <> @CashAccountID

                UNION ALL

                SELECT h.PaidAmount AS PaidNonCash
                FROM [Sales].[InvoiceHeader] h
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND h.PaidAmount > 0
                  AND h.PaymentAccountID IS NOT NULL
                  AND h.PaymentAccountID <> @CashAccountID
                  AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
            ) NonCashSalesUnion
        ), 0) AS TotalNonCashSales

    FROM [Sales].[Shifts] s
    LEFT JOIN [Security].[Users] u ON s.UserID = u.UserID
    WHERE s.ShiftID = @ShiftID;
END
GO
