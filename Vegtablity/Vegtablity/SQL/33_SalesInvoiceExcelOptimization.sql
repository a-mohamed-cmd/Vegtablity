-- =============================================
-- Sales Invoice Excel Import Optimization
-- =============================================

-- 1. Create Performance Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Quotations_PartnerID_Active' AND object_id = OBJECT_ID('Sales.Quotations'))
BEGIN
    CREATE INDEX [IX_Quotations_PartnerID_Active] 
    ON [Sales].[Quotations] ([PartnerID], [IsActive]) 
    INCLUDE ([QuoteID], [QuoteDate], [ExpiryDate]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_QuotationDetails_ProductID' AND object_id = OBJECT_ID('Sales.QuotationDetails'))
BEGIN
    CREATE INDEX [IX_QuotationDetails_ProductID] 
    ON [Sales].[QuotationDetails] ([ProductID]) 
    INCLUDE ([QuotedPrice], [QuoteID]);
END
GO

-- 2. Create Pricing Lookup Stored Procedure
IF OBJECT_ID('[Sales].[sp_GetProductPricingForInvoice]', 'P') IS NOT NULL 
    DROP PROCEDURE [Sales].[sp_GetProductPricingForInvoice];
GO

CREATE PROCEDURE [Sales].[sp_GetProductPricingForInvoice]
    @Barcode NVARCHAR(50),
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Search by Barcode first, then by exact Name match if barcode yields nothing
    DECLARE @PID INT;
    SELECT @PID = ProductID FROM [Inventory].[Products] WHERE Barcode = @Barcode;
    
    IF @PID IS NULL
    BEGIN
        SELECT @PID = ProductID FROM [Inventory].[Products] WHERE ProductName = @Barcode;
    END

    -- If product found, get details and quoted price
    IF @PID IS NOT NULL
    BEGIN
        SELECT 
            p.ProductID,
            p.Barcode,
            p.ProductName,
            u.UnitName,
            p.SalePrice AS DefaultSalePrice,
            p.PurchasePrice AS CostPrice,
            (
                -- Prioritize the latest active quotation for this specific partner
                SELECT TOP 1 qd.QuotedPrice
                FROM [Sales].[QuotationDetails] qd
                INNER JOIN [Sales].[Quotations] q ON qd.QuoteID = q.QuoteID
                WHERE qd.ProductID = p.ProductID
                  AND q.PartnerID = @PartnerID
                  AND q.IsActive = 1
                  AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= GETDATE())
                ORDER BY q.QuoteDate DESC
            ) AS QuotedPrice
        FROM [Inventory].[Products] p
        LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
        WHERE p.ProductID = @PID;
    END
    ELSE
    BEGIN
        -- Return empty result set with correct schema
        SELECT 
            CAST(0 AS INT) AS ProductID,
            @Barcode AS Barcode,
            CAST(NULL AS NVARCHAR(200)) AS ProductName,
            CAST(NULL AS NVARCHAR(50)) AS UnitName,
            CAST(0 AS DECIMAL(18,3)) AS DefaultSalePrice,
            CAST(0 AS DECIMAL(18,3)) AS CostPrice,
            CAST(NULL AS DECIMAL(18,3)) AS QuotedPrice
        WHERE 1=0; -- Return no rows but provide schema for Dapper
    END
END
GO
