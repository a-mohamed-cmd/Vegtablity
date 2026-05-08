
USE VegtablityDB;
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'UnifiedPartnerSearch')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD UnifiedPartnerSearch BIT NOT NULL DEFAULT 1;
END
GO

