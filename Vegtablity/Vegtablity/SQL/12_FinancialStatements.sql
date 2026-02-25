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

    -- 1. Calculate Transactional Totals for Revenue and Expenses
    WITH RawTotals AS (
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    WHEN A.AccountType = 'Revenue' THEN (JE.CreditAmount - JE.DebitAmount)
                    WHEN A.AccountType = 'Expenses' THEN (JE.DebitAmount - JE.CreditAmount)
                    ELSE (JE.DebitAmount - JE.CreditAmount)
                END
            ) as PeriodBalance
        FROM [Accounting].[JournalEntries] JE
        JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE A.AccountType IN ('Revenue', 'Expenses')
          AND JE.EntryDate BETWEEN @StartDate AND @EndDate
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
          AND AccountType IN ('Revenue', 'Expenses')

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
        SUM(ISNULL(r.PeriodBalance, 0)) as Balance
    FROM Hierarchy h
    LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
    JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
    WHERE h.IsTransactional = 1
    GROUP BY h.RootParentID, p.AccountCode, p.AccountName, p.AccountType
    ORDER BY p.AccountCode;
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
