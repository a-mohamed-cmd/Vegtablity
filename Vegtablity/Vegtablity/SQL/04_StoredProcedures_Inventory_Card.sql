-- =============================================
-- Inventory Schema - Product Card Procedures
-- بطاقة الصنف (التحليلات التفصيلية للصنف)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 1. جلب ملخص بطاقة الصنف
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetSummary]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetSummary];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetSummary]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Balance           DECIMAL(18,2) = 0;
    DECLARE @AvgCost           DECIMAL(18,2) = 0;
    DECLARE @TotalInQty        DECIMAL(18,2) = 0;
    DECLARE @TotalInValue      DECIMAL(18,2) = 0;
    DECLARE @TotalOutQty       DECIMAL(18,2) = 0;
    DECLARE @TotalOutValue     DECIMAL(18,2) = 0;
    DECLARE @LastPurchasePrice DECIMAL(18,2) = 0;
    DECLARE @ProfitRate        DECIMAL(18,2) = 0;

    -- الرصيد الحالي
    SELECT @Balance = ISNULL(SUM(CurrentQty), 0)
    FROM [Inventory].[ProductStock]
    WHERE ProductID = @ProductID;

    -- إجمالي الوارد = فواتير الشراء (Purchase)
    SELECT
        @TotalInQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalInValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase';

    -- إجمالي الصادر = فواتير البيع (Sales)
    SELECT
        @TotalOutQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalOutValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Sales';

    -- آخر سعر شراء
    SELECT TOP 1 @LastPurchasePrice = ISNULL(d.UnitPrice, 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase'
    ORDER BY h.InvDate DESC, h.InvID DESC;

    -- متوسط سعر التكلفة
    IF @TotalInQty > 0
        SET @AvgCost = @TotalInValue / @TotalInQty;

    -- معدل الربح التقريبي
    IF @TotalOutQty > 0 AND @AvgCost > 0
    BEGIN
        DECLARE @TotalCostOfSales DECIMAL(18,2) = @TotalOutQty * @AvgCost;
        IF @TotalCostOfSales > 0
            SET @ProfitRate = ((@TotalOutValue - @TotalCostOfSales) / @TotalCostOfSales) * 100;
        ELSE
            SET @ProfitRate = 100;
    END

    SELECT
        @Balance            AS Balance,
        @AvgCost            AS AvgCost,
        @TotalInQty         AS TotalInQty,
        @TotalInValue       AS TotalInValue,
        @TotalOutQty        AS TotalOutQty,
        @TotalOutValue      AS TotalOutValue,
        @LastPurchasePrice  AS LastPurchasePrice,
        @ProfitRate         AS ProfitRate;
END
GO

-- =============================================
-- 2. جلب حركة الصنف (Server-Side Pagination)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetMovements]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetMovements];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetMovements]
    @ProductID   INT,
    @FilterType  NVARCHAR(10) = 'ALL',  -- 'ALL' | 'IN' | 'OUT'
    @PageNumber  INT          = 1,
    @PageSize    INT          = 15
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.InvID,
        h.ReferenceNo,
        h.InvDate,
        h.InvType,
        CASE
            WHEN h.InvType = 'Purchase' THEN 'IN'
            WHEN h.InvType = 'Sales'    THEN 'OUT'
            ELSE 'OTHER'
        END AS MovementDirection,
        CASE
            WHEN h.InvType = 'Purchase' THEN N'فاتورة شراء'
            WHEN h.InvType = 'Sales'    THEN N'فاتورة بيع'
            ELSE h.InvType
        END AS InvTypeName,
        d.Quantity,
        d.UnitPrice,
        d.TotalPrice,
        p.PartnerName,
        -- إجمالي الصفوف المطابقة (بدون OFFSET) لحساب عدد الصفحات
        COUNT(*) OVER () AS TotalCount
    FROM [Sales].[InvoiceDetails]  d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID     = h.InvID
    LEFT  JOIN [Sales].[Partners]      p ON h.PartnerID = p.PartnerID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND (
            @FilterType = 'ALL'
         OR (@FilterType = 'IN'  AND h.InvType = 'Purchase')
         OR (@FilterType = 'OUT' AND h.InvType = 'Sales')
          )
    ORDER BY h.InvDate DESC, h.InvID DESC
    OFFSET  (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- 3. بيانات الرسم البياني (تجميع يومي مع فلتر الفترة)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetChartData]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetChartData];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetChartData]
    @ProductID  INT,
    @MonthsBack INT = 12   -- 1 | 3 | 6 | 12
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FromDate DATE = DATEADD(MONTH, -@MonthsBack, CAST(GETDATE() AS DATE));

    IF @MonthsBack <= 1
    BEGIN
        -- عرض يومي إذا كان شهر أو أقل
        SELECT
            CAST(h.InvDate AS DATE) AS MovementDate,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE 0           END) AS DailyInQty,
            SUM(CASE WHEN h.InvType = 'Sales'    THEN  d.Quantity ELSE 0           END) AS DailyOutQty,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE -d.Quantity END) AS NetDayMovement
        FROM [Sales].[InvoiceDetails]  d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted  = 1
          AND CAST(h.InvDate AS DATE) >= @FromDate
        GROUP BY CAST(h.InvDate AS DATE)
        ORDER BY CAST(h.InvDate AS DATE) ASC;
    END
    ELSE
    BEGIN
        -- عرض شهري (مجمّع بآخر يوم في الشهر لتسهيل الفرز وعرض التاريخ) إذا كان أكثر من شهر
        SELECT
            EOMONTH(h.InvDate) AS MovementDate,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE 0           END) AS DailyInQty,
            SUM(CASE WHEN h.InvType = 'Sales'    THEN  d.Quantity ELSE 0           END) AS DailyOutQty,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE -d.Quantity END) AS NetDayMovement
        FROM [Sales].[InvoiceDetails]  d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted  = 1
          AND CAST(h.InvDate AS DATE) >= @FromDate
        GROUP BY EOMONTH(h.InvDate)
        ORDER BY EOMONTH(h.InvDate) ASC;
    END
END
GO
