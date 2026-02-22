USE VegtablityDB;
GO

IF OBJECT_ID('[Accounting].[sp_Report_TrialBalance]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_TrialBalance];
GO

CREATE PROCEDURE [Accounting].[sp_Report_TrialBalance]
    @StartDate DATETIME,
    @EndDate DATETIME,
    @ReportLevel INT = 0 -- 0: Main, 1: Sub, 2: Group, 3: Transactional (Detailed)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate Transactional Totals
    WITH RawTotals AS (
        SELECT 
            AccountID,
            SUM(CASE WHEN EntryDate < @StartDate THEN (Debit - Credit) ELSE 0 END) as OpeningBalance,
            SUM(CASE WHEN EntryDate >= @StartDate AND EntryDate <= @EndDate THEN Debit ELSE 0 END) as PeriodDebit,
            SUM(CASE WHEN EntryDate >= @StartDate AND EntryDate <= @EndDate THEN Credit ELSE 0 END) as PeriodCredit
        FROM [Accounting].[JournalEntries]
        GROUP BY AccountID
    ),
    -- 2. Build Account Hierarchy with recursive leaf counts/sums
    Hierarchy AS (
        SELECT 
            AccountID, 
            ParentAccountID, 
            AccountCode, 
            AccountName, 
            AccountLevel, 
            IsTransactional,
            AccountID as RootParentID -- Tracking the ancestor at the requested level
        FROM [Accounting].[ChartOfAccounts]
        WHERE (@ReportLevel = 3 AND IsTransactional = 1) -- تفصيلي (Transaction Level)
           OR (@ReportLevel >= 0 AND @ReportLevel <= 2 AND AccountLevel = @ReportLevel + 1) -- 0:Main(1), 1:Sub(2), 2:Group(3)

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
    -- 3. Final Aggregation based on the RootParentID (the requested level)
    SELECT 
        h.RootParentID as AccountID,
        p.AccountCode,
        p.AccountName,
        p.AccountType,
        SUM(ISNULL(r.OpeningBalance, 0)) as OpeningBalance,
        SUM(ISNULL(r.PeriodDebit, 0)) as PeriodDebit,
        SUM(ISNULL(r.PeriodCredit, 0)) as PeriodCredit,
        -- Ending = Opening + (MoveDr - MoveCr)
        (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) as EndingBalance,
        
        -- Keep Dr/Cr for internal use if needed
        CASE WHEN (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) >= 0 
             THEN (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) 
             ELSE 0 END as EndingDebit,
        CASE WHEN (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) < 0 
             THEN ABS(SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) 
             ELSE 0 END as EndingCredit

    FROM Hierarchy h
    LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
    JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
    WHERE h.IsTransactional = 1 -- Only sum up transactional data
    GROUP BY h.RootParentID, p.AccountCode, p.AccountName, p.AccountType
    ORDER BY p.AccountCode;
END
GO
