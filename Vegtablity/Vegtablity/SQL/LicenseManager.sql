-- =========================================================================
-- 1. تهيئة وجلب قواعد البيانات (تُنفذ في قاعدة master)
-- =========================================================================
USE [master];
GO

IF OBJECT_ID('dbo.sp_GetDatabases_Ctrl', 'P') IS NOT NULL 
    DROP PROCEDURE dbo.sp_GetDatabases_Ctrl;
GO

CREATE PROCEDURE dbo.sp_GetDatabases_Ctrl 
AS
BEGIN
    SET NOCOUNT ON;
    SELECT name AS DatabaseName FROM sys.databases
    WHERE name NOT IN ('master','tempdb','model','msdb') 
      AND state_desc='ONLINE'
    ORDER BY name;
END;
GO

-- =========================================================================
-- 2. تهيئة دوال التراخيص (تُنفذ في قاعدة البيانات المستهدفة WashaDB)
-- =========================================================================
USE [WashaDB];
GO

-- التأكد من وجود سكيما Security في قاعدة البيانات قبل إنشاء الدوال
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Security')
BEGIN
    EXEC('CREATE SCHEMA [Security]');
END
GO

-- 2أ. جلب التراخيص
IF OBJECT_ID('[Security].[sp_License_GetAll_Ctrl]', 'P') IS NOT NULL 
    DROP PROCEDURE [Security].[sp_License_GetAll_Ctrl];
GO

CREATE PROCEDURE [Security].[sp_License_GetAll_Ctrl] 
AS
BEGIN
    SET NOCOUNT ON;
    SELECT LicenseID, MachineName, MachineHWID, LicenseKey,
           IsActive, ExpiryDate, CreatedDate
    FROM [Security].[DeviceLicenses] 
    ORDER BY CreatedDate DESC;
END;
GO

-- 2ب. إضافة/تعديل ترخيص جهاز
IF OBJECT_ID('[Security].[sp_License_Save_Ctrl]', 'P') IS NOT NULL 
    DROP PROCEDURE [Security].[sp_License_Save_Ctrl];
GO

CREATE PROCEDURE [Security].[sp_License_Save_Ctrl]
    @LicenseID INT, 
    @MachineName NVARCHAR(200),
    @MachineHWID NVARCHAR(200), 
    @LicenseKey NVARCHAR(500),
    @IsActive BIT, 
    @ExpiryDate DATE
AS 
BEGIN
    SET NOCOUNT ON;
    IF @LicenseID = 0
    BEGIN
        INSERT INTO [Security].[DeviceLicenses]
            (MachineName, MachineHWID, LicenseKey, IsActive, ExpiryDate, CreatedDate)
        VALUES 
            (@MachineName, @MachineHWID, @LicenseKey, @IsActive, @ExpiryDate, GETDATE());
        SELECT SCOPE_IDENTITY() AS LicenseID;
    END
    ELSE
    BEGIN
        UPDATE [Security].[DeviceLicenses] 
        SET MachineName = @MachineName,
            MachineHWID = @MachineHWID, 
            LicenseKey = @LicenseKey,
            IsActive = @IsActive, 
            ExpiryDate = @ExpiryDate
        WHERE LicenseID = @LicenseID;
        SELECT @LicenseID AS LicenseID;
    END
END;
GO

-- 2ج. حذف ترخيص جهاز
IF OBJECT_ID('[Security].[sp_License_Delete_Ctrl]', 'P') IS NOT NULL 
    DROP PROCEDURE [Security].[sp_License_Delete_Ctrl];
GO

CREATE PROCEDURE [Security].[sp_License_Delete_Ctrl]
    @LicenseID INT
AS  
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Security].[DeviceLicenses] 
    WHERE LicenseID = @LicenseID;
END;
GO
