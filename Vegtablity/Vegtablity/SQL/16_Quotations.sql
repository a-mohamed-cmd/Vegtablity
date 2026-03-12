-- =============================================
-- Quotations Tables and Stored Procedures
-- =============================================

IF OBJECT_ID('Sales.Quotations', 'U') IS NULL
BEGIN
    CREATE TABLE [Sales].[Quotations] (
        [QuoteID] INT IDENTITY(1,1) PRIMARY KEY,
        [PartnerID] INT NOT NULL,
        [QuoteDate] DATETIME NOT NULL DEFAULT GETDATE(),
        [ExpiryDate] DATETIME NULL,
        [IsActive] BIT NOT NULL DEFAULT 1,
        [Notes] NVARCHAR(MAX) NULL,
        FOREIGN KEY ([PartnerID]) REFERENCES [Sales].[Partners]([PartnerID])
    );
END
GO

IF OBJECT_ID('Sales.QuotationDetails', 'U') IS NULL
BEGIN
    CREATE TABLE [Sales].[QuotationDetails] (
        [QuoteDetailID] INT IDENTITY(1,1) PRIMARY KEY,
        [QuoteID] INT NOT NULL,
        [ProductID] INT NOT NULL,
        [QuotedPrice] DECIMAL(18, 3) NOT NULL,
        FOREIGN KEY ([QuoteID]) REFERENCES [Sales].[Quotations]([QuoteID]) ON DELETE CASCADE,
        FOREIGN KEY ([ProductID]) REFERENCES [Inventory].[Products]([ProductID])
    );
END
GO

-- =============================================
-- Stored Procedures for Quotations
-- =============================================

-- 1. Insert/Update Quotation Header
IF OBJECT_ID('[Sales].[sp_Quotations_Upsert]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_Upsert];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_Upsert]
    @QuoteID INT OUTPUT,
    @PartnerID INT,
    @QuoteDate DATETIME,
    @ExpiryDate DATETIME = NULL,
    @IsActive BIT,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @QuoteID = 0
    BEGIN
        INSERT INTO [Sales].[Quotations] (PartnerID, QuoteDate, ExpiryDate, IsActive, Notes)
        VALUES (@PartnerID, @QuoteDate, @ExpiryDate, @IsActive, @Notes);
        SET @QuoteID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE [Sales].[Quotations]
        SET PartnerID = @PartnerID,
            QuoteDate = @QuoteDate,
            ExpiryDate = @ExpiryDate,
            IsActive = @IsActive,
            Notes = @Notes
        WHERE QuoteID = @QuoteID;
    END
END
GO

-- 2. Delete Quotation (Cascades to Details)
IF OBJECT_ID('[Sales].[sp_Quotations_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_Delete];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_Delete]
    @QuoteID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Sales].[Quotations] WHERE QuoteID = @QuoteID;
END
GO

-- 3. Get All Quotations
IF OBJECT_ID('[Sales].[sp_Quotations_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetAll];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT q.*, p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    ORDER BY q.QuoteDate DESC;
END
GO

-- 4. Get Quotation Details
IF OBJECT_ID('[Sales].[sp_QuotationDetails_GetByQuoteID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_QuotationDetails_GetByQuoteID];
GO
CREATE PROCEDURE [Sales].[sp_QuotationDetails_GetByQuoteID]
    @QuoteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        qd.QuoteDetailID,
        qd.QuoteID,
        qd.ProductID,
        qd.QuotedPrice,
        p.ProductName,
        p.Barcode,
        u.UnitName
    FROM [Sales].[QuotationDetails] qd
    INNER JOIN [Inventory].[Products] p ON qd.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE qd.QuoteID = @QuoteID;
END
GO

-- 5. Insert Quotation Detail
IF OBJECT_ID('[Sales].[sp_QuotationDetails_Insert]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_QuotationDetails_Insert];
GO
CREATE PROCEDURE [Sales].[sp_QuotationDetails_Insert]
    @QuoteID INT,
    @ProductID INT,
    @QuotedPrice DECIMAL(18, 3)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Sales].[QuotationDetails] (QuoteID, ProductID, QuotedPrice)
    VALUES (@QuoteID, @ProductID, @QuotedPrice);
END
GO

-- 6. Delete Details By QuoteID (for full replacement during editing)
IF OBJECT_ID('[Sales].[sp_QuotationDetails_DeleteByQuoteID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_QuotationDetails_DeleteByQuoteID];
GO
CREATE PROCEDURE [Sales].[sp_QuotationDetails_DeleteByQuoteID]
    @QuoteID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Sales].[QuotationDetails] WHERE QuoteID = @QuoteID;
END
GO

-- 7. Get Active Quote Price directly for SalesInvoice auto-fetch
IF OBJECT_ID('[Sales].[sp_Quotations_GetActivePrice]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetActivePrice];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetActivePrice]
    @PartnerID INT,
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Select the lowest/latest active quoted price if multiple exist
    SELECT TOP 1 qd.QuotedPrice
    FROM [Sales].[QuotationDetails] qd
    INNER JOIN [Sales].[Quotations] q ON qd.QuoteID = q.QuoteID
    WHERE q.PartnerID = @PartnerID
      AND qd.ProductID = @ProductID
      AND q.IsActive = 1
      AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= GETDATE())
    ORDER BY q.QuoteDate DESC;
END

-- 8. Get Quotations By Partner (for customer side panel)
IF OBJECT_ID('[Sales].[sp_Quotations_GetByPartner]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetByPartner];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetByPartner]
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT q.QuoteID, q.PartnerID, q.QuoteDate, q.ExpiryDate, q.IsActive, q.Notes,
           p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.PartnerID = @PartnerID
    ORDER BY q.QuoteDate DESC;
END
GO
