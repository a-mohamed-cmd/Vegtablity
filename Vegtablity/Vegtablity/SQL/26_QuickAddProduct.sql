-- =============================================
-- 26. Quick Add Product Support
-- New SP for adding products quickly during Excel import
-- =============================================
USE VegtablityDB;
GO

IF OBJECT_ID('[Inventory].[sp_Product_QuickAdd]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Product_QuickAdd];
GO

CREATE PROCEDURE [Inventory].[sp_Product_QuickAdd]
    @Barcode      NVARCHAR(50),
    @ProductName  NVARCHAR(200),
    @PurchasePrice DECIMAL(18,3) = 0,
    @SalePrice     DECIMAL(18,3) = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewID INT;

    INSERT INTO [Inventory].[Products] (
        ProductName,
        Barcode,
        CategoryID, -- default 1 (غير محدد)
        UnitID,     -- default 1 (حبة/قطعة)
        PurchasePrice,
        SalePrice,
        AlertQty,
        IsActive,
        CreatedAt,
        UpdatedAt
    )
    VALUES (
        @ProductName,
        @Barcode,
        1,
        1,
        @PurchasePrice,
        @SalePrice,
        0,
        1,
        GETDATE(),
        GETDATE()
    );

    SET @NewID = SCOPE_IDENTITY();
    SELECT @NewID;
END
GO
