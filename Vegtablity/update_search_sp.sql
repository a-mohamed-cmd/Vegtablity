
USE VegtablityDB;
GO
ALTER PROCEDURE [Sales].[sp_Partner_Search]
    @PartnerType NVARCHAR(20),
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PartnerID, 
        p.PartnerName, 
        p.PartnerType, 
        p.Phone, 
        p.Address, 
        p.CurrentBalance, 
        p.IsActive, 
        p.AccountID,
        c.AccountCode
    FROM [Sales].[Partners] p
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON p.AccountID = c.AccountID
    WHERE p.IsActive = 1 AND p.PartnerType = @PartnerType
      AND (
           @SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%' 
           OR p.Phone LIKE '%' + @SearchText + '%'
           OR c.AccountCode LIKE '%' + @SearchText + '%'
      )
    ORDER BY p.PartnerID;
END
GO

