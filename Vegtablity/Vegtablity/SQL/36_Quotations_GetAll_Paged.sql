-- =============================================
-- Sales Quotations - GetAllPaged (For WPF Quotations History)
-- =============================================
USE [VegtablityDB];
GO

-- [Sales].[sp_Quotations_GetAll_Paged]
-- يُستدعى من شاشة سجل عروض الأسعار بـ WPF لعرض كافة عروض الأسعار (القديمة والجديدة والفعالة وغير الفعالة)
IF OBJECT_ID('[Sales].[sp_Quotations_GetAll_Paged]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Quotations_GetAll_Paged];
GO

CREATE PROCEDURE [Sales].[sp_Quotations_GetAll_Paged]
    @PageNumber INT = 1,
    @PageSize   INT = 20,
    @SearchText NVARCHAR(150) = NULL,
    @PartnerID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. إجمالي عدد السجلات (جميع عروض الأسعار: القديمة والجديدة والفعالة وغير الفعالة)
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText);

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
    WHERE (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText)
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
