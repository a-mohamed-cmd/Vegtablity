-- =============================================
-- Settings Schema - Stored Procedures
-- الوحدات، التصنيفات، المخازن
-- مع Soft Delete (IsActive) بدلاً من الحذف الفعلي
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 0. إضافة عمود IsActive للجداول (إذا لم يكن موجوداً)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[Units]') AND name = 'IsActive')
    ALTER TABLE [Settings].[Units] ADD IsActive BIT NOT NULL DEFAULT 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[Categories]') AND name = 'IsActive')
    ALTER TABLE [Settings].[Categories] ADD IsActive BIT NOT NULL DEFAULT 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[Warehouses]') AND name = 'IsActive')
    ALTER TABLE [Settings].[Warehouses] ADD IsActive BIT NOT NULL DEFAULT 1;
GO

-- =============================================
-- 1. الوحدات (Units)
-- =============================================

-- GetAll (النشطة فقط)
IF OBJECT_ID('[Settings].[sp_Unit_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Unit_GetAll];
GO
CREATE PROCEDURE [Settings].[sp_Unit_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UnitID, UnitName, IsActive FROM [Settings].[Units] WHERE IsActive = 1 ORDER BY UnitID;
END
GO

-- Save (Add or Update)
IF OBJECT_ID('[Settings].[sp_Unit_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Unit_Save];
GO
CREATE PROCEDURE [Settings].[sp_Unit_Save]
    @UnitID INT = 0,
    @UnitName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF @UnitID = 0
    BEGIN
        INSERT INTO [Settings].[Units] (UnitName, IsActive) VALUES (@UnitName, 1);
        SELECT SCOPE_IDENTITY() AS UnitID;
    END
    ELSE
    BEGIN
        UPDATE [Settings].[Units] SET UnitName = @UnitName WHERE UnitID = @UnitID;
        SELECT @UnitID AS UnitID;
    END
END
GO

-- Deactivate (Soft Delete)
IF OBJECT_ID('[Settings].[sp_Unit_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Unit_Delete];
GO
CREATE PROCEDURE [Settings].[sp_Unit_Delete]
    @UnitID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Settings].[Units] SET IsActive = 0 WHERE UnitID = @UnitID;
END
GO

-- =============================================
-- 2. التصنيفات (Categories)
-- =============================================

-- GetAll (النشطة فقط)
IF OBJECT_ID('[Settings].[sp_Category_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Category_GetAll];
GO
CREATE PROCEDURE [Settings].[sp_Category_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CatID, CatName, IsActive FROM [Settings].[Categories] WHERE IsActive = 1 ORDER BY CatID;
END
GO

-- Save (Add or Update)
IF OBJECT_ID('[Settings].[sp_Category_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Category_Save];
GO
CREATE PROCEDURE [Settings].[sp_Category_Save]
    @CatID INT = 0,
    @CatName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF @CatID = 0
    BEGIN
        INSERT INTO [Settings].[Categories] (CatName, IsActive) VALUES (@CatName, 1);
        SELECT SCOPE_IDENTITY() AS CatID;
    END
    ELSE
    BEGIN
        UPDATE [Settings].[Categories] SET CatName = @CatName WHERE CatID = @CatID;
        SELECT @CatID AS CatID;
    END
END
GO

-- Deactivate (Soft Delete)
IF OBJECT_ID('[Settings].[sp_Category_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Category_Delete];
GO
CREATE PROCEDURE [Settings].[sp_Category_Delete]
    @CatID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Settings].[Categories] SET IsActive = 0 WHERE CatID = @CatID;
END
GO

-- =============================================
-- 3. المخازن (Warehouses)
-- =============================================

-- GetAll (النشطة فقط)
IF OBJECT_ID('[Settings].[sp_Warehouse_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Warehouse_GetAll];
GO
CREATE PROCEDURE [Settings].[sp_Warehouse_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT WarehouseID, WarehouseName, Address, KeeperName, IsActive FROM [Settings].[Warehouses] WHERE IsActive = 1 ORDER BY WarehouseID;
END
GO

-- Save (Add or Update)
IF OBJECT_ID('[Settings].[sp_Warehouse_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Warehouse_Save];
GO
CREATE PROCEDURE [Settings].[sp_Warehouse_Save]
    @WarehouseID INT = 0,
    @WarehouseName NVARCHAR(100),
    @Address NVARCHAR(255) = NULL,
    @KeeperName NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @WarehouseID = 0
    BEGIN
        INSERT INTO [Settings].[Warehouses] (WarehouseName, Address, KeeperName, IsActive) 
        VALUES (@WarehouseName, @Address, @KeeperName, 1);
        SELECT SCOPE_IDENTITY() AS WarehouseID;
    END
    ELSE
    BEGIN
        UPDATE [Settings].[Warehouses] 
        SET WarehouseName = @WarehouseName, Address = @Address, KeeperName = @KeeperName 
        WHERE WarehouseID = @WarehouseID;
        SELECT @WarehouseID AS WarehouseID;
    END
END
GO

-- Deactivate (Soft Delete)
IF OBJECT_ID('[Settings].[sp_Warehouse_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Warehouse_Delete];
GO
CREATE PROCEDURE [Settings].[sp_Warehouse_Delete]
    @WarehouseID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Settings].[Warehouses] SET IsActive = 0 WHERE WarehouseID = @WarehouseID;
END
GO

-- =============================================
-- 4. حذف Triggers القديمة (لم نعد نحتاجها مع Soft Delete)
-- =============================================
IF OBJECT_ID('[Settings].[trg_PreventDeleteUsedUnit]', 'TR') IS NOT NULL DROP TRIGGER [Settings].[trg_PreventDeleteUsedUnit];
GO
IF OBJECT_ID('[Settings].[trg_PreventDeleteUsedCategory]', 'TR') IS NOT NULL DROP TRIGGER [Settings].[trg_PreventDeleteUsedCategory];
GO
IF OBJECT_ID('[Settings].[trg_PreventDeleteUsedWarehouse]', 'TR') IS NOT NULL DROP TRIGGER [Settings].[trg_PreventDeleteUsedWarehouse];
GO
