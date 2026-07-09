-- =============================================
-- Inventory Schema - Product Card Procedures
-- بطاقة الصنف (التحليلات التفصيلية للصنف)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 1. تحديث ملخص بطاقة الصنف
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetSummary];
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
    DECLARE @AlertQty          DECIMAL(18,2) = 0;
    DECLARE @Barcode           NVARCHAR(50) = '';
    DECLARE @SalePrice         DECIMAL(18,2) = 0;

    -- معلومات الصنف
    SELECT 
        @AlertQty  = ISNULL(AlertQty, 0),
        @Barcode   = ISNULL(Barcode, ''),
        @SalePrice = ISNULL(SalePrice, 0)
    FROM [Inventory].[Products]
    WHERE ProductID = @ProductID;

    -- الرصيد الحالي التراكمي
    SELECT @Balance = ISNULL(SUM(CurrentQty), 0)
    FROM [Inventory].[ProductStock]
    WHERE ProductID = @ProductID;

    -- 1. إجمالي الوارد = فواتير الشراء
    SELECT
        @TotalInQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalInValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase';

    -- إضافة زيادة الجرد المعتمدة
    DECLARE @StockTakeInQty DECIMAL(18,2) = 0;
    DECLARE @StockTakeInValue DECIMAL(18,2) = 0;
    SELECT 
        @StockTakeInQty = ISNULL(SUM(d.DifferenceQuantity), 0),
        @StockTakeInValue = ISNULL(SUM(d.DifferenceValue), 0)
    FROM [Inventory].[StockTakeDetails] d
    INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
    WHERE d.ProductID = @ProductID
      AND h.Status = 'Approved'
      AND d.DifferenceQuantity > 0;

    SET @TotalInQty = @TotalInQty + @StockTakeInQty;
    SET @TotalInValue = @TotalInValue + @StockTakeInValue;

    -- 2. إجمالي الصادر = فواتير البيع
    SELECT
        @TotalOutQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalOutValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Sales';

    -- إضافة الهوالك المرحلة
    DECLARE @WastageOutQty DECIMAL(18,2) = 0;
    DECLARE @WastageOutValue DECIMAL(18,2) = 0;
    SELECT
        @WastageOutQty = ISNULL(SUM(d.Quantity), 0),
        @WastageOutValue = ISNULL(SUM(d.Quantity * d.CostPrice), 0)
    FROM [Inventory].[WastageDetails] d
    INNER JOIN [Inventory].[WastageHeader] h ON d.WastageID = h.WastageID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted = 1;

    -- إضافة عجز الجرد المعتمد
    DECLARE @StockTakeOutQty DECIMAL(18,2) = 0;
    DECLARE @StockTakeOutValue DECIMAL(18,2) = 0;
    SELECT
        @StockTakeOutQty = ISNULL(SUM(ABS(d.DifferenceQuantity)), 0),
        @StockTakeOutValue = ISNULL(SUM(ABS(d.DifferenceValue)), 0)
    FROM [Inventory].[StockTakeDetails] d
    INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
    WHERE d.ProductID = @ProductID
      AND h.Status = 'Approved'
      AND d.DifferenceQuantity < 0;

    SET @TotalOutQty = @TotalOutQty + @WastageOutQty + @StockTakeOutQty;
    SET @TotalOutValue = @TotalOutValue + @WastageOutValue + @StockTakeOutValue;

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
        @ProfitRate         AS ProfitRate,
        @AlertQty           AS AlertQty,
        @Barcode            AS Barcode,
        @SalePrice          AS SalePrice;
END
GO

-- =============================================
-- 2. تحديث أرصدة المستودعات مع إحصائيات الوارد والصادر والهالك
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetStockByWarehouse]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetStockByWarehouse];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetStockByWarehouse]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AlertQty DECIMAL(18,2) = 0;
    SELECT @AlertQty = ISNULL(AlertQty, 0)
    FROM [Inventory].[Products]
    WHERE ProductID = @ProductID;

    SELECT 
        w.WarehouseID,
        w.WarehouseName,
        ISNULL(s.CurrentQty, 0) AS CurrentQty,
        @AlertQty AS AlertQty,
        
        -- إجمالي الوارد (مشتريات للمستودع + زيادة الجرد)
        ISNULL((
            SELECT SUM(id.Quantity)
            FROM [Sales].[InvoiceDetails] id
            INNER JOIN [Sales].[InvoiceHeader] ih ON id.InvID = ih.InvID
            WHERE id.ProductID = @ProductID 
              AND ih.IsPosted = 1 
              AND ih.InvType = 'Purchase' 
              AND ih.WarehouseID = w.WarehouseID
        ), 0) +
        ISNULL((
            SELECT SUM(std.DifferenceQuantity)
            FROM [Inventory].[StockTakeDetails] std
            INNER JOIN [Inventory].[StockTakeHeader] sth ON std.StockTakeID = sth.StockTakeID
            WHERE std.ProductID = @ProductID 
              AND sth.Status = 'Approved' 
              AND sth.WarehouseID = w.WarehouseID
              AND std.DifferenceQuantity > 0
        ), 0) AS IncomingQty,

        -- إجمالي المنصرف (مبيعات للمستودع + هالك + عجز جرد)
        ISNULL((
            SELECT SUM(id.Quantity)
            FROM [Sales].[InvoiceDetails] id
            INNER JOIN [Sales].[InvoiceHeader] ih ON id.InvID = ih.InvID
            WHERE id.ProductID = @ProductID 
              AND ih.IsPosted = 1 
              AND ih.InvType = 'Sales' 
              AND ih.WarehouseID = w.WarehouseID
        ), 0) +
        ISNULL((
            SELECT SUM(wd.Quantity)
            FROM [Inventory].[WastageDetails] wd
            INNER JOIN [Inventory].[WastageHeader] wh ON wd.WastageID = wh.WastageID
            WHERE wd.ProductID = @ProductID 
              AND wh.IsPosted = 1 
              AND wh.WarehouseID = w.WarehouseID
        ), 0) +
        ISNULL((
            SELECT SUM(ABS(std.DifferenceQuantity))
            FROM [Inventory].[StockTakeDetails] std
            INNER JOIN [Inventory].[StockTakeHeader] sth ON std.StockTakeID = sth.StockTakeID
            WHERE std.ProductID = @ProductID 
              AND sth.Status = 'Approved' 
              AND sth.WarehouseID = w.WarehouseID
              AND std.DifferenceQuantity < 0
        ), 0) AS OutgoingQty,

        -- إجمالي الهالك الخاص بالمستودع
        ISNULL((
            SELECT SUM(wd.Quantity)
            FROM [Inventory].[WastageDetails] wd
            INNER JOIN [Inventory].[WastageHeader] wh ON wd.WastageID = wh.WastageID
            WHERE wd.ProductID = @ProductID 
              AND wh.IsPosted = 1 
              AND wh.WarehouseID = w.WarehouseID
        ), 0) AS WastageQty

    FROM [Settings].[Warehouses] w
    LEFT JOIN [Inventory].[ProductStock] s ON s.WarehouseID = w.WarehouseID AND s.ProductID = @ProductID
    ORDER BY w.WarehouseName;
END
GO

-- =============================================
-- 3. تحديث جلب حركات الصنف الموحدة
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetMovements]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetMovements];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetMovements]
    @ProductID   INT,
    @FilterType  NVARCHAR(10) = 'ALL',  -- 'ALL' | 'IN' | 'OUT'
    @PageNumber  INT          = 1,
    @PageSize    INT          = 15
AS
BEGIN
    SET NOCOUNT ON;

    WITH AllMovements AS (
        -- أ. الفواتير
        SELECT
            h.InvID,
            CAST(h.InvID AS NVARCHAR(50)) AS ReferenceNo,
            h.InvDate,
            h.InvType,
            CASE WHEN h.InvType = 'Purchase' THEN 'IN' ELSE 'OUT' END AS MovementDirection,
            CASE WHEN h.InvType = 'Purchase' THEN N'فاتورة شراء' ELSE N'فاتورة بيع' END AS InvTypeName,
            d.Quantity,
            d.UnitPrice,
            d.TotalPrice,
            p.PartnerName
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1

        UNION ALL

        -- ب. الهوالك (منصرف دائمًا)
        SELECT
            h.WastageID AS InvID,
            N'W-' + CAST(h.WastageID AS NVARCHAR(50)) AS ReferenceNo,
            h.WastageDate AS InvDate,
            'Wastage' AS InvType,
            'OUT' AS MovementDirection,
            N'إهلاك بضاعة' AS InvTypeName,
            d.Quantity,
            d.CostPrice AS UnitPrice,
            d.Quantity * d.CostPrice AS TotalPrice,
            w.WarehouseName AS PartnerName
        FROM [Inventory].[WastageDetails] d
        INNER JOIN [Inventory].[WastageHeader] h ON d.WastageID = h.WastageID
        LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1

        UNION ALL

        -- ج. الجرود (تسوية زيادة أو عجز)
        SELECT
            h.StockTakeID AS InvID,
            N'ST-' + CAST(h.StockTakeID AS NVARCHAR(50)) AS ReferenceNo,
            h.StockTakeDate AS InvDate,
            'StockTake' AS InvType,
            CASE WHEN d.DifferenceQuantity > 0 THEN 'IN' ELSE 'OUT' END AS MovementDirection,
            CASE WHEN d.DifferenceQuantity > 0 THEN N'تسوية جرد (زيادة)' ELSE N'تسوية جرد (عجز)' END AS InvTypeName,
            ABS(d.DifferenceQuantity) AS Quantity,
            d.CostPrice AS UnitPrice,
            ABS(d.DifferenceQuantity * d.CostPrice) AS TotalPrice,
            w.WarehouseName AS PartnerName
        FROM [Inventory].[StockTakeDetails] d
        INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
        LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID
          AND h.Status = 'Approved'
          AND d.DifferenceQuantity <> 0
    )
    SELECT 
        InvID,
        ReferenceNo,
        InvDate,
        InvType,
        MovementDirection,
        InvTypeName,
        Quantity,
        UnitPrice,
        TotalPrice,
        PartnerName,
        COUNT(*) OVER () AS TotalCount
    FROM AllMovements
    WHERE (
            @FilterType = 'ALL'
         OR (@FilterType = 'IN' AND MovementDirection = 'IN')
         OR (@FilterType = 'OUT' AND MovementDirection = 'OUT')
          )
    ORDER BY InvDate DESC, InvID DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- 4. تحديث الرسم البياني
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetChartData]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetChartData];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetChartData]
    @ProductID  INT,
    @MonthsBack INT = 12
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FromDate DATE = DATEADD(MONTH, -@MonthsBack, CAST(GETDATE() AS DATE));

    WITH DailyTransactions AS (
        -- الفواتير
        SELECT
            CAST(h.InvDate AS DATE) AS MovementDate,
            CASE WHEN h.InvType = 'Purchase' THEN d.Quantity ELSE 0 END AS InQty,
            CASE WHEN h.InvType = 'Sales' THEN d.Quantity ELSE 0 END AS OutQty
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1
          AND CAST(h.InvDate AS DATE) >= @FromDate

        UNION ALL

        -- الهوالك
        SELECT
            CAST(h.WastageDate AS DATE) AS MovementDate,
            0 AS InQty,
            d.Quantity AS OutQty
        FROM [Inventory].[WastageDetails] d
        INNER JOIN [Inventory].[WastageHeader] h ON d.WastageID = h.WastageID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1
          AND CAST(h.WastageDate AS DATE) >= @FromDate

        UNION ALL

        -- الجرود
        SELECT
            CAST(h.StockTakeDate AS DATE) AS MovementDate,
            CASE WHEN d.DifferenceQuantity > 0 THEN d.DifferenceQuantity ELSE 0 END AS InQty,
            CASE WHEN d.DifferenceQuantity < 0 THEN ABS(d.DifferenceQuantity) ELSE 0 END AS OutQty
        FROM [Inventory].[StockTakeDetails] d
        INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
        WHERE d.ProductID = @ProductID
          AND h.Status = 'Approved'
          AND d.DifferenceQuantity <> 0
          AND CAST(h.StockTakeDate AS DATE) >= @FromDate
    )
    SELECT
        CASE WHEN @MonthsBack <= 1 THEN MovementDate ELSE EOMONTH(MovementDate) END AS MovementDate,
        SUM(InQty) AS DailyInQty,
        SUM(OutQty) AS DailyOutQty,
        SUM(InQty - OutQty) AS NetDayMovement
    FROM DailyTransactions
    GROUP BY CASE WHEN @MonthsBack <= 1 THEN MovementDate ELSE EOMONTH(MovementDate) END
    ORDER BY MovementDate ASC;
END
GO

-- =============================================
-- 5. تعديل بيانات الصنف السريعة مـن لوحة البطاقة
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_UpdateQuickDetails]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_UpdateQuickDetails];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_UpdateQuickDetails]
    @ProductID   INT,
    @ProductName NVARCHAR(255),
    @Barcode     NVARCHAR(50),
    @SalePrice   DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Inventory].[Products]
    SET ProductName = ISNULL(@ProductName, ProductName),
        Barcode     = ISNULL(@Barcode, Barcode),
        SalePrice   = ISNULL(@SalePrice, SalePrice)
    WHERE ProductID = @ProductID;
END
GO
