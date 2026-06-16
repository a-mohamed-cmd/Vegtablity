USE VegtablityDB;
GO

-- 1. Add CurrencySymbol column if it doesn't exist
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') 
    AND name = 'CurrencySymbol'
)
BEGIN
    ALTER TABLE [Settings].[CompanySettings]
    ADD CurrencySymbol NVARCHAR(10) NULL;
END
GO

-- 2. Set default value for existing records
UPDATE [Settings].[CompanySettings]
SET CurrencySymbol = N'د.ك'
WHERE CurrencySymbol IS NULL;
GO

-- 3. Update Stored Procedure to include CurrencySymbol
IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1,
    @CurrencySymbol NVARCHAR(10) = NULL
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
            CurrencySymbol = @CurrencySymbol
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch, CurrencySymbol)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch, @CurrencySymbol);
    END
END
GO
