-- إنشاء قاعدة البيانات
-- إنشاء قاعدة البيانات
-- يمكنك تحديد مسار الملفات (MDF, LDF) بدقة كالتالي:
--IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'VegtablityDB')
--BEGIN
--    CREATE DATABASE VegtablityDB
--    ON PRIMARY 
--    ( NAME = N'VegtablityDB', FILENAME = N'C:\SQL_Data\VegtablityDB.mdf' )
--    LOG ON 
--    ( NAME = N'VegtablityDB_log', FILENAME = N'C:\SQL_Data\VegtablityDB_log.ldf' );
    
--    -- أو بدون تحديد مسار (يتم الحفظ في المسار الافتراضي للسيرفر):
--    -- CREATE DATABASE VegtablityDB;
--END
--GO

-- =============================================
-- 00. كود تنظيف (حذف) القديم - Cleanup Script
-- (استخدم هذا الكود لحذف الجداول القديمة التي بدون Schema لإعادة إنشائها بالشكل الجديد)
-- =============================================
USE VegtablityDB;
GO



-- =============================================
-- 0. إنشاء المخططات (Schemas)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Security') EXEC('CREATE SCHEMA [Security]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Settings') EXEC('CREATE SCHEMA [Settings]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Inventory') EXEC('CREATE SCHEMA [Inventory]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Sales') EXEC('CREATE SCHEMA [Sales]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Accounting') EXEC('CREATE SCHEMA [Accounting]');
GO

-- =============================================
-- 1. جداول النظام والمستخدمين (Schema: Security)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Roles' AND schema_id = SCHEMA_ID('Security'))
BEGIN
    CREATE TABLE [Security].[Roles] (
        RoleID INT PRIMARY KEY IDENTITY(1,1),
        RoleName NVARCHAR(50) NOT NULL UNIQUE,
        Description NVARCHAR(200)
    );

	
	insert into Security.Roles( RoleName ) values ('Admin');
END
go
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users' AND schema_id = SCHEMA_ID('Security'))
BEGIN
    CREATE TABLE [Security].[Users] (
        UserID INT PRIMARY KEY IDENTITY(1,1),
        RoleID INT NOT NULL,
        Username NVARCHAR(50) NOT NULL UNIQUE,
        PasswordHash NVARCHAR(255) NOT NULL,
        FullName NVARCHAR(100),
        IsActive BIT DEFAULT 1,
        CreatedAt DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (RoleID) REFERENCES [Security].[Roles](RoleID)
    );

-- إضافة مستخدم افتراضي 
INSERT INTO [Security].Users (RoleID, Username, PasswordHash, FullName) VALUES (1, N'admin', N'123', N'Administrator');
end
go

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RolePermissions' AND schema_id = SCHEMA_ID('Security'))
BEGIN
    CREATE TABLE [Security].[RolePermissions] (
        PermID INT PRIMARY KEY IDENTITY(1,1),
        RoleID INT NOT NULL,
        FormName NVARCHAR(100) NOT NULL,
        CanAdd BIT DEFAULT 0,
        CanEdit BIT DEFAULT 0,
        CanDelete BIT DEFAULT 0,
        CanView BIT DEFAULT 0,
        CanPrint BIT DEFAULT 0,
        FOREIGN KEY (RoleID) REFERENCES [Security].[Roles](RoleID) ON DELETE CASCADE
    );
END

-- =============================================
-- 2. الإعدادات العامة (Schema: Settings)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Units' AND schema_id = SCHEMA_ID('Settings'))
BEGIN
    CREATE TABLE [Settings].[Units] (
        UnitID INT PRIMARY KEY IDENTITY(1,1),
        UnitName NVARCHAR(50) NOT NULL UNIQUE
    );

-- إضافة الوحدات الأساسية 
INSERT INTO [Settings].Units (UnitName) VALUES (N'كيلو'), (N'صندوق'), (N'حبة');
end
go

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Categories' AND schema_id = SCHEMA_ID('Settings'))
BEGIN
    CREATE TABLE [Settings].[Categories] (
        CatID INT PRIMARY KEY IDENTITY(1,1),
        CatName NVARCHAR(100) NOT NULL UNIQUE
    );
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Warehouses' AND schema_id = SCHEMA_ID('Settings'))
BEGIN
    CREATE TABLE [Settings].[Warehouses] (
        WarehouseID INT PRIMARY KEY IDENTITY(1,1),
        WarehouseName NVARCHAR(100) NOT NULL UNIQUE,
        Address NVARCHAR(255),
        KeeperName NVARCHAR(100),
        AccountID INT NULL
    );
END
GO

 


IF OBJECT_ID('[Settings].[trg_Warehouse_AfterInsert]', 'TR') IS NOT NULL DROP TRIGGER [Settings].[trg_Warehouse_AfterInsert];
GO

CREATE TRIGGER [Settings].[trg_Warehouse_AfterInsert]
ON [Settings].[Warehouses]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InventoryParentID INT;
    SELECT @InventoryParentID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13';

    IF @InventoryParentID IS NULL RETURN;

    DECLARE @WarehouseID INT, @WarehouseName NVARCHAR(100);
    
    DECLARE cur CURSOR FOR SELECT WarehouseID, WarehouseName FROM inserted;
    OPEN cur;
    FETCH NEXT FROM cur INTO @WarehouseID, @WarehouseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Find the next available AccountCode under 13 (e.g., 1301, 1302)
        DECLARE @MaxCode NVARCHAR(20);
        SELECT @MaxCode = MAX(AccountCode) FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @InventoryParentID;
        
        DECLARE @NextCode NVARCHAR(20);
        IF @MaxCode IS NULL
            SET @NextCode = '1301';
        ELSE
            SET @NextCode = CAST((CAST(@MaxCode AS BIGINT) + 1) AS NVARCHAR(20));

        DECLARE @NewAccountID INT;
        
        -- Insert into ChartOfAccounts
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES (@NextCode, N'مخزون - ' + @WarehouseName, @InventoryParentID, 'Assets', 2, 1);
        
        SET @NewAccountID = SCOPE_IDENTITY();

        -- Link the newly created AccountID back to the Warehouse
        UPDATE [Settings].[Warehouses] 
        SET AccountID = @NewAccountID 
        WHERE WarehouseID = @WarehouseID;

        FETCH NEXT FROM cur INTO @WarehouseID, @WarehouseName;
    END

    CLOSE cur;
    DEALLOCATE cur;
END

-- =============================================
-- 3. الشركاء (Schema: Sales)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Partners' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE [Sales].[Partners] (
        PartnerID INT PRIMARY KEY IDENTITY(1,1),
        PartnerName NVARCHAR(150) NOT NULL,
        PartnerType NVARCHAR(20) NOT NULL, -- Supplier, Customer
        Phone NVARCHAR(20),
        Address NVARCHAR(255),
        CurrentBalance DECIMAL(18, 2) DEFAULT 0,
        IsActive BIT DEFAULT 1,
        AccountID INT NULL
    );
END
GO

IF OBJECT_ID('[Sales].[trg_Partner_AfterInsert]', 'TR') IS NOT NULL DROP TRIGGER [Sales].[trg_Partner_AfterInsert];
GO

CREATE TRIGGER [Sales].[trg_Partner_AfterInsert]
ON [Sales].[Partners]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerParentID INT, @SupplierParentID INT;
    SELECT @CustomerParentID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'; -- العملاء
    SELECT @SupplierParentID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'; -- الموردون

    DECLARE @PartnerID INT, @PartnerName NVARCHAR(150), @PartnerType NVARCHAR(20);
    
    DECLARE cur CURSOR FOR SELECT PartnerID, PartnerName, PartnerType FROM inserted;
    OPEN cur;
    FETCH NEXT FROM cur INTO @PartnerID, @PartnerName, @PartnerType;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @TargetParentID INT;
        DECLARE @AccountPrefix NVARCHAR(20);
        
        IF @PartnerType = 'Customer'
        BEGIN
            SET @TargetParentID = @CustomerParentID;
            SET @AccountPrefix = 'عميل - ';
        END
        ELSE IF @PartnerType = 'Supplier'
        BEGIN
            SET @TargetParentID = @SupplierParentID;
            SET @AccountPrefix = 'مورد - ';
        END
        
        IF @TargetParentID IS NOT NULL
        BEGIN
            -- Find the next available AccountCode under the appropriate Parent
            DECLARE @MaxCode NVARCHAR(20);
            SELECT @MaxCode = MAX(AccountCode) FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @TargetParentID;
            
            DECLARE @NextCode NVARCHAR(20);
            IF @MaxCode IS NULL
            BEGIN
                IF @PartnerType = 'Customer' SET @NextCode = '1201';
                ELSE SET @NextCode = '2101';
            END
            ELSE
            BEGIN
                SET @NextCode = CAST((CAST(@MaxCode AS BIGINT) + 1) AS NVARCHAR(20));
            END

            DECLARE @NewAccountID INT;
            
            -- Insert into ChartOfAccounts
            INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
            VALUES (@NextCode, @AccountPrefix + @PartnerName, @TargetParentID, 
                   CASE WHEN @PartnerType = 'Customer' THEN 'Assets' ELSE 'Liabilities' END, 2, 1);
            
            SET @NewAccountID = SCOPE_IDENTITY();

            -- Link the newly created AccountID back to the Partner
            UPDATE [Sales].[Partners] 
            SET AccountID = @NewAccountID 
            WHERE PartnerID = @PartnerID;
        END

        FETCH NEXT FROM cur INTO @PartnerID, @PartnerName, @PartnerType;
    END

    CLOSE cur;
    DEALLOCATE cur;
END
go

-- =============================================
-- Partners (الشركاء) - Stored Procedures
-- العملاء والموردين
-- Soft Delete (IsActive)
-- =============================================


-- =============================================
-- 1. جلب جميع الشركاء النشطين حسب النوع
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_GetAll]', 'P') IS NOT NULL 
DROP PROCEDURE [Sales].[sp_Partner_GetAll];
GO
CREATE PROCEDURE [Sales].[sp_Partner_GetAll]
    @PartnerType NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PartnerID, PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID
    FROM [Sales].[Partners]
    WHERE IsActive = 1 AND (@PartnerType = 'All' OR PartnerType = @PartnerType)
    ORDER BY PartnerID;
END
GO

-- =============================================
-- 2. جلب شريك بالـ ID
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_GetByID];
GO
CREATE PROCEDURE [Sales].[sp_Partner_GetByID]
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PartnerID, PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID
    FROM [Sales].[Partners]
    WHERE PartnerID = @PartnerID;
END
GO

-- =============================================
-- 3. حفظ شريك (إضافة أو تعديل)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_Save]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_Save];
GO
CREATE PROCEDURE [Sales].[sp_Partner_Save]
    @PartnerID INT = 0,
    @PartnerName NVARCHAR(150),
    @PartnerType NVARCHAR(20),
    @Phone NVARCHAR(20) = NULL,
    @Address NVARCHAR(255) = NULL,
    @AccountID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @PartnerID = 0
    BEGIN
        INSERT INTO [Sales].[Partners] (PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID)
        VALUES (@PartnerName, @PartnerType, @Phone, @Address, 0, 1, @AccountID);
        SELECT SCOPE_IDENTITY() AS PartnerID;
    END
    ELSE
    BEGIN
        UPDATE [Sales].[Partners] 
        SET PartnerName = @PartnerName, PartnerType = @PartnerType, Phone = @Phone, Address = @Address, AccountID = @AccountID
        WHERE PartnerID = @PartnerID;
        SELECT @PartnerID AS PartnerID;
    END
END
GO

-- =============================================
-- 4. تعطيل شريك (Soft Delete)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_Delete];
GO
CREATE PROCEDURE [Sales].[sp_Partner_Delete]
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Sales].[Partners] SET IsActive = 0 WHERE PartnerID = @PartnerID;
END
GO

-- =============================================
-- 5. بحث بالاسم أو الهاتف
-- =============================================
IF OBJECT_ID('[Sales].[sp_Partner_Search]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Partner_Search];
GO
CREATE PROCEDURE [Sales].[sp_Partner_Search]
    @PartnerType NVARCHAR(20),
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PartnerID, PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID
    FROM [Sales].[Partners]
    WHERE IsActive = 1 AND PartnerType = @PartnerType
      AND (PartnerName LIKE '%' + @SearchText + '%' OR Phone LIKE '%' + @SearchText + '%')
    ORDER BY PartnerID;
END
GO


-- =============================================
-- 4. المحاسبة (Schema: Accounting)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ChartOfAccounts' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[ChartOfAccounts] (
        AccountID INT PRIMARY KEY IDENTITY(1,1),
        AccountCode NVARCHAR(20) NOT NULL UNIQUE,
        AccountName NVARCHAR(150) NOT NULL,
        ParentAccountID INT NULL,
        AccountType NVARCHAR(50), 
        AccountLevel INT DEFAULT 1,
        IsTransactional BIT DEFAULT 1,
        FOREIGN KEY (ParentAccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID)
    );



end
go



-- =============================================
-- 5. المخزون (Schema: Inventory)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Products' AND schema_id = SCHEMA_ID('Inventory'))
BEGIN
    CREATE TABLE [Inventory].[Products] (
        ProductID INT PRIMARY KEY IDENTITY(1,1),
        ProductName NVARCHAR(150) NOT NULL,
        Barcode NVARCHAR(50) UNIQUE,
        CategoryID INT,
        UnitID INT,
        PurchasePrice DECIMAL(18, 2) DEFAULT 0,
        SalePrice DECIMAL(18, 2) DEFAULT 0,
        AlertQty DECIMAL(18, 2) DEFAULT 0,
        IsActive BIT DEFAULT 1,
        FOREIGN KEY (CategoryID) REFERENCES [Settings].[Categories](CatID),
        FOREIGN KEY (UnitID) REFERENCES [Settings].[Units](UnitID)
    );
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ProductStock' AND schema_id = SCHEMA_ID('Inventory'))
BEGIN
    CREATE TABLE [Inventory].[ProductStock] (
        StockID INT PRIMARY KEY IDENTITY(1,1),
        ProductID INT NOT NULL,
        WarehouseID INT NOT NULL,
        CurrentQty DECIMAL(18, 2) DEFAULT 0,
        AvgCostPrice DECIMAL(18, 2) DEFAULT 0,   -- متوسط سعر التكلفة المرجح لكل مخزن
        FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID),
        FOREIGN KEY (WarehouseID) REFERENCES [Settings].[Warehouses](WarehouseID),
        UNIQUE(ProductID, WarehouseID)
    );
END

-- Add AvgCostPrice to existing ProductStock table if column doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Inventory].[ProductStock]') AND name = 'AvgCostPrice')
BEGIN
    ALTER TABLE [Inventory].[ProductStock]
    ADD AvgCostPrice DECIMAL(18, 2) DEFAULT 0;
END

-- =============================================
-- 6. الفواتير (Schema: Sales)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'InvoiceHeader' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE [Sales].[InvoiceHeader] (
        InvID INT PRIMARY KEY IDENTITY(1,1),
        InvType NVARCHAR(20) NOT NULL, 
        InvDate DATETIME DEFAULT GETDATE(),
        PartnerID INT,
        WarehouseID INT,
        TotalAmount DECIMAL(18, 2) DEFAULT 0,
        Discount DECIMAL(18, 2) DEFAULT 0,
        NetAmount DECIMAL(18, 2) DEFAULT 0,
        PaidAmount DECIMAL(18, 2) DEFAULT 0,
        Remainder DECIMAL(18, 2) DEFAULT 0,
        UserID INT,
        Notes NVARCHAR(255),
        IsPosted BIT DEFAULT 0,
        PaymentAccountID INT NULL,   -- حساب طريقة الدفع (نقدية 11xx)
        FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID),
        FOREIGN KEY (WarehouseID) REFERENCES [Settings].[Warehouses](WarehouseID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END

-- Add PaymentAccountID to existing InvoiceHeader table if column doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Sales].[InvoiceHeader]') AND name = 'PaymentAccountID')
BEGIN
    ALTER TABLE [Sales].[InvoiceHeader]
    ADD PaymentAccountID INT NULL;
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'InvoiceDetails' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE [Sales].[InvoiceDetails] (
        DetID INT PRIMARY KEY IDENTITY(1,1),
        InvID INT NOT NULL,
        ProductID INT NOT NULL,
        UnitPrice DECIMAL(18, 2) DEFAULT 0,
        Quantity DECIMAL(18, 2) DEFAULT 1,
        TotalPrice DECIMAL(18, 2) DEFAULT 0, 
        CostPrice DECIMAL(18, 2) DEFAULT 0, 
        FOREIGN KEY (InvID) REFERENCES [Sales].[InvoiceHeader](InvID) ON DELETE CASCADE,
        FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID)
    );
END

-- =============================================
-- =============================================
-- 7. السندات المالية (Schema: Accounting)
-- =============================================

-- ============================================= -- 4.2 الإجراءات المخزنة (Stored Procedures) -- ============================================= GO

-- 1. تسجيل الدخول 
IF OBJECT_ID('[Security].[sp_User_Login]', 'P') IS NOT NULL 
DROP PROCEDURE [Security].[sp_User_Login]; 
GO

CREATE PROCEDURE [Security].[sp_User_Login]
 @Username NVARCHAR(50), 
 @PasswordHash NVARCHAR(255) 
 AS 
 BEGIN 
 SELECT UserID, FullName, RoleName, Users.IsActive FROM [Security].Users 
 INNER JOIN [Security].Roles ON Users.RoleID = Roles.RoleID 
 WHERE Username = @Username AND PasswordHash = @PasswordHash;
  END 
  GO


-- ============================================= -- 4.3 المراقبات (Triggers) -- ============================================= GO -- تريجر لمنع حذف الفواتير المرحلة 
IF OBJECT_ID('[Sales].[trg_PreventDeletePostedInvoice]', 'TR') IS NOT NULL
 DROP TRIGGER [Sales].[trg_PreventDeletePostedInvoice]; 
 GO

CREATE TRIGGER [Sales].[trg_PreventDeletePostedInvoice] 
ON [Sales].[InvoiceHeader] 
FOR DELETE
 AS
  BEGIN 
  IF EXISTS (SELECT * FROM deleted WHERE IsPosted = 1) BEGIN RAISERROR ('لا يمكن حذف فاتورة مرحلة محاسبياً', 16, 1); ROLLBACK TRANSACTION;
   END ;
   END
    GO

-- ============================================= -- 4.4 البيانات الافتراضية (Seed Data) -- ============================================= GO -- إضافة الأدوار الأساسية INSERT INTO [Security].Roles (RoleName, Description) VALUES (N'Admin', N'مدير النظام'), (N'Cashier', N'كاشير'), (N'StoreKeeper', N'أمين مخزن');





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
    SELECT WarehouseID, WarehouseName, Address, KeeperName, IsActive, AccountID FROM [Settings].[Warehouses] WHERE IsActive = 1 ORDER BY WarehouseID;
END
GO

-- Save (Add or Update)
IF OBJECT_ID('[Settings].[sp_Warehouse_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_Warehouse_Save];
GO
CREATE PROCEDURE [Settings].[sp_Warehouse_Save]
    @WarehouseID INT = 0,
    @WarehouseName NVARCHAR(100),
    @Address NVARCHAR(255) = NULL,
    @KeeperName NVARCHAR(100) = NULL,
    @AccountID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @WarehouseID = 0
    BEGIN
        INSERT INTO [Settings].[Warehouses] (WarehouseName, Address, KeeperName, IsActive, AccountID) 
        VALUES (@WarehouseName, @Address, @KeeperName, 1, @AccountID);
        SELECT SCOPE_IDENTITY() AS WarehouseID;
    END
    ELSE
    BEGIN
        UPDATE [Settings].[Warehouses] 
        SET WarehouseName = @WarehouseName, Address = @Address, KeeperName = @KeeperName, AccountID = @AccountID 
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

IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = 'seq_VoucherNo' AND schema_id = SCHEMA_ID('Accounting'))
    CREATE SEQUENCE [Accounting].[seq_VoucherNo] AS INT START WITH 2025001 INCREMENT BY 1;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Vouchers' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[Vouchers] (
        VoucherID INT PRIMARY KEY IDENTITY(1,1),
        VoucherNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_VoucherNo]),
        VoucherType NVARCHAR(20) NOT NULL, 
        VoucherDate DATETIME DEFAULT GETDATE(),
        PartnerID INT NULL, 
        AccountID INT NULL, 
        Amount DECIMAL(18, 2) NOT NULL,
        Description NVARCHAR(255),
        PaymentMethod NVARCHAR(20) DEFAULT 'Cash', 
        UserID INT,
        IsPosted BIT DEFAULT 0,
        FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID),
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END



-- =============================================
-- 1. تسلسل أرقام القيود + إنشاء جدول القيود المحاسبية
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = 'seq_EntryNo' AND schema_id = SCHEMA_ID('Accounting'))
    CREATE SEQUENCE [Accounting].[seq_EntryNo] AS INT START WITH 22200101 INCREMENT BY 1;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalEntries' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalEntries] (
        EntryID INT PRIMARY KEY IDENTITY(1,1),
        EntryNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_EntryNo]),
        EntryDate DATETIME DEFAULT GETDATE(),
        ReferenceType NVARCHAR(20) NOT NULL,       -- 'Voucher' / 'Invoice'
        ReferenceID INT NOT NULL,                    -- رقم السند أو الفاتورة
        AccountID INT NOT NULL,
        DebitAmount DECIMAL(18, 2) DEFAULT 0,
        CreditAmount DECIMAL(18, 2) DEFAULT 0,
        Description NVARCHAR(255),
        UserID INT NULL,
        CreatedAt DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END
GO

-- =============================================
-- نحتاج حساب صندوق وحساب بنك افتراضيين
-- يمكنك تعديل الأرقام حسب شجرة حساباتك
-- =============================================
-- سنستخدم PaymentMethod لتحديد الحساب:
--   Cash => أول حساب اسمه 'الصندوق' (أو AccountID يُحدد يدوياً)
--   Bank => أول حساب اسمه 'البنك'
-- =============================================

-- =============================================
-- 2. Trigger: عند INSERT أو UPDATE على Vouchers
--    إذا أصبح IsPosted = 1 => ينشئ قيدين
--    إذا تغير IsPosted من 1 إلى 0 => يحذف القيود
--    إذا تعدّل سند مرحّل => يحدّث القيود
-- =============================================
IF OBJECT_ID('[Accounting].[trg_Voucher_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_Voucher_Post];
GO

CREATE TRIGGER [Accounting].[trg_Voucher_Post]
ON [Accounting].[Vouchers]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Handle Unposting (IsPosted 1 -> 0): Delete entries
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted d ON JE.ReferenceID = d.VoucherID AND JE.ReferenceType = 'Voucher'
    INNER JOIN inserted i ON i.VoucherID = d.VoucherID
    WHERE d.IsPosted = 1 AND i.IsPosted = 0;

    -- 2. Handle Updates to Posted Vouchers (IsPosted 1 -> 1 with changes): Delete old entries
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted d ON JE.ReferenceID = d.VoucherID AND JE.ReferenceType = 'Voucher'
    INNER JOIN inserted i ON i.VoucherID = d.VoucherID
    WHERE d.IsPosted = 1 AND i.IsPosted = 1
      AND (d.Amount <> i.Amount OR ISNULL(d.AccountID,0) <> ISNULL(i.AccountID,0)
           OR ISNULL(d.PaymentMethod,'') <> ISNULL(i.PaymentMethod,''));

    -- 3. Prepare for Insertion: Assign ONE EntryNo per Voucher
    DECLARE @VoucherEntryMap TABLE (VoucherID INT, EntryNo INT);

    INSERT INTO @VoucherEntryMap (VoucherID, EntryNo)
    SELECT i.VoucherID, NEXT VALUE FOR [Accounting].[seq_EntryNo]
    FROM inserted i
    LEFT JOIN deleted d ON d.VoucherID = i.VoucherID
    WHERE i.IsPosted = 1
      AND (
          -- New Post
          ISNULL(d.IsPosted, 0) = 0
          -- OR Re-Post (Modified)
          OR (d.IsPosted = 1 AND (d.Amount <> i.Amount OR ISNULL(d.AccountID,0) <> ISNULL(i.AccountID,0) OR ISNULL(d.PaymentMethod,'') <> ISNULL(i.PaymentMethod,'')))
      );

    -- 4. Insert Journal Entries (Both Legs)

    -- Leg 1: The Selected Account (Customer/Vendor/Expense/etc.)
    
    INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT
        m.EntryNo,
        i.VoucherDate,
        'Voucher',
        i.VoucherID,
        i.AccountID,
        CASE WHEN i.VoucherType = 'Payment' THEN i.Amount ELSE 0 END, -- Payment: Dr Account
        CASE WHEN i.VoucherType = 'Receipt' THEN i.Amount ELSE 0 END, -- Receipt: Cr Account
        ISNULL(i.Description, '') + N' - سند رقم ' + CAST(i.VoucherNo AS NVARCHAR),
        i.UserID
    FROM inserted i
    JOIN @VoucherEntryMap m ON m.VoucherID = i.VoucherID;

    -- Leg 2: The Fund Account (Cash/Bank)
    -- Receipt -> Debit | Payment -> Credit
    INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT
        m.EntryNo,
        i.VoucherDate,
        'Voucher',
        i.VoucherID,
        CASE
            WHEN isnumeric(i.PaymentMethod) = 1 THEN CAST(i.PaymentMethod AS INT)
            WHEN i.PaymentMethod = 'Cash' THEN
                ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1), i.AccountID)
            ELSE
                ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountName LIKE N'%بنك%' AND IsTransactional = 1), i.AccountID)
        END,
        CASE WHEN i.VoucherType = 'Receipt' THEN i.Amount ELSE 0 END, -- Receipt: Dr Cash
        CASE WHEN i.VoucherType = 'Payment' THEN i.Amount ELSE 0 END, -- Payment: Cr Cash
        ISNULL(i.Description, '') + N' - سند رقم ' + CAST(i.VoucherNo AS NVARCHAR),
        i.UserID
    FROM inserted i
    JOIN @VoucherEntryMap m ON m.VoucherID = i.VoucherID;
END
GO


-- =============================================
-- 3. Trigger: عند DELETE على Vouchers
--    يحذف جميع القيود المرتبطة بالسند
-- =============================================
IF OBJECT_ID('[Accounting].[trg_Voucher_Delete]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_Voucher_Delete];
GO

CREATE TRIGGER [Accounting].[trg_Voucher_Delete]
ON [Accounting].[Vouchers]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM [Accounting].[JournalEntries]
    WHERE ReferenceType = 'Voucher' 
      AND ReferenceID IN (SELECT VoucherID FROM deleted);
END
GO

PRINT N'✅ تم إنشاء جدول القيود والـ Triggers بنجاح';
GO

-- =============================================
-- 1. جلب جميع السندات حسب النوع
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Voucher_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_GetAll];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_GetAll]
    @VoucherType NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT V.VoucherID, V.VoucherNo, V.VoucherType, V.VoucherDate, V.PartnerID,
           P.PartnerName, V.AccountID, A.AccountName,
           V.Amount, V.Description, V.PaymentMethod, V.UserID,
           U.FullName AS UserName, V.IsPosted
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] A ON V.AccountID = A.AccountID
    LEFT JOIN [Security].[Users] U ON V.UserID = U.UserID
    WHERE V.VoucherType = @VoucherType
    ORDER BY V.VoucherID DESC;
END
GO

-- =============================================
-- 2. جلب سند بالـ ID
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Voucher_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_GetByID];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_GetByID]
    @VoucherID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT V.VoucherID, V.VoucherNo, V.VoucherType, V.VoucherDate, V.PartnerID,
           P.PartnerName, V.AccountID, A.AccountName,
           V.Amount, V.Description, V.PaymentMethod, V.UserID,
           U.FullName AS UserName, V.IsPosted
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] A ON V.AccountID = A.AccountID
    LEFT JOIN [Security].[Users] U ON V.UserID = U.UserID
    WHERE V.VoucherID = @VoucherID;
END
GO

-- =============================================
-- 3. حفظ سند (إضافة أو تعديل)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Voucher_Save]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_Save];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_Save]
    @VoucherID INT = 0,
    @VoucherType NVARCHAR(20),
    @VoucherDate DATETIME,
    @PartnerID INT = NULL,
    @AccountID INT = NULL,
    @Amount DECIMAL(18,2),
    @Description NVARCHAR(255) = NULL,
    @PaymentMethod NVARCHAR(20) = 'Cash',
    @UserID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @VoucherID = 0
    BEGIN
        INSERT INTO [Accounting].[Vouchers] (VoucherType, VoucherDate, PartnerID, AccountID, Amount, Description, PaymentMethod, UserID, IsPosted)
        VALUES (@VoucherType, @VoucherDate, @PartnerID, @AccountID, @Amount, @Description, @PaymentMethod, @UserID, 0);
        SELECT SCOPE_IDENTITY() AS VoucherID;
    END
    ELSE
    BEGIN
        -- لا يمكن تعديل سند مرحّل
        IF EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID AND IsPosted = 1)
        BEGIN
            RAISERROR(N'لا يمكن تعديل سند مرحّل', 16, 1);
            RETURN;
        END
        UPDATE [Accounting].[Vouchers] 
        SET VoucherType = @VoucherType, VoucherDate = @VoucherDate, PartnerID = @PartnerID, AccountID = @AccountID,
            Amount = @Amount, Description = @Description, PaymentMethod = @PaymentMethod
        WHERE VoucherID = @VoucherID;
        SELECT @VoucherID AS VoucherID;
    END
END
GO

-- =============================================
-- 4. حذف سند (فقط إذا لم يُرحّل)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Voucher_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_Delete];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_Delete]
    @VoucherID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID AND IsPosted = 1)
    BEGIN
        RAISERROR(N'لا يمكن حذف سند مرحّل', 16, 1);
        RETURN;
    END
    DELETE FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID;
END
GO

-- =============================================
-- 5. بحث بالوصف أو اسم الشريك
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Voucher_Search]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_Search];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_Search]
    @VoucherType NVARCHAR(20),
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT V.VoucherID, V.VoucherNo, V.VoucherType, V.VoucherDate, V.PartnerID,
           P.PartnerName, V.AccountID, A.AccountName,
           V.Amount, V.Description, V.PaymentMethod, V.UserID,
           U.FullName AS UserName, V.IsPosted
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] A ON V.AccountID = A.AccountID
    LEFT JOIN [Security].[Users] U ON V.UserID = U.UserID
    WHERE V.VoucherType = @VoucherType
      AND (V.Description LIKE '%' + @SearchText + '%' OR P.PartnerName LIKE '%' + @SearchText + '%'
           OR CAST(V.VoucherID AS NVARCHAR) = @SearchText)
    ORDER BY V.VoucherID DESC;
END
GO

-- =============================================
-- 6. ترحيل سند (يُفعّل الـ Trigger لإنشاء القيود)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Voucher_Post]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_Post];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_Post]
    @VoucherID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID)
    BEGIN
        RAISERROR(N'السند غير موجود', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID AND IsPosted = 1)
    BEGIN
        RAISERROR(N'السند مرحّل بالفعل', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM [Accounting].[Vouchers] WHERE VoucherID = @VoucherID AND AccountID IS NULL)
    BEGIN
        RAISERROR(N'يجب تحديد الحساب قبل الترحيل', 16, 1);
        RETURN;
    END
    -- تحديث IsPosted يُفعّل الـ Trigger تلقائياً
    UPDATE [Accounting].[Vouchers] SET IsPosted = 1 WHERE VoucherID = @VoucherID;
END
GO



-- =============================================
-- 1. كشف حساب (Account Statement)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Report_AccountStatement]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_AccountStatement];
GO

CREATE PROCEDURE [Accounting].[sp_Report_AccountStatement]
    @AccountID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. حساب الرصيد الافتتاحى (ما قبل الفترة)
    DECLARE @OpeningBalance DECIMAL(18, 2) = 0;

    SELECT @OpeningBalance = ISNULL(SUM(DebitAmount - CreditAmount), 0)
    FROM [Accounting].[JournalEntries]
    WHERE AccountID = @AccountID
      AND CAST(EntryDate AS DATE) < @StartDate;

    -- النتيجة 1: الرصيد الافتتاحي
    SELECT @OpeningBalance AS OpeningBalance;

    -- النتيجة 2: الحركات
    SELECT 
        JE.EntryID,
        JE.EntryNo,
        JE.EntryDate,
        JE.ReferenceType,
        JE.ReferenceID,
        JE.Description,
        JE.DebitAmount,
        JE.CreditAmount,
        -- الرصيد التراكمي = الرصيد الافتتاحي + مجموع (مدين - دائن) للحركات السابقة والحالية
        @OpeningBalance + SUM(JE.DebitAmount - JE.CreditAmount) OVER (ORDER BY JE.EntryDate, JE.EntryID ROWS UNBOUNDED PRECEDING) AS Balance
    FROM [Accounting].[JournalEntries] JE
    WHERE JE.AccountID = @AccountID
      AND CAST(JE.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY JE.EntryDate, JE.EntryID;

    -- إرجاع الرصيد الافتتاحي كأول سطر (اختياري، أو يمكن للواجهة التعامل معه)
    -- لكن عادة يفضل عرضه في الواجهة منفصلاً أو كسطر أول وهمي.
    -- هنا سنكتفي بإرجاع البيانات وسنقوم بعرض الرصيد الافتتاحي في الواجهة.
    
    -- إضافة: يمكن إرجاع الرصيد الافتتاحي في Select منفصلة أو Output Parameter
    -- لكن للتبسيط، سنقوم بإرجاع dataset ثانية
END
GO


-- =============================================
-- 1. Create CompanySettings Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CompanySettings' AND schema_id = SCHEMA_ID('Settings'))
BEGIN
    CREATE TABLE [Settings].[CompanySettings] (
        SettingID INT PRIMARY KEY DEFAULT 1, -- Only one row allowed
        CompanyName NVARCHAR(200) NOT NULL,
        Address NVARCHAR(255),
        Phone NVARCHAR(50),
        Email NVARCHAR(100),
        Logo VARBINARY(MAX),
        CONSTRAINT CK_OnlyOneRow CHECK (SettingID = 1)
    );

    -- Insert default record
    INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName)
    VALUES (1, N'شركة الخضروات');
END
GO

-- =============================================
-- 2. Stored Procedures
-- =============================================

-- Get Company Settings
IF OBJECT_ID('[Settings].[sp_CompanySettings_Get]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Get];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Get]
AS
BEGIN
    SELECT TOP 1 * FROM [Settings].[CompanySettings];
END
GO

-- Save Company Settings
IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo);
    END
END
GO


-- 2. التحقق من وجود جدول رأس القيد (JournalHeader)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalHeader' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    create TABLE [Accounting].[JournalHeader] (
        JID INT PRIMARY KEY IDENTITY(1,1),
        JournalNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_EntryNo]),
        JDate DATETIME DEFAULT GETDATE(),
        Description NVARCHAR(255),
        UserID INT,
        IsPosted BIT DEFAULT 0,
        TotalAmount DECIMAL(18, 2) DEFAULT 0,
        ReferenceType NVARCHAR(50) DEFAULT 'Manual', 
        ReferenceID INT NULL, 
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END
ELSE
BEGIN
    -- تعديل الترقيم ليستخدم التسلسل العام إذا كان جديداً
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Accounting].[JournalHeader]') AND name = 'JournalNo')
        ALTER TABLE [Accounting].[JournalHeader] ADD JournalNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_EntryNo]);
    
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Accounting].[JournalHeader]') AND name = 'TotalAmount')
        ALTER TABLE [Accounting].[JournalHeader] ADD TotalAmount DECIMAL(18, 2) DEFAULT 0;
END
GO

-- 3. إجراء مخزن لحفظ القيد اليدوي (رأس وتفاصيل)
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Save]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Save];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Save]
    @JID INT = 0,
    @JDate DATETIME,
    @Description NVARCHAR(255),
    @UserID INT,
    @TotalAmount DECIMAL(18, 2),
    @DetailsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @JID = 0
        BEGIN
            INSERT INTO [Accounting].[JournalHeader] (JDate, Description, UserID, TotalAmount, IsPosted, ReferenceType)
            VALUES (@JDate, @Description, @UserID, @TotalAmount, 0, 'Manual');
            SET @JID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- تحديث الرأس (فقط إذا لم يُرحّل)
            IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 1)
            BEGIN
                RAISERROR(N'لا يمكن تعديل قيد مرحّل', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Accounting].[JournalHeader] 
            SET JDate = @JDate, Description = @Description, TotalAmount = @TotalAmount
            WHERE JID = @JID;

            DELETE FROM [Accounting].[JournalDetails] WHERE JID = @JID;
        END

        -- إدخال التفاصيل من الـ XML
        -- ملاحظة: يعمل على كافة نسخ SQL Server الحديثة والقديمة
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
        SELECT 
            @JID,
            T.c.value('@AccountID', 'INT'),
            T.c.value('@Debit', 'DECIMAL(18,2)'),
            T.c.value('@Credit', 'DECIMAL(18,2)'),
            T.c.value('@Notes', 'NVARCHAR(200)')
        FROM @DetailsXml.nodes('/details/item') T(c);

        COMMIT TRANSACTION;
        SELECT @JID AS JID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 4. إجراء ترحيل القيد اليدوي لجدول الحركات العام
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Post]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Post];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Post]
    @JID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 1)
    BEGIN
        RAISERROR(N'القيد مرحّل بالفعل', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- نستخدم نفس رقم القيد الموجود في الرأس ليكون هو رقم الحركة في القيد العام
        -- هذا يضمن الشفافية وتوحيد الترقيم
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            H.JournalNo,
            H.JDate,
            'Manual',
            H.JID,
            D.AccountID,
            D.Debit,
            D.Credit,
            ISNULL(D.Notes, H.Description),
            H.UserID
        FROM [Accounting].[JournalHeader] H
        JOIN [Accounting].[JournalDetails] D ON H.JID = D.JID
        WHERE H.JID = @JID;

        UPDATE [Accounting].[JournalHeader] SET IsPosted = 1 WHERE JID = @JID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 5. جلب كافة القيود اليدوية
IF OBJECT_ID('[Accounting].[sp_JournalEntry_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_GetAll];
GO
CREATE PROCEDURE [Accounting].[sp_JournalEntry_GetAll]
AS
BEGIN
    SELECT JID, JournalNo, JDate, Description, TotalAmount, IsPosted, ReferenceType
    FROM [Accounting].[JournalHeader]
    WHERE ReferenceType in( 'Manual', 'YearEndClose')
    ORDER BY JID DESC;
END
GO

-- 6. جلب تفاصيل قيد معين
IF OBJECT_ID('[Accounting].[sp_JournalEntry_GetDetails]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_GetDetails];
GO
CREATE PROCEDURE [Accounting].[sp_JournalEntry_GetDetails]
    @JID INT
AS
BEGIN
    SELECT JD.JDID, JD.JID, JD.AccountID, A.AccountName, A.AccountCode, JD.Debit, JD.Credit, JD.Notes
    FROM [Accounting].[JournalDetails] JD
    JOIN [Accounting].[ChartOfAccounts] A ON JD.AccountID = A.AccountID
    WHERE JD.JID = @JID;
END
GO

-- 2.2 التحقق من وجود جدول تفاصيل القيد (JournalDetails)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalDetails' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalDetails] (
        JDID INT PRIMARY KEY IDENTITY(1,1),
        JID INT NOT NULL,
        AccountID INT NOT NULL,
        Debit DECIMAL(18, 2) DEFAULT 0,
        Credit DECIMAL(18, 2) DEFAULT 0,
        Notes NVARCHAR(200),
        FOREIGN KEY (JID) REFERENCES [Accounting].[JournalHeader](JID),
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID)
    );
END
GO

IF OBJECT_ID('[Accounting].[sp_Report_TrialBalance]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_TrialBalance];
GO

CREATE PROCEDURE [Accounting].[sp_Report_TrialBalance]
    @StartDate DATETIME,
    @EndDate DATETIME,
    @ReportLevel INT = 0 -- 0: Transactional, 1: Main, 2: Sub, 3: Group
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate Transactional Totals
    WITH RawTotals AS (
        SELECT 
            AccountID,
            SUM(CASE WHEN EntryDate < @StartDate THEN (DebitAmount - CreditAmount) ELSE 0 END) as OpeningBalance,
            SUM(CASE WHEN EntryDate >= @StartDate AND EntryDate <= @EndDate THEN DebitAmount ELSE 0 END) as PeriodDebit,
            SUM(CASE WHEN EntryDate >= @StartDate AND EntryDate <= @EndDate THEN CreditAmount ELSE 0 END) as PeriodCredit
        FROM [Accounting].[JournalEntries]
        GROUP BY AccountID
    ),
    -- 2. Build Account Hierarchy with recursive leaf counts/sums
    Hierarchy AS (
        SELECT 
            AccountID, 
            ParentAccountID, 
            AccountCode, 
            AccountName, 
            AccountLevel, 
            IsTransactional,
            AccountID as RootParentID -- Tracking the ancestor at the requested level
        FROM [Accounting].[ChartOfAccounts]
        WHERE (AccountLevel = @ReportLevel )
           

        UNION ALL

        SELECT 
            c.AccountID, 
            c.ParentAccountID, 
            c.AccountCode, 
            c.AccountName, 
            c.AccountLevel, 
            c.IsTransactional,
            h.RootParentID
        FROM [Accounting].[ChartOfAccounts] c
        JOIN Hierarchy h ON c.ParentAccountID = h.AccountID
    )
    -- 3. Final Aggregation based on the RootParentID (the requested level)
    SELECT 
        h.RootParentID as AccountID,
        p.AccountCode,
        p.AccountName,
        p.AccountType,
        SUM(ISNULL(r.OpeningBalance, 0)) as OpeningBalance,
        SUM(ISNULL(r.PeriodDebit, 0)) as PeriodDebit,
        SUM(ISNULL(r.PeriodCredit, 0)) as PeriodCredit,
        -- Ending = Opening + (MoveDr - MoveCr)
        (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) as EndingBalance,
        
        -- Keep Dr/Cr for internal use if needed
        CASE WHEN (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) >= 0 
             THEN (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) 
             ELSE 0 END as EndingDebit,
        CASE WHEN (SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) < 0 
             THEN ABS(SUM(ISNULL(r.OpeningBalance, 0)) + SUM(ISNULL(r.PeriodDebit, 0)) - SUM(ISNULL(r.PeriodCredit, 0))) 
             ELSE 0 END as EndingCredit

    FROM Hierarchy h
    LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
    JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
    WHERE h.IsTransactional = 1   -- Only sum up transactional data
    GROUP BY h.RootParentID, p.AccountCode, p.AccountName, p.AccountType
    ORDER BY p.AccountCode;
END
GO

-- =============================================
-- 1. جلب جميع الحسابات
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_GetAll];
GO
CREATE PROCEDURE [Accounting].[sp_Account_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID, 
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
    ORDER BY A.AccountType,A.AccountCode;
END
GO

-- =============================================
-- 2. جلب حساب بالـ ID
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_GetByID];
GO
CREATE PROCEDURE [Accounting].[sp_Account_GetByID]
    @AccountID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID,
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
    WHERE A.AccountID = @AccountID;
END
GO

-- =============================================
-- 3. حفظ حساب (إضافة أو تعديل)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Save]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Save];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Save]
    @AccountID INT = 0,
    @AccountCode NVARCHAR(20),
    @AccountName NVARCHAR(150),
    @ParentAccountID INT = NULL,
    @AccountType NVARCHAR(50),
    @AccountLevel INT = 1,
    @IsTransactional BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- التحقق: إذا كان الحساب مراد جعله "فرعي/يقبل قيود" ولكن له أبناء بالفعل في الشجرة
    IF @AccountID <> 0 AND @IsTransactional = 1
    BEGIN
        IF EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @AccountID)
        BEGIN
            RAISERROR(N'لا يمكن جعل الحساب "فرعي" لأنه أب لحسابات أخرى في الشجرة.', 16, 1);
            RETURN;
        END
    END

    IF @AccountID = 0
    BEGIN
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES (@AccountCode, @AccountName, @ParentAccountID, @AccountType, @AccountLevel, @IsTransactional);
        SELECT SCOPE_IDENTITY() AS AccountID;
    END
    ELSE
    BEGIN
        UPDATE [Accounting].[ChartOfAccounts] 
        SET AccountCode = @AccountCode, AccountName = @AccountName, ParentAccountID = @ParentAccountID,
            AccountType = @AccountType, AccountLevel = @AccountLevel, IsTransactional = @IsTransactional
        WHERE AccountID = @AccountID;
        SELECT @AccountID AS AccountID;
    END
END
GO

-- =============================================
-- 4. حذف حساب (فقط إذا لم يُستخدم في قيود)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Delete];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Delete]
    @AccountID INT
AS
BEGIN
    SET NOCOUNT ON;
    -- منع الحذف إذا تم استخدام الحساب في قيود
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalDetails] WHERE AccountID = @AccountID)
    BEGIN
        RAISERROR(N'لا يمكن حذف حساب مستخدم في قيود محاسبية', 16, 1);
        RETURN;
    END
    -- منع الحذف إذا له حسابات فرعية
    IF EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @AccountID)
    BEGIN
        RAISERROR(N'لا يمكن حذف حساب له حسابات فرعية', 16, 1);
        RETURN;
    END
    DELETE FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @AccountID;
END
GO

-- =============================================
-- 5. بحث بالكود أو الاسم
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Search]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Search];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Search]
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID,
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
    WHERE A.AccountCode LIKE '%' + @SearchText + '%' OR A.AccountName LIKE '%' + @SearchText + '%'
    ORDER BY A.AccountCode;
END
GO

-- =============================================
-- 6. جلب الحسابات الأب فقط (غير الفرعية) للـ ComboBox
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_GetParents]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_GetParents];
GO
CREATE PROCEDURE [Accounting].[sp_Account_GetParents]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AccountID, AccountCode, AccountName, AccountType, AccountLevel
    FROM [Accounting].[ChartOfAccounts]
    ORDER BY AccountCode;
END
GO

-- =============================================
-- 4. تعديل بيانات حساب (Explicit Update)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Update]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Update];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Update]
    @AccountID INT,
    @AccountCode NVARCHAR(20),
    @AccountName NVARCHAR(150),
    @ParentAccountID INT = NULL,
    @AccountType NVARCHAR(50),
    @AccountLevel INT = 1,
    @IsTransactional BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- التحقق من وجود الحساب
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @AccountID)
    BEGIN
        RAISERROR(N'الحساب غير موجود.', 16, 1);
        RETURN;
    END

    -- التحقق: إذا كان الحساب له أبناء، لا يمكن جعله "فرعي"
    IF @IsTransactional = 1 AND EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @AccountID)
    BEGIN
        RAISERROR(N'لا يمكن جعل الحساب "فرعي" لأنه أب لحسابات أخرى.', 16, 1);
        RETURN;
    END

    UPDATE [Accounting].[ChartOfAccounts] 
    SET AccountCode = @AccountCode, 
        AccountName = @AccountName, 
        ParentAccountID = @ParentAccountID,
        AccountType = @AccountType, 
        AccountLevel = @AccountLevel, 
        IsTransactional = @IsTransactional
    WHERE AccountID = @AccountID;

    SELECT @AccountID AS AccountID;
END
GO


IF OBJECT_ID('[Accounting].[sp_Setup_InitialAccounts]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Setup_InitialAccounts];
GO
CREATE PROCEDURE [Accounting].[sp_Setup_InitialAccounts]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AssetsID INT, @LiabilitiesID INT, @EquityID INT, @RevenueID INT, @ExpensesID INT,@profit int ,@banckandcash int,@costcode int,@firstbalance int ,@capital int;

    -- 1. الحسابات الرئيسية (Level 0)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '1')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, AccountType, AccountLevel, IsTransactional)
        VALUES ('1', N'الأصول', 'Assets', 0, 0);
    SELECT @AssetsID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '1';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '2')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, AccountType, AccountLevel, IsTransactional)
        VALUES ('2', N'الالتزامات', 'Liabilities', 0, 0);
    SELECT @LiabilitiesID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '2';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '3')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, AccountType, AccountLevel, IsTransactional)
        VALUES ('3', N'حقوق الملكية', 'Equity', 0, 0);
    SELECT @EquityID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '3';

	    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '31')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName,ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('31', N'أرباح وخسائر',@EquityID, 'Equity', 1, 0);
    SELECT @Profit = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '31';

		    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '32')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName,ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('32', N'حساب رأس المال',@EquityID, 'Equity', 1, 0);
    SELECT @capital = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '32';

	 IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '321')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName,ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('321', N'رصيد أول المده', @capital,'Equity', 2, 1);
    SELECT @firstbalance = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '321';

	IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '311')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName,ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('311', N'أرباح وخسائر مرحله', @Profit,'Equity', 2, 1);
    SELECT @Profit = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '311';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '4')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, AccountType, AccountLevel, IsTransactional)
        VALUES ('4', N'الإيرادات', 'Revenue', 0, 0);
    SELECT @RevenueID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '4';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, AccountType, AccountLevel, IsTransactional)
        VALUES ('5', N'المصروفات', 'Expenses', 0, 0);
    SELECT @ExpensesID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5';

    -- 2. تحت الأصول (Assets)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '11')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('11', N'النقدية والبنوك', @AssetsID, 'Assets', 1, 0);
	select @banckandcash = accountID from [Accounting].[ChartOfAccounts] WHERE AccountCode = '11';

        -- 2. تحت الأصول (Assets)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '1101')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('1101', N'الصندوق الرئيسي', @banckandcash, 'Assets', 2, 1);


    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('12', N'العملاء / الذمم المدينة', @AssetsID, 'Assets', 1, 0);

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('13', N'المخزون', @AssetsID, 'Assets', 1, 0);

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '14')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('14', N'الأصول الثابتة', @AssetsID, 'Assets', 1, 0);



    -- 3. تحت الالتزامات (Liabilities)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('21', N'الموردون / الذمم الدائنة', @LiabilitiesID, 'Liabilities', 1, 0);


    -- 4. تحت الإيرادات (Revenues)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '41')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('41', N'إيرادات المبيعات', @RevenueID, 'Revenue', 1, 0);

    -- 5. تحت المصروفات (Expenses)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '51')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('51', N'تكلفة البضاعة المباعة - COGS', @ExpensesID, 'Expenses', 1, 0);
select @costcode = accountID from [Accounting].[ChartOfAccounts] WHERE AccountCode = '51';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5101')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('5101', N'تكلفة البضاعة المباعة', @costcode, 'Expenses', 2, 1);
 

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '52')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('52', N'المصاريف التشغيلية', @ExpensesID, 'Expenses', 1, 0);

    SELECT N'تمت تهيئة الحسابات الرئيسية بنجاح.' AS Result;
END
GO

EXEC Accounting.sp_Setup_InitialAccounts



-- =============================================
-- 1. قائمة الأرباح والخسائر (Profit & Loss)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Report_ProfitLoss]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_ProfitLoss];
GO

CREATE PROCEDURE [Accounting].[sp_Report_ProfitLoss]
    @StartDate DATETIME,
    @EndDate DATETIME,
    @ReportLevel INT = 0 -- 0: Main Categoric, 1: Sub, 2: Group
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate Transactional Totals for Revenue and Expenses
    WITH RawTotals AS (
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    WHEN A.AccountType = 'Revenue' THEN (JE.DebitAmount - JE.CreditAmount )
                    WHEN A.AccountType = 'Expenses' THEN (JE.DebitAmount - JE.CreditAmount)
                    ELSE (JE.DebitAmount - JE.CreditAmount)
                END
            ) as PeriodBalance
        FROM [Accounting].[JournalEntries] JE
        JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE A.AccountType IN ('Revenue', 'Expenses')
          AND JE.EntryDate BETWEEN @StartDate AND @EndDate
        GROUP BY A.AccountID
    ),
    -- 2. Build Hierarchy
    Hierarchy AS (
        SELECT 
            AccountID, 
            ParentAccountID, 
            AccountCode, 
            AccountName, 
            AccountLevel, 
            IsTransactional,
            AccountID as RootParentID
        FROM [Accounting].[ChartOfAccounts]
        WHERE AccountLevel = @ReportLevel
          AND AccountType IN ('Revenue', 'Expenses')

        UNION ALL

        SELECT 
            c.AccountID, 
            c.ParentAccountID, 
            c.AccountCode, 
            c.AccountName, 
            c.AccountLevel, 
            c.IsTransactional,
            h.RootParentID
        FROM [Accounting].[ChartOfAccounts] c
        JOIN Hierarchy h ON c.ParentAccountID = h.AccountID
    )
    -- 3. Aggregation
    SELECT 
        h.RootParentID as AccountID,
        p.AccountCode,
        p.AccountName,
        p.AccountType,
        SUM(ISNULL(r.PeriodBalance, 0)) as Balance
    FROM Hierarchy h
    LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
    JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
    WHERE h.IsTransactional = 1
    GROUP BY h.RootParentID, p.AccountCode, p.AccountName, p.AccountType
    ORDER BY p.AccountCode;
END
GO

-- =============================================
-- 2. قائمة المركز المالي (Balance Sheet)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Report_BalanceSheet]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Report_BalanceSheet];
GO

CREATE PROCEDURE [Accounting].[sp_Report_BalanceSheet]
    @AsOfDate DATETIME,
    @ReportLevel INT = 0 -- 0: Main, 1: Sub, 2: Group
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Calculate Transactional Totals for Assets, Liabilities, and Equity
    -- Important: In accounting, Balance Sheet items are cumulative.
    WITH RawTotals AS (
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    WHEN A.AccountType = 'Assets' THEN (JE.DebitAmount - JE.CreditAmount)
                    WHEN A.AccountType IN ('Liabilities', 'Equity') THEN (JE.CreditAmount - JE.DebitAmount)
                    ELSE (JE.DebitAmount - JE.CreditAmount)
                END
            ) as CurrentBalance
        FROM [Accounting].[JournalEntries] JE
        JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE A.AccountType IN ('Assets', 'Liabilities', 'Equity')
          AND JE.EntryDate <= @AsOfDate
        GROUP BY A.AccountID
    ),
    -- 2. Build Hierarchy
    Hierarchy AS (
        SELECT 
            AccountID, 
            ParentAccountID, 
            AccountCode, 
            AccountName, 
            AccountLevel, 
            IsTransactional,
            AccountID as RootParentID
        FROM [Accounting].[ChartOfAccounts]
        WHERE AccountLevel = @ReportLevel
          AND AccountType IN ('Assets', 'Liabilities', 'Equity')

        UNION ALL

        SELECT 
            c.AccountID, 
            c.ParentAccountID, 
            c.AccountCode, 
            c.AccountName, 
            c.AccountLevel, 
            c.IsTransactional,
            h.RootParentID
        FROM [Accounting].[ChartOfAccounts] c
        JOIN Hierarchy h ON c.ParentAccountID = h.AccountID
    )
    -- 3. Aggregation
    SELECT 
        h.RootParentID as AccountID,
        p.AccountCode,
        p.AccountName,
        p.AccountType,
        SUM(ISNULL(r.CurrentBalance, 0)) as Balance
    FROM Hierarchy h
    LEFT JOIN RawTotals r ON h.AccountID = r.AccountID
    JOIN [Accounting].[ChartOfAccounts] p ON h.RootParentID = p.AccountID
    WHERE h.IsTransactional = 1
    GROUP BY h.RootParentID, p.AccountCode, p.AccountName, p.AccountType
    ORDER BY p.AccountCode;
END
GO

-- =============================================
-- 13. الإقفال السنوي (Year-End Closing)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Accounting_YearEndClose]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Accounting_YearEndClose];
GO

CREATE PROCEDURE [Accounting].[sp_Accounting_YearEndClose]
    @ClosingDate DATETIME,
    @RetainedEarningsAccountID INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. التأكد من وجود حساب الأرباح المبقاة
        IF NOT EXISTS(SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @RetainedEarningsAccountID)
            THROW 50001, N'حساب أرباح وخسائر مبقاة غير موجود، يرجى تهيئته.', 1;

        -- 2. حساب أرصدة الإيرادات والمصروفات حتى تاريخ الإقفال
        DECLARE @Balances TABLE (AccountID INT, Balance DECIMAL(18,2), AccType NVARCHAR(50));

        INSERT INTO @Balances (AccountID, Balance, AccType)
        SELECT 
            A.AccountID,
            SUM(
                CASE 
                    WHEN A.AccountType = 'Revenue' THEN (JE.CreditAmount - JE.DebitAmount)
                    WHEN A.AccountType = 'Expenses' THEN (JE.DebitAmount - JE.CreditAmount)
                    ELSE 0
                END
            ),
            A.AccountType
        FROM [Accounting].[JournalEntries] JE
        JOIN [Accounting].[ChartOfAccounts] A ON JE.AccountID = A.AccountID
        WHERE A.AccountType IN ('Revenue', 'Expenses')
          AND JE.EntryDate <= @ClosingDate
        GROUP BY A.AccountID, A.AccountType
        HAVING SUM(JE.DebitAmount - JE.CreditAmount) <> 0 OR SUM(JE.CreditAmount - JE.DebitAmount) <> 0;

        -- إذا لم تكن هناك أرصدة للإقفال
        IF NOT EXISTS(SELECT 1 FROM @Balances WHERE Balance <> 0)
        BEGIN
            COMMIT TRANSACTION;
            SELECT 0 AS ResultID, N'لا توجد حركات إيرادات أو مصروفات لإقفالها حتى هذا التاريخ.' AS ResultMsg;
            RETURN;
        END

        -- 3. إنشاء رأس قيد الإقفال (JournalHeader)
        DECLARE @JID INT;
        DECLARE @Desc NVARCHAR(255) = N'قيد إقفال السنة المالية حتى تاريخ ' + FORMAT(@ClosingDate, 'yyyy/MM/dd');

        INSERT INTO [Accounting].[JournalHeader] (JDate, Description, UserID, IsPosted, TotalAmount, ReferenceType)
        VALUES (@ClosingDate, @Desc, @UserID, 0, 0, 'YearEndClose');
        
        SET @JID = SCOPE_IDENTITY();

        -- 4. إدراج تفاصيل قيد الإقفال (JournalDetails)
        
        -- إقفال الإيرادات (طبيعتها دائنة، يتم إقفالها مدين)
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
        SELECT @JID, AccountID, 
               CASE WHEN Balance > 0 THEN Balance ELSE 0 END, 
               CASE WHEN Balance < 0 THEN ABS(Balance) ELSE 0 END,
               @Desc
        FROM @Balances WHERE AccType = 'Revenue' AND Balance <> 0;

        -- إقفال المصروفات (طبيعتها مدينة، يتم إقفالها دائن)
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
        SELECT @JID, AccountID, 
               CASE WHEN Balance < 0 THEN ABS(Balance) ELSE 0 END, 
               CASE WHEN Balance > 0 THEN Balance ELSE 0 END,
               @Desc
        FROM @Balances WHERE AccType = 'Expenses' AND Balance <> 0;

        -- 5. إقفال صافي الربح / الخسارة في الأرباح المبقاة
        DECLARE @TotalRevenues DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM @Balances WHERE AccType = 'Revenue'), 0);
        DECLARE @TotalExpenses DECIMAL(18,2) = ISNULL((SELECT SUM(Balance) FROM @Balances WHERE AccType = 'Expenses'), 0);
        DECLARE @NetProfit DECIMAL(18,2) = @TotalRevenues - @TotalExpenses;

        IF @NetProfit <> 0
        BEGIN
            INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
            VALUES (@JID, @RetainedEarningsAccountID,
                    CASE WHEN @NetProfit < 0 THEN ABS(@NetProfit) ELSE 0 END,   -- خسارة -> نقلل من الأرباح المبقاة (مدين)
                    CASE WHEN @NetProfit > 0 THEN @NetProfit ELSE 0 END,         -- ربح -> نضيف للأرباح المبقاة (دائن)
                    N'إقفال صافي الربح / الخسارة');
        END

        -- 6. تحديث إجمالي القيد
        DECLARE @TotalDebit DECIMAL(18,2) = ISNULL((SELECT SUM(Debit) FROM [Accounting].[JournalDetails] WHERE JID = @JID), 0);
        UPDATE [Accounting].[JournalHeader] SET TotalAmount = @TotalDebit WHERE JID = @JID;

        -- 7. ترحيل القيد لإثبات الحركات في سجل القيود العام
        DECLARE @JournalNo INT;
        SELECT @JournalNo = JournalNo FROM [Accounting].[JournalHeader] WHERE JID = @JID;

        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            @JournalNo,
            @ClosingDate,
            'YearEndClose',
            @JID,
            D.AccountID,
            D.Debit,
            D.Credit,
            ISNULL(D.Notes, @Desc),
            @UserID
        FROM [Accounting].[JournalDetails] D
        WHERE D.JID = @JID;

        UPDATE [Accounting].[JournalHeader] SET IsPosted = 1 WHERE JID = @JID;

        COMMIT TRANSACTION;
        SELECT @JID AS ResultID, @JournalNo AS EntryNo, N'تم إقفال السنة المالية وترحيل القيد بنجاح.' AS ResultMsg;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================
-- Vegtablity - All Stored Procedures
-- Schema: [Security]
-- Execute this script in SQL Server Management Studio (SSMS)
-- =============================================

USE [VegtablityDB]
GO

-- =============================================
-- 1. sp_User_Login
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Login]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Login]
GO
CREATE PROCEDURE [Security].[sp_User_Login]
    @Username NVARCHAR(100),
    @PasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserID, u.RoleID, r.RoleName, u.Username, u.FullName, u.IsActive, u.CreatedAt
    FROM [Security].[Users] u
    INNER JOIN [Security].[Roles] r ON u.RoleID = r.RoleID
    WHERE u.Username = @Username AND u.PasswordHash = @PasswordHash AND u.IsActive = 1
END
GO

-- =============================================
-- 2. sp_User_GetAll
-- =============================================
IF OBJECT_ID('[Security].[sp_User_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_GetAll]
GO
CREATE PROCEDURE [Security].[sp_User_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserID, u.RoleID, r.RoleName, u.Username, u.FullName, u.IsActive, u.CreatedAt
    FROM [Security].[Users] u
    INNER JOIN [Security].[Roles] r ON u.RoleID = r.RoleID
    ORDER BY u.UserID
END
GO

-- =============================================
-- 3. sp_User_Add
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Add]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Add]
GO
CREATE PROCEDURE [Security].[sp_User_Add]
    @RoleID INT,
    @Username NVARCHAR(100),
    @PasswordHash NVARCHAR(256),
    @FullName NVARCHAR(200),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Security].[Users] (RoleID, Username, PasswordHash, FullName, IsActive)
    VALUES (@RoleID, @Username, @PasswordHash, @FullName, @IsActive);
    SELECT SCOPE_IDENTITY();
END
GO

-- =============================================
-- 4. sp_User_Update
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Update]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Update]
GO
CREATE PROCEDURE [Security].[sp_User_Update]
    @UserID INT,
    @RoleID INT,
    @Username NVARCHAR(100),
    @FullName NVARCHAR(200),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Security].[Users]
    SET RoleID = @RoleID, Username = @Username, FullName = @FullName, IsActive = @IsActive
    WHERE UserID = @UserID
END
GO

-- =============================================
-- 5. sp_User_Delete
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Delete]
GO
CREATE PROCEDURE [Security].[sp_User_Delete]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Security].[Users] WHERE UserID = @UserID
END
GO

-- =============================================
-- 6. sp_User_ResetPassword
-- =============================================
IF OBJECT_ID('[Security].[sp_User_ResetPassword]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_ResetPassword]
GO
CREATE PROCEDURE [Security].[sp_User_ResetPassword]
    @UserID INT,
    @NewPasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Security].[Users] SET PasswordHash = @NewPasswordHash WHERE UserID = @UserID
END
GO

-- =============================================
-- 7. sp_Role_GetAll
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_GetAll]
GO
CREATE PROCEDURE [Security].[sp_Role_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM [Security].[Roles] ORDER BY RoleName
END
GO

-- =============================================
-- 8. sp_Role_Add
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_Add]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_Add]
GO
CREATE PROCEDURE [Security].[sp_Role_Add]
    @RoleName NVARCHAR(100),
    @Description NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Security].[Roles] (RoleName, Description) VALUES (@RoleName, @Description);
    SELECT SCOPE_IDENTITY();
END
GO

-- =============================================
-- 9. sp_Role_Update
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_Update]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_Update]
GO
CREATE PROCEDURE [Security].[sp_Role_Update]
    @RoleID INT,
    @RoleName NVARCHAR(100),
    @Description NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Security].[Roles] SET RoleName = @RoleName, Description = @Description WHERE RoleID = @RoleID
END
GO

-- =============================================
-- 10. sp_Role_Delete (Deletes role + its permissions)
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_Delete]
GO
CREATE PROCEDURE [Security].[sp_Role_Delete]
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION
        DELETE FROM [Security].[RolePermissions] WHERE RoleID = @RoleID;
        DELETE FROM [Security].[Roles] WHERE RoleID = @RoleID;
    COMMIT TRANSACTION
END
GO

-- =============================================
-- 11. sp_Permission_GetByRole
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_GetByRole]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_GetByRole]
GO
CREATE PROCEDURE [Security].[sp_Permission_GetByRole]
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM [Security].[RolePermissions] WHERE RoleID = @RoleID
END
GO

-- =============================================
-- 12. sp_Permission_Save (Insert or Update)
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_Save]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_Save]
GO
CREATE PROCEDURE [Security].[sp_Permission_Save]
    @PermID INT,
    @RoleID INT,
    @FormName NVARCHAR(100),
    @CanAdd BIT,
    @CanEdit BIT,
    @CanDelete BIT,
    @CanView BIT,
    @CanPrint BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF @PermID > 0
    BEGIN
        UPDATE [Security].[RolePermissions]
        SET CanAdd = @CanAdd, CanEdit = @CanEdit, CanDelete = @CanDelete, CanView = @CanView, CanPrint = @CanPrint
        WHERE PermID = @PermID
    END
    ELSE
    BEGIN
        INSERT INTO [Security].[RolePermissions] (RoleID, FormName, CanAdd, CanEdit, CanDelete, CanView, CanPrint)
        VALUES (@RoleID, @FormName, @CanAdd, @CanEdit, @CanDelete, @CanView, @CanPrint)
    END
END
GO

-- =============================================
-- 13. sp_Permission_CanView
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_CanView]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_CanView]
GO
CREATE PROCEDURE [Security].[sp_Permission_CanView]
    @RoleID INT,
    @FormName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CanView FROM [Security].[RolePermissions] WHERE RoleID = @RoleID AND FormName = @FormName
END
GO

-- =============================================
-- 14. sp_Permission_Delete
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_Delete]
GO
CREATE PROCEDURE [Security].[sp_Permission_Delete]
    @PermID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Security].[RolePermissions] WHERE PermID = @PermID
END
GO

-- =============================================
-- 15. sp_License_Check
-- =============================================
IF OBJECT_ID('[Security].[sp_License_Check]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_License_Check]
GO
CREATE PROCEDURE [Security].[sp_License_Check]
    @MachineHWID NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS BIT) AS IsLicensed
    FROM [Security].[DeviceLicenses]
    WHERE MachineHWID = @MachineHWID AND IsActive = 1
END
GO


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


-- =============================================
-- Invoices Triggers (Inventory & Accounting)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- Trigger: trg_Invoice_Post
-- Handles Both Inventory Stock Updates AND Accounting Journal Entries
-- =============================================
IF OBJECT_ID('[Sales].[trg_Invoice_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_Invoice_Post];
GO

CREATE TRIGGER [Sales].[trg_Invoice_Post]
ON [Sales].[InvoiceHeader]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only proceed if IsPosted changed from 0 to 1
    IF UPDATE(IsPosted)
    BEGIN
        -- ==========================================================
        -- 1. INVENTORY UPDATES
        -- ==========================================================

        -- STEP A: Update AvgCostPrice BEFORE touching CurrentQty (weighted average formula)
        --   NewAvgCost = (OldQty * OldAvgCost + NewQty * BuyPrice) / (OldQty + NewQty)
        UPDATE S
        SET S.AvgCostPrice =
            CASE
                WHEN (S.CurrentQty + D.Quantity) > 0
                THEN (S.CurrentQty * ISNULL(S.AvgCostPrice, 0) + D.Quantity * D.UnitPrice)
                     / (S.CurrentQty + D.Quantity)
                ELSE D.UnitPrice
            END
        FROM [Inventory].[ProductStock] S
        INNER JOIN [Sales].[InvoiceDetails] D ON S.ProductID = D.ProductID
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0 
          AND i.InvType = 'Purchase' 
          AND S.WarehouseID = i.WarehouseID;

        -- STEP B: Increase CurrentQty (after AvgCostPrice is already updated)
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + D.Quantity
        FROM [Inventory].[ProductStock] S
        INNER JOIN [Sales].[InvoiceDetails] D ON S.ProductID = D.ProductID
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0 
          AND i.InvType = 'Purchase' 
          AND S.WarehouseID = i.WarehouseID;

        -- Missing Stock Records for Purchases (Insert if not exists - AvgCostPrice = UnitPrice)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity),
               SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0) -- weighted avg for first purchase
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0 
          AND i.InvType = 'Purchase'
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2 
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
          )
        GROUP BY D.ProductID, i.WarehouseID;

        -- Sales: Decrease Stock
        UPDATE S
        SET S.CurrentQty = S.CurrentQty - D.Quantity
        FROM [Inventory].[ProductStock] S
        INNER JOIN [Sales].[InvoiceDetails] D ON S.ProductID = D.ProductID
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0 
          AND i.InvType = 'Sales'
          AND S.WarehouseID = i.WarehouseID;

        -- Missing Stock Records for Sales (Insert negative if completely missing, to prevent failure)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty)
        SELECT D.ProductID, i.WarehouseID, -SUM(D.Quantity)
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0 
          AND i.InvType = 'Sales'
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2 
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
          )
        GROUP BY D.ProductID, i.WarehouseID;

        -- ==========================================================
        -- 2. ACCOUNTING UPDATES (JOURNAL ENTRIES)
        -- ==========================================================
        
        -- Get generic Accounts for fallback
        DECLARE @InventoryAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1), 
                                           (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13'));
        
        DECLARE @SalesAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1), 
                                       (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '41'));
                                       
        DECLARE @COGSAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5101'), 
                                      ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1),
                                             (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '51')));

        DECLARE @CustomerAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1), 
                                          (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'));

        DECLARE @VendorAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1), 
                                        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'));

        -- Ensure fallback accounts exist (create dummy if absolutely nothing found - though Setup_InitialAccounts should prevent this)

        DECLARE @InvoiceEntryMap TABLE (InvID INT, InvType NVARCHAR(20), EntryNo INT);

        INSERT INTO @InvoiceEntryMap (InvID, InvType, EntryNo)
        SELECT i.InvID, i.InvType, NEXT VALUE FOR [Accounting].[seq_EntryNo]
        FROM inserted i
        INNER JOIN deleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0;

        -- ----------------------------------------------------------------
        -- A. PURCHASE INVOICE ENTRIES
        -- ----------------------------------------------------------------
        
        -- Leg 1: Dr Inventory
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(w.AccountID, @InventoryAcc), -- Dynamically fetch Warehouse AccountID
            i.NetAmount,  -- Debit Inventory
            0,            
            N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE i.InvType = 'Purchase';

        -- Leg 2: Cr Vendor/Supplier
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(p.AccountID, @VendorAcc),  -- Dynamically fetch Partner's AccountID
            0,
            i.NetAmount, -- Credit Supplier
            N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Purchase';

        -- ----------------------------------------------------------------
        -- B. SALES INVOICE ENTRIES
        -- ----------------------------------------------------------------
        
        -- Sales Part 1: Revenue & Receivables
        -- Leg 1: Dr Customer
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(p.AccountID, @CustomerAcc), -- Dynamically fetch Partner's AccountID
            i.NetAmount,  -- Debit Customer
            0,
            N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Sales';

        -- Leg 2: Cr Sales Revenue
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            @SalesAcc,
            0,
            i.NetAmount, -- Credit Sales
            N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Sales';

        -- Sales Part 2: COGS & Inventory
        -- تحسب بمتوسط سعر التكلفة المرجح (الخاص بهذا المخزن) من ProductStock.AvgCostPrice
        ;WITH InvoiceCOGS AS (
            SELECT 
                d.InvID,
                SUM(s.AvgCostPrice * d.Quantity) AS TotalCOGS
            FROM [Sales].[InvoiceDetails] d
            INNER JOIN inserted i ON d.InvID = i.InvID
            LEFT JOIN [Inventory].[ProductStock] s 
                ON s.ProductID = d.ProductID 
                AND s.WarehouseID = i.WarehouseID
            GROUP BY d.InvID
        )
        -- Leg 3: Dr COGS - تكلفة البضاعة المباعة (يُجلب AccountID من حساب كود 5101)
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            @COGSAcc,        -- AccountID مجلوب من AccountCode = '5101' في ChartOfAccounts
            cogs.TotalCOGS,  -- Debit COGS (متوسط التكلفة * الكمية)
            0,
            N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
        WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

        -- Leg 4: Cr Inventory (المخزن - برقم الحساب الخاص بالمخزن)
        ;WITH InvoiceCOGS AS (
            SELECT 
                d.InvID,
                SUM(s.AvgCostPrice * d.Quantity) AS TotalCOGS
            FROM [Sales].[InvoiceDetails] d
            INNER JOIN inserted i ON d.InvID = i.InvID
            LEFT JOIN [Inventory].[ProductStock] s 
                ON s.ProductID = d.ProductID 
                AND s.WarehouseID = i.WarehouseID
            GROUP BY d.InvID
        )
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(w.AccountID, @InventoryAcc), -- AccountID الخاص بالمخزن
            0,
            cogs.TotalCOGS, -- Credit Inventory/Warehouse
            N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
        LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

        -- ==========================================================
        -- C. PAYMENT JOURNAL ENTRIES
        -- قيد السداد الجزئي عند الترحيل (إذا كان PaidAmount > 0 وتم اختيار حساب دفع)
        -- ==========================================================

        -- Purchase: Dr Vendor Account / Cr Cash Account (11xx)
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               ISNULL(p.AccountID, @VendorAcc),  -- Dr حساب المورد
               i.PaidAmount, 0,
               N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               i.PaymentAccountID, 0, i.PaidAmount,  -- Cr حساب الدفع المختار (نقدية)
               N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

        -- Sales: Dr Cash Account (11xx) / Cr Customer Account
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               i.PaymentAccountID, i.PaidAmount, 0,  -- Dr حساب الدفع المختار (نقدية)
               N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Sales' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               ISNULL(p.AccountID, @CustomerAcc), 0, i.PaidAmount,  -- Cr حساب العميل
               N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Sales' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

    END
END
GO


-- =============================================
-- Invoices Stored Procedures (Sales & Purchases)
-- =============================================

-- =============================================
-- Inventory Schema - Product Card Procedures
-- بطاقة الصنف (التحليلات التفصيلية للصنف)
-- =============================================

-- =============================================
-- 1. جلب ملخص بطاقة الصنف
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetSummary]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetSummary];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetSummary]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Balance           DECIMAL(18,2) = 0;
    DECLARE @AvgCost           DECIMAL(18,2) = 0;
    DECLARE @TotalInQty        DECIMAL(18,2) = 0;
    DECLARE @TotalInValue      DECIMAL(18,2) = 0;
    DECLARE @TotalOutQty       DECIMAL(18,2) = 0;
    DECLARE @TotalOutValue     DECIMAL(18,2) = 0;
    DECLARE @LastPurchasePrice DECIMAL(18,2) = 0;
    DECLARE @ProfitRate        DECIMAL(18,2) = 0;

    -- الرصيد الحالي
    SELECT @Balance = ISNULL(SUM(CurrentQty), 0)
    FROM [Inventory].[ProductStock]
    WHERE ProductID = @ProductID;

    -- إجمالي الوارد = فواتير الشراء (Purchase)
    SELECT
        @TotalInQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalInValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase';

    -- إجمالي الصادر = فواتير البيع (Sales)
    SELECT
        @TotalOutQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalOutValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Sales';

    -- آخر سعر شراء
    SELECT TOP 1 @LastPurchasePrice = ISNULL(d.UnitPrice, 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase'
    ORDER BY h.InvDate DESC, h.InvID DESC;

    -- متوسط سعر التكلفة
    IF @TotalInQty > 0
        SET @AvgCost = @TotalInValue / @TotalInQty;

    -- معدل الربح التقريبي
    IF @TotalOutQty > 0 AND @AvgCost > 0
    BEGIN
        DECLARE @TotalCostOfSales DECIMAL(18,2) = @TotalOutQty * @AvgCost;
        IF @TotalCostOfSales > 0
            SET @ProfitRate = ((@TotalOutValue - @TotalCostOfSales) / @TotalCostOfSales) * 100;
        ELSE
            SET @ProfitRate = 100;
    END

    SELECT
        @Balance            AS Balance,
        @AvgCost            AS AvgCost,
        @TotalInQty         AS TotalInQty,
        @TotalInValue       AS TotalInValue,
        @TotalOutQty        AS TotalOutQty,
        @TotalOutValue      AS TotalOutValue,
        @LastPurchasePrice  AS LastPurchasePrice,
        @ProfitRate         AS ProfitRate;
END
GO

-- =============================================
-- 2. جلب حركة الصنف (Server-Side Pagination)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetMovements]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetMovements];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetMovements]
    @ProductID   INT,
    @FilterType  NVARCHAR(10) = 'ALL',  -- 'ALL' | 'IN' | 'OUT'
    @PageNumber  INT          = 1,
    @PageSize    INT          = 15
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.InvID,
        h.ReferenceNo,
        h.InvDate,
        h.InvType,
        CASE
            WHEN h.InvType = 'Purchase' THEN 'IN'
            WHEN h.InvType = 'Sales'    THEN 'OUT'
            ELSE 'OTHER'
        END AS MovementDirection,
        CASE
            WHEN h.InvType = 'Purchase' THEN N'فاتورة شراء'
            WHEN h.InvType = 'Sales'    THEN N'فاتورة بيع'
            ELSE h.InvType
        END AS InvTypeName,
        d.Quantity,
        d.UnitPrice,
        d.TotalPrice,
        p.PartnerName,
        -- إجمالي الصفوف المطابقة (بدون OFFSET) لحساب عدد الصفحات
        COUNT(*) OVER () AS TotalCount
    FROM [Sales].[InvoiceDetails]  d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID     = h.InvID
    LEFT  JOIN [Sales].[Partners]      p ON h.PartnerID = p.PartnerID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND (
            @FilterType = 'ALL'
         OR (@FilterType = 'IN'  AND h.InvType = 'Purchase')
         OR (@FilterType = 'OUT' AND h.InvType = 'Sales')
          )
    ORDER BY h.InvDate DESC, h.InvID DESC
    OFFSET  (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- 3. بيانات الرسم البياني (تجميع يومي مع فلتر الفترة)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetChartData]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetChartData];
GO
create PROCEDURE [Inventory].[sp_ProductCard_GetChartData] 
    @ProductID  INT,
    @MonthsBack INT = 12
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FromDate DATE = DATEADD(MONTH, -@MonthsBack, CAST(GETDATE() AS DATE));

    IF @MonthsBack <= 1
    BEGIN
        -- عرض يومي إذا كان شهر أو أقل
        SELECT
            CAST(h.InvDate AS DATE) AS MovementDate,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE 0           END) AS DailyInQty,
            SUM(CASE WHEN h.InvType = 'Sales'    THEN  d.Quantity ELSE 0           END) AS DailyOutQty,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE -d.Quantity END) AS NetDayMovement
        FROM [Sales].[InvoiceDetails]  d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted  = 1
          AND CAST(h.InvDate AS DATE) >= @FromDate
        GROUP BY CAST(h.InvDate AS DATE)
        ORDER BY CAST(h.InvDate AS DATE) ASC;
    END
    ELSE
    BEGIN
        -- عرض شهري (مجمّع بآخر يوم في الشهر لتسهيل الفرز وعرض التاريخ) إذا كان أكثر من شهر
        SELECT
            EOMONTH(h.InvDate) AS MovementDate,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE 0           END) AS DailyInQty,
            SUM(CASE WHEN h.InvType = 'Sales'    THEN  d.Quantity ELSE 0           END) AS DailyOutQty,
            SUM(CASE WHEN h.InvType = 'Purchase' THEN  d.Quantity ELSE -d.Quantity END) AS NetDayMovement
        FROM [Sales].[InvoiceDetails]  d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted  = 1
          AND CAST(h.InvDate AS DATE) >= @FromDate
        GROUP BY EOMONTH(h.InvDate)
        ORDER BY EOMONTH(h.InvDate) ASC;
    END
END
go
 

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
    SELECT * FROM [Sales].[InvoiceHeader] WHERE InvID = @InvID;
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
        p.Barcode
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
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



-- Add ReferenceNo (Supplier Invoice Number) to InvoiceHeader
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('Sales.InvoiceHeader') AND name = 'ReferenceNo'
)
BEGIN
    ALTER TABLE Sales.InvoiceHeader ADD ReferenceNo NVARCHAR(50) NULL;
END
GO

-- Add CreatedAt (Addition Date) to InvoiceHeader
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('Sales.InvoiceHeader') AND name = 'CreatedAt'
)
BEGIN
    ALTER TABLE Sales.InvoiceHeader ADD CreatedAt DATETIME DEFAULT GETDATE() WITH VALUES;
END
GO

-- Create Sequence for Sales Invoices
IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = 'SalesInvoiceSeq' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE SEQUENCE Sales.SalesInvoiceSeq
    AS INT
    START WITH 1001
    INCREMENT BY 1;
END
GO

-- Update sp_Invoice_Save to automatically generate sequence for sales invoices


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
        SELECT CAST(SCOPE_IDENTITY() AS INT) AS InvID;
    END
    ELSE
    BEGIN
        UPDATE [Sales].[InvoiceHeader] 
        SET InvType = @InvType, InvDate = @InvDate, PartnerID = @PartnerID, WarehouseID = @WarehouseID, 
            TotalAmount = @TotalAmount, Discount = @Discount, NetAmount = @NetAmount, 
            PaidAmount = @PaidAmount, Remainder = @Remainder, UserID = @UserID, Notes = @Notes, IsPosted = @IsPosted, ReferenceNo = @ReferenceNo
        WHERE InvID = @InvID;
        SELECT @InvID AS InvID;
    END
END
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
    SELECT * FROM [Sales].[InvoiceHeader] WHERE InvID = @InvID;
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
        p.Barcode
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
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

-- =============================================
-- 9. sp_Invoice_GetFiltered  (Dashboard List with Pagination)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetFiltered]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetFiltered];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetFiltered]
    @InvType    NVARCHAR(20)  = NULL,
    @DateFrom   DATE          = NULL,
    @DateTo     DATE          = NULL,
    @IsPosted   BIT           = NULL,
    @SearchText NVARCHAR(100) = NULL,
    @PageNumber INT           = 0,      -- Zero-based page index
    @PageSize   INT           = 20
AS
BEGIN
    SET NOCOUNT ON;

    -- Result Set 1: Paged invoice rows
    SELECT
        h.InvID,
        h.InvType,
        CONVERT(DATE, h.InvDate) AS InvDate,
        h.PartnerID,
        ISNULL(p.PartnerName, N'—')   AS PartnerName,
        h.WarehouseID,
        ISNULL(w.WarehouseName, N'—') AS WarehouseName,
        h.TotalAmount,
        h.Discount,
        h.NetAmount,
        h.PaidAmount,
        h.Remainder,
        h.IsPosted,
        h.ReferenceNo,
        h.Notes
    FROM   [Sales].[InvoiceHeader]    h
    LEFT JOIN [Sales].[Partners]      p ON p.PartnerID   = h.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON w.WarehouseID = h.WarehouseID
    WHERE
        (@InvType    IS NULL OR h.InvType  = @InvType)
        AND (@DateFrom   IS NULL OR CONVERT(DATE, h.InvDate) >= @DateFrom)
        AND (@DateTo     IS NULL OR CONVERT(DATE, h.InvDate) <= @DateTo)
        AND (@IsPosted   IS NULL OR h.IsPosted = @IsPosted)
        AND (@SearchText IS NULL OR
             p.PartnerName LIKE '%' + @SearchText + '%'
          OR CAST(h.InvID AS NVARCHAR) LIKE '%' + @SearchText + '%'
          OR h.ReferenceNo   LIKE '%' + @SearchText + '%')
    ORDER BY h.InvID DESC
    OFFSET (@PageNumber * @PageSize) ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- Result Set 2: Total count (for pagination controls)
    SELECT COUNT(*) AS TotalCount
    FROM   [Sales].[InvoiceHeader]    h
    LEFT JOIN [Sales].[Partners]      p ON p.PartnerID = h.PartnerID
    WHERE
        (@InvType    IS NULL OR h.InvType  = @InvType)
        AND (@DateFrom   IS NULL OR CONVERT(DATE, h.InvDate) >= @DateFrom)
        AND (@DateTo     IS NULL OR CONVERT(DATE, h.InvDate) <= @DateTo)
        AND (@IsPosted   IS NULL OR h.IsPosted = @IsPosted)
        AND (@SearchText IS NULL OR
             p.PartnerName LIKE '%' + @SearchText + '%'
          OR CAST(h.InvID AS NVARCHAR) LIKE '%' + @SearchText + '%'
          OR h.ReferenceNo   LIKE '%' + @SearchText + '%');
END
GO

-- =============================================
-- 10. sp_Invoice_GetDashboardStats  (4 KPI cards)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetDashboardStats]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetDashboardStats];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetDashboardStats]
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(CASE WHEN InvType = 'Sales'    THEN 1 END)            AS TotalSalesCount,
        ISNULL(SUM(CASE WHEN InvType = 'Sales'    THEN NetAmount END), 0) AS TotalSalesAmount,
        ISNULL(SUM(CASE WHEN InvType = 'Sales'    THEN Remainder END), 0) AS SalesRemainder,
        COUNT(CASE WHEN InvType = 'Purchase' THEN 1 END)            AS TotalPurchaseCount,
        ISNULL(SUM(CASE WHEN InvType = 'Purchase' THEN NetAmount END), 0) AS TotalPurchaseAmount,
        ISNULL(SUM(CASE WHEN InvType = 'Purchase' THEN Remainder END), 0) AS PurchaseRemainder,
        COUNT(*) AS TotalInvoices
    FROM [Sales].[InvoiceHeader]
    WHERE IsPosted = 1
      AND (@DateFrom IS NULL OR CONVERT(DATE, InvDate) >= @DateFrom)
      AND (@DateTo   IS NULL OR CONVERT(DATE, InvDate) <= @DateTo);
END
GO

-- =============================================
-- 11. sp_Invoice_AddPayment  (payment on posted invoice)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_AddPayment]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_AddPayment];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_AddPayment]
    @InvID            INT,
    @PaymentAmount    DECIMAL(18,2),
    @PaymentAccountID INT,
    @UserID           INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @InvType   NVARCHAR(20), @PartnerID INT,
                @Remainder DECIMAL(18,2), @IsPosted  BIT;

        SELECT @InvType   = InvType,
               @PartnerID = PartnerID,
               @Remainder = Remainder,
               @IsPosted  = IsPosted
        FROM [Sales].[InvoiceHeader]
        WHERE InvID = @InvID;

        IF @IsPosted = 0
        BEGIN RAISERROR(N'لا يمكن إضافة سداد لفاتورة غير مرحّلة', 16, 1); RETURN; END

        IF @PaymentAmount <= 0 OR @PaymentAmount > @Remainder
        BEGIN RAISERROR(N'مبلغ السداد غير صحيح أو يتجاوز المتبقي', 16, 1); RETURN; END

        -- 1. Update header amounts
        UPDATE [Sales].[InvoiceHeader]
        SET PaidAmount = PaidAmount + @PaymentAmount,
            Remainder  = Remainder  - @PaymentAmount
        WHERE InvID = @InvID;

        -- 2. Get partner account
        DECLARE @PartnerAccountID INT;
        SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

        -- 3. Journal entry (two complementary legs)
        DECLARE @EntryNo   INT           = NEXT VALUE FOR [Accounting].[seq_EntryNo];
        DECLARE @EntryDate DATE          = CAST(GETDATE() AS DATE);
        DECLARE @Desc      NVARCHAR(255) = N'سداد إضافي - فاتورة رقم ' + CAST(@InvID AS NVARCHAR);

        IF @InvType = 'Sales'
        BEGIN
            -- Dr Cash  /  Cr Customer
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount,       CreditAmount,      Description, UserID)
            VALUES
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID, @PaymentAmount, 0,                @Desc, @UserID),
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  0,               @PaymentAmount, @Desc, @UserID);
        END
        ELSE -- Purchase
        BEGIN
            -- Dr Vendor  /  Cr Cash
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount,       CreditAmount,      Description, UserID)
            VALUES
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  @PaymentAmount, 0,               @Desc, @UserID),
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID,  0,              @PaymentAmount,  @Desc, @UserID);
        END

        COMMIT TRANSACTION;
        SELECT 1 AS Success;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================
-- ⚡ PERFORMANCE INDEXES — InvoiceHeader
-- =============================================

-- Index 1: Dashboard Stats (sp_Invoice_GetDashboardStats)
-- يُغطّي COUNT + SUM بدون Full Table Scan
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_InvoiceHeader_Stats'
      AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
CREATE INDEX IX_InvoiceHeader_Stats
    ON [Sales].[InvoiceHeader] (IsPosted, InvType)
    INCLUDE (NetAmount, Remainder);
GO

-- Index 2: Dashboard Filter List (sp_Invoice_GetFiltered)
-- يُسرّع الفلترة حسب النوع + الحالة + التاريخ
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_InvoiceHeader_FilteredList'
      AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
CREATE INDEX IX_InvoiceHeader_FilteredList
    ON [Sales].[InvoiceHeader] (InvType, IsPosted, InvDate DESC)
    INCLUDE (PartnerID, WarehouseID, TotalAmount, Discount, NetAmount, PaidAmount, Remainder, ReferenceNo);
GO

-- Index 3: Partner lookup (JOIN مع Partners)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_InvoiceHeader_PartnerID'
      AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
CREATE INDEX IX_InvoiceHeader_PartnerID
    ON [Sales].[InvoiceHeader] (PartnerID);
GO

-- =============================================
-- ⚡ PERFORMANCE INDEXES — Inventory.Products
-- =============================================

-- Index 1: GetAll - الأصناف النشطة (sp_Product_GetAll)
-- يُغطّي WHERE IsActive = 1 ORDER BY ProductID
-- يتجنّب Full Table Scan عند جلب كل الأصناف
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Products_IsActive_ProductID'
      AND object_id = OBJECT_ID('[Inventory].[Products]'))
CREATE INDEX IX_Products_IsActive_ProductID
    ON [Inventory].[Products] (IsActive, ProductID)
    INCLUDE (ProductName, ProductNameEn, Barcode, CategoryID, UnitID, PurchasePrice, SalePrice, AlertQty);
GO

-- Index 2: GetByBarcode (sp_Product_GetByBarcode)
-- بحث سريع بالباركود مع فلتر IsActive
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Products_Barcode_IsActive'
      AND object_id = OBJECT_ID('[Inventory].[Products]'))
CREATE INDEX IX_Products_Barcode_IsActive
    ON [Inventory].[Products] (Barcode, IsActive)
    INCLUDE (ProductID, ProductName, ProductNameEn, CategoryID, UnitID, PurchasePrice, SalePrice, AlertQty);
GO

-- Index 3: Search by Name (sp_Product_Search)
-- يُسرّع بحث LIKE '%...%' على اسم الصنف العربي
-- ملاحظة: LIKE '%text%' يستفيد من Index Scan أكثر من Seek
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Products_ProductName_IsActive'
      AND object_id = OBJECT_ID('[Inventory].[Products]'))
CREATE INDEX IX_Products_ProductName_IsActive
    ON [Inventory].[Products] (ProductName, IsActive)
    INCLUDE (ProductID, ProductNameEn, Barcode, CategoryID, UnitID, PurchasePrice, SalePrice, AlertQty);
GO

-- Index 4: JOIN مع Settings.Categories و Settings.Units
-- يُسرّع عمليات LEFT JOIN في كل استعلامات الأصناف
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Products_CategoryID_UnitID'
      AND object_id = OBJECT_ID('[Inventory].[Products]'))
CREATE INDEX IX_Products_CategoryID_UnitID
    ON [Inventory].[Products] (CategoryID, UnitID)
    INCLUDE (ProductID, IsActive);
GO

-- =============================================
-- 15. Stored Procedures - Product Card Details (بطاقة الصنف)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetSummary]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetSummary];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetSummary]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Balance           DECIMAL(18,2) = 0;
    DECLARE @AvgCost           DECIMAL(18,2) = 0;
    DECLARE @TotalInQty        DECIMAL(18,2) = 0;
    DECLARE @TotalInValue      DECIMAL(18,2) = 0;
    DECLARE @TotalOutQty       DECIMAL(18,2) = 0;
    DECLARE @TotalOutValue     DECIMAL(18,2) = 0;
    DECLARE @LastPurchasePrice DECIMAL(18,2) = 0;
    DECLARE @ProfitRate        DECIMAL(18,2) = 0;

    -- الرصيد الحالي
    SELECT @Balance = ISNULL(SUM(CurrentQty), 0)
    FROM [Inventory].[ProductStock]
    WHERE ProductID = @ProductID;

    -- إجمالي الوارد = فواتير الشراء (Purchase)
    SELECT
        @TotalInQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalInValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase';

    -- إجمالي الصادر = فواتير البيع (Sales)
    SELECT
        @TotalOutQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalOutValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Sales';

    -- آخر سعر شراء
    SELECT TOP 1 @LastPurchasePrice = ISNULL(d.UnitPrice, 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase'
    ORDER BY h.InvDate DESC, h.InvID DESC;

    -- متوسط سعر التكلفة
    IF @TotalInQty > 0
        SET @AvgCost = @TotalInValue / @TotalInQty;

    -- معدل الربح التقريبي
    IF @TotalOutQty > 0 AND @AvgCost > 0
    BEGIN
        DECLARE @TotalCostOfSales DECIMAL(18,2) = @TotalOutQty * @AvgCost;
        IF @TotalCostOfSales > 0
            SET @ProfitRate = ((@TotalOutValue - @TotalCostOfSales) / @TotalCostOfSales) * 100;
        ELSE
            SET @ProfitRate = 100;
    END

    SELECT
        @Balance            AS Balance,
        @AvgCost            AS AvgCost,
        @TotalInQty         AS TotalInQty,
        @TotalInValue       AS TotalInValue,
        @TotalOutQty        AS TotalOutQty,
        @TotalOutValue      AS TotalOutValue,
        @LastPurchasePrice  AS LastPurchasePrice,
        @ProfitRate         AS ProfitRate;
END
GO

-- =============================================
-- 2. جلب حركة الصنف (Server-Side Pagination)
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetMovements]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetMovements];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetMovements]
    @ProductID   INT,
    @FilterType  NVARCHAR(10) = 'ALL',  -- 'ALL' | 'IN' | 'OUT'
    @PageNumber  INT          = 1,
    @PageSize    INT          = 15
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.InvID,
        h.ReferenceNo,
        h.InvDate,
        h.InvType,
        CASE
            WHEN h.InvType = 'Purchase' THEN 'IN'
            WHEN h.InvType = 'Sales'    THEN 'OUT'
            ELSE 'OTHER'
        END AS MovementDirection,
        CASE
            WHEN h.InvType = 'Purchase' THEN N'فاتورة شراء'
            WHEN h.InvType = 'Sales'    THEN N'فاتورة بيع'
            ELSE h.InvType
        END AS InvTypeName,
        d.Quantity,
        d.UnitPrice,
        d.TotalPrice,
        p.PartnerName,
        COUNT(*) OVER () AS TotalCount
    FROM [Sales].[InvoiceDetails]  d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID     = h.InvID
    LEFT  JOIN [Sales].[Partners]      p ON h.PartnerID = p.PartnerID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND (
            @FilterType = 'ALL'
         OR (@FilterType = 'IN'  AND h.InvType = 'Purchase')
         OR (@FilterType = 'OUT' AND h.InvType = 'Sales')
          )
    ORDER BY h.InvDate DESC, h.InvID DESC
    OFFSET  (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO


-- =============================================
-- ⚡ PERFORMANCE INDEXES — Product Card (بطاقة الصنف)
-- =============================================
-- تحليل الاستعلامات المستخدمة في:
--   sp_ProductCard_GetSummary  /  sp_ProductCard_GetMovements  /  sp_ProductCard_GetChartData
-- الجداول المستهدفة: Sales.InvoiceDetail, Sales.InvoiceHeader, Inventory.ProductStock

-- ─── INDEX 1: InvoiceDetail → ProductID  (الأهم!) ─────────────────────────────
-- جميع الـ SPs تفلتر بـ d.ProductID = @ProductID
-- بدون هذا الـ Index → Full Table Scan على InvoiceDetail في كل مرة
-- نُضمّن InvID لتفادي Key Lookup عند JOIN مع InvoiceHeader
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_InvoiceDetail_ProductID'
      AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
CREATE INDEX IX_InvoiceDetail_ProductID
    ON [Sales].[InvoiceDetails] (ProductID)
    INCLUDE (InvID, Quantity, UnitPrice, TotalPrice);
GO

-- ─── INDEX 2: InvoiceHeader → (IsPosted, InvType, InvDate DESC) ────────────────
-- يُغطّي WHERE h.IsPosted = 1 AND h.InvType IN (...)
-- يُسرّع ORDER BY h.InvDate DESC في GetSummary (آخر سعر شراء)
-- يُسرّع GROUP BY CAST(h.InvDate AS DATE) في GetChartData
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_InvoiceHeader_IsPosted_InvType_InvDate'
      AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
CREATE INDEX IX_InvoiceHeader_IsPosted_InvType_InvDate
    ON [Sales].[InvoiceHeader] (IsPosted, InvType, InvDate DESC)
    INCLUDE (InvID, PartnerID, ReferenceNo);
GO

-- ─── INDEX 3: ProductStock → ProductID ────────────────────────────────────────
-- يُسرّع SELECT SUM(Quantity) في GetSummary (الرصيد الحالي)
-- يمنع Full Scan على جدول الأرصدة عند تعدد المستودعات
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_ProductStock_ProductID'
      AND object_id = OBJECT_ID('[Inventory].[ProductStock]'))
CREATE INDEX IX_ProductStock_ProductID
    ON [Inventory].[ProductStock] (ProductID)
    INCLUDE (WarehouseID, CurrentQty, AvgCostPrice);
GO

-- ─── INDEX 4: InvoiceDetail → (InvID, ProductID) Composite ────────────────────
-- يُحسّن الـ JOIN في الاتجاه العكسي: من InvoiceHeader → InvoiceDetail
-- مفيد جداً عندما يبدأ Query Optimizer بجدول الهيدر بدل الديتيل
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_InvoiceDetail_InvID_ProductID'
      AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
CREATE INDEX IX_InvoiceDetail_InvID_ProductID
    ON [Sales].[InvoiceDetails] (InvID, ProductID)
    INCLUDE (Quantity, UnitPrice,  TotalPrice );
GO

-- ─── INDEX 5: Partners → PartnerID (Covering) ──────────────────────────────────
-- يُسرّع LEFT JOIN مع Settings.Partners في GetMovements
-- يتجنب Lookup على جدول الشركاء عند كثرة السجلات
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_Partners_PartnerID_Name'
      AND object_id = OBJECT_ID('[sales].[Partners]'))
CREATE INDEX IX_Partners_PartnerID_Name
    ON sales.[Partners] (PartnerID)
    INCLUDE (PartnerName);
GO

