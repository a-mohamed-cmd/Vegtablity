-- =============================================
-- Partners (الشركاء) - Stored Procedures
-- العملاء والموردين
-- Soft Delete (IsActive)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 1. جلب جميع الشركاء النشطين حسب النوع
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_GetAll];
GO
CREATE PROCEDURE [Sales].[sp_Partner_GetAll]
    @PartnerType NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PartnerID, p.PartnerName, p.PartnerType, p.Phone, p.Address, p.CurrentBalance, p.IsActive, p.AccountID, c.AccountCode
    FROM [Sales].[Partners] p
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON p.AccountID = c.AccountID
    WHERE p.IsActive = 1 AND p.PartnerType = @PartnerType
    ORDER BY p.PartnerID;
END
GO

-- =============================================
-- 2. جلب شريك بالـ ID
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_GetByID];
GO
CREATE PROCEDURE [Sales].[sp_Partner_GetByID]
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PartnerID, PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID
    FROM [Sales].[Partners]
    WHERE PartnerID = @PartnerID;
END
GO

-- =============================================
-- 3. حفظ شريك (إضافة أو تعديل)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_Save]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_Save];
GO
CREATE PROCEDURE [Sales].[sp_Partner_Save]
    @PartnerID INT = 0,
    @PartnerName NVARCHAR(150),
    @PartnerType NVARCHAR(20),
    @Phone NVARCHAR(20) = NULL,
    @Address NVARCHAR(255) = NULL,
    @AccountID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @PartnerID = 0
    BEGIN
        INSERT INTO [Sales].[Partners] (PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID)
        VALUES (@PartnerName, @PartnerType, @Phone, @Address, 0, 1, @AccountID);
        SELECT SCOPE_IDENTITY() AS PartnerID;
    END
    ELSE
    BEGIN
        UPDATE [Sales].[Partners] 
        SET PartnerName = @PartnerName, PartnerType = @PartnerType, Phone = @Phone, Address = @Address, AccountID = @AccountID
        WHERE PartnerID = @PartnerID;
        SELECT @PartnerID AS PartnerID;
    END
END
GO

-- =============================================
-- 4. تعطيل شريك (Soft Delete)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_Delete];
GO
CREATE PROCEDURE [Sales].[sp_Partner_Delete]
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Sales].[Partners] SET IsActive = 0 WHERE PartnerID = @PartnerID;
END
GO

-- =============================================
-- 5. بحث بالاسم أو الهاتف
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_Search]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_Search];
GO
CREATE PROCEDURE [Sales].[sp_Partner_Search]
    @PartnerType NVARCHAR(20),
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PartnerID, PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID
    FROM [Sales].[Partners]
    WHERE IsActive = 1 AND PartnerType = @PartnerType
      AND (PartnerName LIKE '%' + @SearchText + '%' OR Phone LIKE '%' + @SearchText + '%')
    ORDER BY PartnerID;
END
GO
