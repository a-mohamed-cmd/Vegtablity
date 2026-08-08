-- =============================================
-- Sales Quotations - GetPaged (Missing SP)
-- =============================================
USE [VegtablityDB];
GO

-- [Sales].[sp_Quotations_GetPaged]
-- يُستدعى من QuoteService.GetQuotesPaged لعرض سجل عروض الأسعار مع ترقيم الصفحات
IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO

CREATE PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize   INT = 20,
    @SearchText NVARCHAR(200) = NULL,
    @PartnerID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. إجمالي عدد السجلات
    SELECT COUNT(*) AS TotalCount
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE
        q.IsActive = 1 
        AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
        AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
        AND (
            @SearchText IS NULL
            OR @SearchText = ''
            OR p.PartnerName LIKE N'%' + @SearchText + N'%'
            OR CAST(q.QuoteID AS NVARCHAR) LIKE N'%' + @SearchText + N'%'
        );

    -- 2. البيانات المرقّمة
    SELECT
        q.QuoteID,
        q.PartnerID,
        q.QuoteDate,
        q.ExpiryDate,
        q.IsActive,
        q.Notes,
        p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE
        q.IsActive = 1 
        AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
        AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
        AND (
            @SearchText IS NULL
            OR @SearchText = ''
            OR p.PartnerName LIKE N'%' + @SearchText + N'%'
            OR CAST(q.QuoteID AS NVARCHAR) LIKE N'%' + @SearchText + N'%'
        )
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
