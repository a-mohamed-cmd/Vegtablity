-- =============================================================================================================
-- SHIFT PROCEDURES (v2.1) - حساب الكاش والشبكة والملخص المالي وإغلاق الوردية بدقة متناهية
-- متوافق مع: Flutter App, WPF Desktop, Thermal Print, Web API
-- =============================================================================================================

USE [WashaDB]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SP 1: sp_Shift_GetSummary
-- جلب ملخص الوردية الكامل (المبيعات، الكاش، K-Net، السندات، العجز/الزيادة)
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetSummary];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetSummary] 
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. المتغيرات الأساسية للوردية
    DECLARE @StartingCash DECIMAL(18,3) = 0;
    DECLARE @EndingCash   DECIMAL(18,3) = NULL;

    SELECT @StartingCash = ISNULL(StartingCash, 0), @EndingCash = EndingCash
    FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

    -- حسابات الكاش والمبيعات والشبكة
    DECLARE @TotalSales              DECIMAL(18,3) = 0;
    DECLARE @TotalPurchases          DECIMAL(18,3) = 0;
    DECLARE @SalesCount              INT = 0;
    DECLARE @PurchasesCount          INT = 0;
    DECLARE @TotalPaidSalesCash      DECIMAL(18,3) = 0;
    DECLARE @TotalPaidSalesNonCash   DECIMAL(18,3) = 0;
    DECLARE @TotalRemainder          DECIMAL(18,3) = 0;
    DECLARE @TotalPaidPurchasesCash  DECIMAL(18,3) = 0;
    DECLARE @TotalPaidPurchasesNonCash DECIMAL(18,3) = 0;
    DECLARE @TotalPurchasesRemainder DECIMAL(18,3) = 0;
    DECLARE @TotalReceiptVouchers    DECIMAL(18,3) = 0;
    DECLARE @TotalPaymentVouchers    DECIMAL(18,3) = 0;

    -- 2. إجماليات فواتير المبيعات
    SELECT 
        @TotalSales     = ISNULL(SUM(CAST(NetAmount AS DECIMAL(18,3))), 0),
        @SalesCount     = COUNT(*),
        @TotalRemainder = ISNULL(SUM(CAST(Remainder AS DECIMAL(18,3))), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Sales' AND ShiftID = @ShiftID;

    -- 3. إجماليات فواتير المشتريات
    SELECT 
        @TotalPurchases          = ISNULL(SUM(CAST(NetAmount AS DECIMAL(18,3))), 0),
        @PurchasesCount          = COUNT(*),
        @TotalPurchasesRemainder = ISNULL(SUM(CAST(Remainder AS DECIMAL(18,3))), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Purchase' AND ShiftID = @ShiftID;

    -- 4. مبيعات الكاش النقدية الفعلية بالدرج (الحساب 1101 ومشتقاته حصراً + الفواتير المباشرة)
    SELECT @TotalPaidSalesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
    FROM (
        -- فواتير مجزأة: الدفعات النقدية على حساب الصندوق 1101
        SELECT sp.Amount AS PaidCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )

        UNION ALL

        -- فواتير مباشرة (غير مجزأة): مسددة كاش
        SELECT h.PaidAmount AS PaidCash
        FROM [Sales].[InvoiceHeader] h
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountID IS NULL
              OR c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )
    ) CashSalesUnion;

    -- 5. مبيعات الشبكة K-Net / فيزا / بطاقات / بنك (أي حساب دفع بخلاف 1101)
    SELECT @TotalPaidSalesNonCash = ISNULL(SUM(CAST(PaidNonCash AS DECIMAL(18,3))), 0)
    FROM (
        -- فواتير مجزأة: الدفعات غير النقدية
        SELECT sp.Amount AS PaidNonCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        INNER JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'

        UNION ALL

        -- فواتير مباشرة (غير مجزأة): مسددة شبكة/KNET/بنك
        SELECT h.PaidAmount AS PaidNonCash
        FROM [Sales].[InvoiceHeader] h
        INNER JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'
    ) NonCashSalesUnion;

    -- 6. مشتريات الكاش النقدية الفعلية من الصندوق (الحساب 1101 حصراً)
    SELECT @TotalPaidPurchasesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
    FROM (
        SELECT sp.Amount AS PaidCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )

        UNION ALL

        SELECT h.PaidAmount AS PaidCash
        FROM [Sales].[InvoiceHeader] h
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountID IS NULL
              OR c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )
    ) CashPurchasesUnion;

    -- مشتريات غير نقدية
    SELECT @TotalPaidPurchasesNonCash = ISNULL(SUM(CAST(PaidNonCash AS DECIMAL(18,3))), 0)
    FROM (
        SELECT sp.Amount AS PaidNonCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        INNER JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'

        UNION ALL

        SELECT h.PaidAmount AS PaidNonCash
        FROM [Sales].[InvoiceHeader] h
        INNER JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'
    ) NonCashPurchasesUnion;

    -- 7. سندات القبض الكاش بالدرج
    SELECT @TotalReceiptVouchers = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
        CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
    ) = c.AccountID
    WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
      AND (
          c.AccountCode = '1101'
          OR c.AccountCode LIKE '1101%'
          OR v.PaymentMethod = 'Cash'
          OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
      );

    -- 8. سندات الصرف الكاش من الدرج (المصروفات النقدية)
    SELECT @TotalPaymentVouchers = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
        CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
    ) = c.AccountID
    WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
      AND (
          c.AccountCode = '1101'
          OR c.AccountCode LIKE '1101%'
          OR v.PaymentMethod = 'Cash'
          OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
      );

    -- 9. حساب النقدية المتوقعة بالدرج
    DECLARE @ExpectedCash DECIMAL(18,3) = @StartingCash 
                                        + @TotalPaidSalesCash 
                                        - @TotalPaidPurchasesCash 
                                        + @TotalReceiptVouchers 
                                        - @TotalPaymentVouchers;

    DECLARE @Difference DECIMAL(18,3) = ISNULL(@EndingCash, @ExpectedCash) - @ExpectedCash;

    -- 10. إرجاع النتائج المتوافقة مع كافة الأنظمة والشاشات والطباعة
    SELECT
        s.ShiftID,
        s.UserID,
        s.StartTime,
        s.EndTime,
        s.StartingCash,
        s.EndingCash,
        s.Status,
        u.FullName AS UserName,

        @TotalSales                 AS TotalSales,
        @TotalPurchases             AS TotalPurchases,
        @SalesCount                 AS SalesCount,
        @PurchasesCount             AS PurchasesCount,

        @TotalPaidSalesCash         AS TotalPaidSales,        -- مبيعات الكاش النقدية الفعلية (توافق قديم وجديد)
        @TotalPaidSalesCash         AS TotalCashSales,        -- لشاشة إغلاق الوردية والطباعة
        @TotalPaidSalesCash         AS CashSales,             -- لطباعة وتقارير Flutter
        @TotalPaidSalesNonCash      AS TotalNonCashSales,     -- مبيعات غير نقدية (شبكة / بطاقات)
        @TotalPaidSalesNonCash      AS TotalKnetSales,        -- لطباعة وتقارير Flutter (K-Net)
        @TotalPaidSalesNonCash      AS KnetSales,             -- لطباعة Flutter
        @TotalPaidSalesNonCash      AS CardSales,             -- للبطاقات
        @TotalRemainder             AS TotalRemainder,

        @TotalPaidPurchasesCash     AS TotalPaidPurchases,    -- مشتريات كاش فقط
        @TotalPaidPurchasesCash     AS TotalCashPurchases,
        @TotalPaidPurchasesNonCash  AS TotalNonCashPurchases,
        @TotalPurchasesRemainder    AS TotalPurchasesRemainder,

        @TotalReceiptVouchers       AS TotalReceiptVouchers,
        @TotalPaymentVouchers       AS TotalPaymentVouchers,
        @TotalPaymentVouchers       AS TotalExpenses,

        @ExpectedCash               AS ExpectedCash,
        ISNULL(s.EndingCash, @ExpectedCash) AS ActualCash,
        @Difference                 AS Difference

    FROM [Sales].[Shifts] s
    LEFT JOIN [Security].[Users] u ON s.UserID = u.UserID
    WHERE s.ShiftID = @ShiftID;
END
GO

-- ============================================================
-- SP 2: sp_Shift_Close
-- إغلاق الوردية وترحيل الفواتير والسندات وقيد تسوية فرق الكاش
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_Close]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_Close];
GO

CREATE PROCEDURE [Sales].[sp_Shift_Close]
    @ShiftID    INT,
    @EndingCash DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- ① إغلاق الوردية
        UPDATE [Sales].[Shifts]
        SET EndTime    = GETDATE(),
            EndingCash = @EndingCash,
            Status     = 'Closed'
        WHERE ShiftID = @ShiftID AND Status = 'Open';

        IF @@ROWCOUNT = 0
            THROW 50001, 'الوردية غير موجودة أو مغلقة بالفعل', 1;

        -- ② جلب بيانات الوردية
        DECLARE @StartingCash           DECIMAL(18,3) = 0;
        DECLARE @UserID                 INT;
        DECLARE @TotalPaidSalesCash     DECIMAL(18,3) = 0;
        DECLARE @TotalPaidPurchasesCash DECIMAL(18,3) = 0;
        DECLARE @TotalReceiptV          DECIMAL(18,3) = 0;
        DECLARE @TotalPaymentV          DECIMAL(18,3) = 0;
        DECLARE @ExpectedCash           DECIMAL(18,3) = 0;
        DECLARE @Difference             DECIMAL(18,3) = 0;

        SELECT @StartingCash = ISNULL(StartingCash, 0), @UserID = UserID
        FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

        -- مبيعات مسددة كاش فقط بالدرج (الحساب 1101 ومشتقاته حصراً)
        SELECT @TotalPaidSalesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
        FROM (
            SELECT sp.Amount AS PaidCash
            FROM [Sales].[InvoicePaymentSplits] sp
            INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
              AND (
                  c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )

            UNION ALL

            SELECT h.PaidAmount AS PaidCash
            FROM [Sales].[InvoiceHeader] h
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
              AND h.PaidAmount > 0
              AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
              AND (
                  c.AccountID IS NULL
                  OR c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )
        ) CashSalesUnion;

        -- مشتريات مسددة كاش فقط من الدرج (الحساب 1101 ومشتقاته حصراً)
        SELECT @TotalPaidPurchasesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
        FROM (
            SELECT sp.Amount AS PaidCash
            FROM [Sales].[InvoicePaymentSplits] sp
            INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
              AND (
                  c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )

            UNION ALL

            SELECT h.PaidAmount AS PaidCash
            FROM [Sales].[InvoiceHeader] h
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
              AND h.PaidAmount > 0
              AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
              AND (
                  c.AccountID IS NULL
                  OR c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )
        ) CashPurchasesUnion;

        -- سندات القبض الكاش
        SELECT @TotalReceiptV = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
        FROM [Accounting].[Vouchers] v
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
            CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
        ) = c.AccountID
        WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR v.PaymentMethod = 'Cash'
              OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          );

        -- سندات الصرف الكاش
        SELECT @TotalPaymentV = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
        FROM [Accounting].[Vouchers] v
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
            CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
        ) = c.AccountID
        WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR v.PaymentMethod = 'Cash'
              OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          );

        -- الكاش المتوقع = كاش الافتتاح + مبيعات نقدية - مشتريات نقدية + سندات قبض نقدية - سندات صرف نقدية
        SET @ExpectedCash = @StartingCash
                          + @TotalPaidSalesCash
                          - @TotalPaidPurchasesCash
                          + @TotalReceiptV
                          - @TotalPaymentV;

        SET @Difference = @EndingCash - @ExpectedCash;

        -- ③ قيد تسوية فرق الكاش (إن وُجد)
        IF ABS(@Difference) > 0.001
        BEGIN
            DECLARE @CashboxID      INT;
            DECLARE @RevenueIDchild INT;
            DECLARE @AbsDiff        DECIMAL(18,2) = CAST(ABS(@Difference) AS DECIMAL(18,2));
            DECLARE @JournalDesc    NVARCHAR(255);
            DECLARE @EntryNo        INT;
            DECLARE @DebitAccID     INT;
            DECLARE @CreditAccID    INT;

            SELECT TOP 1 @CashboxID = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE (AccountCode = '1101' OR AccountCode LIKE '1101%' OR LOWER(AccountName) LIKE '%cash%' OR AccountName LIKE N'%كاش%' OR AccountName LIKE N'%صندوق%')
              AND IsTransactional = 1;

            SELECT TOP 1 @RevenueIDchild = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountCode = '412';

            IF @RevenueIDchild IS NULL
            BEGIN
                SELECT TOP 1 @RevenueIDchild = AccountID
                FROM [Accounting].[ChartOfAccounts]
                WHERE (AccountName LIKE N'%إيراد%' OR AccountName LIKE N'%أرباح%' OR AccountCode LIKE '4%')
                  AND IsTransactional = 1;
            END

            IF @CashboxID IS NOT NULL AND @RevenueIDchild IS NOT NULL
            BEGIN
                IF @Difference > 0
                BEGIN
                    SET @JournalDesc = N'فائض كاش - إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                    SET @DebitAccID  = @CashboxID;
                    SET @CreditAccID = @RevenueIDchild;
                END
                ELSE
                BEGIN
                    SET @JournalDesc = N'عجز كاش - إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                    SET @DebitAccID  = @RevenueIDchild;
                    SET @CreditAccID = @CashboxID;
                END

                IF OBJECT_ID('[Accounting].[seq_EntryNo]', 'SO') IS NOT NULL
                BEGIN
                    SET @EntryNo = NEXT VALUE FOR [Accounting].[seq_EntryNo];
                    INSERT INTO [Accounting].[JournalEntries]
                        (EntryNo, EntryDate, ReferenceType, ReferenceID,
                         AccountID, DebitAmount, CreditAmount, Description, UserID)
                    VALUES
                        (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                         @DebitAccID, @AbsDiff, 0, @JournalDesc, @UserID),
                        (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                         @CreditAccID, 0, @AbsDiff, @JournalDesc, @UserID);
                END
            END
        END

        -- ④ ترحيل الفواتير المرتبطة بهذه الوردية
        UPDATE [Sales].[InvoiceHeader]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID AND IsPosted = 0;

        -- ⑤ ترحيل السندات المرتبطة بهذه الوردية
        UPDATE [Accounting].[Vouchers]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID AND IsPosted = 0;

        COMMIT TRANSACTION;

        -- إرجاع ملخص للإغلاق
        SELECT
            @ShiftID                AS ShiftID,
            @StartingCash           AS StartingCash,
            @TotalPaidSalesCash     AS TotalPaidSales,
            @TotalPaidSalesCash     AS TotalCashSales,
            @TotalPaidSalesCash     AS CashSales,
            @TotalPaidPurchasesCash AS TotalPaidPurchases,
            @TotalPaidPurchasesCash AS TotalCashPurchases,
            @TotalReceiptV          AS TotalReceiptVouchers,
            @TotalPaymentV          AS TotalPaymentVouchers,
            @ExpectedCash           AS ExpectedCash,
            @EndingCash             AS ActualCash,
            @Difference             AS Difference;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ============================================================
-- SP 3: sp_Shift_GetPaymentMethodTotals
-- إجماليات طرق الدفع التفصيلية (Splits + Direct + Vouchers)
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetPaymentMethodTotals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetPaymentMethodTotals];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetPaymentMethodTotals]
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DefaultCashID INT;
    DECLARE @DefaultCashCode NVARCHAR(50) = '1101';
    DECLARE @DefaultCashName NVARCHAR(100) = N'نقدي (كاش)';

    SELECT TOP 1 
        @DefaultCashID = AccountID,
        @DefaultCashCode = AccountCode,
        @DefaultCashName = AccountName
    FROM [Accounting].[ChartOfAccounts]
    WHERE (AccountCode = '1101' OR AccountName LIKE N'%صندوق%' OR AccountName LIKE N'%كاش%' OR AccountCode LIKE '110%')
      AND IsTransactional = 1;

    SELECT 
        AccountID,
        AccountCode,
        PaymentMethodName,
        InvType,
        SUM(TotalAmount) AS TotalAmount,
        MAX(SourceType)  AS SourceType
    FROM (
        -- 1. إجماليات طرق الدفع من فواتير المبيعات/المشتريات المقسمة (Splits)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            h.InvType,
            SUM(CAST(sp.Amount AS DECIMAL(18,3)))   AS TotalAmount,
            'InvoiceSplit' AS SourceType
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader]          h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON sp.PaymentAccountID = c.AccountID
        WHERE h.ShiftID = @ShiftID AND sp.Amount > 0
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), h.InvType

        UNION ALL

        -- 2. إجماليات طرق الدفع المباشرة من فواتير المبيعات/المشتريات (غير المقسمة / Direct)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            h.InvType,
            SUM(CAST(h.PaidAmount AS DECIMAL(18,3))) AS TotalAmount,
            'InvoiceDirect' AS SourceType
        FROM [Sales].[InvoiceHeader]                h
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON h.PaymentAccountID = c.AccountID
        WHERE h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (
              SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID
          )
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), h.InvType

        UNION ALL

        -- 3. إجماليات طرق الدفع من السندات المالية (قبض وصرف)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            v.VoucherType  AS InvType,
            SUM(CAST(v.Amount AS DECIMAL(18,3)))    AS TotalAmount,
            'Voucher'      AS SourceType
        FROM [Accounting].[Vouchers]                v
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON (
            CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
        ) = c.AccountID
        WHERE v.ShiftID = @ShiftID AND v.Amount > 0
          AND (
              c.AccountCode LIKE '11%' 
              OR c.AccountID IS NULL 
              OR v.PaymentMethod = 'Cash' 
              OR v.PaymentMethod = 'Bank'
          )
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), v.VoucherType
    ) CombinedPaymentTotals
    GROUP BY AccountID, AccountCode, PaymentMethodName, InvType
    ORDER BY AccountCode, InvType;
END
GO

-- ============================================================
-- SP 4: sp_Shift_GetVouchers
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetVouchers]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetVouchers];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetVouchers]
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        v.VoucherID,
        v.VoucherType,
        v.VoucherDate,
        v.Amount,
        v.AccountID,
        c.AccountName,
        v.Description,
        v.ShiftID
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON v.AccountID = c.AccountID
    WHERE v.ShiftID = @ShiftID
    ORDER BY v.VoucherID;
END
GO

PRINT N'✅ [Sales].[sp_Shift_GetSummary], [sp_Shift_Close], [sp_Shift_GetPaymentMethodTotals], [sp_Shift_GetVouchers] updated successfully.';
