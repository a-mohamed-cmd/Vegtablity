-- ============================================================
-- Patch 38: Update sp_JournalEntry_GetPaged with Advanced Search & Filter
-- Fully backward-compatible with all existing versions
-- ============================================================

IF OBJECT_ID('[Accounting].[sp_JournalEntry_GetPaged]', 'P') IS NOT NULL 
    DROP PROCEDURE [Accounting].[sp_JournalEntry_GetPaged];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_GetPaged]
    @PageIndex     INT = 1,
    @PageSize      INT = 20,
    @JournalNo     NVARCHAR(50) = NULL,
    @SearchText    NVARCHAR(255) = NULL,
    @IsPosted      BIT = NULL,
    @StartDate     DATETIME = NULL,
    @EndDate       DATETIME = NULL,
    @TotalCount    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- تنظيف المدخلات
    SET @JournalNo = NULLIF(LTRIM(RTRIM(@JournalNo)), '');
    SET @SearchText = NULLIF(LTRIM(RTRIM(@SearchText)), '');

    -- ضبط تاريخ النهاية ليشمل اليوم كاملاً حتى 23:59:59
    IF @EndDate IS NOT NULL AND CAST(@EndDate AS TIME) = '00:00:00'
        SET @EndDate = DATEADD(SECOND, -1, DATEADD(DAY, 1, CAST(@EndDate AS DATE)));

    -- 1. حساب إجمالي عدد القيود المطابقة لشروط البحث
    SELECT @TotalCount = COUNT(1)
    FROM [Accounting].[JournalHeader]
    WHERE ReferenceType IN ('Manual', 'YearEndClose')
      AND (@JournalNo IS NULL OR CAST(JournalNo AS NVARCHAR(50)) LIKE '%' + @JournalNo + '%')
      AND (@SearchText IS NULL OR Description LIKE '%' + @SearchText + '%')
      AND (@IsPosted IS NULL OR IsPosted = @IsPosted)
      AND (@StartDate IS NULL OR CAST(JDate AS DATE) >= CAST(@StartDate AS DATE))
      AND (@EndDate IS NULL OR CAST(JDate AS DATE) <= CAST(@EndDate AS DATE));

    -- 2. جلب صفحة القيود المطلوبة مع الترقيم
    SELECT JID, JournalNo, JDate, Description, TotalAmount, IsPosted, ReferenceType
    FROM [Accounting].[JournalHeader]
    WHERE ReferenceType IN ('Manual', 'YearEndClose')
      AND (@JournalNo IS NULL OR CAST(JournalNo AS NVARCHAR(50)) LIKE '%' + @JournalNo + '%')
      AND (@SearchText IS NULL OR Description LIKE '%' + @SearchText + '%')
      AND (@IsPosted IS NULL OR IsPosted = @IsPosted)
      AND (@StartDate IS NULL OR CAST(JDate AS DATE) >= CAST(@StartDate AS DATE))
      AND (@EndDate IS NULL OR CAST(JDate AS DATE) <= CAST(@EndDate AS DATE))
    ORDER BY JID DESC
    OFFSET (@PageIndex - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);
END
GO

PRINT N'=== [Accounting].[sp_JournalEntry_GetPaged] updated successfully ===';
