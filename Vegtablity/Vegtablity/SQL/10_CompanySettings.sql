USE VegtablityDB;
GO

-- =============================================
-- 1. Create CompanySettings Table & Alter Missing Columns
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
        UnifiedPartnerSearch BIT NOT NULL DEFAULT 1,
        CurrencySymbol NVARCHAR(100) DEFAULT N'د.ك',
        UseDetailedInvoiceDesign BIT NOT NULL DEFAULT 0,
        UseCustomInvoiceDesign BIT NOT NULL DEFAULT 0,
        ProductionMode BIT NOT NULL DEFAULT 0,
        EnableDailyOrders BIT NOT NULL DEFAULT 0,
        DeliverySystemMode NVARCHAR(50) NULL DEFAULT NULL,
        CONSTRAINT CK_OnlyOneRow CHECK (SettingID = 1)
    );

    -- Insert default record
    INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName)
    VALUES (1, N'شركة الخضروات');
END
GO

-- Ensure new columns exist on existing databases
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'EnableDailyOrders')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD EnableDailyOrders BIT NOT NULL DEFAULT 0;
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'DeliverySystemMode')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD DeliverySystemMode NVARCHAR(50) NULL DEFAULT NULL;
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
    SELECT TOP 1 
        SettingID,
        CompanyName,
        Address,
        Phone,
        Email,
        Logo,
        ISNULL(UnifiedPartnerSearch, 1) AS UnifiedPartnerSearch,
        ISNULL(CurrencySymbol, N'د.ك') AS CurrencySymbol,
        ISNULL(UseDetailedInvoiceDesign, 0) AS UseDetailedInvoiceDesign,
        ISNULL(UseCustomInvoiceDesign, 0) AS UseCustomInvoiceDesign,
        ISNULL(ProductionMode, 0) AS ProductionMode,
        ISNULL(EnableDailyOrders, 0) AS EnableDailyOrders,
        DeliverySystemMode
    FROM [Settings].[CompanySettings];
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
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1,
    @CurrencySymbol NVARCHAR(100) = NULL,
    @UseDetailedInvoiceDesign BIT = 0,
    @UseCustomInvoiceDesign BIT = 0,
    @ProductionMode BIT = 0,
    @EnableDailyOrders BIT = 0,
    @DeliverySystemMode NVARCHAR(50) = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo,
            UnifiedPartnerSearch = @UnifiedPartnerSearch,
            CurrencySymbol = @CurrencySymbol,
            UseDetailedInvoiceDesign = @UseDetailedInvoiceDesign,
            UseCustomInvoiceDesign = @UseCustomInvoiceDesign,
            ProductionMode = @ProductionMode,
            EnableDailyOrders = @EnableDailyOrders,
            DeliverySystemMode = @DeliverySystemMode
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch, CurrencySymbol, UseDetailedInvoiceDesign, UseCustomInvoiceDesign, ProductionMode, EnableDailyOrders, DeliverySystemMode)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch, @CurrencySymbol, @UseDetailedInvoiceDesign, @UseCustomInvoiceDesign, @ProductionMode, @EnableDailyOrders, @DeliverySystemMode);
    END
END
GO
