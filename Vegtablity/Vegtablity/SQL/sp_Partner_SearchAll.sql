-- =============================================
-- [Sales].[sp_Partner_SearchAll]
-- البحث في العملاء والموردين معاً بالاسم أو رقم الحساب
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_SearchAll]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Partner_SearchAll];
GO

CREATE PROCEDURE [Sales].[sp_Partner_SearchAll]
    @SearchText NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PartnerID,
        p.PartnerName,
        p.PartnerType,        -- 'Customer' / 'Supplier'
        p.Phone,
        p.IsActive,
        p.AccountID,
        c.AccountCode         -- رقم الحساب من مخطط الحسابات
    FROM [Sales].[Partners] p
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON p.AccountID = c.AccountID
    WHERE p.IsActive = 1
      AND (
           @SearchText IS NULL
           OR @SearchText = ''
           OR p.PartnerName LIKE N'%' + @SearchText + N'%'
           OR c.AccountCode  LIKE N'%' + @SearchText + N'%'
      )
    ORDER BY p.PartnerType, p.PartnerName;
END
GO
