USE VegtablityDB;
GO

-- Add ReferenceNo (Supplier Invoice Number) to InvoiceHeader
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('Sales.InvoiceHeader') AND name = 'ReferenceNo'
)
BEGIN
    ALTER TABLE Sales.InvoiceHeader ADD ReferenceNo NVARCHAR(50) NULL;
END
GO

-- Update sp_Invoice_Save to include ReferenceNo
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
    @ReferenceNo NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @InvID = 0
    BEGIN
        INSERT INTO [Sales].[InvoiceHeader] 
            (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, Discount, NetAmount, PaidAmount, Remainder, UserID, Notes, IsPosted, ReferenceNo)
        VALUES 
            (@InvType, @InvDate, @PartnerID, @WarehouseID, @TotalAmount, @Discount, @NetAmount, @PaidAmount, @Remainder, @UserID, @Notes, @IsPosted, @ReferenceNo);
        SELECT SCOPE_IDENTITY() AS InvID;
    END
    ELSE
    BEGIN
        UPDATE [Sales].[InvoiceHeader] 
        SET InvType = @InvType, InvDate = @InvDate, PartnerID = @PartnerID, WarehouseID = @WarehouseID, 
            TotalAmount = @TotalAmount, Discount = @Discount, NetAmount = @NetAmount, 
            PaidAmount = @PaidAmount, Remainder = @Remainder, UserID = @UserID, Notes = @Notes, IsPosted = @IsPosted,
            ReferenceNo = @ReferenceNo
        WHERE InvID = @InvID;
        SELECT @InvID AS InvID;
    END
END
GO
