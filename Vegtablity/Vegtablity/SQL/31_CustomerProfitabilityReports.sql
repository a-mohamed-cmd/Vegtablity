-- =============================================
-- 31_CustomerProfitabilityReports.sql
-- =============================================

-- 1. [Sales].[sp_Report_CustomerSalesSummary]
-- ملخص وربحية مبيعات العملاء: يوضح إجمالي المبيعات، التكلفة، الربح، وسداد ورصيد العملاء من قيود اليومية
IF OBJECT_ID('[Sales].[sp_Report_CustomerSalesSummary]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_CustomerSalesSummary];
GO
CREATE PROCEDURE [Sales].[sp_Report_CustomerSalesSummary]
    @StartDate DATETIME,
    @EndDate   DATETIME,
    @TopN      INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. استخراج تكلفة البضاعة المباعة (COGS) من قيود اليومية لكل فاتورة مرحلة
    ;WITH JournalInvoiceCOGS AS (
        SELECT 
            je.ReferenceID AS InvID,
            SUM(je.DebitAmount - je.CreditAmount) AS COGSCost
        FROM [Accounting].[JournalEntries] je
        INNER JOIN [Accounting].[ChartOfAccounts] a ON je.AccountID = a.AccountID
        WHERE je.ReferenceType = 'Invoice'
          AND (a.AccountType = 'COGS' OR a.AccountCode LIKE '51%')
          AND CAST(je.EntryDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
        GROUP BY je.ReferenceID
    ),
    -- 2. القاعدة الأساسية: تجميع المبيعات والسداد والأرصدة بالكامل من جدول القيود اليومية المرحلة
    CustomerJournalStats AS (
        SELECT 
            p.PartnerID,
            p.AccountID,
            -- عدد الفواتير المرحلة للعميل من واقع قيود اليومية
            COUNT(DISTINCT CASE 
                WHEN je.ReferenceType = 'Invoice' 
                     AND CAST(je.EntryDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
                THEN je.ReferenceID 
                ELSE NULL 
            END) AS InvoiceCount,
            -- إجمالي مبيعات العميل من واقع قيود اليومية المرحلة (الطرف المدين لقيود فواتير المبيعات)
            ISNULL(SUM(CASE 
                WHEN CAST(je.EntryDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
                     AND je.ReferenceType = 'Invoice'
                THEN (je.DebitAmount - je.CreditAmount)
                ELSE 0 
            END), 0) AS TotalSales,
            -- إجمالي سداد العميل من واقع قيود اليومية المرحلة (الطرف الدائن للسدادات وسندات القبض)
            ISNULL(SUM(CASE 
                WHEN CAST(je.EntryDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
                     AND (je.ReferenceType IN ('Payment', 'Voucher', 'Manual', 'Receipt') OR je.ReferenceType <> 'Invoice')
                     AND je.CreditAmount > 0
                THEN je.CreditAmount
                ELSE 0 
            END), 0) AS TotalPaid,
            -- رصيد مديونية العميل التراكمي حتى نهاية الفترة من واقع قيود اليومية المرحلة (المدين - الدائن)
            ISNULL(SUM(CASE 
                WHEN CAST(je.EntryDate AS DATE) <= CAST(@EndDate AS DATE)
                THEN (je.DebitAmount - je.CreditAmount)
                ELSE 0 
            END), 0) AS OutstandingDebt
        FROM [Sales].[Partners] p
        INNER JOIN [Accounting].[JournalEntries] je ON je.AccountID = p.AccountID
        GROUP BY p.PartnerID, p.AccountID
    ),
    -- 3. تكلفة المبيعات المحسوبة من قيود الفواتير المرتبطة بكل عميل
    CustomerCOGSFromJournals AS (
        SELECT 
            p.PartnerID,
            ISNULL(SUM(cogs.COGSCost), 0) AS TotalCOGS
        FROM [Sales].[Partners] p
        INNER JOIN [Accounting].[JournalEntries] je_cust ON je_cust.AccountID = p.AccountID AND je_cust.ReferenceType = 'Invoice'
        INNER JOIN JournalInvoiceCOGS cogs ON je_cust.ReferenceID = cogs.InvID
        WHERE CAST(je_cust.EntryDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
        GROUP BY p.PartnerID
    ),
    -- 4. دعم العملاء النقديين الذين ليس لهم حسابات دائن/مدين في دليل الحسابات (احتياطي فقط)
    CashCustomerInvoices AS (
        SELECT 
            p.PartnerID,
            ISNULL(p.PartnerName, N'عميل نقدي') AS PartnerName,
            ISNULL(p.Phone, '') AS Phone,
            p.AccountID,
            COUNT(DISTINCT h.InvID) AS InvoiceCount,
            ISNULL(SUM(h.NetAmount), 0) AS TotalSales,
            ISNULL(SUM(ISNULL(Det.TotalCost, 0)), 0) AS TotalCOGS,
            ISNULL(SUM(h.PaidAmount), 0) AS TotalPaid,
            ISNULL(SUM(h.Remainder), 0) AS OutstandingDebt
        FROM [Sales].[Partners] p
        INNER JOIN [Sales].[InvoiceHeader] h ON p.PartnerID = h.PartnerID
        LEFT JOIN (
            SELECT InvID, SUM(ISNULL(Quantity, 1) * ISNULL(CostPrice, 0)) AS TotalCost
            FROM [Sales].[InvoiceDetails]
            GROUP BY InvID
        ) Det ON h.InvID = Det.InvID
        WHERE p.AccountID IS NULL
          AND (h.InvType = 'Sales' OR h.InvType = 'Sale' OR h.InvType IS NULL OR h.InvType = '' OR h.InvType = N'مبيعات' OR h.InvType NOT LIKE '%Purchase%')
          AND h.IsPosted = 1
          AND CAST(h.InvDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
        GROUP BY p.PartnerID, p.PartnerName, p.Phone, p.AccountID
    ),
    -- 5. دمج البيانات مع إعطاء الأولوية التامة والمطلقة لقيود اليومية المرحلة
    CombinedResults AS (
        SELECT 
            p.PartnerID,
            p.PartnerName,
            ISNULL(p.Phone, '') AS Phone,
            p.AccountID,
            j.InvoiceCount,
            j.TotalSales,
            -- تكلفة البضاعة من قيود اليومية، وبديل تفاصيل الفاتورة إذا لم يتم قيد التكلفة محاسبياً
            CASE 
                WHEN ISNULL(c.TotalCOGS, 0) > 0 THEN c.TotalCOGS
                ELSE ISNULL((
                    SELECT SUM(ISNULL(d.Quantity, 1) * ISNULL(d.CostPrice, 0))
                    FROM [Sales].[InvoiceHeader] ih
                    JOIN [Sales].[InvoiceDetails] d ON ih.InvID = d.InvID
                    WHERE ih.PartnerID = p.PartnerID AND ih.IsPosted = 1
                      AND CAST(ih.InvDate AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(@EndDate AS DATE)
                ), 0)
            END AS TotalCOGS,
            j.TotalPaid,
            j.OutstandingDebt
        FROM [Sales].[Partners] p
        INNER JOIN CustomerJournalStats j ON p.PartnerID = j.PartnerID
        LEFT JOIN CustomerCOGSFromJournals c ON p.PartnerID = c.PartnerID
        WHERE (j.TotalSales > 0 OR j.TotalPaid > 0 OR j.OutstandingDebt <> 0)

        UNION ALL

        -- العملاء النقديون بدون قيود في حال وجودهم
        SELECT 
            csh.PartnerID,
            csh.PartnerName,
            csh.Phone,
            csh.AccountID,
            csh.InvoiceCount,
            csh.TotalSales,
            csh.TotalCOGS,
            csh.TotalPaid,
            csh.OutstandingDebt
        FROM CashCustomerInvoices csh
        WHERE csh.PartnerID NOT IN (SELECT PartnerID FROM CustomerJournalStats)
    )
    -- 6. الاستعلام النهائي
    SELECT TOP (ISNULL(NULLIF(@TopN, 0), 2147483647))
        r.PartnerID,
        r.PartnerName,
        r.Phone,
        r.AccountID,
        r.InvoiceCount,
        r.TotalSales,
        r.TotalCOGS,
        r.TotalCOGS AS TotalCost,
        (r.TotalSales - r.TotalCOGS) AS TotalProfit,
        (r.TotalSales - r.TotalCOGS) AS NetProfit,
        CASE 
            WHEN r.TotalSales > 0 
            THEN ((r.TotalSales - r.TotalCOGS) / r.TotalSales) * 100 
            ELSE 0 
        END AS ProfitMarginPercent,
        r.TotalPaid,
        r.OutstandingDebt
    FROM CombinedResults r
    ORDER BY TotalProfit DESC;
END
GO

-- 2. [Sales].[sp_Report_CustomerInvoicesDetail]
-- فواتير عميل معين: يسرد الفواتير مع توضيح ربحية كل فاتورة
IF OBJECT_ID('[Sales].[sp_Report_CustomerInvoicesDetail]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_CustomerInvoicesDetail];
GO
CREATE PROCEDURE [Sales].[sp_Report_CustomerInvoicesDetail]
    @PartnerID INT,
    @StartDate DATETIME,
    @EndDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.InvID,
        h.InvDate,
        h.ReferenceNo,
        h.TotalAmount,
        h.Discount,
        h.NetAmount,
        ISNULL(Det.TotalCost, 0) AS TotalCOGS,
        h.NetAmount - ISNULL(Det.TotalCost, 0) AS Profit
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN (
        SELECT InvID, SUM(Quantity * CostPrice) AS TotalCost
        FROM [Sales].[InvoiceDetails]
        GROUP BY InvID
    ) Det ON h.InvID = Det.InvID
    WHERE h.InvType = 'Sales' AND h.IsPosted = 1
      AND h.PartnerID = @PartnerID
      AND h.InvDate BETWEEN @StartDate AND @EndDate
    ORDER BY h.InvDate DESC;
END
GO

-- 3. [Sales].[sp_Report_CustomerProductSales]
-- مبيعات الأصناف لكل عميل: مجمع حسب الصنف والعميل
IF OBJECT_ID('[Sales].[sp_Report_CustomerProductSales]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_CustomerProductSales];
GO
CREATE PROCEDURE [Sales].[sp_Report_CustomerProductSales]
    @PartnerID INT, -- اختياري (إذا كان 0 يعرض للكل)
    @StartDate DATETIME,
    @EndDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PartnerName,
        prod.ProductName,
        SUM(d.Quantity) AS TotalQty,
        SUM(d.TotalPrice) AS TotalSalesValue,
        SUM(d.Quantity * d.CostPrice) AS TotalCostValue,
        SUM(d.TotalPrice) - SUM(d.Quantity * d.CostPrice) AS NetProfit
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    INNER JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    INNER JOIN [Inventory].[Products] prod ON d.ProductID = prod.ProductID
    WHERE h.InvType = 'Sales' AND h.IsPosted = 1
      AND (@PartnerID = 0 OR h.PartnerID = @PartnerID)
      AND h.InvDate BETWEEN @StartDate AND @EndDate
    GROUP BY p.PartnerName, prod.ProductName
    ORDER BY p.PartnerName, TotalSalesValue DESC;
END
GO

PRINT N'✅ تم إنشاء تقارير ربحية العملاء بنجاح';
GO
