-- =============================================
-- عروض المشتريات (Purchase Quotations)
-- Tables and Stored Procedures
-- =============================================
USE [VegtablityDB]
GO

-- 1. إنشاء الـ Schema إذا لم تكن موجودة
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Purchases')
BEGIN
    EXEC('CREATE SCHEMA [Purchases]')
END
GO

-- 2. جدول رأس عرض المشتريات
IF OBJECT_ID('[Purchases].[PurchaseQuoteHeader]', 'U') IS NOT NULL DROP TABLE [Purchases].[PurchaseQuoteHeader];
GO
CREATE TABLE [Purchases].[PurchaseQuoteHeader](
    [PurchaseQuoteID] INT IDENTITY(1,1) PRIMARY KEY,
    [PartnerID] INT NOT NULL,
    [QuoteDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [ExpiryDate] DATETIME NULL,
    [Notes] NVARCHAR(500) NULL,
    [CreatedAt] DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_PurchaseQuote_Partner FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID)
);
GO

-- 3. جدول تفاصيل عرض المشتريات
IF OBJECT_ID('[Purchases].[PurchaseQuoteDetails]', 'U') IS NOT NULL DROP TABLE [Purchases].[PurchaseQuoteDetails];
GO
CREATE TABLE [Purchases].[PurchaseQuoteDetails](
    [DetailID] INT IDENTITY(1,1) PRIMARY KEY,
    [PurchaseQuoteID] INT NOT NULL,
    [ProductID] INT NOT NULL,
    [UnitPrice] DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_Details_Header FOREIGN KEY (PurchaseQuoteID) REFERENCES [Purchases].[PurchaseQuoteHeader](PurchaseQuoteID) ON DELETE CASCADE,
    CONSTRAINT FK_Details_Product FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID)
);
GO

-- 4. إجراء الحفظ (Header + Details)
IF OBJECT_ID('[Purchases].[sp_PurchaseQuote_Save]', 'P') IS NOT NULL DROP PROCEDURE [Purchases].[sp_PurchaseQuote_Save];
GO
CREATE PROCEDURE [Purchases].[sp_PurchaseQuote_Save]
    @PurchaseQuoteID INT = 0,
    @PartnerID INT,
    @QuoteDate DATETIME,
    @ExpiryDate DATETIME = NULL,
    @Notes NVARCHAR(500) = NULL,
    @DetailsXml XML -- استخدام XML بدلاً من JSON للتوافق مع جميع إصدارات SQL Server
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION
    BEGIN TRY
        IF @PurchaseQuoteID = 0
        BEGIN
            INSERT INTO [Purchases].[PurchaseQuoteHeader] (PartnerID, QuoteDate, ExpiryDate, Notes)
            VALUES (@PartnerID, @QuoteDate, @ExpiryDate, @Notes);
            SET @PurchaseQuoteID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [Purchases].[PurchaseQuoteHeader]
            SET PartnerID = @PartnerID, QuoteDate = @QuoteDate, ExpiryDate = @ExpiryDate, Notes = @Notes
            WHERE PurchaseQuoteID = @PurchaseQuoteID;
            
            -- مسح التفاصيل القديمة لإعادة كتابتها
            DELETE FROM [Purchases].[PurchaseQuoteDetails] WHERE PurchaseQuoteID = @PurchaseQuoteID;
        END

        -- إدراج التفاصيل من الـ XML (حذف Quantity بناءً على طلب المستخدم)
        INSERT INTO [Purchases].[PurchaseQuoteDetails] (PurchaseQuoteID, ProductID, UnitPrice)
        SELECT 
            @PurchaseQuoteID,
            T.Item.value('@ProductID', 'INT'),
            T.Item.value('@UnitPrice', 'DECIMAL(18,2)')
        FROM @DetailsXml.nodes('/Details/Item') AS T(Item);

        COMMIT TRANSACTION
        SELECT @PurchaseQuoteID AS PurchaseQuoteID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 5. جلب جميع العروض مع البحث
IF OBJECT_ID('[Purchases].[sp_PurchaseQuote_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Purchases].[sp_PurchaseQuote_GetAll];
GO
CREATE PROCEDURE [Purchases].[sp_PurchaseQuote_GetAll]
    @SearchText NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT q.*, p.PartnerName
    FROM [Purchases].[PurchaseQuoteHeader] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@SearchText IS NULL OR p.PartnerName LIKE '%' + @SearchText + '%' OR q.Notes LIKE '%' + @SearchText + '%')
    ORDER BY q.QuoteDate DESC;
END
GO

-- 6. جلب تفاصيل عرض معين
IF OBJECT_ID('[Purchases].[sp_PurchaseQuote_GetDetails]', 'P') IS NOT NULL DROP PROCEDURE [Purchases].[sp_PurchaseQuote_GetDetails];
GO
CREATE PROCEDURE [Purchases].[sp_PurchaseQuote_GetDetails]
    @PurchaseQuoteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.*, p.ProductName, p.Barcode, u.UnitName
    FROM [Purchases].[PurchaseQuoteDetails] d
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE d.PurchaseQuoteID = @PurchaseQuoteID;
END
GO
