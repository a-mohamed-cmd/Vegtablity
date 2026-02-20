-- =============================================
-- Inventory Schema - Stored Procedures
-- الأصناف (Products)
-- مع Soft Delete (IsActive)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 0. إضافة أعمدة جديدة (إذا لم تكن موجودة)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Inventory].[Products]') AND name = 'IsActive')
    ALTER TABLE [Inventory].[Products] ADD IsActive BIT NOT NULL DEFAULT 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Inventory].[Products]') AND name = 'ProductNameEn')
    ALTER TABLE [Inventory].[Products] ADD ProductNameEn NVARCHAR(150) NULL;
GO

-- =============================================
-- 1. جلب جميع الأصناف النشطة مع اسم الوحدة والتصنيف
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Product_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetAll];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1
    ORDER BY p.ProductID;
END
GO

-- =============================================
-- 2. جلب صنف بالـ ID
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Product_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetByID];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetByID]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.ProductID = @ProductID;
END
GO

-- =============================================
-- 3. حفظ صنف (إضافة أو تعديل - Save = Add/Update)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Product_Save]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_Save];
GO
CREATE PROCEDURE [Inventory].[sp_Product_Save]
    @ProductID INT = 0,
    @ProductName NVARCHAR(150),
    @ProductNameEn NVARCHAR(150) = NULL,
    @Barcode NVARCHAR(50) = NULL,
    @CategoryID INT = NULL,
    @UnitID INT = NULL,
    @PurchasePrice DECIMAL(18,2) = 0,
    @SalePrice DECIMAL(18,2) = 0,
    @AlertQty DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @ProductID = 0
    BEGIN
        INSERT INTO [Inventory].[Products] 
            (ProductName, ProductNameEn, Barcode, CategoryID, UnitID, PurchasePrice, SalePrice, AlertQty, IsActive)
        VALUES 
            (@ProductName, @ProductNameEn, @Barcode, @CategoryID, @UnitID, @PurchasePrice, @SalePrice, @AlertQty, 1);
        SELECT SCOPE_IDENTITY() AS ProductID;
    END
    ELSE
    BEGIN
        UPDATE [Inventory].[Products] 
        SET ProductName = @ProductName, ProductNameEn = @ProductNameEn, Barcode = @Barcode, CategoryID = @CategoryID,
            UnitID = @UnitID, PurchasePrice = @PurchasePrice, SalePrice = @SalePrice, AlertQty = @AlertQty
        WHERE ProductID = @ProductID;
        SELECT @ProductID AS ProductID;
    END
END
GO

-- =============================================
-- 4. تعطيل صنف (Soft Delete)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Product_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_Delete];
GO
CREATE PROCEDURE [Inventory].[sp_Product_Delete]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Inventory].[Products] SET IsActive = 0 WHERE ProductID = @ProductID;
END
GO

-- =============================================
-- 5. بحث بالباركود
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Product_GetByBarcode]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetByBarcode];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetByBarcode]
    @Barcode NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.Barcode = @Barcode AND p.IsActive = 1;
END
GO

-- =============================================
-- 6. بحث بالاسم (LIKE) - عربي + انجليزي + باركود
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Product_Search]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_Search];
GO
CREATE PROCEDURE [Inventory].[sp_Product_Search]
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1 AND (
        p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
    )
    ORDER BY p.ProductID;
END
GO
