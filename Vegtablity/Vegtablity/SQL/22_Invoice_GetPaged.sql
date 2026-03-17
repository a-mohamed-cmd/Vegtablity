-- =============================================
-- Optimized Paging for Invoices
-- =============================================
USE VegtablityDB;
GO

IF OBJECT_ID('[Sales].[sp_Invoice_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetPaged];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @InvType NVARCHAR(20) = 'Sales',
    @SearchText NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. Get Total Count
    SELECT COUNT(*) 
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    WHERE h.InvType = @InvType
      AND (@SearchText IS NULL OR 
           p.PartnerName LIKE '%' + @SearchText + '%' OR 
           h.ReferenceNo LIKE '%' + @SearchText + '%' OR
           CAST(h.InvID AS NVARCHAR) = @SearchText);

    -- 2. Get Paged Data
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    WHERE h.InvType = @InvType
      AND (@SearchText IS NULL OR 
           p.PartnerName LIKE '%' + @SearchText + '%' OR 
           h.ReferenceNo LIKE '%' + @SearchText + '%' OR 
           CAST(h.InvID AS NVARCHAR) = @SearchText)
    ORDER BY h.InvID DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
