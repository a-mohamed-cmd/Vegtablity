-- =============================================
-- Optimized Pagination Stored Procedures
-- =============================================
USE VegtablityDB;
GO

-- 1. Paged Products with Search
IF OBJECT_ID('[Inventory].[sp_Product_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetPaged];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get Total count for UI
    SELECT COUNT(*) AS TotalCount
    FROM [Inventory].[Products] p
    WHERE p.IsActive = 1 AND (
        @SearchText IS NULL OR @SearchText = ''
        OR p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
        OR (ISNUMERIC(@SearchText) = 1 AND p.ProductID = TRY_CAST(@SearchText AS INT))
    );

    -- Get Page Data
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1 AND (
        @SearchText IS NULL OR @SearchText = ''
        OR p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
        OR (ISNUMERIC(@SearchText) = 1 AND p.ProductID = TRY_CAST(@SearchText AS INT))
    )
    ORDER BY p.ProductName -- Logical sort for users
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- 2. Paged Quotations History
IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL,
    @PartnerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total Count
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText);

    -- Page Data
    SELECT q.*, p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText)
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
