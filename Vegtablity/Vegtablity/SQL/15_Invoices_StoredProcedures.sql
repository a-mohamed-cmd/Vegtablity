-- =============================================
-- Invoices Stored Procedures (Sales & Purchases)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 1. sp_Invoice_Save (Header)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Save]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_Save];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_Save]
    @InvID INT = 0,
    @InvType NVARCHAR(20),
    @InvDate DATETIME,
    @PartnerID INT,
    @WarehouseID INT,
    @TotalAmount DECIMAL(18, 2),
    @Discount DECIMAL(18, 2),
    @NetAmount DECIMAL(18, 2),
    @PaidAmount DECIMAL(18, 2),
    @Remainder DECIMAL(18, 2),
    @UserID INT,
    @Notes NVARCHAR(255),
    @IsPosted BIT = 0,
    @ReferenceNo NVARCHAR(50) = NULL,
    @PaymentAccountID INT = NULL    -- حساب طريقة الدفع (11xx)
AS
BEGIN
    SET NOCOUNT ON;
    IF @InvID = 0
    BEGIN
        INSERT INTO [Sales].[InvoiceHeader] 
            (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, Discount, NetAmount, PaidAmount, Remainder, UserID, Notes, IsPosted, ReferenceNo, PaymentAccountID)
        VALUES 
            (@InvType, @InvDate, @PartnerID, @WarehouseID, @TotalAmount, @Discount, @NetAmount, @PaidAmount, @Remainder, @UserID, @Notes, @IsPosted, @ReferenceNo, @PaymentAccountID);
        SELECT CAST(SCOPE_IDENTITY() AS INT) AS InvID;
    END
    ELSE
    BEGIN
        UPDATE [Sales].[InvoiceHeader] 
        SET InvType = @InvType, InvDate = @InvDate, PartnerID = @PartnerID, WarehouseID = @WarehouseID, 
            TotalAmount = @TotalAmount, Discount = @Discount, NetAmount = @NetAmount, 
            PaidAmount = @PaidAmount, Remainder = @Remainder, UserID = @UserID, Notes = @Notes,
            IsPosted = @IsPosted, ReferenceNo = @ReferenceNo, PaymentAccountID = @PaymentAccountID
        WHERE InvID = @InvID;
        SELECT @InvID AS InvID;
    END
END
GO

-- =============================================
-- 2. sp_InvoiceDetail_Save
-- =============================================
IF OBJECT_ID('[Sales].[sp_InvoiceDetail_Save]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_InvoiceDetail_Save];
GO
CREATE PROCEDURE [Sales].[sp_InvoiceDetail_Save]
    @InvID INT,
    @ProductID INT,
    @UnitPrice DECIMAL(18, 2),
    @Quantity DECIMAL(18, 2),
    @TotalPrice DECIMAL(18, 2),
    @CostPrice DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Sales].[InvoiceDetails] (InvID, ProductID, UnitPrice, Quantity, TotalPrice, CostPrice)
    VALUES (@InvID, @ProductID, @UnitPrice, @Quantity, @TotalPrice, @CostPrice);
END
GO

-- =============================================
-- 3. sp_InvoiceDetails_DeleteByInvID
-- =============================================
IF OBJECT_ID('[Sales].[sp_InvoiceDetails_DeleteByInvID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_InvoiceDetails_DeleteByInvID];
GO
CREATE PROCEDURE [Sales].[sp_InvoiceDetails_DeleteByInvID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Sales].[InvoiceDetails] WHERE InvID = @InvID;
END
GO

-- =============================================
-- 4. sp_Invoice_Delete
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_Delete];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_Delete]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    -- Due to ON DELETE CASCADE on InvoiceDetails, this will delete details too
    -- But if IsPosted = 1, maybe we should prevent deletion or let trg handle reverse
    -- The trg_Invoice_Post handles it on UPDATE. On DELETE we should reverse or prevent.
    -- For now, simple delete.
    DELETE FROM [Sales].[InvoiceHeader] WHERE InvID = @InvID;
END
GO

-- =============================================
-- 5. sp_Invoice_GetAll
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetAll];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetAll]
    @InvType NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    WHERE h.InvType = @InvType
    ORDER BY h.InvID DESC;
END
GO

-- =============================================
-- 6. sp_Invoice_GetByID 
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetByID];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetByID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT inv.*, chart.AccountCode, par.PartnerName
    FROM [Sales].[InvoiceHeader] inv
    LEFT JOIN [Sales].[Partners] par ON inv.[PartnerID] = par.[PartnerID]
    LEFT JOIN [Accounting].[ChartOfAccounts] chart ON par.[AccountID] = chart.[AccountID]
    WHERE inv.InvID = @InvID;
END
GO

-- =============================================
-- 7. sp_InvoiceDetails_GetByInvID
-- =============================================
IF OBJECT_ID('[Sales].[sp_InvoiceDetails_GetByInvID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID];
GO
CREATE PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.*,
        p.ProductName,
        p.ProductNameEn,
        u.UnitName,
        p.Barcode
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE d.InvID = @InvID;
END
GO

-- =============================================
-- 8. sp_Stock_GetByProduct
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Stock_GetByProduct]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Stock_GetByProduct];
GO
CREATE PROCEDURE [Inventory].[sp_Stock_GetByProduct]
    @ProductID INT,
    @WarehouseID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CurrentQty 
    FROM [Inventory].[ProductStock] 
    WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;
END
GO
