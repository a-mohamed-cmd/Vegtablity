USE VegtablityDB;
GO

-- =============================================
-- الإقفال السنوي (Year-End Closing)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Accounting_YearEndClose]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Accounting_YearEndClose];
GO

CREATE PROCEDURE [Accounting].[sp_Accounting_YearEndClose]
    @ClosingDate DATETIME,
    @RetainedEarningsAccountID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. التأكد من وجود حساب الأرباح المبقاة
        IF NOT EXISTS(SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @RetainedEarningsAccountID)
            THROW 50001, N'حساب أرباح وخسائر مبقاة غير موجود، يرجى تهيئته.', 1;

        -- 2. حساب أرصدة الإيرادات والمصروفات حتى تاريخ الإقفال
        DECLARE @Balances TABLE (AccountID INT, Balance DECIMAL(18,2), AccType NVARCHAR(50));

        INSERT INTO @Balances (AccountID, Balance, AccType)
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    WHEN A.AccountType = 'Revenue' THEN (JE.CreditAmount - JE.DebitAmount)
                    WHEN A.AccountType = 'Expenses' THEN (JE.DebitAmount - JE.CreditAmount)
                    ELSE 0
                END
            ),
            A.AccountType
        FROM [Accounting].[JournalEntries] JE
        JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE A.AccountType IN ('Revenue', 'Expenses')
          AND JE.EntryDate <= @ClosingDate
        GROUP BY A.AccountID, A.AccountType
        HAVING SUM(JE.DebitAmount - JE.CreditAmount) <> 0 OR SUM(JE.CreditAmount - JE.DebitAmount) <> 0;

        -- إذا لم تكن هناك أرصدة للإقفال
        IF NOT EXISTS(SELECT 1 FROM @Balances WHERE Balance <> 0)
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS ResultID, N'لا توجد حركات إيرادات أو مصروفات لإقفالها حتى هذا التاريخ.' AS ResultMsg;
            RETURN;
        END

        -- 3. إنشاء رأس قيد الإقفال (JournalHeader)
        DECLARE @JID INT;
        DECLARE @Desc NVARCHAR(255) = N'قيد إقفال السنة المالية حتى تاريخ ' + FORMAT(@ClosingDate, 'yyyy/MM/dd');

        INSERT INTO [Accounting].[JournalHeader] (JDate, Description, UserID, IsPosted, TotalAmount, ReferenceType)
        VALUES (@ClosingDate, @Desc, @UserID, 0, 0, 'YearEndClose');
        
        SET @JID = SCOPE_IDENTITY();

        -- 4. إدراج تفاصيل قيد الإقفال (JournalDetails)
        
        -- إقفال الإيرادات (طبيعتها دائنة، يتم إقفالها مدين)
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
        SELECT @JID, AccountID, 
               CASE WHEN Balance > 0 THEN Balance ELSE 0 END, 
               CASE WHEN Balance < 0 THEN ABS(Balance) ELSE 0 END,
               @Desc
        FROM @Balances WHERE AccType = 'Revenue' AND Balance <> 0;

        -- إقفال المصروفات (طبيعتها مدينة، يتم إقفالها دائن)
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
        SELECT @JID, AccountID, 
               CASE WHEN Balance < 0 THEN ABS(Balance) ELSE 0 END, 
               CASE WHEN Balance > 0 THEN Balance ELSE 0 END,
               @Desc
        FROM @Balances WHERE AccType = 'Expenses' AND Balance <> 0;

        -- 5. إقفال صافي الربح / الخسارة في الأرباح المبقاة
        DECLARE @TotalRevenues DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM @Balances WHERE AccType = 'Revenue'), 0);
        DECLARE @TotalExpenses DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM @Balances WHERE AccType = 'Expenses'), 0);
        DECLARE @NetProfit DECIMAL(18,2) = @TotalRevenues - @TotalExpenses;

        IF @NetProfit <> 0
        BEGIN
            INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
            VALUES (@JID, @RetainedEarningsAccountID,
                    CASE WHEN @NetProfit < 0 THEN ABS(@NetProfit) ELSE 0 END,   -- خسارة -> نقلل من الأرباح المبقاة (مدين)
                    CASE WHEN @NetProfit > 0 THEN @NetProfit ELSE 0 END,         -- ربح -> نضيف للأرباح المبقاة (دائن)
                    N'إقفال صافي الربح / الخسارة');
        END

        -- 6. تحديث إجمالي القيد
        DECLARE @TotalDebit DECIMAL(18,2) = ISNULL((SELECT SUM(Debit) FROM [Accounting].[JournalDetails] WHERE JID = @JID), 0);
        UPDATE [Accounting].[JournalHeader] SET TotalAmount = @TotalDebit WHERE JID = @JID;

        -- 7. ترحيل القيد لإثبات الحركات في سجل القيود العام
        DECLARE @JournalNo INT;
        SELECT @JournalNo = JournalNo FROM [Accounting].[JournalHeader] WHERE JID = @JID;

        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            @JournalNo,
            @ClosingDate,
            'YearEndClose',
            @JID,
            D.AccountID,
            D.Debit,
            D.Credit,
            ISNULL(D.Notes, @Desc),
            @UserID
        FROM [Accounting].[JournalDetails] D
        WHERE D.JID = @JID;

        UPDATE [Accounting].[JournalHeader] SET IsPosted = 1 WHERE JID = @JID;

        COMMIT TRANSACTION;
        SELECT @JID AS ResultID, @JournalNo AS EntryNo, N'تم إقفال السنة المالية وترحيل القيد بنجاح.' AS ResultMsg;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
