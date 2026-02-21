USE VegtablityDB;
GO

-- =============================================
-- 1. Create CompanySettings Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CompanySettings' AND schema_id = SCHEMA_ID('Settings'))
BEGIN
    CREATE TABLE [Settings].[CompanySettings] (
        SettingID INT PRIMARY KEY DEFAULT 1, -- Only one row allowed
        CompanyName NVARCHAR(200) NOT NULL,
        Address NVARCHAR(255),
        Phone NVARCHAR(50),
        Email NVARCHAR(100),
        Logo VARBINARY(MAX),
        CONSTRAINT CK_OnlyOneRow CHECK (SettingID = 1)
    );

    -- Insert default record
    INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName)
    VALUES (1, N'شركة الخضروات');
END
GO

-- =============================================
-- 2. Stored Procedures
-- =============================================

-- Get Company Settings
IF OBJECT_ID('[Settings].[sp_CompanySettings_Get]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Get];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Get]
AS
BEGIN
    SELECT TOP 1 * FROM [Settings].[CompanySettings];
END
GO

-- Save Company Settings
IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo);
    END
END
GO
