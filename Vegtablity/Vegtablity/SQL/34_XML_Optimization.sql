-- =============================================
-- XML Optimization for Invoices and Quotations (Mobile/POS Sync)
-- =============================================
USE [VegtablityDB];
GO

-- 1. [Sales].[sp_Invoice_Save_XML]
-- نسخة مطورة تدعم حفظ التفاصيل عبر XML لتجنب التعارض مع الإجراء القديم
IF OBJECT_ID('[Sales].[sp_Invoice_Save_XML]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_Save_XML];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Save_XML]
    @InvID INT OUTPUT = 0,
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
    @PaymentAccountID INT = NULL,
    @DetailsXml XML 
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- حفظ الرأس
        IF @InvID = 0
        BEGIN
            INSERT INTO [Sales].[InvoiceHeader] 
                (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, Discount, NetAmount, PaidAmount, Remainder, UserID, Notes, IsPosted, ReferenceNo, PaymentAccountID)
            VALUES 
                (@InvType, @InvDate, @PartnerID, @WarehouseID, @TotalAmount, @Discount, @NetAmount, @PaidAmount, @Remainder, @UserID, @Notes, @IsPosted, @ReferenceNo, @PaymentAccountID);
            SET @InvID = CAST(SCOPE_IDENTITY() AS INT);
        END
        ELSE
        BEGIN
            UPDATE [Sales].[InvoiceHeader] 
            SET InvType = @InvType, InvDate = @InvDate, PartnerID = @PartnerID, WarehouseID = @WarehouseID, 
                TotalAmount = @TotalAmount, Discount = @Discount, NetAmount = @NetAmount, 
                PaidAmount = @PaidAmount, Remainder = @Remainder, UserID = @UserID, Notes = @Notes,
                IsPosted = @IsPosted, ReferenceNo = @ReferenceNo, PaymentAccountID = @PaymentAccountID
            WHERE InvID = @InvID;
            
            DELETE FROM [Sales].[InvoiceDetails] WHERE InvID = @InvID;
        END

        -- إدراج التفاصيل من الـ XML
        INSERT INTO [Sales].[InvoiceDetails] (InvID, ProductID, UnitPrice, Quantity, TotalPrice, CostPrice)
        SELECT 
            @InvID,
            T.Item.value('@ProductID', 'INT'),
            T.Item.value('@UnitPrice', 'DECIMAL(18,2)'),
            T.Item.value('@Quantity', 'DECIMAL(18,2)'),
            T.Item.value('@TotalPrice', 'DECIMAL(18,2)'),
            T.Item.value('@CostPrice', 'DECIMAL(18,2)')
        FROM @DetailsXml.nodes('//Item') AS T(Item);

        COMMIT TRANSACTION;
        SELECT @InvID AS InvID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 2. [Sales].[sp_Quotations_Upsert_XML]
-- نسخة مطورة لعروض الأسعار تدعم XML لتجنب التعارض مع الإجراء القديم
IF OBJECT_ID('[Sales].[sp_Quotations_Upsert_XML]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_Upsert_XML];
GO

CREATE PROCEDURE [Sales].[sp_Quotations_Upsert_XML]
    @QuoteID INT OUTPUT = 0,
    @PartnerID INT,
    @QuoteDate DATETIME,
    @ExpiryDate DATETIME = NULL,
    @IsActive BIT,
    @Notes NVARCHAR(MAX) = NULL,
    @DetailsXml XML 
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
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
            
            DELETE FROM [Sales].[QuotationDetails] WHERE QuoteID = @QuoteID;
        END

        -- إدراج التفاصيل الجديدة (بدون كمية بناءً على طلب المستخدم)
        INSERT INTO [Sales].[QuotationDetails] (QuoteID, ProductID, QuotedPrice)
        SELECT 
            @QuoteID,
            T.Item.value('@ProductID', 'INT'),
            T.Item.value('@QuotedPrice', 'DECIMAL(18,3)')
        FROM @DetailsXml.nodes('//Item') AS T(Item);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

-- 3. [Sales].[sp_Invoice_GetByID]
-- نسخة مطورة تجلب بيانات الرأس مع اسم الشريك لضمان الظهور الصحيح في الواجهة
IF OBJECT_ID('[Sales].[sp_Invoice_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetByID];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_GetByID]  
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        inv.*, 
        par.PartnerName,
        chart.AccountCode
    FROM [Sales].[InvoiceHeader] inv
    LEFT JOIN [Sales].[Partners] par ON inv.[PartnerID] = par.[PartnerID]
    LEFT JOIN [Accounting].[ChartOfAccounts] chart ON par.[AccountID] = chart.[AccountID]
    WHERE inv.InvID = @InvID;
END
GO

-- 4. [Sales].[sp_InvoiceDetails_GetByInvID]
-- نسخة مطورة تستخدم LEFT JOIN لضمان تحميل التفاصيل حتى لو حذف الصنف
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
        p.Barcode
    FROM [Sales].[InvoiceDetails] d
    LEFT JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    WHERE d.InvID = @InvID;
END
GO
