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

    -- جلب بيانات الوردية الأساسية
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
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS TotalSales,

        -- إجمالي المشتريات (NetAmount) في الوردية
        ISNULL((
            SELECT SUM(CAST(h.NetAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS TotalPurchases,

        -- عدد فواتير المبيعات
        ISNULL((
            SELECT COUNT(*)
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS SalesCount,

        -- عدد فواتير المشتريات
        ISNULL((
            SELECT COUNT(*)
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS PurchasesCount,

        -- إجمالي المبالغ المسددة (Paid) في فواتير المبيعات
        ISNULL((
            SELECT SUM(CAST(h.PaidAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS TotalPaidSales,

        -- إجمالي المبالغ المتبقية (Remainder / آجل) في المبيعات
        ISNULL((
            SELECT SUM(CAST(h.Remainder AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS TotalRemainder,

        -- إجمالي المبالغ المسددة (Paid) في فواتير المشتريات
        ISNULL((
            SELECT SUM(CAST(h.PaidAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS TotalPaidPurchases,

        -- إجمالي المبالغ المتبقية (Remainder / آجل) في المشتريات
        ISNULL((
            SELECT SUM(CAST(h.Remainder AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.CreatedAt >= s.StartTime
              AND (s.EndTime IS NULL OR h.CreatedAt <= s.EndTime)
              AND h.UserID = s.UserID
        ), 0) AS TotalPurchasesRemainder

    FROM [Sales].[Shifts] s
    LEFT JOIN [Security].[Users] u ON s.UserID = u.UserID
    WHERE s.ShiftID = @ShiftID;
END
GO


-- ============================================================
-- SP 2: sp_Shift_Close
-- إغلاق الوردية + قيد محاسبي لفرق الكاش
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

        -- =====================================================
        -- 1. إغلاق الوردية
        -- =====================================================
        UPDATE [Sales].[Shifts]
        SET
            EndTime    = GETDATE(),
            EndingCash = @EndingCash,
            Status     = 'Closed'
        WHERE ShiftID = @ShiftID
          AND Status  = 'Open';

        IF @@ROWCOUNT = 0
            THROW 50001, 'الوردية غير موجودة أو مغلقة بالفعل', 1;

        -- =====================================================
        -- 2. حساب الكاش المتوقع والفرق
        -- ExpectedCash = StartingCash - TotalPaidPurchases + TotalPaidSales
        -- =====================================================
        DECLARE @StartingCash       DECIMAL(18,3);
        DECLARE @StartTime          DATETIME;
        DECLARE @UserID             INT;
        DECLARE @TotalPaidSales     DECIMAL(18,3) = 0;
        DECLARE @TotalPaidPurchases DECIMAL(18,3) = 0;
        DECLARE @ExpectedCash       DECIMAL(18,3);
        DECLARE @Difference         DECIMAL(18,3);

        SELECT
            @StartingCash = StartingCash,
            @StartTime    = StartTime,
            @UserID       = UserID
        FROM [Sales].[Shifts]
        WHERE ShiftID = @ShiftID;

        -- مبيعات مسددة خلال الوردية
        SELECT @TotalPaidSales = ISNULL(SUM(CAST(PaidAmount AS DECIMAL(18,3))), 0)
        FROM [Sales].[InvoiceHeader]
        WHERE InvType = 'Sales'
          AND CreatedAt >= @StartTime
          AND UserID = @UserID;

        -- مشتريات مسددة خلال الوردية
        SELECT @TotalPaidPurchases = ISNULL(SUM(CAST(PaidAmount AS DECIMAL(18,3))), 0)
        FROM [Sales].[InvoiceHeader]
        WHERE InvType = 'Purchase'
          AND CreatedAt >= @StartTime
          AND UserID = @UserID;

        SET @ExpectedCash = @StartingCash - @TotalPaidPurchases + @TotalPaidSales;
        SET @Difference   = @EndingCash - @ExpectedCash;

        -- =====================================================
        -- 3. قيد محاسبي فقط إذا كان الفرق غير صفر
        -- =====================================================
        IF ABS(@Difference) > 0.001
        BEGIN
            DECLARE @CashboxID      INT;
            DECLARE @RevenueIDchild INT;
            DECLARE @AbsDiff        DECIMAL(18,2) = CAST(ABS(@Difference) AS DECIMAL(18,2));
            DECLARE @JournalDesc    NVARCHAR(255);
            DECLARE @EntryNo        INT;
            DECLARE @DebitAccID     INT;
            DECLARE @CreditAccID    INT;

            -- جلب حساب الصندوق
            SELECT TOP 1 @CashboxID = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountName LIKE N'%صندوق%'
              AND IsTransactional = 1;

            -- جلب حساب الإيرادات الأخرى (412)
            SELECT @RevenueIDchild = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountCode = '412';

            IF @CashboxID IS NULL OR @RevenueIDchild IS NULL
                THROW 50002, 'تعذر إيجاد حسابات الصندوق أو الإيرادات الأخرى في دليل الحسابات', 1;

            IF @Difference > 0
            BEGIN
                -- *** فائض: مدين الصندوق / دائن إيرادات أخرى (412) ***
                SET @JournalDesc = N'فائض كاش عند إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                SET @DebitAccID  = @CashboxID;
                SET @CreditAccID = @RevenueIDchild;
            END
            ELSE
            BEGIN
                -- *** عجز: مدين إيرادات أخرى (412) / دائن الصندوق ***
                SET @JournalDesc = N'عجز كاش عند إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                SET @DebitAccID  = @RevenueIDchild;
                SET @CreditAccID = @CashboxID;
            END

            -- جلب رقم القيد التالي من الـ Sequence (مشترك بين السطرين)
            SET @EntryNo = NEXT VALUE FOR [Accounting].[seq_EntryNo];

            -- السطر 1: المدين
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID,
                 AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                 @DebitAccID, @AbsDiff, 0, @JournalDesc, @UserID);

            -- السطر 2: الدائن
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID,
                 AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                 @CreditAccID, 0, @AbsDiff, @JournalDesc, @UserID);
        END

        -- =====================================================
        -- 4. ترحيل الفواتير المرتبطة بهذه الوردية
        -- =====================================================
        -- بدلاً من ShiftID غير الموجود، نربط الفواتير بوقت فتح وإغلاق الوردية
        DECLARE @ShiftEnd DATETIME;
        SELECT @ShiftEnd = EndTime FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

        UPDATE [Sales].[InvoiceHeader]
        SET IsPosted = 1
        WHERE CreatedAt >= @StartTime 
          AND CreatedAt <= @ShiftEnd 
          AND UserID = @UserID
          AND IsPosted = 0;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
