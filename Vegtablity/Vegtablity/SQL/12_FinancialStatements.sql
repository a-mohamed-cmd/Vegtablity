USE VegtablityDB;
GO

-- =============================================
-- 1. قائمة الأرباح والخسائر (Profit & Loss)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Report_ProfitLoss]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_ProfitLoss];
GO

CREATE PROCEDURE [Accounting].[sp_Report_ProfitLoss]
    @StartDate DATETIME,
    @EndDate DATETIME,
    @ReportLevel INT = 0 -- 0: Main Categoric, 1: Sub, 2: Group
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. حساب إجمالي الحركات من قيود اليومية لجميع حسابات الإيرادات والمصروفات
    -- متطابق كلياً مع إجراء الويب (CAST AS DATE لشمول كامل اليوم الأخير حتى 23:59:59)
    WITH RawTotals AS (
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    -- الإيرادات: الدائن - المدين (مطابق لإجراء الويب)
                    WHEN (A.AccountType IN ('Revenue', N'إيرادات', N'الايرادات') OR A.AccountCode LIKE '4%') 
                        THEN (ISNULL(JE.CreditAmount, 0) - ISNULL(JE.DebitAmount, 0))
                    -- المصروفات وتكلفة المبيعات: المدين - الدائن
                    WHEN (A.AccountType IN ('Expenses', 'COGS', N'مصروفات', N'المصروفات', N'تكلفة المبيعات') OR A.AccountCode LIKE '5%' OR A.AccountCode LIKE '6%') 
                        THEN (ISNULL(JE.DebitAmount, 0) - ISNULL(JE.CreditAmount, 0))
                    ELSE (ISNULL(JE.DebitAmount, 0) - ISNULL(JE.CreditAmount, 0))
                END
            ) as PeriodBalance
        FROM [Accounting].[JournalEntries] JE
        INNER JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE (
            A.AccountType IN ('Revenue', 'Expenses', 'COGS', N'إيرادات', N'الايرادات', N'مصروفات', N'المصروفات', N'تكلفة المبيعات')
            OR A.AccountCode LIKE '4%' 
            OR A.AccountCode LIKE '5%' 
            OR A.AccountCode LIKE '6%'
        )
          -- حل مشكلة نقص اليوم: تحويل التاريخ لـ DATE لضمان شمول كامل حركات اليوم الأخير
          AND CAST(JE.EntryDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
        GROUP BY A.AccountID
    ),
    -- 2. بناء تسلسل شجرة الحسابات (Hierarchy)
    Hierarchy AS (
        SELECT 
            AccountID, 
            ParentAccountID, 
            AccountCode, 
            AccountName, 
            AccountLevel, 
            IsTransactional,
            AccountID as RootParentID
        FROM [Accounting].[ChartOfAccounts]
        WHERE (AccountLevel = @ReportLevel OR (@ReportLevel = 0 AND ParentAccountID IS NULL))
          AND (
            AccountType IN ('Revenue', 'Expenses', 'COGS', N'إيرادات', N'الايرادات', N'مصروفات', N'المصروفات') 
            OR AccountCode LIKE '4%' 
            OR AccountCode LIKE '5%' 
            OR AccountCode LIKE '6%'
          )

        UNION ALL

        SELECT 
            c.AccountID, 
            c.ParentAccountID, 
            c.AccountCode, 
            c.AccountName, 
            c.AccountLevel, 
            c.IsTransactional,
            h.RootParentID
        FROM [Accounting].[ChartOfAccounts] c
        JOIN Hierarchy h ON c.ParentAccountID = h.AccountID
    ),
    -- 3. تجميع البيانات وضمان عدم سقوط أي قيد يومية مسجل
    AggregatedData AS (
        SELECT 
            h.RootParentID as AccountID,
            p.AccountCode,
            p.AccountName,
            CASE 
                WHEN p.AccountType IN ('Revenue', N'إيرادات', N'الايرادات') OR p.AccountCode LIKE '4%' THEN 'Revenue'
                ELSE 'Expenses'
            END AS AccountType,
            SUM(ISNULL(r.PeriodBalance, 0)) as Balance
        FROM Hierarchy h
        LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
        JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
        WHERE (h.IsTransactional = 1 OR NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] child WHERE child.ParentAccountID = h.AccountID) OR r.PeriodBalance IS NOT NULL)
        GROUP BY h.RootParentID, p.AccountCode, p.AccountName,
                 CASE WHEN p.AccountType IN ('Revenue', N'إيرادات', N'الايرادات') OR p.AccountCode LIKE '4%' THEN 'Revenue' ELSE 'Expenses' END

        UNION ALL

        -- ضمان الأمان المحاسبي التام: الحسابات التي عليها قيود يومية وسقط تسلسلها في الشجرة
        SELECT 
            a.AccountID,
            a.AccountCode,
            a.AccountName,
            CASE 
                WHEN a.AccountType IN ('Revenue', N'إيرادات', N'الايرادات') OR a.AccountCode LIKE '4%' THEN 'Revenue'
                ELSE 'Expenses'
            END AS AccountType,
            r.PeriodBalance as Balance
        FROM RawTotals r
        JOIN [Accounting].[ChartOfAccounts] a ON r.AccountID = a.AccountID
        WHERE r.AccountID NOT IN (SELECT AccountID FROM Hierarchy)
    )
    SELECT 
        AccountID,
        AccountCode,
        AccountName,
        AccountType,
        SUM(Balance) as Balance
    FROM AggregatedData
    GROUP BY AccountID, AccountCode, AccountName, AccountType
    ORDER BY AccountCode;
END
GO

-- =============================================
-- 2. قائمة المركز المالي (Balance Sheet)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Report_BalanceSheet]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_BalanceSheet];
GO

CREATE PROCEDURE [Accounting].[sp_Report_BalanceSheet]
    @AsOfDate DATETIME,
    @ReportLevel INT = 0 -- 0: Main, 1: Sub, 2: Group
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate Transactional Totals for Assets, Liabilities, and Equity
    -- Important: In accounting, Balance Sheet items are cumulative.
    WITH RawTotals AS (
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    WHEN A.AccountType = 'Assets' THEN (JE.DebitAmount - JE.CreditAmount)
                    WHEN A.AccountType IN ('Liabilities', 'Equity') THEN (JE.CreditAmount - JE.DebitAmount)
                    ELSE (JE.DebitAmount - JE.CreditAmount)
                END
            ) as CurrentBalance
        FROM [Accounting].[JournalEntries] JE
        JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE A.AccountType IN ('Assets', 'Liabilities', 'Equity')
          AND JE.EntryDate <= @AsOfDate
        GROUP BY A.AccountID
    ),
    -- 2. Build Hierarchy
    Hierarchy AS (
        SELECT 
            AccountID, 
            ParentAccountID, 
            AccountCode, 
            AccountName, 
            AccountLevel, 
            IsTransactional,
            AccountID as RootParentID
        FROM [Accounting].[ChartOfAccounts]
        WHERE AccountLevel = @ReportLevel
          AND AccountType IN ('Assets', 'Liabilities', 'Equity')

        UNION ALL

        SELECT 
            c.AccountID, 
            c.ParentAccountID, 
            c.AccountCode, 
            c.AccountName, 
            c.AccountLevel, 
            c.IsTransactional,
            h.RootParentID
        FROM [Accounting].[ChartOfAccounts] c
        JOIN Hierarchy h ON c.ParentAccountID = h.AccountID
    )
    -- 3. Aggregation
    SELECT 
        h.RootParentID as AccountID,
        p.AccountCode,
        p.AccountName,
        p.AccountType,
        SUM(ISNULL(r.CurrentBalance, 0)) as Balance
    FROM Hierarchy h
    LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
    JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
    WHERE h.IsTransactional = 1
    GROUP BY h.RootParentID, p.AccountCode, p.AccountName, p.AccountType
    ORDER BY p.AccountCode;
END
GO
