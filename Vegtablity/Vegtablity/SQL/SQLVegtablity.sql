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
go
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
go

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
go
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
ON Sales.Partners
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
    SELECT p.PartnerID, p.PartnerName, p.PartnerType, p.Phone, p.Address, 
	  ISNULL((
            SELECT SUM(JE.DebitAmount - JE.CreditAmount) 
            FROM [Accounting].[JournalEntries] JE 
            WHERE JE.AccountID = p.AccountID
        ), 0) AS CurrentBalance,
		 p.IsActive, p.AccountID,
		 c.AccountCode
    FROM [Sales].[Partners] p
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON p.AccountID = c.AccountID
    WHERE p.IsActive = 1 AND (@PartnerType = 'All' OR p.PartnerType = @PartnerType)
    ORDER BY p.PartnerID;
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
        PurchasePrice DECIMAL(18, 3) DEFAULT 0,
        SalePrice DECIMAL(18, 3) DEFAULT 0,
        AlertQty DECIMAL(18, 2) DEFAULT 0,
        IsActive BIT DEFAULT 1,
        FOREIGN KEY (CategoryID) REFERENCES [Settings].[Categories](CatID),
        FOREIGN KEY (UnitID) REFERENCES [Settings].[Units](UnitID)
    );
END
go


IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ProductStock' AND schema_id = SCHEMA_ID('Inventory'))
BEGIN
    CREATE TABLE [Inventory].[ProductStock] (
        StockID INT PRIMARY KEY IDENTITY(1,1),
        ProductID INT NOT NULL,
        WarehouseID INT NOT NULL,
        CurrentQty DECIMAL(18, 2) DEFAULT 0,
        AvgCostPrice DECIMAL(18, 3) DEFAULT 0,   -- متوسط سعر التكلفة المرجح لكل مخزن
        FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID),
        FOREIGN KEY (WarehouseID) REFERENCES [Settings].[Warehouses](WarehouseID),
        UNIQUE(ProductID, WarehouseID)
    );
END
go
-- Add AvgCostPrice to existing ProductStock table if column doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Inventory].[ProductStock]') AND name = 'AvgCostPrice')
BEGIN
    ALTER TABLE [Inventory].[ProductStock]
    ADD AvgCostPrice DECIMAL(18, 2) DEFAULT 0;
END
go
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
        TotalAmount DECIMAL(18, 3) DEFAULT 0,
        Discount DECIMAL(18, 3) DEFAULT 0,
        NetAmount DECIMAL(18, 3) DEFAULT 0,
        PaidAmount DECIMAL(18, 3) DEFAULT 0,
        Remainder DECIMAL(18, 3) DEFAULT 0,
        UserID INT,
        Notes NVARCHAR(255),
        IsPosted BIT DEFAULT 0,
        PaymentAccountID INT NULL,   -- حساب طريقة الدفع (نقدية 11xx)
        FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID),
        FOREIGN KEY (WarehouseID) REFERENCES [Settings].[Warehouses](WarehouseID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END
go
-- Add PaymentAccountID to existing InvoiceHeader table if column doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Sales].[InvoiceHeader]') AND name = 'PaymentAccountID')
BEGIN
    ALTER TABLE [Sales].[InvoiceHeader]
    ADD PaymentAccountID INT NULL;
END
go
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'InvoiceDetails' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    create TABLE [Sales].[InvoiceDetails] (
        DetID INT PRIMARY KEY IDENTITY(1,1),
        InvID INT NOT NULL,
        ProductID INT NOT NULL,
		ReferenceNo nvarchar null,
        UnitPrice DECIMAL(18, 3) DEFAULT 0,
        Quantity DECIMAL(18, 2) DEFAULT 1,
        TotalPrice DECIMAL(18, 3) DEFAULT 0, 
        CostPrice DECIMAL(18, 3) DEFAULT 0, 
        FOREIGN KEY (InvID) REFERENCES [Sales].[InvoiceHeader](InvID) ON DELETE CASCADE,
        FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID)
    );
END
go
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
        Amount DECIMAL(18, 3) NOT NULL,
        Description NVARCHAR(255),
        PaymentMethod NVARCHAR(20) DEFAULT 'Cash', 
        UserID INT,
        IsPosted BIT DEFAULT 0,
        FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID),
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END

go

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
        DebitAmount DECIMAL(18, 3) DEFAULT 0,
        CreditAmount DECIMAL(18, 3) DEFAULT 0,
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
    @Amount DECIMAL(18,3),
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
        UnifiedPartnerSearch BIT NOT NULL DEFAULT 1,
        CurrencySymbol NVARCHAR(100) DEFAULT N'د.ك',
        UseDetailedInvoiceDesign BIT NOT NULL DEFAULT 0,
        UseCustomInvoiceDesign BIT NOT NULL DEFAULT 0,
        ProductionMode BIT NOT NULL DEFAULT 0,
        EnableDailyOrders BIT NOT NULL DEFAULT 0,
        DeliverySystemMode NVARCHAR(50) NULL DEFAULT NULL,
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
        TotalAmount DECIMAL(18, 3) DEFAULT 0,
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
    @TotalAmount DECIMAL(18, 3),
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
            T.c.value('@Debit', 'DECIMAL(18,3)'),
            T.c.value('@Credit', 'DECIMAL(18,3)'),
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

-- 4. Trigger: ترحيل وإلغاء ترحيل القيد اليدوي تلقائياً عند تغيير IsPosted
IF OBJECT_ID('[Accounting].[trg_JournalHeader_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_JournalHeader_Post];
GO

CREATE TRIGGER [Accounting].[trg_JournalHeader_Post]
ON [Accounting].[JournalHeader]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. حالة إلغاء الترحيل (UNPOSTING: IsPosted 1 -> 0): حذف القيد من [Accounting].[JournalEntries]
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted del ON JE.ReferenceID = del.JID AND JE.ReferenceType = 'Manual'
    INNER JOIN inserted ins ON ins.JID = del.JID
    WHERE del.IsPosted = 1 AND ins.IsPosted = 0;

    -- 2. حالة التعديل على قيد مرحل (IsPosted 1 -> 1 مع التغيير): حذف القيود القديمة
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted del ON JE.ReferenceID = del.JID AND JE.ReferenceType = 'Manual'
    INNER JOIN inserted ins ON ins.JID = del.JID
    WHERE del.IsPosted = 1 AND ins.IsPosted = 1
      AND (del.JDate <> ins.JDate OR ISNULL(del.Description,'') <> ISNULL(ins.Description,'') OR del.TotalAmount <> ins.TotalAmount);

    -- 3. حالة الترحيل (POSTING: 0 -> 1 أو Re-Post): إدخال القيود في [Accounting].[JournalEntries]
    INSERT INTO [Accounting].[JournalEntries] (
        EntryNo, 
        EntryDate, 
        ReferenceType, 
        ReferenceID, 
        AccountID, 
        DebitAmount, 
        CreditAmount, 
        Description, 
        UserID
    )
    SELECT 
        ins.JournalNo,
        ins.JDate,
        'Manual',
        ins.JID,
        jd.AccountID,
        jd.Debit,
        jd.Credit,
        ISNULL(jd.Notes, ins.Description),
        ins.UserID
    FROM inserted ins
    JOIN [Accounting].[JournalDetails] jd ON ins.JID = jd.JID
    LEFT JOIN deleted del ON del.JID = ins.JID
    WHERE ins.IsPosted = 1
      AND (
          ISNULL(del.IsPosted, 0) = 0 -- الترحيل من جديد (0 -> 1)
          OR (del.IsPosted = 1 AND (del.JDate <> ins.JDate OR ISNULL(del.Description,'') <> ISNULL(ins.Description,'') OR del.TotalAmount <> ins.TotalAmount)) -- إعادة الترحيل عند التعديل
      );
END
GO

-- 4.1 Trigger: حذف القيود من [Accounting].[JournalEntries] عند حذف رأس القيد اليدوي
IF OBJECT_ID('[Accounting].[trg_JournalHeader_Delete]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_JournalHeader_Delete];
GO

CREATE TRIGGER [Accounting].[trg_JournalHeader_Delete]
ON [Accounting].[JournalHeader]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Accounting].[JournalEntries]
    WHERE ReferenceType = 'Manual' 
      AND ReferenceID IN (SELECT JID FROM deleted);
END
GO

-- 4.2 إجراء ترحيل القيد اليدوي لجدول الحركات العام
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Post]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Post];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Post]
    @JID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID)
    BEGIN
        RAISERROR(N'القيد غير موجود', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 1)
    BEGIN
        RAISERROR(N'القيد مرحّل بالفعل', 16, 1);
        RETURN;
    END

    -- تحديث IsPosted يُفعّل الـ Trigger تلقائياً لإنشاء القيود
    UPDATE [Accounting].[JournalHeader] SET IsPosted = 1 WHERE JID = @JID;
END
GO

-- 4.3 إجراء إلغاء ترحيل القيد اليدوي (حذف القيود من JournalEntries وإرجاع الحالة إلى غير مرحل)
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Unpost]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Unpost];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Unpost]
    @JID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID)
    BEGIN
        RAISERROR(N'القيد غير موجود', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 0)
    BEGIN
        RAISERROR(N'القيد غير مرحّل بالأساس', 16, 1);
        RETURN;
    END

    -- تحديث IsPosted يُفعّل الـ Trigger تلقائياً لحذف القيد من JournalEntries
    UPDATE [Accounting].[JournalHeader] SET IsPosted = 0 WHERE JID = @JID;
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

-- 5.1 جلب القيود اليدوية مصفحة (Pagination)
IF OBJECT_ID('[Accounting].[sp_JournalEntry_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_GetPaged];
GO
CREATE PROCEDURE [Accounting].[sp_JournalEntry_GetPaged]
    @PageIndex INT = 1,
    @PageSize INT = 20,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- الإجمالي الأقصى للقيود اليدوية
    SELECT @TotalCount = COUNT(1)
    FROM [Accounting].[JournalHeader]
    WHERE ReferenceType IN ('Manual', 'YearEndClose');

    -- جلب صفحة القيود المطلوبة
    SELECT JID, JournalNo, JDate, Description, TotalAmount, IsPosted, ReferenceType
    FROM [Accounting].[JournalHeader]
    WHERE ReferenceType IN ('Manual', 'YearEndClose')
    ORDER BY JID DESC
    OFFSET (@PageIndex - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
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
        Debit DECIMAL(18, 3) DEFAULT 0,
        Credit DECIMAL(18, 3) DEFAULT 0,
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
    DECLARE @AssetsID INT, @LiabilitiesID INT, @EquityID INT, @RevenueID INT, @ExpensesID INT,@profit int ,@banckandcash int,@costcode int,@firstbalance int ,@capital int ,@RevenueIDchild int ,@Customers int;

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
        VALUES ('4', N'الايرادات', 'Revenue', 0, 0);
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
     SELECT @Customers = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '1201')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('1201', N'مبيعات مباشره', @Customers, 'Assets', 2, 1);

    IF NOT EXISTS (SELECT 1 FROM [Sales].[Partners] WHERE PartnerName = N'سند مباشر')
    BEGIN
               INSERT INTO [Sales].[Partners] ( PartnerName, PartnerType, Phone, Address, CurrentBalance, IsActive, AccountID)
        VALUES ( N'سند مباشر', 'Other', NULL, NULL, 0.00, 1, (SELECT AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '1201'));
       END

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
        VALUES ('41', N'إيرادات المتنوعه', @RevenueID, 'Revenue', 1, 0);
		  SELECT @RevenueIDchild = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '41';

     -- 4. تحت الإيرادات (Revenues)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '411')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('411', N'إيرادات المبيعات', @RevenueIDchild, 'Revenue', 2, 1);
		 
   -- 4. تحت الإيرادات (Revenues)
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '412')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('412', N'إيرادات اخري', @RevenueIDchild, 'Revenue', 2, 1);
   
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

    -- 6. مصروف الهالك والتوالف
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '64')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('64', N'مصروف الهالك والتوالف', @ExpensesID, 'Expenses', 1, 0);

    DECLARE @WastageExpID INT;
    SELECT @WastageExpID = AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '64';

    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '6401')
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES ('6401', N'هالك وتوالف بضاعة', @WastageExpID, 'Expenses', 2, 1);

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
create PROCEDURE [Security].[sp_License_Check]
    @MachineHWID NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT CAST(CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS BIT) AS IsLicensed
    FROM [Security].[DeviceLicenses]
    WHERE MachineHWID = @MachineHWID 
      AND IsActive = 1 
      -- هذا هو السطر المهم الذي يتحقق إما من أن تاريخ الانتهاء مفتوح (NULL) 
      -- أو أن تاريخ الانتهاء ما زال أكبر من أو يساوي تاريخ اليوم (GETDATE)
      AND (ExpiryDate IS NULL OR CAST(ExpiryDate AS DATE) >= CAST(GETDATE() AS DATE))
END


-- =============================================
-- Inventory Schema - Stored Procedures
-- الأصناف (Products)
-- مع Soft Delete (IsActive)
-- =============================================

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
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
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
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
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
    @PurchasePrice DECIMAL(18,3) = 0,
    @SalePrice DECIMAL(18,3) = 0,
    @AlertQty DECIMAL(18,2) = 0,
    @ProductType INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @ProductID = 0
    BEGIN
        INSERT INTO [Inventory].[Products] 
            (ProductName, ProductNameEn, Barcode, CategoryID, UnitID, PurchasePrice, SalePrice, AlertQty, IsActive, ProductType)
        VALUES 
            (@ProductName, @ProductNameEn, @Barcode, @CategoryID, @UnitID, @PurchasePrice, @SalePrice, @AlertQty, 1, ISNULL(@ProductType, 1));
        SELECT SCOPE_IDENTITY() AS ProductID;
    END
    ELSE
    BEGIN
        UPDATE [Inventory].[Products] 
        SET ProductName = @ProductName, ProductNameEn = @ProductNameEn, Barcode = @Barcode, CategoryID = @CategoryID,
            UnitID = @UnitID, PurchasePrice = @PurchasePrice, SalePrice = @SalePrice, AlertQty = @AlertQty,
            ProductType = ISNULL(@ProductType, ProductType)
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
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
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
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
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
        -- C. PAYMENT JOURNAL ENTRIES (دعم التجزئة Split والتحصيل المباشر)
        -- ==========================================================

        -- ──────────────────────────────────────────────────────────
        -- المسار 1: SPLIT PAYMENTS (عند وجود تقسيم في InvoicePaymentSplits)
        -- ──────────────────────────────────────────────────────────

        -- 1.1 مشتريات Split: Dr المورد / Cr حساب طريقة الدفع
        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            m.EntryNo, i.InvDate, 'Payment', i.InvID,
            ISNULL(p.AccountID, @VendorAcc),  -- Dr حساب المورد
            sp.Amount, 0,
            N'سداد [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR), 
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID
        WHERE i.InvType = 'Purchase' AND sp.Amount > 0;

        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            m.EntryNo, i.InvDate, 'Payment', i.InvID,
            sp.PaymentAccountID,              -- Cr حساب طريقة الدفع
            0, sp.Amount,
            N'سداد [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR), 
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID
        WHERE i.InvType = 'Purchase' AND sp.Amount > 0;

        -- 1.2 مبيعات Split: Dr حساب طريقة الدفع / Cr العميل
        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            m.EntryNo, i.InvDate, 'Payment', i.InvID,
            sp.PaymentAccountID,              -- Dr حساب طريقة الدفع (خزينة/بنك/كي نت)
            sp.Amount, 0,
            N'تحصيل [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR), 
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID
        WHERE i.InvType = 'Sales' AND sp.Amount > 0;

        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            m.EntryNo, i.InvDate, 'Payment', i.InvID,
            ISNULL(p.AccountID, @CustomerAcc), -- Cr حساب العميل
            0, sp.Amount,
            N'تحصيل [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR), 
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID
        WHERE i.InvType = 'Sales' AND sp.Amount > 0;

        -- ──────────────────────────────────────────────────────────
        -- المسار 2: SINGLE PAYMENT FALLBACK (عند عدم وجود تجزئة)
        -- ──────────────────────────────────────────────────────────

        -- 2.1 مشتريات مباشر: Dr المورد / Cr حساب الدفع المباشر
        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               ISNULL(p.AccountID, @VendorAcc),
               i.PaidAmount, 0,
               N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = i.InvID);

        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               i.PaymentAccountID, 0, i.PaidAmount,
               N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = i.InvID);

        -- 2.2 مبيعات مباشر: Dr حساب التحصيل المباشر / Cr العميل
        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               i.PaymentAccountID, i.PaidAmount, 0,
               N'تحصيل جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Sales' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = i.InvID);

        INSERT INTO [Accounting].[JournalEntries] 
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               ISNULL(p.AccountID, @CustomerAcc), 0, i.PaidAmount,
               N'تحصيل جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Sales' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = i.InvID);

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

    DECLARE @Balance           DECIMAL(18,3) = 0;
    DECLARE @AvgCost           DECIMAL(18,3) = 0;
    DECLARE @TotalInQty        DECIMAL(18,3) = 0;
    DECLARE @TotalInValue      DECIMAL(18,3) = 0;
    DECLARE @TotalOutQty       DECIMAL(18,3) = 0;
    DECLARE @TotalOutValue     DECIMAL(18,3) = 0;
    DECLARE @LastPurchasePrice DECIMAL(18,3) = 0;
    DECLARE @ProfitRate        DECIMAL(18,3) = 0;
    DECLARE @AlertQty          DECIMAL(18,2) = 0;
    DECLARE @Barcode           NVARCHAR(50) = '';

    -- معلومات الصنف (حد الطلب، الباركود)
    SELECT 
        @AlertQty = ISNULL(AlertQty, 0),
        @Barcode  = ISNULL(Barcode, '')
    FROM [Inventory].[Products]
    WHERE ProductID = @ProductID;

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
        @ProfitRate         AS ProfitRate,
        @AlertQty           AS AlertQty,
        @Barcode            AS Barcode;
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


IF OBJECT_ID('[Sales].[sp_Invoice_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetByID];
GO
create PROCEDURE [Sales].[sp_Invoice_GetByID]  
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
   SELECT inv.*,par.PartnerName,chart.AccountCode  FROM [Sales].[InvoiceHeader] inv
	join [Sales].[Partners] par on inv.[PartnerID] =par.[PartnerID]
	join [Accounting].[ChartOfAccounts] chart on par.[AccountID] = chart.[AccountID]
	 WHERE InvID = @InvID;
END
go
-- =============================================
-- 7. sp_InvoiceDetails_GetByInvID
-- =============================================
IF OBJECT_ID('[Sales].[sp_InvoiceDetails_GetByInvID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID];
GO
create PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID]
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
    WHERE d.InvID = @InvID
	order by [DetID];
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
    @TotalAmount DECIMAL(18, 3),
    @Discount DECIMAL(18, 3),
    @NetAmount DECIMAL(18, 3),
    @PaidAmount DECIMAL(18, 3),
    @Remainder DECIMAL(18, 3),
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
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName,
        acc.AccountName AS PaymentAccountName,
        acc.AccountCode AS PaymentAccountCode
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
    WHERE h.InvID = @InvID;
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
-- ============================================================
-- STEP 2: إضافة VoucherPaidAmount لجدول رؤوس الفواتير
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('[Sales].[InvoiceHeader]')
      AND name = 'VoucherPaidAmount'
)
BEGIN
    ALTER TABLE [Sales].[InvoiceHeader]
    ADD VoucherPaidAmount DECIMAL(18,3) NOT NULL DEFAULT 0;
    PRINT N'✅ تم إضافة VoucherPaidAmount إلى [Sales].[InvoiceHeader]';
END
ELSE
    PRINT N'⚠️ العمود VoucherPaidAmount موجود مسبقاً في [Sales].[InvoiceHeader]';
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
        (h.PaidAmount + h.VoucherPaidAmount) as PaidAmount,
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

-- Add ReferenceNo (Supplier Invoice Number) to InvoiceHeader
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('Sales.InvoiceHeader') AND name = 'ReferenceNo'
)
BEGIN
    ALTER TABLE Sales.InvoiceHeader ADD ReferenceNo NVARCHAR(50) NULL;
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

IF OBJECT_ID('[Inventory].[sp_ProductCard_GetStockByWarehouse]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_GetStockByWarehouse];
GO
CREATE PROCEDURE [Inventory].[sp_ProductCard_GetStockByWarehouse]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AlertQty DECIMAL(18,2) = 0;
    SELECT @AlertQty = ISNULL(AlertQty, 0)
    FROM [Inventory].[Products]
    WHERE ProductID = @ProductID;

    SELECT 
        w.WarehouseName,
        ISNULL(s.CurrentQty, 0) AS CurrentQty,
        @AlertQty AS AlertQty
    FROM [Inventory].[ProductStock] s
    INNER JOIN Settings.[Warehouses] w ON s.WarehouseID = w.WarehouseID
    WHERE s.ProductID = @ProductID AND s.CurrentQty > 0
    ORDER BY w.WarehouseName;
END
GO
IF OBJECT_ID('[Inventory].[sp_ProductCard_UpdateQuickDetails]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_ProductCard_UpdateQuickDetails];
GO
create PROCEDURE [Inventory].[sp_ProductCard_UpdateQuickDetails]
    @ProductID   INT,
    @ProductName NVARCHAR(255),
    @Barcode     NVARCHAR(50),
    @SalePrice   DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Inventory].[Products]
    SET ProductName = ISNULL(@ProductName, ProductName),
        Barcode     = ISNULL(@Barcode, Barcode),
        SalePrice   = ISNULL(@SalePrice, SalePrice)
    WHERE ProductID = @ProductID;
END
go
-- =============================================
-- Dashboard Schema & Procedures
-- =============================================
-- =============================================
-- Dashboard Schema & Procedures
-- =============================================


-- Create Reports Schema if not exists (we'll use this for Dashboard)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Reports') EXEC('CREATE SCHEMA [Reports]');
GO

-- =============================================
-- 1. Dashboard Summary (Sales today, Purchases today, Products, Customers)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetSummary]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetSummary];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetSummary]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodaySales DECIMAL(18,2) = 0;
    DECLARE @TodayPurchases DECIMAL(18,2) = 0;
    DECLARE @TotalProducts INT = 0;
    DECLARE @TotalCustomers INT = 0;
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    -- 1. Today's Sales
    SELECT @TodaySales = ISNULL(SUM(NetAmount), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Sales' 
      AND IsPosted = 1 
      AND CAST(InvDate AS DATE) = @Today;

    -- 2. Today's Purchases
    SELECT @TodayPurchases = ISNULL(SUM(NetAmount), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Purchase' 
      AND IsPosted = 1 
      AND CAST(InvDate AS DATE) = @Today;

    -- 3. Total Products 
    SELECT @TotalProducts = COUNT(*)
    FROM [Inventory].[Products]
    WHERE IsActive = 1;

    -- 4. Total Customers
    SELECT @TotalCustomers = COUNT(*)
    FROM Sales.[Partners]
    WHERE PartnerType IN ('Customer', 'Both') AND IsActive = 1;

    -- Output
    SELECT 
        @TodaySales AS TodaySales,
        @TodayPurchases AS TodayPurchases,
        @TotalProducts AS TotalProducts,
        @TotalCustomers AS TotalCustomers;
END
GO

-- =============================================
-- 2. Sales Chart (Last 7 Days)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetSalesChart]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetSalesChart];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetSalesChart]
    @Days INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = CAST(DATEADD(DAY, -(@Days - 1), GETDATE()) AS DATE);

    -- CTE to generate the last N dates
    WITH DateRange AS (
        SELECT @StartDate AS DateValue
        UNION ALL
        SELECT DATEADD(DAY, 1, DateValue)
        FROM DateRange
        WHERE DATEADD(DAY, 1, DateValue) <= CAST(GETDATE() AS DATE)
    )
    SELECT 
        d.DateValue,
        ISNULL(SUM(h.NetAmount), 0) AS TotalSales
    FROM DateRange d
    LEFT JOIN [Sales].[InvoiceHeader] h 
        ON CAST(h.InvDate AS DATE) = d.DateValue 
        AND h.InvType = 'Sales' 
        AND h.IsPosted = 1
    GROUP BY d.DateValue
    ORDER BY d.DateValue;
END
GO

-- =============================================
-- 3. Low Stock Alerts
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetAlertProducts]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetAlertProducts];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetAlertProducts]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.ProductID,
        p.ProductName,
        ISNULL(SUM(s.CurrentQty), 0) AS CurrentQty,
        ISNULL(p.AlertQty, 0) AS AlertQty
    FROM [Inventory].[Products] p
    LEFT JOIN [Inventory].[ProductStock] s ON p.ProductID = s.ProductID
    WHERE p.IsActive = 1
    GROUP BY p.ProductID, p.ProductName, p.AlertQty
    HAVING ISNULL(SUM(s.CurrentQty), 0) <= ISNULL(p.AlertQty, 0)
       AND ISNULL(p.AlertQty, 0) > 0
    ORDER BY CurrentQty ASC;
END
GO

-- =============================================
-- 4. Customer Debts (مديونيات العملاء)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetCustomerDebts]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetCustomerDebts];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetCustomerDebts]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 50
        p.PartnerID,
        p.PartnerName,
        ISNULL(SUM(JE.DebitAmount - JE.CreditAmount), 0) AS Balance
    FROM [Sales].[Partners] p
    INNER JOIN [Accounting].[JournalEntries] JE ON JE.AccountID = p.AccountID
    WHERE p.PartnerType IN ('Customer', 'Both')
    GROUP BY p.PartnerID, p.PartnerName
    HAVING ISNULL(SUM(JE.DebitAmount - JE.CreditAmount), 0) > 0
    ORDER BY Balance DESC;
END
GO

-- =============================================
-- 5. Supplier Debts (مديونيات الموردين)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetSupplierDebts]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetSupplierDebts];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetSupplierDebts]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 50
        p.PartnerID,
        p.PartnerName,
        ISNULL(SUM(JE.CreditAmount - JE.DebitAmount), 0) AS Balance
    FROM [Sales].[Partners] p
    INNER JOIN [Accounting].[JournalEntries] JE ON JE.AccountID = p.AccountID
    WHERE p.PartnerType IN ('Supplier', 'Both')
    GROUP BY p.PartnerID, p.PartnerName
    HAVING ISNULL(SUM(JE.CreditAmount - JE.DebitAmount), 0) > 0
    ORDER BY Balance DESC;
END
GO

ALTER PROCEDURE [Security].[sp_User_Login]
    @Username NVARCHAR(50), 
    @PasswordHash NVARCHAR(255) 
AS 
BEGIN 
    SET NOCOUNT ON;
    SELECT 
        Users.UserID, 
        Users.FullName, 
        Users.RoleID,  -- تمت إضافة هذا العمود المفقود
        Roles.RoleName, 
        Users.IsActive 
    FROM [Security].Users 
    INNER JOIN [Security].Roles ON Users.RoleID = Roles.RoleID 
    WHERE Username = @Username AND PasswordHash = @PasswordHash;
END 
GO

-- =============================================
-- Auto-Restored Missing Table: [Security].[DeviceLicenses]
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeviceLicenses' AND schema_id = SCHEMA_ID('Security'))
BEGIN
    CREATE TABLE [Security].[DeviceLicenses] (
        LicenseID INT PRIMARY KEY IDENTITY(1,1),
        MachineName NVARCHAR(100),
        MachineHWID NVARCHAR(255),
        LicenseKey NVARCHAR(MAX),
        IsActive BIT DEFAULT 1,
        ExpiryDate DATETIME,
        CreatedDate DATETIME DEFAULT GETDATE()
    );
END
GO

-- =============================================
-- Auto-Restored Missing Procedure: [Security].[sp_CheckDeviceLicense]
-- =============================================
IF OBJECT_ID('[Security].[sp_CheckDeviceLicense]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_CheckDeviceLicense];
GO

CREATE PROCEDURE [Security].[sp_CheckDeviceLicense] 
    @MachineHWID NVARCHAR(255) 
AS 
BEGIN 
    -- يرجع 1 إذا كان الجهاز مرخصاً ونشطاً 
    IF EXISTS (SELECT 1 FROM [Security].[DeviceLicenses] WHERE MachineHWID = @MachineHWID AND IsActive = 1) 
    BEGIN 
        SELECT 1 AS IsLicensed, ExpiryDate FROM [Security].[DeviceLicenses] WHERE MachineHWID = @MachineHWID; 
    END
    ELSE
    BEGIN 
        SELECT 0 AS IsLicensed, NULL AS ExpiryDate; 
    END
END 
GO


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
GO


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

-- ======================================================================
-- Vegtablity ERP - Comprehensive Reports & Indexes Update Script
-- ======================================================================
-- Execute this script in SQL Server Management Studio (SSMS)
-- Target Database: [VegtablityDB]
-- ======================================================================

 

PRINT '====================================================='
PRINT '1. CREATING MISSING INDEXES FOR PERFORMANCE OPTIMIZATION'
PRINT '====================================================='

-- 1. Inventory Schema Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_Barcode' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_Barcode] ON [Inventory].[Products] ([Barcode]) INCLUDE ([ProductName], saleprice);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_IsActive' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_IsActive] ON [Inventory].[Products] ([IsActive]) INCLUDE ([ProductID], [ProductName], saleprice);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Stock_Warehouse_Product' AND object_id = OBJECT_ID('[Inventory].[ProductStock]'))
    CREATE NONCLUSTERED INDEX [IX_Stock_Warehouse_Product] ON [Inventory].[ProductStock] ([WarehouseID], [ProductID]) INCLUDE ([CurrentQty]);
GO

-- 2. Sales Schema Indexes (Invoices & Details)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Invoices_InvDate' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_Invoices_InvDate] ON [Sales].[InvoiceHeader] ([InvDate]) INCLUDE ([TotalAmount], [Discount], [NetAmount], [PaidAmount], [Remainder]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Invoices_Partner_Date' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_Invoices_Partner_Date] ON [Sales].[InvoiceHeader] ([PartnerID], [InvDate]) INCLUDE ([NetAmount], [Remainder], [IsPosted]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceDetails_InvID' AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceDetails_InvID] ON [Sales].[InvoiceDetails] ([InvID]) INCLUDE ([ProductID], [Quantity], [UnitPrice], [TotalPrice], [CostPrice]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceDetails_Product' AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceDetails_Product] ON [Sales].[InvoiceDetails] ([ProductID]) INCLUDE ([InvID], [Quantity], [TotalPrice], [CostPrice]);
GO

-- 3. Quotations Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Quotations_Partner_IsActive' AND object_id = OBJECT_ID('[Sales].[Quotations]'))
    CREATE NONCLUSTERED INDEX [IX_Quotations_Partner_IsActive] ON [Sales].[Quotations] ([PartnerID], [IsActive]) INCLUDE ([QuoteDate], [ExpiryDate]);
GO

-- 4. Accounting Schema Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_JournalEntries_Date' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
    CREATE NONCLUSTERED INDEX [IX_JournalEntries_Date] ON [Accounting].[JournalEntries] ([EntryDate]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_JournalEntryDetails_EntryID' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
    CREATE NONCLUSTERED INDEX [IX_JournalEntryDetails_EntryID] ON [Accounting].[JournalEntries] ([EntryID]) INCLUDE ([AccountID], [Debitamount], [Creditamount]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_JournalEntryDetails_Account' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
    CREATE NONCLUSTERED INDEX [IX_JournalEntryDetails_Account] ON [Accounting].[JournalEntries] ([AccountID]) INCLUDE ([EntryID], [Debitamount], [Creditamount]);
GO

PRINT '✅ Indexes Created Successfully.'
GO

PRINT '====================================================='
PRINT '2. CREATING COMPREHENSIVE REPORTS STORED PROCEDURES'
PRINT '====================================================='

-- ======================================================================
-- REPORT 1: تقرير أرباح كل صنف خلال فترة معينة + الأصناف الأكثر ربحية
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_ProductProfits]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_ProductProfits]
GO
CREATE PROCEDURE [Reports].[sp_Report_ProductProfits]
    @StartDate DATE,
    @EndDate DATE,
    @OrderBy NVARCHAR(50) = 'ProfitDesc' -- 'ProfitDesc', 'QtyDesc', 'RevenueDesc'
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        p.ProductID,
        p.Barcode,
        p.ProductName,
        u.UnitName,
        SUM(d.Quantity) AS TotalQtySold,
        SUM(d.TotalPrice) AS TotalRevenue,
        SUM(d.Quantity * ISNULL(d.CostPrice, p.PurchasePrice)) AS TotalCost,
        SUM(d.TotalPrice) - SUM(d.Quantity * ISNULL(d.CostPrice, p.PurchasePrice)) AS NetProfit,
        CASE WHEN SUM(d.TotalPrice) > 0 
             THEN ((SUM(d.TotalPrice) - SUM(d.Quantity * ISNULL(d.CostPrice, p.PurchasePrice))) / SUM(d.TotalPrice)) * 100 
             ELSE 0 END AS ProfitMarginPercent
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND i.IsPosted = 1
    GROUP BY p.ProductID, p.Barcode, p.ProductName, u.UnitName
    ORDER BY 
        CASE WHEN @OrderBy = 'ProfitDesc' THEN SUM(d.TotalPrice) - SUM(d.Quantity * ISNULL(d.CostPrice, p.[PurchasePrice])) END DESC,
        CASE WHEN @OrderBy = 'QtyDesc' THEN SUM(d.Quantity) END DESC,
        CASE WHEN @OrderBy = 'RevenueDesc' THEN SUM(d.TotalPrice) END DESC;
END
GO

-- ======================================================================
-- REPORT 2: تقرير أرباح لكل فاتورة على حدة
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_InvoiceProfits]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_InvoiceProfits]
GO
CREATE PROCEDURE [Reports].[sp_Report_InvoiceProfits]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.InvID,
        i.InvDate,
        p.PartnerName AS CustomerName,
        i.TotalAmount AS GrossTotal,
        i.Discount,
        i.NetAmount,
        -- Calculate Total Cost of items in this invoice
        ISNULL((SELECT SUM(d.Quantity * ISNULL(d.CostPrice, pr.[PurchasePrice])) 
                FROM [Sales].[InvoiceDetails] d 
                INNER JOIN [Inventory].[Products] pr ON d.ProductID = pr.ProductID 
                WHERE d.InvID = i.InvID), 0) AS TotalCost,
        -- Profit = NetAmount - TotalCost
        i.NetAmount - ISNULL((SELECT SUM(d.Quantity * ISNULL(d.CostPrice, pr.[PurchasePrice])) 
                              FROM [Sales].[InvoiceDetails] d 
                              INNER JOIN [Inventory].[Products] pr ON d.ProductID = pr.ProductID 
                              WHERE d.InvID = i.InvID), 0) AS NetProfit,
        i.IsPosted
    FROM [Sales].[InvoiceHeader] i
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY i.InvDate DESC, i.InvID DESC;
END
GO

-- ======================================================================
-- REPORT 3: تقرير المبيعات اليومية والشهرية التفصيلي
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_SalesSummaryByPeriod]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_SalesSummaryByPeriod]
GO
CREATE PROCEDURE [Reports].[sp_Report_SalesSummaryByPeriod]
    @StartDate DATE,
    @EndDate DATE,
    @PeriodType NVARCHAR(10) = 'Daily' -- 'Daily' or 'Monthly'
AS
BEGIN
    SET NOCOUNT ON;

    IF @PeriodType = 'Daily'
    BEGIN
        SELECT 
            CAST(InvDate AS DATE) AS PeriodString,
            COUNT(InvID) AS InvoiceCount,
            SUM(TotalAmount) AS TotalGrossAmount,
            SUM(Discount) AS TotalDiscount,
            SUM(NetAmount) AS TotalNetAmount,
            SUM(PaidAmount) AS TotalPaid,
            SUM(Remainder) AS TotalCredit
        FROM [Sales].[InvoiceHeader]
        WHERE CAST(InvDate AS DATE) BETWEEN @StartDate AND @EndDate
          AND IsPosted = 1
        GROUP BY CAST(InvDate AS DATE)
        ORDER BY CAST(InvDate AS DATE) DESC;
    END
    ELSE IF @PeriodType = 'Monthly'
    BEGIN
        SELECT 
            FORMAT(InvDate, 'yyyy-MM') AS PeriodString,
            COUNT(InvID) AS InvoiceCount,
            SUM(TotalAmount) AS TotalGrossAmount,
            SUM(Discount) AS TotalDiscount,
            SUM(NetAmount) AS TotalNetAmount,
            SUM(PaidAmount) AS TotalPaid,
            SUM(Remainder) AS TotalCredit
        FROM [Sales].[InvoiceHeader]
        WHERE CAST(InvDate AS DATE) BETWEEN @StartDate AND @EndDate
          AND IsPosted = 1
        GROUP BY FORMAT(InvDate, 'yyyy-MM')
        ORDER BY FORMAT(InvDate, 'yyyy-MM') DESC;
    END
END
GO

-- ======================================================================
-- REPORT 4: تقرير مبيعات العملاء (أعلى العملاء شراءً)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_TopCustomers]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_TopCustomers]
GO
CREATE PROCEDURE [Reports].[sp_Report_TopCustomers]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.PartnerID,
        p.PartnerName,
        p.Phone,
        COUNT(i.InvID) AS TotalInvoices,
        SUM(i.NetAmount) AS TotalPurchases,
        SUM(i.PaidAmount) AS TotalPaid,
        SUM(i.Remainder) AS TotalCreditBalance
    FROM [Sales].[Partners] p
    INNER JOIN [Sales].[InvoiceHeader] i ON p.PartnerID = i.PartnerID
    WHERE p.PartnerType = 'Customer'
      AND CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND i.IsPosted = 1
    GROUP BY p.PartnerID, p.PartnerName, p.Phone
    ORDER BY SUM(i.NetAmount) DESC;
END
GO

-- ======================================================================
-- REPORT 5: تقرير فواتير المبيعات الآجلة (أعمار الديون)
-- ======================================================================

IF OBJECT_ID('[Reports].[sp_Report_UnpaidInvoicesAging]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_UnpaidInvoicesAging]
GO
CREATE PROCEDURE [Reports].[sp_Report_UnpaidInvoicesAging]
    @AsOfDate DATE = NULL,
    @PartnerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @AsOfDate IS NULL SET @AsOfDate = GETDATE();

    SELECT 
        i.InvID,
        i.InvDate,
        p.PartnerName AS CustomerName,
        i.NetAmount AS InvoiceTotal,
        i.PaidAmount,
        i.Remainder AS UnpaidBalance,
        DATEDIFF(DAY, i.InvDate, @AsOfDate) AS DaysOverdue,
        CASE 
            WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 30 THEN '1_0_to_30_Days'
            WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 60 THEN '2_31_to_60_Days'
            WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 90 THEN '3_61_to_90_Days'
            ELSE '4_Over_90_Days'
        END AS AgingBucket
    FROM [Sales].[InvoiceHeader] i
    INNER JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.Remainder > 0 
      AND i.IsPosted = 1
      AND CAST(i.InvDate AS DATE) <= @AsOfDate
      AND (@PartnerID IS NULL OR @PartnerID = 0 OR i.PartnerID = @PartnerID)
    ORDER BY DaysOverdue DESC;
END
GO

-- ======================================================================
-- REPORT 6: تقرير تقييم المخزون (Inventory Valuation)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_InventoryValuation]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_InventoryValuation]
GO
CREATE PROCEDURE [Reports].[sp_Report_InventoryValuation]
    @WarehouseID INT = 0 -- 0 means all warehouses
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        w.WarehouseName,
        p.ProductID,
        p.Barcode,
        p.ProductName,
        u.UnitName,
        s.[CurrentQty] AS CurrentStock,
        s.[AvgCostPrice] AS UnitCost,
        p.[SalePrice] AS UnitSellingPrice,
        (s.[CurrentQty] * s.[AvgCostPrice]) AS TotalCostValue,
        (s.[CurrentQty] * p.[SalePrice]) AS TotalRetailValue
    FROM [Inventory].[ProductStock] s
    INNER JOIN [Inventory].[Products] p ON s.ProductID = p.ProductID
    INNER JOIN [Settings].[Warehouses] w ON s.WarehouseID = w.WarehouseID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE (@WarehouseID = 0 OR s.WarehouseID = @WarehouseID)
      AND s.[CurrentQty] > 0
    ORDER BY w.WarehouseName, p.ProductName;
END
GO

-- ======================================================================
-- REPORT 7: تقرير الأصناف الراكدة (Dead/Slow-Moving Stock)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_SlowMovingStock]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_SlowMovingStock]
GO
CREATE PROCEDURE [Reports].[sp_Report_SlowMovingStock]
    @MonthsInactive INT = 3 -- Default 3 months
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CutoffDate DATE = DATEADD(MONTH, -@MonthsInactive, GETDATE());

    SELECT 
        p.ProductID,
        p.Barcode,
        p.ProductName,
        c.[CatName],
        u.UnitName,
        ISNULL(SUM(s.[CurrentQty]), 0) AS CurrentTotalStock,
        p.[PurchasePrice],
        MAX(i.InvDate) AS LastSoldDate,
        DATEDIFF(DAY, ISNULL(MAX(i.InvDate),GETDATE()), GETDATE()) AS DaysSinceLastSale
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.[CatID]
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    LEFT JOIN [Inventory].[ProductStock] s ON p.ProductID = s.ProductID
    LEFT JOIN [Sales].[InvoiceDetails] d ON p.ProductID = d.ProductID
    LEFT JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
    GROUP BY p.ProductID, p.Barcode, p.ProductName, c.[CatName], u.UnitName, p.[PurchasePrice]
    HAVING ISNULL(SUM(s.[CurrentQty]), 0) > 0 
       AND (MAX(i.InvDate) IS NULL OR MAX(i.InvDate) < @CutoffDate)
    ORDER BY DaysSinceLastSale DESC;
END
GO

-- ======================================================================
-- REPORT 8: تقرير حركة المخزون لكل صنف على حدة (Stock Movement)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_StockMovement]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_StockMovement]
GO
create PROCEDURE [Reports].[sp_Report_StockMovement]
    @ProductID INT,
    @WarehouseID INT = 0, -- 0 تعني الكل
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Movement.TransactionDate,
        Movement.TransactionType,
        Movement.WarehouseName,
        Movement.QtyIn,
        Movement.QtyOut,
        Movement.UnitPrice
    FROM (
        -- أولاً: المشتريات (الوارد QtyIn)
        SELECT
            i.InvDate AS TransactionDate,
            N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR) AS TransactionType,
            w.WarehouseName,
            d.Quantity AS QtyIn,
            0 AS QtyOut,
            d.UnitPrice
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
        INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID 
          AND i.InvType = 'Purchase' 
          AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID)
          AND i.IsPosted = 1

        UNION ALL

        -- ثانياً: المبيعات (الصادر QtyOut)
        SELECT
            i.InvDate AS TransactionDate,
            N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR) AS TransactionType,
            w.WarehouseName,
            0 AS QtyIn,
            d.Quantity AS QtyOut,
            d.UnitPrice
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
        INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID 
          AND i.InvType = 'Sales' 
          AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID)
          AND i.IsPosted = 1
    ) AS Movement
    WHERE CAST(Movement.TransactionDate AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY Movement.TransactionDate DESC;
END
GO


-- ======================================================================
-- REPORT 9: تقرير تحليل المصروفات (Expenses Analysis)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_ExpensesAnalysis]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_ExpensesAnalysis]
GO
CREATE PROCEDURE [Reports].[sp_Report_ExpensesAnalysis]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Expenses are accounts located in the P&L as Debit balances (usually starts with 3 or 5 depending on the chart)
    -- We will query all transactions for Accounts marked as IncomeStatement where BalanceType = Debit
    SELECT 
        a.AccountCode,
        a.AccountName,
        SUM(d.DebitAmount) AS TotalExpense
    FROM [Accounting].[JournalEntries] d
    INNER JOIN [Accounting].[JournalEntries] j ON d.EntryID = j.EntryID
    INNER JOIN [Accounting].[ChartOfAccounts] a ON d.AccountID = a.AccountID
    WHERE CAST(j.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND a.AccountType = 'Expenses'
    GROUP BY a.AccountCode, a.AccountName
    HAVING SUM(d.DebitAmount) > 0
    ORDER BY TotalExpense DESC;
END
GO


-- ======================================================================
-- REPORT 10: تقرير عروض الأسعار (المعلقة والفعالة)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_QuotationsStatus]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_QuotationsStatus]
GO
CREATE PROCEDURE [Reports].[sp_Report_QuotationsStatus]
    @Status NVARCHAR(20) = 'All' -- 'All', 'Active', 'Expired'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        q.QuoteID,
        p.PartnerName AS CustomerName,
        q.QuoteDate,
        q.ExpiryDate,
        q.IsActive,
        ISNULL((SELECT SUM(QuotedPrice) 
                FROM [Sales].[QuotationDetails] 
                WHERE QuoteID = q.QuoteID), 0) AS QuoteTotalValue,
        CASE 
            WHEN q.IsActive = 0 THEN 'مغلق'
            WHEN q.ExpiryDate IS NOT NULL AND CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE) THEN 'منتهي الصلاحية'
            ELSE 'فعال (قيد الانتظار)'
        END AS QuoteStatus
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@Status = 'All')
       OR (@Status = 'Active' AND q.IsActive = 1 AND (q.ExpiryDate IS NULL OR CAST(q.ExpiryDate AS DATE) >= CAST(GETDATE() AS DATE)))
       OR (@Status = 'Expired' AND (q.IsActive = 0 OR CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE)))
    ORDER BY q.QuoteDate DESC;
END
GO

-- ======================================================================
-- REPORT 11: تقرير الموردين (أعلى الموردين مشتريات)
-- *Placeholder - Assuming Purchase module structure matches Sales*
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_TopSuppliers]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_TopSuppliers]
GO
CREATE PROCEDURE [Reports].[sp_Report_TopSuppliers]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Note: Since the Purchase Invoices tables are not fully clear yet, 
    -- this relies on Journal Entries linking to supplier accounts if applicable,
    -- or if a [Purchases].[Invoices] schema exists.
    -- For now, this returns a scaffold. You will need to adjust table names if Purchases module is implemented.
    
    PRINT 'Top Suppliers Report created (Requires Purchase Invoices table to be active).'
    
    /* Example query if Purchase Invoices exist:
    SELECT 
        p.PartnerID, p.PartnerName, SUM(pi.NetAmount) AS TotalPurchases
    FROM [Sales].[Partners] p
    INNER JOIN [Purchases].[Invoices] pi ON p.PartnerID = pi.PartnerID
    WHERE p.PartnerType = 'Supplier' AND CAST(pi.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY p.PartnerID, p.PartnerName
    ORDER BY TotalPurchases DESC;
    */
END
GO

PRINT '✅ All Report Stored Procedures Created Successfully.'
GO





-- 1.1 Users Table: Optimize login and active user lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_Username' AND object_id = OBJECT_ID('[Security].[Users]'))
    CREATE UNIQUE NONCLUSTERED INDEX [IX_Users_Username] ON [Security].[Users] ([Username]) INCLUDE ([PasswordHash], [RoleID], [IsActive], [FullName]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_RoleID_IsActive' AND object_id = OBJECT_ID('[Security].[Users]'))
    CREATE NONCLUSTERED INDEX [IX_Users_RoleID_IsActive] ON [Security].[Users] ([RoleID], [IsActive]) INCLUDE ([Username], [FullName]);
GO

-- 1.2 RolePermissions: Optimize permission checks (CanView, CanAdd, etc.)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RolePermissions_RoleID_Form' AND object_id = OBJECT_ID('[Security].[RolePermissions]'))
    CREATE UNIQUE NONCLUSTERED INDEX [IX_RolePermissions_RoleID_Form] ON [Security].[RolePermissions] ([RoleID], [FormName]) INCLUDE ([CanView], [CanAdd], [CanEdit], [CanDelete], [CanPrint]);
GO

-- 1.3 DeviceLicenses: Optimize hardware ID validation
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DeviceLicenses_MachineHWID' AND object_id = OBJECT_ID('[Security].[DeviceLicenses]'))
    CREATE NONCLUSTERED INDEX [IX_DeviceLicenses_MachineHWID] ON [Security].[DeviceLicenses] ([MachineHWID]) INCLUDE ([IsActive], [ExpiryDate]);
GO


PRINT '====================================================='
PRINT '2. SETTINGS SCHEMA INDEXES'
PRINT '====================================================='

-- 2.1 Warehouses: Optimize active warehouse lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Warehouses_IsActive' AND object_id = OBJECT_ID('[Settings].[Warehouses]'))
    CREATE NONCLUSTERED INDEX [IX_Warehouses_IsActive] ON [Settings].[Warehouses] ([IsActive]) INCLUDE ([WarehouseID], [WarehouseName]);
GO

-- 2.2 Categories: Optimize active category lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Categories_IsActive' AND object_id = OBJECT_ID('[Settings].[Categories]'))
    CREATE NONCLUSTERED INDEX [IX_Categories_IsActive] ON [Settings].[Categories] ([IsActive]) INCLUDE ([CatID], [CatName]);
GO

-- 2.3 Units: Optimize active unit lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Units_IsActive' AND object_id = OBJECT_ID('[Settings].[Units]'))
    CREATE NONCLUSTERED INDEX [IX_Units_IsActive] ON [Settings].[Units] ([IsActive]) INCLUDE ([UnitID], [UnitName]);
GO


PRINT '====================================================='
PRINT '3. SALES SCHEMA INDEXES (Partners, Quotations, Invoices)'
PRINT '====================================================='

-- 3.1 Partners (Customers & Suppliers): Combine Type & Active status for dropdowns
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partners_Type_IsActive' AND object_id = OBJECT_ID('[Sales].[Partners]'))
    CREATE NONCLUSTERED INDEX [IX_Partners_Type_IsActive] ON [Sales].[Partners] ([PartnerType], [IsActive]) INCLUDE ([PartnerID], [PartnerName], [AccountID]);
GO
-- Partner Phone Lookup
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partners_Phone' AND object_id = OBJECT_ID('[Sales].[Partners]'))
    CREATE NONCLUSTERED INDEX [IX_Partners_Phone] ON [Sales].[Partners] ([Phone]) INCLUDE ([PartnerID], [PartnerName]);
GO

-- 3.2 Quotations: Header optimizations
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Quotations_Partner_Date' AND object_id = OBJECT_ID('[Sales].[Quotations]'))
    CREATE NONCLUSTERED INDEX [IX_Quotations_Partner_Date] ON [Sales].[Quotations] ([PartnerID], [QuoteDate] DESC) INCLUDE ([IsActive], [ExpiryDate]);
GO
-- 3.3 Quotation Details: Product lookups
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_QuotationDetails_QuoteID_Product' AND object_id = OBJECT_ID('[Sales].[QuotationDetails]'))
    CREATE NONCLUSTERED INDEX [IX_QuotationDetails_QuoteID_Product] ON [Sales].[QuotationDetails] ([QuoteID], [ProductID]) INCLUDE ([QuotedPrice]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_QuotationDetails_Product' AND object_id = OBJECT_ID('[Sales].[QuotationDetails]'))
    CREATE NONCLUSTERED INDEX [IX_QuotationDetails_Product] ON [Sales].[QuotationDetails] ([ProductID]) INCLUDE ([QuoteID], [QuotedPrice]);
GO

-- 3.4 InvoiceHeader: Filtering & Reports (Type, Date, Posted Status)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceHeader_Type_Date_Posted' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceHeader_Type_Date_Posted] ON [Sales].[InvoiceHeader] ([InvType], [IsPosted], [InvDate] DESC) INCLUDE ([PartnerID], [WarehouseID], [NetAmount], [Remainder], [ReferenceNo]);
GO
-- Unpaid Invoices Lookup
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceHeader_Remainder_Posted' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceHeader_Remainder_Posted] ON [Sales].[InvoiceHeader] ([IsPosted], [Remainder]) INCLUDE ([InvID], [InvDate], [PartnerID], [InvType]);
GO
-- Foreign Keys
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceHeader_WarehouseID' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceHeader_WarehouseID] ON [Sales].[InvoiceHeader] ([WarehouseID]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceHeader_UserID' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceHeader_UserID] ON [Sales].[InvoiceHeader] ([UserID]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceHeader_PaymentAccountID' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceHeader_PaymentAccountID] ON [Sales].[InvoiceHeader] ([PaymentAccountID]);
GO

-- 3.5 InvoiceDetails: Reverse lookup (Product -> Invoice) for Card Movements
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceDetails_ProductID_InvID' AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceDetails_ProductID_InvID] ON [Sales].[InvoiceDetails] ([ProductID], [InvID]) INCLUDE ([Quantity], [UnitPrice], [TotalPrice], [CostPrice]);
GO


PRINT '====================================================='
PRINT '4. INVENTORY SCHEMA INDEXES'
PRINT '====================================================='

-- 4.1 Products: Name search and Foreign Keys
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Products_Name_En' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_Name_En] ON [Inventory].[Products] ([ProductNameEn]) INCLUDE ([ProductName], [ProductID], [IsActive]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Products_Category' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_Category] ON [Inventory].[Products] ([CategoryID]) INCLUDE ([ProductID], [ProductName], [IsActive]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Products_Unit' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_Unit] ON [Inventory].[Products] ([UnitID]);
GO

-- 4.2 ProductStock: Low Stock Warnings
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductStock_Qty' AND object_id = OBJECT_ID('[Inventory].[ProductStock]'))
    CREATE NONCLUSTERED INDEX [IX_ProductStock_Qty] ON [Inventory].[ProductStock] ([CurrentQty]) INCLUDE ([ProductID], [WarehouseID]);
GO


PRINT '====================================================='
PRINT '5. ACCOUNTING SCHEMA INDEXES'
PRINT '====================================================='

-- 5.1 ChartOfAccounts: Code lookup & Parent Hierarchy
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ChartOfAccounts_AccountCode' AND object_id = OBJECT_ID('[Accounting].[ChartOfAccounts]'))
    CREATE UNIQUE NONCLUSTERED INDEX [IX_ChartOfAccounts_AccountCode] ON [Accounting].[ChartOfAccounts] ([AccountCode]) INCLUDE ([AccountID], [AccountName], [IsTransactional]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ChartOfAccounts_ParentID' AND object_id = OBJECT_ID('[Accounting].[ChartOfAccounts]'))
    CREATE NONCLUSTERED INDEX [IX_ChartOfAccounts_ParentID] ON [Accounting].[ChartOfAccounts] ([ParentAccountID]) INCLUDE ([AccountID], [AccountName], [AccountCode]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ChartOfAccounts_IsTransactional' AND object_id = OBJECT_ID('[Accounting].[ChartOfAccounts]'))
    CREATE NONCLUSTERED INDEX [IX_ChartOfAccounts_IsTransactional] ON [Accounting].[ChartOfAccounts] ([IsTransactional]) INCLUDE ([AccountID], [AccountCode], [AccountName]);
GO

-- 5.2 JournalHeader (if exists as defined in Reports SP): Date and Reference
IF OBJECT_ID('[Accounting].[JournalHeader]', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalHeader_EntryDate_Posted' AND object_id = OBJECT_ID('[Accounting].[JournalHeader]'))
        CREATE NONCLUSTERED INDEX [IX_JournalHeader_EntryDate_Posted] ON [Accounting].[JournalHeader] ([JDate] DESC, [IsPosted]) INCLUDE ([JID], [ReferenceType], [ReferenceID]);
    
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalHeader_Reference' AND object_id = OBJECT_ID('[Accounting].[JournalHeader]'))
        CREATE NONCLUSTERED INDEX [IX_JournalHeader_Reference] ON [Accounting].[JournalHeader] ([ReferenceType], [ReferenceID]) INCLUDE ([JID], [IsPosted]);
END
GO

-- 5.3 JournalDetails (if exists as defined in Reports SP): Account Lookups
IF OBJECT_ID('[Accounting].[JournalDetails]', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalDetails_AccountID' AND object_id = OBJECT_ID('[Accounting].[JournalDetails]'))
        CREATE NONCLUSTERED INDEX [IX_JournalDetails_AccountID] ON [Accounting].[JournalDetails] ([AccountID]) INCLUDE ([JID], [Debit], [Credit]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalDetails_JID' AND object_id = OBJECT_ID('[Accounting].[JournalDetails]'))
        CREATE NONCLUSTERED INDEX [IX_JournalDetails_JID] ON [Accounting].[JournalDetails] ([JID]) INCLUDE ([AccountID], [Debit], [Credit]);
END
GO

-- 5.4 JournalEntries (Legacy flat table): Filtering and Foreign Keys
IF OBJECT_ID('[Accounting].[JournalEntries]', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalEntries_Reference' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
        CREATE NONCLUSTERED INDEX [IX_JournalEntries_Reference] ON [Accounting].[JournalEntries] ([ReferenceType], [ReferenceID]) INCLUDE ([EntryID], [AccountID], [EntryDate]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalEntries_Account_Date' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
        CREATE NONCLUSTERED INDEX [IX_JournalEntries_Account_Date] ON [Accounting].[JournalEntries] ([AccountID], [CreatedAt] DESC) INCLUDE ([DebitAmount], [CreditAmount]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalEntries_VoucherID' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
        CREATE NONCLUSTERED INDEX [IX_JournalEntries_VoucherID] ON [Accounting].[JournalEntries] ([ReferenceID]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_JournalEntries_UserID' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
        CREATE NONCLUSTERED INDEX [IX_JournalEntries_UserID] ON [Accounting].[JournalEntries] ([UserID]);
END
GO

-- 5.5 Vouchers: Date and Type
IF OBJECT_ID('[Accounting].[Vouchers]', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Vouchers_Type_Date_Posted' AND object_id = OBJECT_ID('[Accounting].[Vouchers]'))
        CREATE NONCLUSTERED INDEX [IX_Vouchers_Type_Date_Posted] ON [Accounting].[Vouchers] ([VoucherType], [IsPosted], [VoucherDate] DESC) INCLUDE ([VoucherID], [PartnerID], [Amount]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Vouchers_PartnerID' AND object_id = OBJECT_ID('[Accounting].[Vouchers]'))
        CREATE NONCLUSTERED INDEX [IX_Vouchers_PartnerID] ON [Accounting].[Vouchers] ([PartnerID]) INCLUDE ([VoucherID], [VoucherType], [Amount]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Vouchers_AccountID' AND object_id = OBJECT_ID('[Accounting].[Vouchers]'))
        CREATE NONCLUSTERED INDEX [IX_Vouchers_AccountID] ON [Accounting].[Vouchers] ([AccountID]);
        
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Vouchers_UserID' AND object_id = OBJECT_ID('[Accounting].[Vouchers]'))
        CREATE NONCLUSTERED INDEX [IX_Vouchers_UserID] ON [Accounting].[Vouchers] ([UserID]);
END
GO

PRINT '====================================================='
PRINT '✅ INDEX CREATION COMPLETED SUCCESSFULLY'
PRINT '====================================================='
GO


-- 1. Paged Products with Search
IF OBJECT_ID('[Inventory].[sp_Product_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetPaged];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get Total count for UI
    SELECT COUNT(*) AS TotalCount
    FROM [Inventory].[Products] p
    WHERE p.IsActive = 1 AND (
        @SearchText IS NULL OR @SearchText = ''
        OR p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
    );

    -- Get Page Data
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1 AND (
        @SearchText IS NULL OR @SearchText = ''
        OR p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
    )
    ORDER BY p.ProductName -- Logical sort for users
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- 2. Paged Quotations History
IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total Count
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE));

    -- Page Data
    SELECT q.*, p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO


-- 1. Optimization for Product Search and Paging
-- Helps with: WHERE IsActive=1 AND (Name LIKE ... OR Barcode LIKE ...) ORDER BY ProductName
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Products_Search_Paged' AND object_id = OBJECT_ID('[Inventory].[Products]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Products_Search_Paged]
    ON [Inventory].[Products] ([IsActive], [ProductName])
    INCLUDE ([Barcode], [ProductNameEn], [CategoryID], [UnitID], [SalePrice]);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Products_Barcode' AND object_id = OBJECT_ID('[Inventory].[Products]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Products_Barcode]
    ON [Inventory].[Products] ([Barcode])
    WHERE [Barcode] IS NOT NULL;
END
GO

-- 2. Optimization for Quotations History
-- Helps with: ORDER BY QuoteDate DESC (Main history grid)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Quotations_QuoteDate' AND object_id = OBJECT_ID('[Sales].[Quotations]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Quotations_QuoteDate]
    ON [Sales].[Quotations] ([QuoteDate] DESC)
    INCLUDE ([PartnerID], [IsActive]);
END
GO

-- 3. Optimization for Lookups (Partners by Type)
-- Helps with: SELECT * FROM Partners WHERE PartnerType = 'Customer'
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Partners_Type' AND object_id = OBJECT_ID('[Sales].[Partners]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Partners_Type]
    ON [Sales].[Partners] ([PartnerType])
    INCLUDE ([PartnerName]);
END
GO

-- 4. Optimization for Quotation Details
-- Helps with Joins and fetching details for a specific quote
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_QuotationDetails_QuoteID' AND object_id = OBJECT_ID('[Sales].[QuotationDetails]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_QuotationDetails_QuoteID]
    ON [Sales].[QuotationDetails] ([QuoteID])
    INCLUDE ([ProductID], [QuotedPrice] );
END
GO


IF OBJECT_ID('[Sales].[sp_Invoice_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetPaged];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @InvType NVARCHAR(20) = 'Sales',
    @SearchText NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. Get Total Count
    SELECT COUNT(*) 
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    WHERE h.InvType = @InvType
      AND (@SearchText IS NULL OR 
           p.PartnerName LIKE '%' + @SearchText + '%' OR 
           h.ReferenceNo LIKE '%' + @SearchText + '%' OR
           CAST(h.InvID AS NVARCHAR) = @SearchText);

    -- 2. Get Paged Data
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
      AND (@SearchText IS NULL OR 
           p.PartnerName LIKE '%' + @SearchText + '%' OR 
           h.ReferenceNo LIKE '%' + @SearchText + '%' OR 
           CAST(h.InvID AS NVARCHAR) = @SearchText)
    ORDER BY h.InvID DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceHeader_Partner_Date' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
BEGIN
    CREATE INDEX IX_InvoiceHeader_Partner_Date ON [Sales].[InvoiceHeader] (PartnerID, InvDate DESC);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceHeader_Posted' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
BEGIN
    CREATE INDEX IX_InvoiceHeader_Posted ON [Sales].[InvoiceHeader] (IsPosted) INCLUDE (InvDate, TotalAmount);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_Search' AND object_id = OBJECT_ID('[Inventory].[Products]'))
BEGIN
    CREATE INDEX IX_Products_Search ON [Inventory].[Products] (Barcode) INCLUDE (ProductName, SalePrice);
END
GO



-- 2. Paged Quotations History
IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total Count
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText);

    -- Page Data
    SELECT q.*, p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText)
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- 1. Paged Products with Search
IF OBJECT_ID('[Inventory].[sp_Product_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetPaged];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get Total count for UI
    SELECT COUNT(*) AS TotalCount
    FROM [Inventory].[Products] p
    WHERE p.IsActive = 1 AND (
        @SearchText IS NULL OR @SearchText = ''
        OR p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
    );

    -- Get Page Data
    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName,
        p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1 AND (
        @SearchText IS NULL OR @SearchText = ''
        OR p.ProductName LIKE '%' + @SearchText + '%' 
        OR p.ProductNameEn LIKE '%' + @SearchText + '%' 
        OR p.Barcode LIKE '%' + @SearchText + '%'
    )
    ORDER BY p.ProductName -- Logical sort for users
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- 2. Paged Quotations History
IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO
CREATE PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL,
    @PartnerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total Count
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText);

    -- Page Data
    SELECT q.*, p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText)
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
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
    @QuoteID INT,
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. Total Count
    SELECT COUNT(*) FROM [Sales].[QuotationDetails] WHERE QuoteID = @QuoteID;

    -- 2. Paginated Data
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
    WHERE qd.QuoteID = @QuoteID
    ORDER BY qd.QuoteDetailID
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- 5. Insert Quotation Detail
IF OBJECT_ID('[Sales].[sp_QuotationDetails_Insert]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_QuotationDetails_Insert];
GO
CREATE PROCEDURE [Sales].[sp_QuotationDetails_Insert]
    @QuoteID INT,
    @ProductID INT,
    @QuotedPrice DECIMAL(18, 3),
    @Quantity DECIMAL(18, 3) = 1
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
go
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

IF OBJECT_ID('[Inventory].[sp_Inventory_GetAvgCostByProduct]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Inventory_GetAvgCostByProduct];
GO
CREATE PROCEDURE [Inventory].[sp_Inventory_GetAvgCostByProduct]
    @ProductID INT,
    @WarehouseID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(AvgCostPrice, 0) 
    FROM [Inventory].[ProductStock] 
    WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;
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
    @QuoteID INT,
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. Total Count
    SELECT COUNT(*) FROM [Sales].[QuotationDetails] WHERE QuoteID = @QuoteID;

    -- 2. Paginated Data
    SELECT 
        qd.QuoteDetailID,
        qd.QuoteID,
        qd.ProductID,
        qd.QuotedPrice,
        ISNULL(p.ProductName, N'صنف غير معروف') AS ProductName,
        p.Barcode,
        u.UnitName
    FROM [Sales].[QuotationDetails] qd
    LEFT JOIN [Inventory].[Products] p ON qd.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE qd.QuoteID = @QuoteID
    ORDER BY qd.QuoteDetailID
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- 5. Insert Quotation Detail
IF OBJECT_ID('[Sales].[sp_QuotationDetails_Insert]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_QuotationDetails_Insert];
GO
CREATE PROCEDURE [Sales].[sp_QuotationDetails_Insert]
    @QuoteID INT,
    @ProductID INT,
    @QuotedPrice DECIMAL(18, 3),
    @Quantity DECIMAL(18, 3) = 1
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
go
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

IF OBJECT_ID('[Sales].[sp_QuotationDetails_GetByQuoteID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_QuotationDetails_GetByQuoteID];
GO
CREATE PROCEDURE [Sales].[sp_QuotationDetails_GetByQuoteID]
    @QuoteID INT,
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. Total Count
    SELECT COUNT(*) AS TotalCount FROM [Sales].[QuotationDetails] WHERE QuoteID = @QuoteID;

    -- 2. Paginated Data
    SELECT 
        qd.QuoteDetailID,
        qd.QuoteID,
        qd.ProductID,
        qd.QuotedPrice,
        ISNULL(p.ProductName, N'صنف غير معروف') AS ProductName,
        p.Barcode,
        u.UnitName
    FROM [Sales].[QuotationDetails] qd
    LEFT JOIN [Inventory].[Products] p ON qd.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE qd.QuoteID = @QuoteID
    ORDER BY qd.QuoteDetailID
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

IF OBJECT_ID('[Sales].[sp_InvoiceDetails_GetByInvID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID];
GO
create PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID]
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
    WHERE d.InvID = @InvID
	order by [DetID];
END
GO


IF OBJECT_ID('[Sales].[sp_Report_InvoicePrint]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_InvoicePrint];
GO
create  PROCEDURE [Sales].[sp_Report_InvoicePrint]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. بيانات رأس الفاتورة الضرورية فقط للطباعة
    SELECT 
        H.InvID, 
        H.InvDate, 
        H.TotalAmount, -- مستخدم للأرقام وللتفقيط (الكتابة بالحروف)
        P.PartnerName, 
        CH.AccountCode,
		h.Notes
    FROM [Sales].[InvoiceHeader] H
    LEFT JOIN [Sales].[Partners] P ON H.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] CH ON P.[AccountID] = CH.[AccountID]
    WHERE H.InvID = @InvID;

    -- 2. بيانات الأصناف المطلوبة فقط للجدول
    SELECT 
        PR.ProductName, 
        PR.ProductNameEn,
        UN.UnitName,
        D.Quantity, 
        D.UnitPrice, 
        D.TotalPrice
    FROM [Sales].[InvoiceDetails] D
    JOIN [Inventory].[Products] PR ON D.ProductID = PR.ProductID
    LEFT JOIN [Settings].[Units] UN ON PR.UnitID = UN.UnitID
    WHERE D.InvID = @InvID
	order by d.DetID;
END
go 
IF OBJECT_ID('[Sales].[sp_Partner_SearchAll]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Partner_SearchAll];
GO
CREATE PROCEDURE [Sales].[sp_Partner_SearchAll]
    @SearchText NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.PartnerID,
        p.PartnerName,
        p.PartnerType,
        p.Phone,
        p.IsActive,
        p.AccountID,
        c.AccountCode
    FROM [Sales].[Partners] p
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON p.AccountID = c.AccountID
    WHERE p.IsActive = 1
      AND (
           @SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR c.AccountCode LIKE '%' + @SearchText + '%'
      )
    ORDER BY p.PartnerType, p.PartnerName;
END
GO


 
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'UnifiedPartnerSearch')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD UnifiedPartnerSearch BIT NOT NULL DEFAULT 1;
END
GO
 
 
 IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL
    DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO
create PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo,
            UnifiedPartnerSearch = @UnifiedPartnerSearch
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch);
    END
END
GO
 

 IF OBJECT_ID('[Sales].[sp_Partner_Search]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Partner_Search];
GO
create PROCEDURE [Sales].[sp_Partner_Search]
    @PartnerType NVARCHAR(20),
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PartnerID, 
        p.PartnerName, 
        p.PartnerType, 
        p.Phone, 
        p.Address, 
        p.CurrentBalance, 
        p.IsActive, 
        p.AccountID,
        c.AccountCode
    FROM [Sales].[Partners] p
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON p.AccountID = c.AccountID
    WHERE p.IsActive = 1 AND p.PartnerType = @PartnerType
      AND (
           @SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%' 
           OR p.Phone LIKE '%' + @SearchText + '%'
           OR c.AccountCode LIKE '%' + @SearchText + '%'
      )
    ORDER BY p.PartnerID;
END
GO

 IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO
 create PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(150) = NULL,
    @PartnerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total Count
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText);

    -- Page Data
    SELECT q.*, p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE q.IsActive = 1 AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
      AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText)
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- عروض المشتريات (Purchase Quotations)
-- Tables and Stored Procedures
-- =============================================


-- 1. إنشاء الـ Schema إذا لم تكن موجودة
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Purchases')
BEGIN
    EXEC('CREATE SCHEMA [Purchases]')
END
GO

-- 2. جدول رأس عرض المشتريات
IF OBJECT_ID('[Purchases].[PurchaseQuoteHeader]', 'U') IS NULL 
begin
CREATE TABLE [Purchases].[PurchaseQuoteHeader](
    [PurchaseQuoteID] INT IDENTITY(1,1) PRIMARY KEY,
    [PartnerID] INT NOT NULL,
    [QuoteDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [ExpiryDate] DATETIME NULL,
    [Notes] NVARCHAR(500) NULL,
    [CreatedAt] DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_PurchaseQuote_Partner FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID)
	
);
end;
GO

-- 3. جدول تفاصيل عرض المشتريات
IF OBJECT_ID('[Purchases].[PurchaseQuoteDetails]', 'U') IS NULL 
begin
CREATE TABLE [Purchases].[PurchaseQuoteDetails](
    [DetailID] INT IDENTITY(1,1) PRIMARY KEY,
    [PurchaseQuoteID] INT NOT NULL,
    [ProductID] INT NOT NULL,
    [Quantity] DECIMAL(18,2) NOT NULL DEFAULT 1,
    [UnitPrice] DECIMAL(18,3) NOT NULL,
    CONSTRAINT FK_Details_Header FOREIGN KEY (PurchaseQuoteID) REFERENCES [Purchases].[PurchaseQuoteHeader](PurchaseQuoteID) ON DELETE CASCADE,
    CONSTRAINT FK_Details_Product FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID)
);
end;
GO


-- 4. إجراء الحفظ (Header + Details)

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
            T.Item.value('@UnitPrice', 'DECIMAL(18,3)')
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

IF OBJECT_ID('[Purchases].[sp_PurchaseQuote_GetPaged]', 'P') IS NOT NULL DROP PROCEDURE [Purchases].[sp_PurchaseQuote_GetPaged];
GO
CREATE PROCEDURE [Purchases].[sp_PurchaseQuote_GetPaged]
    @PageNumber INT = 1,
    @PageSize INT = 20,
    @SearchText NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- النتيجة الأولى: إجمالي عدد السجلات المطابقة للبحث
    SELECT COUNT(*) 
    FROM [Purchases].[PurchaseQuoteHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    WHERE (@SearchText IS NULL 
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR CAST(h.PurchaseQuoteID AS NVARCHAR) LIKE '%' + @SearchText + '%');

    -- النتيجة الثانية: بيانات الصفحة المطلوبة
    SELECT 
        h.PurchaseQuoteID,
        h.PartnerID,
        p.PartnerName,
        h.QuoteDate,
        h.ExpiryDate,
        h.Notes
    FROM [Purchases].[PurchaseQuoteHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    WHERE (@SearchText IS NULL 
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR CAST(h.PurchaseQuoteID AS NVARCHAR) LIKE '%' + @SearchText + '%')
    ORDER BY h.PurchaseQuoteID DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO


 
-- Description: جلب كافة عروض المشتريات الخاصة بمورد معين
-- =============================================
IF OBJECT_ID('[Purchases].[sp_PurchaseQuote_GetByPartner]', 'P') IS NOT NULL DROP PROCEDURE [Purchases].[sp_PurchaseQuote_GetByPartner];
GO
CREATE PROCEDURE [Purchases].[sp_PurchaseQuote_GetByPartner]
    @PartnerID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        h.PurchaseQuoteID,
        h.PartnerID,
        h.QuoteDate,
        h.ExpiryDate,
        h.Notes
    FROM [Purchases].[PurchaseQuoteHeader] h
    WHERE h.PartnerID = @PartnerID
    ORDER BY h.PurchaseQuoteID DESC; -- ترتيب تنازلي لعرض أحدث العروض أولاً
END
GO


-- 1. [Sales].[sp_Invoice_Save_XML]
-- نسخة مطورة تدعم حفظ التفاصيل عبر XML لتجنب التعارض مع الإجراء القديم
IF OBJECT_ID('[Sales].[sp_Invoice_Save_XML]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_Save_XML];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Save_XML]
    @InvID            INT OUTPUT,
    @InvType          NVARCHAR(20),
    @InvDate          DATETIME,
    @PartnerID        INT,
    @WarehouseID      INT,
    @TotalAmount      DECIMAL(18, 3),
    @Discount         DECIMAL(18, 3),
    @NetAmount        DECIMAL(18, 3),
    @PaidAmount       DECIMAL(18, 3),
    @Remainder        DECIMAL(18, 3),
    @UserID           INT,
    @Notes            NVARCHAR(255),
    @IsPosted         BIT           = 0,
    @ReferenceNo      NVARCHAR(50)  = NULL,
    @PaymentAccountID INT           = NULL,
    @ShiftID          INT           = NULL,
    @DetailsXml       XML           = NULL,
    @TempCustomerName NVARCHAR(150) = NULL,
    @TempPhone        VARCHAR(20)   = NULL,
    @TempAddress      NVARCHAR(255) = NULL,
    @TempDeliveryDate DATE          = NULL,
    @TempDeliveryTime VARCHAR(50)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- حفظ الرأس
        IF @InvID = 0
        BEGIN
            INSERT INTO [Sales].[InvoiceHeader] 
                (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, Discount, NetAmount, PaidAmount, Remainder, UserID, Notes, IsPosted, ReferenceNo, PaymentAccountID, ShiftID)
            VALUES 
                (@InvType, @InvDate, @PartnerID, @WarehouseID, @TotalAmount, @Discount, @NetAmount, @PaidAmount, @Remainder, @UserID, @Notes, @IsPosted, @ReferenceNo, @PaymentAccountID, @ShiftID);
            SET @InvID = CAST(SCOPE_IDENTITY() AS INT);
        END
        ELSE
        BEGIN
            UPDATE [Sales].[InvoiceHeader] 
            SET InvType = @InvType, InvDate = @InvDate, PartnerID = @PartnerID, WarehouseID = @WarehouseID, 
                TotalAmount = @TotalAmount, Discount = @Discount, NetAmount = @NetAmount, 
                PaidAmount = @PaidAmount, Remainder = @Remainder, UserID = @UserID, Notes = @Notes,
                IsPosted = @IsPosted, ReferenceNo = @ReferenceNo, PaymentAccountID = @PaymentAccountID,
                ShiftID = ISNULL(@ShiftID, ShiftID)
            WHERE InvID = @InvID;
            
            IF EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('[Sales].[InvoiceDetail]'))
                DELETE FROM [Sales].[InvoiceDetail] WHERE InvID = @InvID;
            ELSE IF EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
                DELETE FROM [Sales].[InvoiceDetails] WHERE InvID = @InvID;
        END

        -- إدراج التفاصيل من الـ XML
        IF @DetailsXml IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('[Sales].[InvoiceDetail]'))
            BEGIN
                INSERT INTO [Sales].[InvoiceDetail] (InvID, ProductID, UnitPrice, Quantity, TotalPrice, CostPrice)
                SELECT 
                    @InvID,
                    T.Item.value('@ProductID', 'INT'),
                    T.Item.value('@UnitPrice', 'DECIMAL(18,3)'),
                    T.Item.value('@Quantity', 'DECIMAL(18,3)'),
                    T.Item.value('@TotalPrice', 'DECIMAL(18,3)'),
                    T.Item.value('@CostPrice', 'DECIMAL(18,3)')
                FROM @DetailsXml.nodes('//Item') AS T(Item);
            END
            ELSE IF EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
            BEGIN
                INSERT INTO [Sales].[InvoiceDetails] (InvID, ProductID, UnitPrice, Quantity, TotalPrice, CostPrice)
                SELECT 
                    @InvID,
                    T.Item.value('@ProductID', 'INT'),
                    T.Item.value('@UnitPrice', 'DECIMAL(18,3)'),
                    T.Item.value('@Quantity', 'DECIMAL(18,3)'),
                    T.Item.value('@TotalPrice', 'DECIMAL(18,3)'),
                    T.Item.value('@CostPrice', 'DECIMAL(18,3)')
                FROM @DetailsXml.nodes('//Item') AS T(Item);
            END
        END

        COMMIT TRANSACTION;
        SELECT @InvID AS InvID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- إضافة عمود ShiftID كعمود اختياري (NULL)
IF NOT EXISTS (SELECT * FROM sys.columns 
               WHERE object_id = OBJECT_ID('[Sales].[InvoiceHeader]') 
               AND name = 'ShiftID')
BEGIN
    ALTER TABLE [Sales].[InvoiceHeader] ADD ShiftID INT NULL;
    PRINT 'Column ShiftID added successfully.';
END
ELSE
BEGIN
    PRINT 'Column ShiftID already exists.';
END
GO
 
IF OBJECT_ID('[Sales].[sp_Invoice_Save_XML]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_Save_XML];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Save_XML]
    @InvID INT OUTPUT,
    @InvType NVARCHAR(20),
    @InvDate DATETIME,
    @PartnerID INT,
    @WarehouseID INT,
    @TotalAmount DECIMAL(18, 3),
    @Discount DECIMAL(18, 3),
    @NetAmount DECIMAL(18, 3),
    @PaidAmount DECIMAL(18, 3),
    @Remainder DECIMAL(18, 3),
    @UserID INT,
    @Notes NVARCHAR(255),
    @IsPosted BIT = 0,
    @ReferenceNo NVARCHAR(50) = NULL,
    @PaymentAccountID INT = NULL,
    @ShiftID INT = NULL,         -- ✨ تمت الإضافة هنا بـ NULL افتراضياً
    @DetailsXml XML 
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
	-- قيمه افتراضيه لو مفيش حساب للسداد
	
        -- حفظ الرأس
        IF @InvID = 0
        BEGIN
            INSERT INTO [Sales].[InvoiceHeader] 
                (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, Discount, NetAmount, PaidAmount, Remainder, UserID, Notes, IsPosted, ReferenceNo, PaymentAccountID, ShiftID)
            VALUES 
                (@InvType, @InvDate, @PartnerID, @WarehouseID, @TotalAmount, @Discount, @NetAmount, @PaidAmount, @Remainder, @UserID, @Notes, @IsPosted, @ReferenceNo, @PaymentAccountID, @ShiftID); -- ✨ تمت الإضافة
            SET @InvID = CAST(SCOPE_IDENTITY() AS INT);
        END
        ELSE
        BEGIN
            UPDATE [Sales].[InvoiceHeader] 
            SET InvType = @InvType, InvDate = @InvDate, PartnerID = @PartnerID, WarehouseID = @WarehouseID, 
                TotalAmount = @TotalAmount, Discount = @Discount, NetAmount = @NetAmount, 
                PaidAmount = @PaidAmount, Remainder = @Remainder, UserID = @UserID, Notes = @Notes,
                IsPosted = @IsPosted, ReferenceNo = @ReferenceNo, PaymentAccountID = @PaymentAccountID,
                ShiftID = ISNULL(ShiftID, @ShiftID)   -- ✨ عدم تغيير ShiftID إذا كان موجوداً مسبقاً
            WHERE InvID = @InvID;
            
            DELETE FROM [Sales].[InvoiceDetails] WHERE InvID = @InvID;
        END

        -- إدراج التفاصيل من الـ XML
        INSERT INTO [Sales].[InvoiceDetails] (InvID, ProductID, UnitPrice, Quantity, TotalPrice, CostPrice)
        SELECT 
            @InvID,
            T.Item.value('@ProductID', 'INT'),
            T.Item.value('@UnitPrice', 'DECIMAL(18,3)'),
            T.Item.value('@Quantity', 'DECIMAL(18,3)'),
            T.Item.value('@TotalPrice', 'DECIMAL(18,3)'),
            T.Item.value('@CostPrice', 'DECIMAL(18,3)')
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
    @QuoteID INT OUTPUT,
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
GO


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
    WHERE d.InvID = @InvID
    Order by d.DetID ;
END
GO


-- [Sales].[sp_Quotations_GetPaged]
-- يُستدعى من QuoteService.GetQuotesPaged لعرض سجل عروض الأسعار مع ترقيم الصفحات
IF OBJECT_ID('[Sales].[sp_Quotations_GetPaged]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Quotations_GetPaged];
GO

CREATE PROCEDURE [Sales].[sp_Quotations_GetPaged]
    @PageNumber INT = 1,
    @PageSize   INT = 20,
    @SearchText NVARCHAR(200) = NULL,
    @PartnerID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. إجمالي عدد السجلات
    SELECT COUNT(*) AS TotalCount
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE
        q.IsActive = 1 
        AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
        AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
        AND (
            @SearchText IS NULL
            OR @SearchText = ''
            OR p.PartnerName LIKE N'%' + @SearchText + N'%'
            OR CAST(q.QuoteID AS NVARCHAR) LIKE N'%' + @SearchText + N'%'
        );

    -- 2. البيانات المرقّمة
    SELECT
        q.QuoteID,
        q.PartnerID,
        q.QuoteDate,
        q.ExpiryDate,
        q.IsActive,
        q.Notes,
        p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE
        q.IsActive = 1 
        AND (q.ExpiryDate IS NULL OR q.ExpiryDate >= CAST(GETDATE() AS DATE))
        AND (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
        AND (
            @SearchText IS NULL
            OR @SearchText = ''
            OR p.PartnerName LIKE N'%' + @SearchText + N'%'
            OR CAST(q.QuoteID AS NVARCHAR) LIKE N'%' + @SearchText + N'%'
        )
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- [Sales].[sp_Quotations_GetAll_Paged]
-- يُستدعى من شاشة سجل عروض الأسعار بـ WPF لعرض كافة عروض الأسعار (القديمة والجديدة والفعالة وغير الفعالة)
IF OBJECT_ID('[Sales].[sp_Quotations_GetAll_Paged]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Quotations_GetAll_Paged];
GO

CREATE PROCEDURE [Sales].[sp_Quotations_GetAll_Paged]
    @PageNumber INT = 1,
    @PageSize   INT = 20,
    @SearchText NVARCHAR(150) = NULL,
    @PartnerID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- 1. إجمالي عدد السجلات (جميع عروض الأسعار: القديمة والجديدة والفعالة وغير الفعالة)
    SELECT COUNT(*) AS TotalCount 
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText);

    -- 2. البيانات المرقّمة
    SELECT 
        q.QuoteID,
        q.PartnerID,
        q.QuoteDate,
        q.ExpiryDate,
        q.IsActive,
        q.Notes,
        p.PartnerName
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@PartnerID IS NULL OR q.PartnerID = @PartnerID)
      AND (@SearchText IS NULL OR @SearchText = ''
           OR p.PartnerName LIKE '%' + @SearchText + '%'
           OR q.Notes LIKE '%' + @SearchText + '%'
           OR CAST(q.QuoteID AS NVARCHAR) = @SearchText)
    ORDER BY q.QuoteDate DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- Shifts Module (POS)
-- =============================================

IF OBJECT_ID('Sales.Shifts', 'U') IS NULL
BEGIN
    CREATE TABLE [Sales].[Shifts] (
        [ShiftID] INT IDENTITY(1,1) PRIMARY KEY,
        [UserID] INT NOT NULL,
        [StartTime] DATETIME NOT NULL DEFAULT GETDATE(),
        [EndTime] DATETIME NULL,
        [StartingCash] DECIMAL(18, 2) NOT NULL DEFAULT 0,
        [EndingCash] DECIMAL(18, 3) NULL,
        [Status] NVARCHAR(20) NOT NULL DEFAULT 'Open', -- 'Open', 'Closed'
        FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID])
    );
END
GO


IF NOT EXISTS (SELECT * FROM sys.foreign_keys 
               WHERE object_id = OBJECT_ID('[Sales].[FK_InvoiceHeader_Shifts]') 
               AND parent_object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
BEGIN
    ALTER TABLE [Sales].[InvoiceHeader] 
    ADD CONSTRAINT FK_InvoiceHeader_Shifts 
    FOREIGN KEY (ShiftID) REFERENCES [Sales].[Shifts](ShiftID);
    PRINT 'Constraint FK_InvoiceHeader_Shifts added successfully.';
END
ELSE
BEGIN
    PRINT 'Constraint FK_InvoiceHeader_Shifts already exists.';
END
GO

-- 1. Open Shift
IF OBJECT_ID('[Sales].[sp_Shift_Open]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_Open];
GO
CREATE PROCEDURE [Sales].[sp_Shift_Open]
    @UserID INT,
    @StartingCash DECIMAL(18, 2),
    @ShiftID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if user already has an open shift
    IF EXISTS (SELECT 1 FROM [Sales].[Shifts] WHERE UserID = @UserID AND Status = 'Open')
    BEGIN
        RAISERROR('المستخدم لديه وردية مفتوحة بالفعل.', 16, 1);
        RETURN;
    END

    INSERT INTO [Sales].[Shifts] (UserID, StartingCash, Status)
    VALUES (@UserID, @StartingCash, 'Open');
    
    SET @ShiftID = SCOPE_IDENTITY();
END
GO

-- 2. Close Shift
IF OBJECT_ID('[Sales].[sp_Shift_Close]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_Close];
GO
CREATE PROCEDURE [Sales].[sp_Shift_Close]
    @ShiftID INT,
    @EndingCash DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [Sales].[Shifts]
    SET EndTime = GETDATE(),
        EndingCash = @EndingCash,
        Status = 'Closed'
    WHERE ShiftID = @ShiftID AND Status = 'Open';
END
GO

-- 3. Get Active Shift for User
IF OBJECT_ID('[Sales].[sp_Shift_GetActive]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_GetActive];
GO
CREATE PROCEDURE [Sales].[sp_Shift_GetActive]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP 1 ShiftID, UserID, StartTime, StartingCash, Status
    FROM [Sales].[Shifts]
    WHERE UserID = @UserID AND Status = 'Open'
    ORDER BY ShiftID DESC, StartTime DESC;
END
GO

-- =============================================
-- Trigger: trg_Shifts_StatusChange
-- عند تعديل حالة الوردية [Status] يتم حذف القيد القديم وإنشاؤه مجدداً
-- =============================================
IF OBJECT_ID('[Sales].[trg_Shifts_StatusChange]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_Shifts_StatusChange];
GO

CREATE TRIGGER [Sales].[trg_Shifts_StatusChange]
ON [Sales].[Shifts]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- التفعيل فقط إذا شمل التحديث تغيير عمود Status
    IF NOT UPDATE(Status) RETURN;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ShiftID INT;
        DECLARE @NewStatus NVARCHAR(50);
    DECLARE @OldStatus NVARCHAR(50);

    DECLARE shift_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT i.ShiftID, i.Status AS NewStatus, d.Status AS OldStatus
    FROM inserted i
    INNER JOIN deleted d ON i.ShiftID = d.ShiftID
    WHERE i.Status <> d.Status;

    OPEN shift_cursor;
    FETCH NEXT FROM shift_cursor INTO @ShiftID, @NewStatus, @OldStatus;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 1. مسح القيد القديم للوردية من قيود اليومية
        DELETE FROM [Accounting].[JournalEntries]
        WHERE ReferenceType = 'ShiftClose' AND ReferenceID = @ShiftID;

        IF OBJECT_ID('[Accounting].[JournalHeader]', 'U') IS NOT NULL AND OBJECT_ID('[Accounting].[JournalEntryDetails]', 'U') IS NOT NULL
        BEGIN
            DELETE FROM [Accounting].[JournalEntryDetails]
            WHERE JID IN (
                SELECT JID FROM [Accounting].[JournalHeader]
                WHERE ReferenceType = 'ShiftClose' AND ReferenceID = @ShiftID
            );

            DELETE FROM [Accounting].[JournalHeader]
            WHERE ReferenceType = 'ShiftClose' AND ReferenceID = @ShiftID;
        END

        -- 2. إعادة إنشاء القيد عند تحول الحالة إلى Closed أو Open حسب وجود فرق كاش
        IF @NewStatus IN ('Closed', 'Open')
        BEGIN
            DECLARE @StartingCash DECIMAL(18,3) = 0;
            DECLARE @EndingCash DECIMAL(18,3) = 0;
            DECLARE @UserID INT;
            DECLARE @TotalPaidSales DECIMAL(18,3) = 0;
            DECLARE @TotalPaidPurchases DECIMAL(18,3) = 0;
            DECLARE @TotalReceiptV DECIMAL(18,3) = 0;
            DECLARE @TotalPaymentV DECIMAL(18,3) = 0;
            DECLARE @ExpectedCash DECIMAL(18,3) = 0;
            DECLARE @Difference DECIMAL(18,3) = 0;

            SELECT @StartingCash = ISNULL(StartingCash, 0),
                   @EndingCash = ISNULL(EndingCash, 0),
                   @UserID = UserID
            FROM [Sales].[Shifts]
            WHERE ShiftID = @ShiftID;

            -- مبيعات مسددة
            SELECT @TotalPaidSales = ISNULL(SUM(CAST(PaidAmount AS DECIMAL(18,3))), 0)
            FROM [Sales].[InvoiceHeader]
            WHERE InvType = 'Sales' AND ShiftID = @ShiftID;

            -- مشتريات مسددة
            SELECT @TotalPaidPurchases = ISNULL(SUM(CAST(PaidAmount AS DECIMAL(18,3))), 0)
            FROM [Sales].[InvoiceHeader]
            WHERE InvType = 'Purchase' AND ShiftID = @ShiftID;

            -- سندات القبض
            SELECT @TotalReceiptV = ISNULL(SUM(CAST(Amount AS DECIMAL(18,3))), 0)
            FROM [Accounting].[Vouchers]
            WHERE VoucherType = 'Receipt' AND ShiftID = @ShiftID;

            -- سندات الصرف
            SELECT @TotalPaymentV = ISNULL(SUM(CAST(Amount AS DECIMAL(18,3))), 0)
            FROM [Accounting].[Vouchers]
            WHERE VoucherType = 'Payment' AND ShiftID = @ShiftID;

            SET @ExpectedCash = @StartingCash + @TotalPaidSales - @TotalPaidPurchases + @TotalReceiptV - @TotalPaymentV;
            SET @Difference = @EndingCash - @ExpectedCash;

            -- إنشاء القيد فقط إذا كان هناك فرق كاش فعلي
            IF ABS(@Difference) > 0.001
            BEGIN
                DECLARE @CashboxID INT;
                DECLARE @RevenueIDchild INT;
                DECLARE @AbsDiff DECIMAL(18,2) = CAST(ABS(@Difference) AS DECIMAL(18,2));
                DECLARE @JournalDesc NVARCHAR(255);
                DECLARE @EntryNo INT;
                DECLARE @DebitAccID INT;
                DECLARE @CreditAccID INT;

                SELECT TOP 1 @CashboxID = AccountID
                FROM [Accounting].[ChartOfAccounts]
                WHERE AccountCode = '1101';

                SELECT TOP 1 @RevenueIDchild = AccountID
                FROM [Accounting].[ChartOfAccounts]
                WHERE AccountCode = '411';

                IF @CashboxID IS NOT NULL AND @RevenueIDchild IS NOT NULL
                BEGIN
                    IF @Difference > 0
                    BEGIN
                        SET @JournalDesc = N'فائض كاش - ' + CASE WHEN @NewStatus = 'Closed' THEN N'إغلاق' ELSE N'تعديل' END + N' الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                        SET @DebitAccID  = @CashboxID;
                        SET @CreditAccID = @RevenueIDchild;
                    END
                    ELSE
                    BEGIN
                        SET @JournalDesc = N'عجز كاش - ' + CASE WHEN @NewStatus = 'Closed' THEN N'إغلاق' ELSE N'تعديل' END + N' الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                        SET @DebitAccID  = @RevenueIDchild;
                        SET @CreditAccID = @CashboxID;
                    END

                    IF OBJECT_ID('[Accounting].[seq_EntryNo]', 'SO') IS NOT NULL
                    BEGIN
                        SET @EntryNo = NEXT VALUE FOR [Accounting].[seq_EntryNo];

                        INSERT INTO [Accounting].[JournalEntries]
                            (EntryNo, EntryDate, ReferenceType, ReferenceID,
                             AccountID, DebitAmount, CreditAmount, Description, UserID)
                        VALUES
                            (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                             @DebitAccID, @AbsDiff, 0, @JournalDesc, @UserID),
                            (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                             @CreditAccID, 0, @AbsDiff, @JournalDesc, @UserID);
                    END
                END
            END
        END

        -- 3. تحديث حالة الترحيل IsPosted للفواتير والسندات التابعة للوردية
        IF @NewStatus = 'Closed'
        BEGIN
            -- عند إغلاق الوردية: ترحيل كافة الفواتير والسندات المرتبطة بهذه الوردية
            UPDATE [Sales].[InvoiceHeader]
            SET IsPosted = 1
            WHERE ShiftID = @ShiftID AND IsPosted = 0;

            UPDATE [Accounting].[Vouchers]
            SET IsPosted = 1
            WHERE ShiftID = @ShiftID AND IsPosted = 0;
        END
        ELSE IF @NewStatus = 'Open'
        BEGIN
            -- عند إعادة فتح الوردية: الغاء ترحيل كافة الفواتير والسندات (تحويلها إلى غير مرحل 0)
            UPDATE [Sales].[InvoiceHeader]
            SET IsPosted = 0
            WHERE ShiftID = @ShiftID AND IsPosted = 1;

            UPDATE [Accounting].[Vouchers]
            SET IsPosted = 0
            WHERE ShiftID = @ShiftID AND IsPosted = 1;
        END

        FETCH NEXT FROM shift_cursor INTO @ShiftID, @NewStatus, @OldStatus;
    END

    CLOSE shift_cursor;
    DEALLOCATE shift_cursor;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PrinterSettings' AND schema_id = SCHEMA_ID('Settings'))
BEGIN
CREATE TABLE [Settings].[PrinterSettings] (
    [SettingID] INT IDENTITY(1,1) PRIMARY KEY,
    [MachineHWID] VARCHAR(100) NOT NULL UNIQUE,     -- البصمة الفريدة للجهاز لربط الإعدادات
    [ConnectionType] VARCHAR(50) NOT NULL,           -- نوع الاتصال (None, Network, Bluetooth)
    [IPAddress] VARCHAR(50) NULL,                    -- عنوان الـ IP (لطابعات الشبكة)
    [Port] INT NULL DEFAULT 9100,                     -- منفذ الاتصال
    [BluetoothDevice] VARCHAR(255) NULL,             -- اسم/معرف جهاز البلوتوث
    [CreatedAt] DATETIME DEFAULT GETDATE(),
    [UpdatedAt] DATETIME DEFAULT GETDATE()
);
end
GO

IF OBJECT_ID('[Settings].[sp_PrinterSettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_PrinterSettings_Save];
GO
CREATE PROCEDURE [Settings].[sp_PrinterSettings_Save]
    @MachineHWID VARCHAR(100),
    @ConnectionType VARCHAR(50),
    @IPAddress VARCHAR(50) = NULL,
    @Port INT = 9100,
    @BluetoothDevice VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS(SELECT 1 FROM [Settings].[PrinterSettings] WHERE [MachineHWID] = @MachineHWID)
    BEGIN
        UPDATE [Settings].[PrinterSettings]
        SET [ConnectionType] = @ConnectionType,
            [IPAddress] = @IPAddress,
            [Port] = @Port,
            [BluetoothDevice] = @BluetoothDevice,
            [UpdatedAt] = GETDATE()
        WHERE [MachineHWID] = @MachineHWID;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[PrinterSettings] ([MachineHWID], [ConnectionType], [IPAddress], [Port], [BluetoothDevice])
        VALUES (@MachineHWID, @ConnectionType, @IPAddress, @Port, @BluetoothDevice);
    END
END
GO

IF OBJECT_ID('[Settings].[sp_PrinterSettings_Get]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_PrinterSettings_Get];
GO
CREATE PROCEDURE [Settings].[sp_PrinterSettings_Get]
    @MachineHWID VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP 1 [SettingID], [MachineHWID], [ConnectionType], [IPAddress], [Port], [BluetoothDevice]
    FROM [Settings].[PrinterSettings]
    WHERE [MachineHWID] = @MachineHWID;
END
GO


-- =============================================
-- عروض المشتريات والمبيعات للشركاء (POS الجديد)
-- =============================================


-- 6. إجراء جلب الموردين أصحاب العروض النشطة (Purchases)
IF OBJECT_ID('[Purchases].[sp_PurchaseQuote_GetActivePartners]', 'P') IS NOT NULL DROP PROCEDURE [Purchases].[sp_PurchaseQuote_GetActivePartners];
GO
CREATE PROCEDURE [Purchases].[sp_PurchaseQuote_GetActivePartners]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT p.PartnerID, p.PartnerName, p.Phone, p.Address, p.CurrentBalance
    FROM [Sales].[Partners] p
    INNER JOIN [Purchases].[PurchaseQuoteHeader] h ON p.PartnerID = h.PartnerID
    WHERE h.ExpiryDate IS NULL OR h.ExpiryDate >= GETDATE()
    ORDER BY p.PartnerName;
END
GO

-- 7. إجراء جلب العملاء أصحاب العروض النشطة (Sales)
IF OBJECT_ID('[Sales].[sp_SalesQuote_GetActivePartners]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_SalesQuote_GetActivePartners];
GO
CREATE PROCEDURE [Sales].[sp_SalesQuote_GetActivePartners]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT p.PartnerID, p.PartnerName, p.Phone, p.Address, p.CurrentBalance
    FROM [Sales].[Partners] p
    INNER JOIN [Sales].[Quotations] h ON p.PartnerID = h.PartnerID
    WHERE h.IsActive = 1 AND (h.ExpiryDate IS NULL OR h.ExpiryDate >= GETDATE())
    ORDER BY p.PartnerName;
END
GO

-- =============================================
-- sp_Invoice_GetAll_Pos (For POS daily report filter)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetAll_Pos]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_GetAll_Pos];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetAll_Pos]  
    @InvType NVARCHAR(20),
	@ShiftID int = null
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName,
        acc.AccountName AS PaymentAccountName,
        acc.AccountCode AS PaymentAccountCode
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
    WHERE h.InvType = @InvType AND (@ShiftID IS NULL OR h.ShiftID = @ShiftID)
    ORDER BY h.InvID DESC;
END
GO


-- ============================================================
-- ============================================================
-- SP 1: sp_Shift_GetSummary
-- جلب ملخص الوردية الكامل (المبيعات، الكاش، K-Net، السندات، العجز/الزيادة)
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetSummary];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetSummary] 
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- جلب المتغيرات الأساسية للوردية
    DECLARE @StartingCash DECIMAL(18,3) = 0;
    DECLARE @EndingCash   DECIMAL(18,3) = NULL;

    SELECT @StartingCash = ISNULL(StartingCash, 0), @EndingCash = EndingCash
    FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

    -- حسابات الكاش والمبيعات والشبكة
    DECLARE @TotalSales              DECIMAL(18,3) = 0;
    DECLARE @TotalPurchases          DECIMAL(18,3) = 0;
    DECLARE @SalesCount              INT = 0;
    DECLARE @PurchasesCount          INT = 0;
    DECLARE @TotalPaidSalesCash      DECIMAL(18,3) = 0;
    DECLARE @TotalPaidSalesNonCash   DECIMAL(18,3) = 0;
    DECLARE @TotalRemainder          DECIMAL(18,3) = 0;
    DECLARE @TotalPaidPurchasesCash  DECIMAL(18,3) = 0;
    DECLARE @TotalPaidPurchasesNonCash DECIMAL(18,3) = 0;
    DECLARE @TotalPurchasesRemainder DECIMAL(18,3) = 0;
    DECLARE @TotalReceiptVouchers    DECIMAL(18,3) = 0;
    DECLARE @TotalPaymentVouchers    DECIMAL(18,3) = 0;

    -- 1. إجماليات فواتير المبيعات
    SELECT 
        @TotalSales = ISNULL(SUM(CAST(NetAmount AS DECIMAL(18,3))), 0),
        @SalesCount = COUNT(*),
        @TotalRemainder = ISNULL(SUM(CAST(Remainder AS DECIMAL(18,3))), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Sales' AND ShiftID = @ShiftID;

    -- 2. إجماليات فواتير المشتريات
    SELECT 
        @TotalPurchases = ISNULL(SUM(CAST(NetAmount AS DECIMAL(18,3))), 0),
        @PurchasesCount = COUNT(*),
        @TotalPurchasesRemainder = ISNULL(SUM(CAST(Remainder AS DECIMAL(18,3))), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Purchase' AND ShiftID = @ShiftID;

    -- 3. مبيعات الكاش النقدية الفعلية بالدرج (Splits الكاش + Direct الكاش)
    SELECT @TotalPaidSalesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
    FROM (
        -- فواتير مجزأة: الدفعات النقدية
        SELECT sp.Amount AS PaidCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND (
              c.AccountID IS NULL
              OR NOT (
                  c.AccountCode LIKE '112%' 
                  OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                  OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                  OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                  OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
              )
          )

        UNION ALL

        -- فواتير مباشرة (غير مجزأة): مسددة كاش
        SELECT h.PaidAmount AS PaidCash
        FROM [Sales].[InvoiceHeader] h
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountID IS NULL
              OR NOT (
                  c.AccountCode LIKE '112%' 
                  OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                  OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                  OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                  OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
              )
          )
    ) CashSalesUnion;

    -- 4. مبيعات الشبكة K-Net / فيزا / بطاقات / بنك (Splits + Direct)
    SELECT @TotalPaidSalesNonCash = ISNULL(SUM(CAST(PaidNonCash AS DECIMAL(18,3))), 0)
    FROM (
        -- فواتير مجزأة: الدفعات غير النقدية
        SELECT sp.Amount AS PaidNonCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        INNER JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND (
              c.AccountCode LIKE '112%' 
              OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
              OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
              OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
              OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
          )

        UNION ALL

        -- فواتير مباشرة (غير مجزأة): مسددة شبكة/KNET
        SELECT h.PaidAmount AS PaidNonCash
        FROM [Sales].[InvoiceHeader] h
        INNER JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountCode LIKE '112%' 
              OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
              OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
              OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
              OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
          )
    ) NonCashSalesUnion;

    -- 5. مشتريات الكاش النقدية الفعلية من الصندوق
    SELECT @TotalPaidPurchasesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
    FROM (
        SELECT sp.Amount AS PaidCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND (
              c.AccountID IS NULL
              OR NOT (
                  c.AccountCode LIKE '112%' 
                  OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                  OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                  OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                  OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
              )
          )

        UNION ALL

        SELECT h.PaidAmount AS PaidCash
        FROM [Sales].[InvoiceHeader] h
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountID IS NULL
              OR NOT (
                  c.AccountCode LIKE '112%' 
                  OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                  OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                  OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                  OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
              )
          )
    ) CashPurchasesUnion;

    -- 6. سندات القبض الكاش بالدرج
    SELECT @TotalReceiptVouchers = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON v.AccountID = c.AccountID
    WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
      AND (
          c.AccountID IS NULL
          OR NOT (
              c.AccountCode LIKE '112%' 
              OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
              OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
              OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
              OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
          )
      );

    -- 7. سندات الصرف الكاش من الدرج (المصروفات النقدية)
    SELECT @TotalPaymentVouchers = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON v.AccountID = c.AccountID
    WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
      AND (
          c.AccountID IS NULL
          OR NOT (
              c.AccountCode LIKE '112%' 
              OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
              OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
              OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
              OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
          )
      );

    -- 8. حساب النقدية المتوقعة بالدرج
    DECLARE @ExpectedCash DECIMAL(18,3) = @StartingCash 
                                        + @TotalPaidSalesCash 
                                        - @TotalPaidPurchasesCash 
                                        + @TotalReceiptVouchers 
                                        - @TotalPaymentVouchers;

    DECLARE @Difference DECIMAL(18,3) = ISNULL(@EndingCash, @ExpectedCash) - @ExpectedCash;

    -- النتيجة النهائية مع التوافق التام لكافة المنصات
    SELECT
        s.ShiftID,
        s.UserID,
        s.StartTime,
        s.EndTime,
        s.StartingCash,
        s.EndingCash,
        s.Status,
        u.FullName AS UserName,

        @TotalSales             AS TotalSales,
        @TotalPurchases         AS TotalPurchases,
        @SalesCount             AS SalesCount,
        @PurchasesCount         AS PurchasesCount,

        @TotalPaidSalesCash     AS TotalPaidSales,        -- التوافق مع الكود القديم (مبيعات الكاش فقط)
        @TotalPaidSalesCash     AS TotalCashSales,        -- لشاشة إغلاق الوردية والطباعة
        @TotalPaidSalesCash     AS CashSales,             -- لطباعة وتقارير Flutter
        @TotalPaidSalesNonCash  AS TotalNonCashSales,     -- مبيعات غير نقدية
        @TotalPaidSalesNonCash  AS TotalKnetSales,        -- لطباعة وتقارير Flutter
        @TotalPaidSalesNonCash  AS KnetSales,             -- لطباعة Flutter
        @TotalPaidSalesNonCash  AS CardSales,             -- للبطاقات
        @TotalRemainder         AS TotalRemainder,

        @TotalPaidPurchasesCash AS TotalPaidPurchases,    -- مشتريات كاش فقط
        @TotalPaidPurchasesCash AS TotalCashPurchases,
        @TotalPurchasesRemainder AS TotalPurchasesRemainder,

        @TotalReceiptVouchers   AS TotalReceiptVouchers,
        @TotalPaymentVouchers   AS TotalPaymentVouchers,
        @TotalPaymentVouchers   AS TotalExpenses,

        @ExpectedCash           AS ExpectedCash,
        ISNULL(s.EndingCash, @ExpectedCash) AS ActualCash,
        @Difference             AS Difference

    FROM [Sales].[Shifts] s
    LEFT JOIN [Security].[Users] u ON s.UserID = u.UserID
    WHERE s.ShiftID = @ShiftID;
END
GO

-- ============================================================
-- SP 2: sp_Shift_Close
-- إغلاق الوردية وترحيل الفواتير والسندات وقيد تسوية فرق الكاش
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_Close]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_Close];
GO

CREATE PROCEDURE [Sales].[sp_Shift_Close]
    @ShiftID    INT,
    @EndingCash DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- ① إغلاق الوردية
        UPDATE [Sales].[Shifts]
        SET EndTime    = GETDATE(),
            EndingCash = @EndingCash,
            Status     = 'Closed'
        WHERE ShiftID = @ShiftID AND Status = 'Open';

        IF @@ROWCOUNT = 0
            THROW 50001, 'الوردية غير موجودة أو مغلقة بالفعل', 1;

        -- ② جلب بيانات الوردية
        DECLARE @StartingCash       DECIMAL(18,3) = 0;
        DECLARE @UserID             INT;
        DECLARE @TotalPaidSalesCash DECIMAL(18,3) = 0;
        DECLARE @TotalPaidPurchasesCash DECIMAL(18,3) = 0;
        DECLARE @TotalReceiptV      DECIMAL(18,3) = 0;
        DECLARE @TotalPaymentV      DECIMAL(18,3) = 0;
        DECLARE @ExpectedCash       DECIMAL(18,3) = 0;
        DECLARE @Difference         DECIMAL(18,3) = 0;

        SELECT @StartingCash = ISNULL(StartingCash, 0), @UserID = UserID
        FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

        -- مبيعات مسددة كاش فقط بالدرج (Splits + Direct Cash)
        SELECT @TotalPaidSalesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
        FROM (
            SELECT sp.Amount AS PaidCash
            FROM [Sales].[InvoicePaymentSplits] sp
            INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
              AND (
                  c.AccountID IS NULL
                  OR NOT (
                      c.AccountCode LIKE '112%' 
                      OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                      OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                      OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                      OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
                  )
              )

            UNION ALL

            SELECT h.PaidAmount AS PaidCash
            FROM [Sales].[InvoiceHeader] h
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
              AND h.PaidAmount > 0
              AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
              AND (
                  c.AccountID IS NULL
                  OR NOT (
                      c.AccountCode LIKE '112%' 
                      OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                      OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                      OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                      OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
                  )
              )
        ) CashSalesUnion;

        -- مشتريات مسددة كاش فقط من الدرج (Splits + Direct Cash)
        SELECT @TotalPaidPurchasesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
        FROM (
            SELECT sp.Amount AS PaidCash
            FROM [Sales].[InvoicePaymentSplits] sp
            INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
              AND (
                  c.AccountID IS NULL
                  OR NOT (
                      c.AccountCode LIKE '112%' 
                      OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                      OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                      OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                      OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
                  )
              )

            UNION ALL

            SELECT h.PaidAmount AS PaidCash
            FROM [Sales].[InvoiceHeader] h
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
              AND h.PaidAmount > 0
              AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
              AND (
                  c.AccountID IS NULL
                  OR NOT (
                      c.AccountCode LIKE '112%' 
                      OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                      OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                      OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                      OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
                  )
              )
        ) CashPurchasesUnion;

        -- سندات القبض الكاش
        SELECT @TotalReceiptV = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
        FROM [Accounting].[Vouchers] v
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON v.AccountID = c.AccountID
        WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
          AND (
              c.AccountID IS NULL
              OR NOT (
                  c.AccountCode LIKE '112%' 
                  OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                  OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                  OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                  OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
              )
          );

        -- سندات الصرف الكاش
        SELECT @TotalPaymentV = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
        FROM [Accounting].[Vouchers] v
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON v.AccountID = c.AccountID
        WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
          AND (
              c.AccountID IS NULL
              OR NOT (
                  c.AccountCode LIKE '112%' 
                  OR c.AccountName LIKE N'%كي نت%' OR c.AccountName LIKE N'%فيزا%' OR c.AccountName LIKE N'%بنك%' 
                  OR c.AccountName LIKE N'%شيك%' OR c.AccountName LIKE N'%بطاق%' OR c.AccountName LIKE N'%شبك%' OR c.AccountName LIKE N'%مدى%' OR c.AccountName LIKE N'%لينك%' OR c.AccountName LIKE N'%رابط%'
                  OR LOWER(c.AccountName) LIKE '%knet%' OR LOWER(c.AccountName) LIKE '%k-net%' OR LOWER(c.AccountName) LIKE '%link%'
                  OR LOWER(c.AccountName) LIKE '%visa%' OR LOWER(c.AccountName) LIKE '%bank%' OR LOWER(c.AccountName) LIKE '%card%' OR LOWER(c.AccountName) LIKE '%master%'
              )
          );

        -- الكاش المتوقع = كاش الافتتاح + مبيعات نقدية - مشتريات نقدية + سندات قبض نقدية - سندات صرف نقدية
        SET @ExpectedCash = @StartingCash
                          + @TotalPaidSalesCash
                          - @TotalPaidPurchasesCash
                          + @TotalReceiptV
                          - @TotalPaymentV;

        SET @Difference = @EndingCash - @ExpectedCash;

        -- ③ قيد تسوية فرق الكاش (إن وُجد)
        IF ABS(@Difference) > 0.001
        BEGIN
            DECLARE @CashboxID      INT;
            DECLARE @RevenueIDchild INT;
            DECLARE @AbsDiff        DECIMAL(18,2) = CAST(ABS(@Difference) AS DECIMAL(18,2));
            DECLARE @JournalDesc    NVARCHAR(255);
            DECLARE @EntryNo        INT;
            DECLARE @DebitAccID     INT;
            DECLARE @CreditAccID    INT;

            SELECT TOP 1 @CashboxID = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE (AccountCode = '1101' OR AccountName LIKE N'%صندوق%' OR AccountName LIKE N'%كاش%' OR AccountCode LIKE '110%')
              AND IsTransactional = 1;

            SELECT TOP 1 @RevenueIDchild = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountCode = '412';

            IF @RevenueIDchild IS NULL
            BEGIN
                SELECT TOP 1 @RevenueIDchild = AccountID
                FROM [Accounting].[ChartOfAccounts]
                WHERE (AccountName LIKE N'%إيراد%' OR AccountName LIKE N'%أرباح%' OR AccountCode LIKE '4%')
                  AND IsTransactional = 1;
            END

            IF @CashboxID IS NOT NULL AND @RevenueIDchild IS NOT NULL
            BEGIN
                IF @Difference > 0
                BEGIN
                    SET @JournalDesc = N'فائض كاش - إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                    SET @DebitAccID  = @CashboxID;
                    SET @CreditAccID = @RevenueIDchild;
                END
                ELSE
                BEGIN
                    SET @JournalDesc = N'عجز كاش - إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                    SET @DebitAccID  = @RevenueIDchild;
                    SET @CreditAccID = @CashboxID;
                END

                IF OBJECT_ID('[Accounting].[seq_EntryNo]', 'SO') IS NOT NULL
                BEGIN
                    SET @EntryNo = NEXT VALUE FOR [Accounting].[seq_EntryNo];
                    INSERT INTO [Accounting].[JournalEntries]
                        (EntryNo, EntryDate, ReferenceType, ReferenceID,
                         AccountID, DebitAmount, CreditAmount, Description, UserID)
                    VALUES
                        (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                         @DebitAccID, @AbsDiff, 0, @JournalDesc, @UserID),
                        (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                         @CreditAccID, 0, @AbsDiff, @JournalDesc, @UserID);
                END
            END
        END

        -- ④ ترحيل الفواتير المرتبطة بهذه الوردية
        UPDATE [Sales].[InvoiceHeader]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID AND IsPosted = 0;

        -- ⑤ ترحيل السندات المرتبطة بهذه الوردية
        UPDATE [Accounting].[Vouchers]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID AND IsPosted = 0;

        COMMIT TRANSACTION;

        -- إرجاع ملخص للإغلاق
        SELECT
            @ShiftID            AS ShiftID,
            @StartingCash       AS StartingCash,
            @TotalPaidSalesCash AS TotalPaidSales,
            @TotalPaidPurchasesCash AS TotalPaidPurchases,
            @TotalReceiptV      AS TotalReceiptVouchers,
            @TotalPaymentV      AS TotalPaymentVouchers,
            @ExpectedCash       AS ExpectedCash,
            @EndingCash         AS ActualCash,
            @Difference         AS Difference;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('[Sales].[sp_Invoice_AddPayment_pos]', 'P') IS NOT NULL 
    DROP PROCEDURE [Sales].[sp_Invoice_AddPayment_pos];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_AddPayment_pos]
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

        IF @InvID IS NULL OR @Remainder IS NULL
        BEGIN RAISERROR(N'الفاتورة غير موجودة', 16, 1); RETURN; END

        IF @PaymentAmount <= 0 OR @PaymentAmount > @Remainder
        BEGIN RAISERROR(N'مبلغ السداد غير صحيح أو يتجاوز المتبقي', 16, 1); RETURN; END

        -- ① تحديث مبالغ الفاتورة دائماً بغض النظر عن IsPosted
        UPDATE [Sales].[InvoiceHeader]
        SET PaidAmount = PaidAmount + @PaymentAmount,
            Remainder  = Remainder  - @PaymentAmount,
			PaymentAccountID =@PaymentAccountID
        WHERE InvID = @InvID;

        -- ② إضافة قيود محاسبية فقط إذا كانت الفاتورة مرحّلة
        IF @IsPosted = 1
        BEGIN
            DECLARE @PartnerAccountID INT;
            SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

            DECLARE @EntryNo   INT           = NEXT VALUE FOR [Accounting].[seq_EntryNo];
            DECLARE @EntryDate DATE          = CAST(GETDATE() AS DATE);
            DECLARE @Desc      NVARCHAR(255) = N'سداد إضافي - فاتورة رقم ' + CAST(@InvID AS NVARCHAR);

            IF @InvType = 'Sales'
            BEGIN
                -- Dr Cash  /  Cr Customer
                INSERT INTO [Accounting].[JournalEntries]
                    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
                VALUES
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID, @PaymentAmount, 0,              @Desc, @UserID),
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  0,              @PaymentAmount, @Desc, @UserID);
            END
            ELSE -- Purchase
            BEGIN
                -- Dr Vendor  /  Cr Cash
                INSERT INTO [Accounting].[JournalEntries]
                    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
                VALUES
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  @PaymentAmount, 0,              @Desc, @UserID),
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID,  0,              @PaymentAmount, @Desc, @UserID);
            END
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

-- ============================================================
-- SP 1: sp_Shift_GetSummary
-- جلب ملخص الوردية (المبيعات، المشتريات، الكاش المتوقع)
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetSummary];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetSummary] 
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. تحديد ID حساب الصندوق الرئيسي (1101)
    DECLARE @CashAccountID INT;
    SELECT TOP 1 @CashAccountID = AccountID 
    FROM [Accounting].[ChartOfAccounts] 
    WHERE AccountCode = '1101';

    -- احتياطي في حال عدم وجود الكود 1101
    IF @CashAccountID IS NULL
    BEGIN
        SELECT TOP 1 @CashAccountID = AccountID 
        FROM [Accounting].[ChartOfAccounts] 
        WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1;
    END

    -- 2. جلب بيانات الوردية الأساسية والملخص المالي
    SELECT
        s.ShiftID,
        s.UserID,
        s.StartTime,
        s.EndTime,
        s.StartingCash,
        s.Status,
        u.FullName AS UserName,

        -- إجمالي المبيعات (NetAmount) في الوردية
        ISNULL((
            SELECT SUM(CAST(h.NetAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalSales,

        -- إجمالي المشتريات (NetAmount) في الوردية
        ISNULL((
            SELECT SUM(CAST(h.NetAmount AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalPurchases,

        -- عدد فواتير المبيعات
        ISNULL((
            SELECT COUNT(*)
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.ShiftID = @ShiftID
        ), 0) AS SalesCount,

        -- عدد فواتير المشتريات
        ISNULL((
            SELECT COUNT(*)
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.ShiftID = @ShiftID
        ), 0) AS PurchasesCount,

        -- ✅ 1. مبيعات الكاش النقدية الفعلية لحساب الصندوق 1101 بالدرج
        ISNULL((
            SELECT SUM(CAST(PaidCash AS DECIMAL(18,3)))
            FROM (
                SELECT sp.Amount AS PaidCash
                FROM [Sales].[InvoicePaymentSplits] sp
                INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND sp.PaymentAccountID = @CashAccountID

                UNION ALL

                SELECT h.PaidAmount AS PaidCash
                FROM [Sales].[InvoiceHeader] h
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND h.PaidAmount > 0
                  AND (h.PaymentAccountID = @CashAccountID OR h.PaymentAccountID IS NULL)
                  AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
            ) CashSalesUnion
        ), 0) AS TotalPaidSales,

        -- المتبقي الآجل للمبيعات
        ISNULL((
            SELECT SUM(CAST(h.Remainder AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Sales'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalRemainder,

        -- ✅ 2. مشتريات الكاش النقدية الفعلية من الصندوق 1101
        ISNULL((
            SELECT SUM(CAST(PaidCash AS DECIMAL(18,3)))
            FROM (
                SELECT sp.Amount AS PaidCash
                FROM [Sales].[InvoicePaymentSplits] sp
                INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
                WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
                  AND sp.PaymentAccountID = @CashAccountID

                UNION ALL

                SELECT h.PaidAmount AS PaidCash
                FROM [Sales].[InvoiceHeader] h
                WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
                  AND h.PaidAmount > 0
                  AND (h.PaymentAccountID = @CashAccountID OR h.PaymentAccountID IS NULL)
                  AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
            ) CashPurchasesUnion
        ), 0) AS TotalPaidPurchases,

        -- المتبقي الآجل للمشتريات
        ISNULL((
            SELECT SUM(CAST(h.Remainder AS DECIMAL(18,3)))
            FROM [Sales].[InvoiceHeader] h
            WHERE h.InvType = 'Purchase'
              AND h.ShiftID = @ShiftID
        ), 0) AS TotalPurchasesRemainder,

        -- ✅ 3. إجمالي سندات القبض الكاش لحساب الصندوق 1101
        ISNULL((
            SELECT SUM(CAST(v.Amount AS DECIMAL(18,3)))
            FROM [Accounting].[Vouchers] v
            WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
              AND (v.AccountID = @CashAccountID OR v.AccountID IS NULL)
        ), 0) AS TotalReceiptVouchers,

        -- ✅ 4. إجمالي سندات الصرف الكاش لحساب الصندوق 1101
        ISNULL((
            SELECT SUM(CAST(v.Amount AS DECIMAL(18,3)))
            FROM [Accounting].[Vouchers] v
            WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
              AND (v.AccountID = @CashAccountID OR v.AccountID IS NULL)
        ), 0) AS TotalPaymentVouchers,

        -- ✅ 5. إجمالي التحصيلات غير النقدية (كي نت / فيزا / بنك) - أي حساب غير 1101
        ISNULL((
            SELECT SUM(CAST(PaidNonCash AS DECIMAL(18,3)))
            FROM (
                SELECT sp.Amount AS PaidNonCash
                FROM [Sales].[InvoicePaymentSplits] sp
                INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND sp.PaymentAccountID <> @CashAccountID

                UNION ALL

                SELECT h.PaidAmount AS PaidNonCash
                FROM [Sales].[InvoiceHeader] h
                WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
                  AND h.PaidAmount > 0
                  AND h.PaymentAccountID IS NOT NULL
                  AND h.PaymentAccountID <> @CashAccountID
                  AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
            ) NonCashSalesUnion
        ), 0) AS TotalNonCashSales

    FROM [Sales].[Shifts] s
    LEFT JOIN [Security].[Users] u ON s.UserID = u.UserID
    WHERE s.ShiftID = @ShiftID;
END
GO
 

-- ============================================================
-- SP 2: sp_Shift_Close
-- إغلاق الوردية + قيد محاسبي لفرق الكاش
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_Close]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_Close];
GO

CREATE PROCEDURE [Sales].[sp_Shift_Close]
    @ShiftID    INT,
    @EndingCash DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        -- =====================================================
        -- 1. إغلاق الوردية
        -- =====================================================
        UPDATE [Sales].[Shifts]
        SET
            EndTime    = GETDATE(),
            EndingCash = @EndingCash,
            Status     = 'Closed'
        WHERE ShiftID = @ShiftID
          AND Status  = 'Open';

        IF @@ROWCOUNT = 0
            THROW 50001, 'الوردية غير موجودة أو مغلقة بالفعل', 1;

        -- =====================================================
        -- 2. حساب الكاش المتوقع والفرق
        -- ExpectedCash = StartingCash - TotalPaidPurchases + TotalPaidSales
        -- =====================================================
        DECLARE @StartingCash       DECIMAL(18,3);
        DECLARE @UserID             INT;
        DECLARE @TotalPaidSales     DECIMAL(18,3) = 0;
        DECLARE @TotalPaidPurchases DECIMAL(18,3) = 0;
        DECLARE @ExpectedCash       DECIMAL(18,3);
        DECLARE @Difference         DECIMAL(18,3);

        SELECT
            @StartingCash = StartingCash,
            @UserID       = UserID
        FROM [Sales].[Shifts]
        WHERE ShiftID = @ShiftID;

        -- مبيعات مسددة خلال الوردية (الاعتماد على ShiftID)
        SELECT @TotalPaidSales = ISNULL(SUM(CAST(PaidAmount AS DECIMAL(18,3))), 0)
        FROM [Sales].[InvoiceHeader]
        WHERE InvType = 'Sales'
          AND ShiftID = @ShiftID;

        -- مشتريات مسددة خلال الوردية (الاعتماد على ShiftID)
        SELECT @TotalPaidPurchases = ISNULL(SUM(CAST(PaidAmount AS DECIMAL(18,3))), 0)
        FROM [Sales].[InvoiceHeader]
        WHERE InvType = 'Purchase'
          AND ShiftID = @ShiftID;

        SET @ExpectedCash = @StartingCash - @TotalPaidPurchases + @TotalPaidSales;
        SET @Difference   = @EndingCash - @ExpectedCash;

        -- =====================================================
        -- 3. قيد محاسبي فقط إذا كان الفرق غير صفر
        -- =====================================================
        IF ABS(@Difference) > 0.001
        BEGIN
            DECLARE @CashboxID      INT;
            DECLARE @RevenueIDchild INT;
            DECLARE @AbsDiff        DECIMAL(18,2) = CAST(ABS(@Difference) AS DECIMAL(18,2));
            DECLARE @JournalDesc    NVARCHAR(255);
            DECLARE @EntryNo        INT;
            DECLARE @DebitAccID     INT;
            DECLARE @CreditAccID    INT;

            -- جلب حساب الصندوق
            SELECT TOP 1 @CashboxID = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountName LIKE N'%صندوق%'
              AND IsTransactional = 1;

            -- جلب حساب الإيرادات الأخرى (412)
            SELECT @RevenueIDchild = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountCode = '412';

            IF @CashboxID IS NULL OR @RevenueIDchild IS NULL
                THROW 50002, 'تعذر إيجاد حسابات الصندوق أو الإيرادات الأخرى في دليل الحسابات', 1;

            IF @Difference > 0
            BEGIN
                -- *** فائض: مدين الصندوق / دائن إيرادات أخرى (412) ***
                SET @JournalDesc = N'فائض كاش عند إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                SET @DebitAccID  = @CashboxID;
                SET @CreditAccID = @RevenueIDchild;
            END
            ELSE
            BEGIN
                -- *** عجز: مدين إيرادات أخرى (412) / دائن الصندوق ***
                SET @JournalDesc = N'عجز كاش عند إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                SET @DebitAccID  = @RevenueIDchild;
                SET @CreditAccID = @CashboxID;
            END

            -- جلب رقم القيد التالي من الـ Sequence (مشترك بين السطرين)
            SET @EntryNo = NEXT VALUE FOR [Accounting].[seq_EntryNo];

            -- السطر 1: المدين
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID,
                 AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                 @DebitAccID, @AbsDiff, 0, @JournalDesc, @UserID);

            -- السطر 2: الدائن
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID,
                 AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                 @CreditAccID, 0, @AbsDiff, @JournalDesc, @UserID);
        END

        -- =====================================================
        -- 4. ترحيل الفواتير المرتبطة بهذه الوردية
        -- =====================================================
        -- بدلاً من الوقت، نربط الفواتير بـ ShiftID مباشرة
        UPDATE [Sales].[InvoiceHeader]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID 
          AND IsPosted = 0;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO



-- ============================================================
-- STEP 1: إضافة ShiftID لجدول السندات
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('[Accounting].[Vouchers]')
      AND name = 'ShiftID'
)
BEGIN
    ALTER TABLE [Accounting].[Vouchers]
    ADD ShiftID INT NULL;
    -- إضافة Foreign Key للربط مع جدول الورديات
    ALTER TABLE [Accounting].[Vouchers]
    ADD CONSTRAINT FK_Vouchers_ShiftID
        FOREIGN KEY (ShiftID) REFERENCES [Sales].[Shifts](ShiftID);
    PRINT N'✅ تم إضافة ShiftID إلى [Accounting].[Vouchers]';
END
ELSE
    PRINT N'⚠️ العمود ShiftID موجود مسبقاً في [Accounting].[Vouchers]';
GO

-- ============================================================
-- STEP 3: sp_Partner_GetUnpaidInvoices
-- جلب الفواتير المُرحّلة وغير المسدّدة بالكامل للشريك
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Partner_GetUnpaidInvoices]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Partner_GetUnpaidInvoices];
GO
CREATE PROCEDURE [Sales].[sp_Partner_GetUnpaidInvoices]
    @PartnerID INT,
    @InvType   NVARCHAR(20)  -- 'Sales' or 'Purchase'
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.InvID,
        h.InvDate,
        h.InvType,
        h.TotalAmount,
        h.Discount,
        h.NetAmount,
        h.PaidAmount,
        h.VoucherPaidAmount,
        h.Remainder,
        h.Notes,
        p.PartnerName,
        h.IsPosted,
        h.CreatedAt
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    WHERE h.PartnerID = @PartnerID
      AND h.InvType   = @InvType
      AND h.IsPosted  = 1
      AND h.Remainder > 0
    ORDER BY h.InvDate DESC, h.InvID DESC;
END
GO
PRINT N'✅ تم إنشاء sp_Partner_GetUnpaidInvoices';
GO
-- ============================================================
-- STEP 4: sp_Partner_BulkPayment_pos
-- سداد مديونيات جماعي مع إنشاء سند قبض/صرف غير مرحّل
-- الترحيل سيتم لاحقاً عند إغلاق الوردية
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Partner_BulkPayment_pos]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Partner_BulkPayment_pos];
GO
CREATE PROCEDURE [Sales].[sp_Partner_BulkPayment_pos]
        @PartnerID    INT,
        @VoucherType  NVARCHAR(20),
        @TotalAmount  DECIMAL(18,3),
        @AccountID    INT,             -- حساب الصندوق/البنك المستخدم
        @UserID       INT,
        @ShiftID      INT,
        @Description  NVARCHAR(255) = NULL,
        @AllocationsXML NVARCHAR(MAX) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 0. جلب حساب العميل/المورد
            DECLARE @PartnerAccountID INT;
            SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

            IF @PartnerAccountID IS NULL
            BEGIN
                RAISERROR(N'الشريك ليس لديه حساب مالي مرتبط', 16, 1);
                RETURN;
            END

            -- ① تحليل XML لجدول مؤقت
            DECLARE @Allocs TABLE (InvID INT, Amount DECIMAL(18,3));

            IF @AllocationsXML IS NOT NULL AND LTRIM(RTRIM(@AllocationsXML)) <> '' AND @AllocationsXML <> '<Allocations></Allocations>' AND @AllocationsXML <> '<Allocations />'
            BEGIN
                INSERT INTO @Allocs (InvID, Amount)
                SELECT
                    x.item.value('@InvID',  'INT'),
                    x.item.value('@Amount', 'DECIMAL(18,3)')
                FROM (SELECT CAST(@AllocationsXML AS XML)) T(x)
                CROSS APPLY T.x.nodes('/Allocations/Item') AS x(item);

                -- ② التحقق من مجموع المبالغ
                DECLARE @SumCheck DECIMAL(18,3);
                SELECT @SumCheck = SUM(Amount) FROM @Allocs;

                IF ABS(@SumCheck - @TotalAmount) > 0.01
                BEGIN
                    RAISERROR(N'مجموع مبالغ الفواتير لا يساوي المبلغ الإجمالي المُدخل', 16, 1);
                    RETURN;
                END

                -- ③ التحقق من أن كل فاتورة: مرحّلة، Remainder >= المبلغ المراد سداده
                IF EXISTS (
                    SELECT 1 FROM @Allocs a
                    INNER JOIN [Sales].[InvoiceHeader] h ON a.InvID = h.InvID
                    WHERE h.IsPosted = 0 OR h.Remainder < a.Amount OR a.Amount <= 0
                )
                BEGIN
                    RAISERROR(N'إحدى الفواتير غير مرحّلة أو المبلغ يتجاوز المتبقي', 16, 1);
                    RETURN;
                END

                -- ④ تحديث VoucherPaidAmount و Remainder في الفواتير المحددة
                UPDATE h
                SET h.VoucherPaidAmount = h.VoucherPaidAmount + a.Amount,
                    h.Remainder         = h.Remainder         - a.Amount
                FROM [Sales].[InvoiceHeader] h
                INNER JOIN @Allocs a ON h.InvID = a.InvID;
            END

            -- ⑤ إنشاء السند في حالة غير مرحّلة (IsPosted = 0)
            -- سيتم الترحيل جماعياً عند إغلاق الوردية
            INSERT INTO [Accounting].[Vouchers]
                (VoucherType, VoucherDate, PartnerID, AccountID,
                 Amount, Description, PaymentMethod, UserID, IsPosted, ShiftID)
            VALUES
                (@VoucherType, GETDATE(), @PartnerID, @PartnerAccountID,
                 @TotalAmount,
                 ISNULL(@Description,
                    CASE @VoucherType
                        WHEN 'Receipt' THEN N'سند قبض - سداد مديونيات'
                        ELSE                N'سند صرف - سداد مستحقات'
                    END),
                 CAST(@AccountID AS NVARCHAR(50)), -- يتم حفظ حساب الصندوق/البنك هنا لتستخدمه الـ Trigger
                 @UserID, 0, @ShiftID);

            DECLARE @VoucherID INT = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            -- إرجاع رقم السند المُنشأ للطباعة
            SELECT
                v.VoucherID,
                v.VoucherType,
                v.VoucherDate,
                v.Amount,
                v.Description,
                v.ShiftID,
                p.PartnerName,
                u.FullName AS UserName,
                a.AccountName
            FROM [Accounting].[Vouchers] v
            LEFT JOIN [Sales].[Partners]             p ON v.PartnerID = p.PartnerID
            LEFT JOIN [Security].[Users]             u ON v.UserID    = u.UserID
            LEFT JOIN [Accounting].[ChartOfAccounts] a ON v.AccountID = a.AccountID
            WHERE v.VoucherID = @VoucherID;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH

    END
	go
PRINT N'✅ تم إنشاء sp_Partner_BulkPayment_pos';
GO
-- ============================================================
-- STEP 5: تعديل sp_Shift_GetSummary لإضافة إجمالي السندات
-- ============================================================
-- STEP 5: تعديل sp_Shift_GetSummary لإضافة إجمالي السندات وحساب الكاش بدقة
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetSummary];
GO

CREATE PROCEDURE [Sales].[sp_Shift_GetSummary] 
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. المتغيرات الأساسية للوردية
    DECLARE @StartingCash DECIMAL(18,3) = 0;
    DECLARE @EndingCash   DECIMAL(18,3) = NULL;

    SELECT @StartingCash = ISNULL(StartingCash, 0), @EndingCash = EndingCash
    FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

    -- حسابات الكاش والمبيعات والشبكة
    DECLARE @TotalSales              DECIMAL(18,3) = 0;
    DECLARE @TotalPurchases          DECIMAL(18,3) = 0;
    DECLARE @SalesCount              INT = 0;
    DECLARE @PurchasesCount          INT = 0;
    DECLARE @TotalPaidSalesCash      DECIMAL(18,3) = 0;
    DECLARE @TotalPaidSalesNonCash   DECIMAL(18,3) = 0;
    DECLARE @TotalRemainder          DECIMAL(18,3) = 0;
    DECLARE @TotalPaidPurchasesCash  DECIMAL(18,3) = 0;
    DECLARE @TotalPaidPurchasesNonCash DECIMAL(18,3) = 0;
    DECLARE @TotalPurchasesRemainder DECIMAL(18,3) = 0;
    DECLARE @TotalReceiptVouchers    DECIMAL(18,3) = 0;
    DECLARE @TotalPaymentVouchers    DECIMAL(18,3) = 0;

    -- 2. إجماليات فواتير المبيعات
    SELECT 
        @TotalSales     = ISNULL(SUM(CAST(NetAmount AS DECIMAL(18,3))), 0),
        @SalesCount     = COUNT(*),
        @TotalRemainder = ISNULL(SUM(CAST(Remainder AS DECIMAL(18,3))), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Sales' AND ShiftID = @ShiftID;

    -- 3. إجماليات فواتير المشتريات
    SELECT 
        @TotalPurchases          = ISNULL(SUM(CAST(NetAmount AS DECIMAL(18,3))), 0),
        @PurchasesCount          = COUNT(*),
        @TotalPurchasesRemainder = ISNULL(SUM(CAST(Remainder AS DECIMAL(18,3))), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Purchase' AND ShiftID = @ShiftID;

    -- 4. مبيعات الكاش النقدية الفعلية بالدرج (الحساب 1101 ومشتقاته حصراً + الفواتير المباشرة)
    SELECT @TotalPaidSalesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
    FROM (
        -- فواتير مجزأة: الدفعات النقدية على حساب الصندوق 1101
        SELECT sp.Amount AS PaidCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )

        UNION ALL

        -- فواتير مباشرة (غير مجزأة): مسددة كاش
        SELECT h.PaidAmount AS PaidCash
        FROM [Sales].[InvoiceHeader] h
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountID IS NULL
              OR c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )
    ) CashSalesUnion;

    -- 5. مبيعات الشبكة K-Net / فيزا / بطاقات / بنك (أي حساب دفع بخلاف 1101)
    SELECT @TotalPaidSalesNonCash = ISNULL(SUM(CAST(PaidNonCash AS DECIMAL(18,3))), 0)
    FROM (
        -- فواتير مجزأة: الدفعات غير النقدية
        SELECT sp.Amount AS PaidNonCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        INNER JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'

        UNION ALL

        -- فواتير مباشرة (غير مجزأة): مسددة شبكة/KNET/بنك
        SELECT h.PaidAmount AS PaidNonCash
        FROM [Sales].[InvoiceHeader] h
        INNER JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'
    ) NonCashSalesUnion;

    -- 6. مشتريات الكاش النقدية الفعلية من الصندوق (الحساب 1101 حصراً)
    SELECT @TotalPaidPurchasesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
    FROM (
        SELECT sp.Amount AS PaidCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )

        UNION ALL

        SELECT h.PaidAmount AS PaidCash
        FROM [Sales].[InvoiceHeader] h
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND (
              c.AccountID IS NULL
              OR c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          )
    ) CashPurchasesUnion;

    -- مشتريات غير نقدية
    SELECT @TotalPaidPurchasesNonCash = ISNULL(SUM(CAST(PaidNonCash AS DECIMAL(18,3))), 0)
    FROM (
        SELECT sp.Amount AS PaidNonCash
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
        INNER JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'

        UNION ALL

        SELECT h.PaidAmount AS PaidNonCash
        FROM [Sales].[InvoiceHeader] h
        INNER JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
        WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
          AND c.AccountCode <> '1101'
          AND c.AccountCode NOT LIKE '1101%'
    ) NonCashPurchasesUnion;

    -- 7. سندات القبض الكاش بالدرج
    SELECT @TotalReceiptVouchers = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
        CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
    ) = c.AccountID
    WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
      AND (
          c.AccountCode = '1101'
          OR c.AccountCode LIKE '1101%'
          OR v.PaymentMethod = 'Cash'
          OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
      );

    -- 8. سندات الصرف الكاش من الدرج (المصروفات النقدية)
    SELECT @TotalPaymentVouchers = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
        CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
    ) = c.AccountID
    WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
      AND (
          c.AccountCode = '1101'
          OR c.AccountCode LIKE '1101%'
          OR v.PaymentMethod = 'Cash'
          OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
      );

    -- 9. حساب النقدية المتوقعة بالدرج
    DECLARE @ExpectedCash DECIMAL(18,3) = @StartingCash 
                                        + @TotalPaidSalesCash 
                                        - @TotalPaidPurchasesCash 
                                        + @TotalReceiptVouchers 
                                        - @TotalPaymentVouchers;

    DECLARE @Difference DECIMAL(18,3) = ISNULL(@EndingCash, @ExpectedCash) - @ExpectedCash;

    -- 10. إرجاع النتائج المتوافقة مع كافة الأنظمة والشاشات والطباعة
    SELECT
        s.ShiftID,
        s.UserID,
        s.StartTime,
        s.EndTime,
        s.StartingCash,
        s.EndingCash,
        s.Status,
        u.FullName AS UserName,

        @TotalSales                 AS TotalSales,
        @TotalPurchases             AS TotalPurchases,
        @SalesCount                 AS SalesCount,
        @PurchasesCount             AS PurchasesCount,

        @TotalPaidSalesCash         AS TotalPaidSales,        -- مبيعات الكاش النقدية الفعلية (توافق قديم وجديد)
        @TotalPaidSalesCash         AS TotalCashSales,        -- لشاشة إغلاق الوردية والطباعة
        @TotalPaidSalesCash         AS CashSales,             -- لطباعة وتقارير Flutter
        @TotalPaidSalesNonCash      AS TotalNonCashSales,     -- مبيعات غير نقدية (شبكة / بطاقات)
        @TotalPaidSalesNonCash      AS TotalKnetSales,        -- لطباعة وتقارير Flutter (K-Net)
        @TotalPaidSalesNonCash      AS KnetSales,             -- لطباعة Flutter
        @TotalPaidSalesNonCash      AS CardSales,             -- للبطاقات
        @TotalRemainder             AS TotalRemainder,

        @TotalPaidPurchasesCash     AS TotalPaidPurchases,    -- مشتريات كاش فقط
        @TotalPaidPurchasesCash     AS TotalCashPurchases,
        @TotalPaidPurchasesNonCash  AS TotalNonCashPurchases,
        @TotalPurchasesRemainder    AS TotalPurchasesRemainder,

        @TotalReceiptVouchers       AS TotalReceiptVouchers,
        @TotalPaymentVouchers       AS TotalPaymentVouchers,
        @TotalPaymentVouchers       AS TotalExpenses,

        @ExpectedCash               AS ExpectedCash,
        ISNULL(s.EndingCash, @ExpectedCash) AS ActualCash,
        @Difference                 AS Difference

    FROM [Sales].[Shifts] s
    LEFT JOIN [Security].[Users] u ON s.UserID = u.UserID
    WHERE s.ShiftID = @ShiftID;
END
GO

-- ============================================================
-- STEP 6: تعديل sp_Shift_Close - ترحيل السندات عند الإغلاق وحساب الكاش بدقة
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Shift_Close]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_Close];
GO

CREATE PROCEDURE [Sales].[sp_Shift_Close]
    @ShiftID    INT,
    @EndingCash DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- ① إغلاق الوردية
        UPDATE [Sales].[Shifts]
        SET EndTime    = GETDATE(),
            EndingCash = @EndingCash,
            Status     = 'Closed'
        WHERE ShiftID = @ShiftID AND Status = 'Open';

        IF @@ROWCOUNT = 0
            THROW 50001, 'الوردية غير موجودة أو مغلقة بالفعل', 1;

        -- ② جلب بيانات الوردية
        DECLARE @StartingCash           DECIMAL(18,3) = 0;
        DECLARE @UserID                 INT;
        DECLARE @TotalPaidSalesCash     DECIMAL(18,3) = 0;
        DECLARE @TotalPaidPurchasesCash DECIMAL(18,3) = 0;
        DECLARE @TotalReceiptV          DECIMAL(18,3) = 0;
        DECLARE @TotalPaymentV          DECIMAL(18,3) = 0;
        DECLARE @ExpectedCash           DECIMAL(18,3) = 0;
        DECLARE @Difference             DECIMAL(18,3) = 0;

        SELECT @StartingCash = ISNULL(StartingCash, 0), @UserID = UserID
        FROM [Sales].[Shifts] WHERE ShiftID = @ShiftID;

        -- مبيعات مسددة كاش فقط بالدرج (الحساب 1101 ومشتقاته حصراً)
        SELECT @TotalPaidSalesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
        FROM (
            SELECT sp.Amount AS PaidCash
            FROM [Sales].[InvoicePaymentSplits] sp
            INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
              AND (
                  c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )

            UNION ALL

            SELECT h.PaidAmount AS PaidCash
            FROM [Sales].[InvoiceHeader] h
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Sales' AND h.ShiftID = @ShiftID
              AND h.PaidAmount > 0
              AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
              AND (
                  c.AccountID IS NULL
                  OR c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )
        ) CashSalesUnion;

        -- مشتريات مسددة كاش فقط من الدرج (الحساب 1101 ومشتقاته حصراً)
        SELECT @TotalPaidPurchasesCash = ISNULL(SUM(CAST(PaidCash AS DECIMAL(18,3))), 0)
        FROM (
            SELECT sp.Amount AS PaidCash
            FROM [Sales].[InvoicePaymentSplits] sp
            INNER JOIN [Sales].[InvoiceHeader] h ON sp.InvID = h.InvID
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON sp.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
              AND (
                  c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountID IS NULL AND (c.AccountName IS NULL OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )

            UNION ALL

            SELECT h.PaidAmount AS PaidCash
            FROM [Sales].[InvoiceHeader] h
            LEFT JOIN [Accounting].[ChartOfAccounts] c ON h.PaymentAccountID = c.AccountID
            WHERE h.InvType = 'Purchase' AND h.ShiftID = @ShiftID
              AND h.PaidAmount > 0
              AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID)
              AND (
                  c.AccountID IS NULL
                  OR c.AccountCode = '1101'
                  OR c.AccountCode LIKE '1101%'
                  OR (c.AccountCode IS NULL AND (LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
              )
        ) CashPurchasesUnion;

        -- سندات القبض الكاش
        SELECT @TotalReceiptV = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
        FROM [Accounting].[Vouchers] v
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
            CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
        ) = c.AccountID
        WHERE v.VoucherType = 'Receipt' AND v.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR v.PaymentMethod = 'Cash'
              OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          );

        -- سندات الصرف الكاش
        SELECT @TotalPaymentV = ISNULL(SUM(CAST(v.Amount AS DECIMAL(18,3))), 0)
        FROM [Accounting].[Vouchers] v
        LEFT JOIN [Accounting].[ChartOfAccounts] c ON (
            CASE WHEN ISNUMERIC(v.PaymentMethod) = 1 THEN CAST(v.PaymentMethod AS INT) ELSE v.AccountID END
        ) = c.AccountID
        WHERE v.VoucherType = 'Payment' AND v.ShiftID = @ShiftID
          AND (
              c.AccountCode = '1101'
              OR c.AccountCode LIKE '1101%'
              OR v.PaymentMethod = 'Cash'
              OR (c.AccountID IS NULL AND (v.PaymentMethod IS NULL OR v.PaymentMethod = '' OR LOWER(c.AccountName) LIKE '%cash%' OR c.AccountName LIKE N'%كاش%' OR c.AccountName LIKE N'%صندوق%'))
          );

        -- الكاش المتوقع = كاش الافتتاح + مبيعات نقدية - مشتريات نقدية + سندات قبض نقدية - سندات صرف نقدية
        SET @ExpectedCash = @StartingCash
                          + @TotalPaidSalesCash
                          - @TotalPaidPurchasesCash
                          + @TotalReceiptV
                          - @TotalPaymentV;

        SET @Difference = @EndingCash - @ExpectedCash;

        -- ③ قيد تسوية فرق الكاش (إن وُجد)
        IF ABS(@Difference) > 0.001
        BEGIN
            DECLARE @CashboxID      INT;
            DECLARE @RevenueIDchild INT;
            DECLARE @AbsDiff        DECIMAL(18,2) = CAST(ABS(@Difference) AS DECIMAL(18,2));
            DECLARE @JournalDesc    NVARCHAR(255);
            DECLARE @EntryNo        INT;
            DECLARE @DebitAccID     INT;
            DECLARE @CreditAccID    INT;

            SELECT TOP 1 @CashboxID = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE (AccountCode = '1101' OR AccountCode LIKE '1101%' OR LOWER(AccountName) LIKE '%cash%' OR AccountName LIKE N'%كاش%' OR AccountName LIKE N'%صندوق%')
              AND IsTransactional = 1;

            SELECT TOP 1 @RevenueIDchild = AccountID
            FROM [Accounting].[ChartOfAccounts]
            WHERE AccountCode = '412';

            IF @RevenueIDchild IS NULL
            BEGIN
                SELECT TOP 1 @RevenueIDchild = AccountID
                FROM [Accounting].[ChartOfAccounts]
                WHERE (AccountName LIKE N'%إيراد%' OR AccountName LIKE N'%أرباح%' OR AccountCode LIKE '4%')
                  AND IsTransactional = 1;
            END

            IF @CashboxID IS NOT NULL AND @RevenueIDchild IS NOT NULL
            BEGIN
                IF @Difference > 0
                BEGIN
                    SET @JournalDesc = N'فائض كاش - إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                    SET @DebitAccID  = @CashboxID;
                    SET @CreditAccID = @RevenueIDchild;
                END
                ELSE
                BEGIN
                    SET @JournalDesc = N'عجز كاش - إغلاق الوردية رقم ' + CAST(@ShiftID AS NVARCHAR(20));
                    SET @DebitAccID  = @RevenueIDchild;
                    SET @CreditAccID = @CashboxID;
                END

                IF OBJECT_ID('[Accounting].[seq_EntryNo]', 'SO') IS NOT NULL
                BEGIN
                    SET @EntryNo = NEXT VALUE FOR [Accounting].[seq_EntryNo];
                    INSERT INTO [Accounting].[JournalEntries]
                        (EntryNo, EntryDate, ReferenceType, ReferenceID,
                         AccountID, DebitAmount, CreditAmount, Description, UserID)
                    VALUES
                        (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                         @DebitAccID, @AbsDiff, 0, @JournalDesc, @UserID),
                        (@EntryNo, GETDATE(), N'ShiftClose', @ShiftID,
                         @CreditAccID, 0, @AbsDiff, @JournalDesc, @UserID);
                END
            END
        END

        -- ④ ترحيل الفواتير المرتبطة بهذه الوردية
        UPDATE [Sales].[InvoiceHeader]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID AND IsPosted = 0;

        -- ⑤ ترحيل السندات المرتبطة بهذه الوردية (تُولّد القيود عبر trg_Voucher_Post)
        UPDATE [Accounting].[Vouchers]
        SET IsPosted = 1
        WHERE ShiftID = @ShiftID AND IsPosted = 0;

        COMMIT TRANSACTION;

        -- إرجاع ملخص للإغلاق
        SELECT
            @ShiftID                AS ShiftID,
            @StartingCash           AS StartingCash,
            @TotalPaidSalesCash     AS TotalPaidSales,
            @TotalPaidSalesCash     AS TotalCashSales,
            @TotalPaidSalesCash     AS CashSales,
            @TotalPaidPurchasesCash AS TotalPaidPurchases,
            @TotalPaidPurchasesCash AS TotalCashPurchases,
            @TotalReceiptV          AS TotalReceiptVouchers,
            @TotalPaymentV          AS TotalPaymentVouchers,
            @ExpectedCash           AS ExpectedCash,
            @EndingCash             AS ActualCash,
            @Difference             AS Difference;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم تحديث sp_Shift_Close';
GO



IF OBJECT_ID('[Sales].[sp_Shift_GetVouchers]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetVouchers];
GO
CREATE PROCEDURE [Sales].[sp_Shift_GetVouchers]
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        v.VoucherID,
        v.VoucherType,
        v.VoucherDate,
        v.Amount,
        v.Description,
        p.PartnerName,
        a.AccountName
    FROM [Accounting].[Vouchers] v
    LEFT JOIN [Sales].[Partners] p ON v.PartnerID = p.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] a ON v.AccountID = a.AccountID
    WHERE v.ShiftID = @ShiftID
    ORDER BY v.VoucherDate ASC;
END
GO


IF NOT EXISTS (SELECT 1 FROM [Sales].[Partners] WHERE PartnerName = N'سند مباشر' AND PartnerType = 'Other')
BEGIN
    INSERT INTO [Sales].[Partners]
               ([PartnerName]
               ,[PartnerType])
         VALUES
               (N'سند مباشر'
               ,'Other')
    PRINT N'تم إضافة العميل الثابت "سند مباشر" بنجاح.';
END
ELSE
BEGIN
    PRINT N'العميل الثابت "سند مباشر" موجود مسبقاً.';
END
GO

IF OBJECT_ID('[Sales].[sp_GetCode_PartnerGeneral]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_GetCode_PartnerGeneral];
GO
CREATE PROCEDURE [Sales].[sp_GetCode_PartnerGeneral]
AS
BEGIN
select * from Sales.Partners where [PartnerName] =N'سند مباشر'
end 
go

IF OBJECT_ID('[Accounting].[sp_Account_Revenue]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Revenue];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Revenue]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID, 
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
	where a.AccountType = 'Revenue' and a.IsTransactional = 1
    ORDER BY A.AccountType,A.AccountCode;
END
GO

IF OBJECT_ID('[Accounting].[sp_Account_Expenses]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Expenses];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Expenses]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID, 
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
	where a.AccountType = 'Expenses' and a.IsTransactional = 1
    ORDER BY A.AccountType,A.AccountCode;
END
GO

IF OBJECT_ID('[Accounting].[sp_VoucherGeneral_Save]', 'P') IS NOT NULL 
    DROP PROCEDURE [Accounting].[sp_VoucherGeneral_Save];
GO

CREATE PROCEDURE [Accounting].[sp_VoucherGeneral_Save]
    @VoucherType NVARCHAR(20),
    @VoucherDate DATETIME,
    @AccountID INT,
    @Amount DECIMAL(18,3),
    @Description NVARCHAR(255) = NULL,
    @PaymentMethod NVARCHAR(20) = 'Cash',
    @UserID INT,
    @ShiftID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StaticPartnerID INT;
    DECLARE @NewVoucherNo NVARCHAR(50);

    -- 1. جلب معرّف العميل الثابت 'سند مباشر'
    SELECT @StaticPartnerID = PartnerID 
    FROM [Sales].[Partners] 
    WHERE [PartnerName] = N'سند مباشر' AND [PartnerType] = 'Other';

    IF @StaticPartnerID IS NULL
    BEGIN
        RAISERROR('العميل الثابت "سند مباشر" غير موجود في قاعدة البيانات.', 16, 1);
        RETURN;
    END

    -- 2. توليد رقم السند (VoucherNo) التلقائي
    -- يجلب أكبر رقم موجود كـ (رقم صحيح) ويزيد عليه 1
    SELECT @NewVoucherNo = CAST(ISNULL(MAX(CAST(VoucherNo AS INT)), 0) + 1 AS NVARCHAR(50))
    FROM [Accounting].[Vouchers]
    WHERE ISNUMERIC(VoucherNo) = 1;

    -- تفادي الأخطاء لو كان الجدول فارغاً
    IF @NewVoucherNo IS NULL
        SET @NewVoucherNo = '1';

    -- 3. حفظ السند الجديد مع VoucherNo
    INSERT INTO [Accounting].[Vouchers] (
        [VoucherNo],
        [VoucherType],
        [VoucherDate],
        [PartnerID],
        [AccountID],
        [Amount],
        [Description],
        [PaymentMethod],
        [UserID],
        [IsPosted],
        [ShiftID]
    )
    VALUES (
        @NewVoucherNo,
        @VoucherType,
        @VoucherDate,
        @StaticPartnerID,
        @AccountID,
        @Amount,
        @Description,
        @PaymentMethod,
        @UserID,
        0, -- IsPosted = 0 (مسودة)
        @ShiftID
    );

    DECLARE @NewVoucherID INT = SCOPE_IDENTITY();

    -- 4. إرجاع السند المحفوظ بالكامل
    SELECT 
        [VoucherID],
        [VoucherNo],
        [VoucherType],
        [VoucherDate],
        [PartnerID],
        [AccountID],
        [Amount],
        [Description],
        [PaymentMethod],
        [UserID],
        [IsPosted],
        [ShiftID]
    FROM [Accounting].[Vouchers]
    WHERE [VoucherID] = @NewVoucherID;

END
GO

-- جلب سعر الصنف من عرض اسعار المورد

IF OBJECT_ID('[Purchases].[sp_Purchases_quoteItems_Price]', 'P') IS NOT NULL 
    DROP PROCEDURE [Purchases].[sp_Purchases_quoteItems_Price];
GO

CREATE PROCEDURE [Purchases].[sp_Purchases_quoteItems_Price]
    @PartnerID  INT,
    @ProductID  INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1 d.UnitPrice
    FROM [Purchases].[PurchaseQuoteDetails] d
    INNER JOIN [Purchases].[PurchaseQuoteHeader] h
        ON d.PurchaseQuoteID = h.PurchaseQuoteID
    WHERE h.PartnerID  = @PartnerID
      AND d.ProductID  = @ProductID
      AND (h.ExpiryDate IS NULL OR h.ExpiryDate >= CAST(GETDATE() AS DATE))
    ORDER BY h.QuoteDate DESC, h.PurchaseQuoteID DESC;
END
GO

IF OBJECT_ID('[Sales].[sp_Shift_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_GetAll];
    go
 
    CREATE PROCEDURE [Sales].[sp_Shift_GetAll]
    AS
    BEGIN
        SET NOCOUNT ON;
        
        SELECT 
            s.[ShiftID],
            s.[UserID],
            u.[FullName] AS [UserName],
            s.[StartTime],
            s.[EndTime],
            s.[StartingCash],
            s.[EndingCash],
            s.[Status]
        FROM [Sales].[Shifts] s
        LEFT JOIN [Security].[Users] u ON s.[UserID] = u.[UserID]
        ORDER BY s.[ShiftID] DESC;
    END
	go

	
-- 1. Add CurrencySymbol column if it doesn't exist
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') 
    AND name = 'CurrencySymbol'
)
BEGIN
    ALTER TABLE [Settings].[CompanySettings]
    ADD CurrencySymbol NVARCHAR(100) NULL;
END
GO

-- 2. Set default value for existing records
UPDATE [Settings].[CompanySettings]
SET CurrencySymbol = N'د.ك'
WHERE CurrencySymbol IS NULL;
GO

-- 3. Update Stored Procedure to include CurrencySymbol
IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1,
    @CurrencySymbol NVARCHAR(100) = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo,
            UnifiedPartnerSearch = @UnifiedPartnerSearch,
            CurrencySymbol = @CurrencySymbol
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch, CurrencySymbol)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch, @CurrencySymbol);
    END
END
GO
-- ============================================================
-- Inventory & Wastage Management Feature - Phase 2
-- إنشاء جداول وإجراءات الهوالك والجرد الآلي
-- ============================================================

-- ============================================================
-- 1. جدول الهوالك (الرئيسي)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('[Inventory].[WastageHeader]'))
BEGIN
    CREATE TABLE [Inventory].[WastageHeader] (
        WastageID INT IDENTITY(1,1) PRIMARY KEY,
        WastageDate DATETIME NOT NULL DEFAULT GETDATE(),
        UserID INT NOT NULL,
        ShiftID INT NULL,
        WarehouseID INT NOT NULL DEFAULT 1,
        TotalValue DECIMAL(18,3) NOT NULL DEFAULT 0,
        Notes NVARCHAR(500),
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        IsPosted BIT NOT NULL DEFAULT 0 -- 0=Pending, 1=Posted/Deducted from stock
    );
    PRINT N'✅ تم إنشاء جدول WastageHeader';
END
GO

-- ============================================================
-- 2. جدول الهوالك (التفاصيل)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('[Inventory].[WastageDetails]'))
BEGIN
    CREATE TABLE [Inventory].[WastageDetails] (
        DetailID INT IDENTITY(1,1) PRIMARY KEY,
        WastageID INT NOT NULL FOREIGN KEY REFERENCES [Inventory].[WastageHeader](WastageID) ON DELETE CASCADE,
        ProductID INT NOT NULL,
        Quantity DECIMAL(18,3) NOT NULL,
        CostPrice DECIMAL(18,3) NOT NULL,
        TotalCost AS (Quantity * CostPrice) PERSISTED
    );
    PRINT N'✅ تم إنشاء جدول WastageDetails';
END
GO

-- ============================================================
-- 3. جدول الجرد الآلي (الرئيسي)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('[Inventory].[StockTakeHeader]'))
BEGIN
    CREATE TABLE [Inventory].[StockTakeHeader] (
        StockTakeID INT IDENTITY(1,1) PRIMARY KEY,
        StockTakeDate DATETIME NOT NULL DEFAULT GETDATE(),
        UserID INT NOT NULL,
        Status NVARCHAR(50) NOT NULL DEFAULT 'Pending', -- Pending, Approved, Rejected
        TotalDifferenceValue DECIMAL(18,3) NOT NULL DEFAULT 0,
        Notes NVARCHAR(500),
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        ApprovedBy INT NULL,
        ApprovedAt DATETIME NULL
    );
    PRINT N'✅ تم إنشاء جدول StockTakeHeader';
END
GO
-- ============================================================
-- 4. جدول الجرد الآلي (التفاصيل)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('[Inventory].[StockTakeDetails]'))
BEGIN
    CREATE TABLE [Inventory].[StockTakeDetails] (
        DetailID INT IDENTITY(1,1) PRIMARY KEY,
        StockTakeID INT NOT NULL FOREIGN KEY REFERENCES [Inventory].[StockTakeHeader](StockTakeID) ON DELETE CASCADE,
        ProductID INT NOT NULL,
        SystemQuantity DECIMAL(18,3) NOT NULL,
        ActualQuantity DECIMAL(18,3) NOT NULL,
        DifferenceQuantity AS (ActualQuantity - SystemQuantity) PERSISTED,
        CostPrice DECIMAL(18,3) NOT NULL,
        DifferenceValue AS ((ActualQuantity - SystemQuantity) * CostPrice) PERSISTED
    );
    PRINT N'✅ تم إنشاء جدول StockTakeDetails';
END
GO
-- ============================================================
-- 5. إضافة الصلاحيات لجدول Permissions (إن وُجد)
-- ============================================================
IF EXISTS (SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('[Security].[Permissions]'))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [Security].[Permissions] WHERE PermissionName = 'إدارة التوالف')
        INSERT INTO [Security].[Permissions] (PermissionName, Description) 
        VALUES (N'إدارة التوالف', N'إضافة ومراجعة الهوالك والتوالف');
    IF NOT EXISTS (SELECT 1 FROM [Security].[Permissions] WHERE PermissionName = 'إدارة الجرد الآلي')
        INSERT INTO [Security].[Permissions] (PermissionName, Description) 
        VALUES (N'إدارة الجرد الآلي', N'إنشاء واعتماد تسويات الجرد المخزني');
    
    PRINT N'✅ تم إدراج صلاحيات إدارة التوالف والجرد في جدول Permissions';
END
GO
-- ============================================================
-- 6. إجراء مخزن (SP) لحفظ الفاتورة / الهوالك عبر XML
-- ============================================================
IF OBJECT_ID('[Inventory].[sp_Wastage_Save_XML]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_Save_XML];
GO
CREATE PROCEDURE [Inventory].[sp_Wastage_Save_XML]
    @WastageID INT OUTPUT,
    @WastageDate DATETIME,
    @UserID INT,
    @ShiftID INT = NULL,
    @WarehouseID INT = 1,
    @TotalValue DECIMAL(18,3),
    @Notes NVARCHAR(500),
    @DetailsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @WastageID = 0 OR @WastageID IS NULL
        BEGIN
            INSERT INTO [Inventory].[WastageHeader] 
                (WastageDate, UserID, ShiftID, WarehouseID, TotalValue, Notes, CreatedAt, IsPosted)
            VALUES 
                (@WastageDate, @UserID, @ShiftID, @WarehouseID, @TotalValue, @Notes, GETDATE(), 0);
            
            SET @WastageID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [Inventory].[WastageHeader]
            SET WastageDate = @WastageDate,
                UserID = @UserID,
                ShiftID = @ShiftID,
                WarehouseID = @WarehouseID,
                TotalValue = @TotalValue,
                Notes = @Notes
            WHERE WastageID = @WastageID;
            
            -- حذف التفاصيل القديمة
            DELETE FROM [Inventory].[WastageDetails] WHERE WastageID = @WastageID;
        END
        -- إدراج التفاصيل الجديدة
        INSERT INTO [Inventory].[WastageDetails] (WastageID, ProductID, Quantity, CostPrice)
        SELECT 
            @WastageID,
            x.item.value('@ProductID', 'INT'),
            x.item.value('@Quantity', 'DECIMAL(18,3)'),
            x.item.value('@CostPrice', 'DECIMAL(18,3)')
        FROM @DetailsXml.nodes('/Details/Item') AS x(item);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم إنشاء الإجراء المخزن لحفظ الهوالك sp_Wastage_Save_XML';
GO
-- ============================================================
-- 7. إجراء مخزن لترحيل الهوالك وخصمها من المخزون
-- (يعتمد هذا الإجراء على آلية خصم المخزون الموجودة لديك)
-- ============================================================
IF OBJECT_ID('[Inventory].[sp_Wastage_Post]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_Post];
GO
CREATE PROCEDURE [Inventory].[sp_Wastage_Post]
    @WastageID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @IsPosted BIT;
        SELECT @IsPosted = IsPosted FROM [Inventory].[WastageHeader] WHERE WastageID = @WastageID;
        
        IF @IsPosted = 1
            THROW 50000, N'تم ترحيل هذا المستند مسبقاً ولا يمكن ترحيله مرة أخرى.', 1;
        -- تحديث حالة المستند
        UPDATE [Inventory].[WastageHeader] SET IsPosted = 1 WHERE WastageID = @WastageID;
        -- ** ملاحظة هامة **
        -- هنا يجب استدعاء الإجراء الخاص بتحديث كميات المنتجات (مثل sp_UpdateStock) أو كتابة استعلام التحديث.
        -- لتجنب أي تعارض مع الجداول الحالية (التي قد يكون اسمها Products أو Stock)، يرجى ربط كود خصم الكمية هنا 
        -- بناءً على جدول Products لديك.
        
        -- مثال مقترح للتحديث (يرجى إزالة التعليق إذا كان جدول المخزون اسمه Inventory.Products):
        /*
        UPDATE p
        SET p.Quantity = p.Quantity - d.Quantity
        FROM [Inventory].[Products] p
        INNER JOIN [Inventory].[WastageDetails] d ON p.ProductID = d.ProductID
        WHERE d.WastageID = @WastageID;
        */
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم إنشاء الإجراء المخزن لترحيل الهوالك sp_Wastage_Post';
GO
-- ============================================================
-- 8. إجراء مخزن (SP) لحفظ أو تعديل تسوية جرد (مسودة)
-- ============================================================
IF OBJECT_ID('[Inventory].[sp_StockTake_Save_XML]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_StockTake_Save_XML];
GO

CREATE PROCEDURE [Inventory].[sp_StockTake_Save_XML]
    @StockTakeID INT OUTPUT,
    @StockTakeDate DATETIME,
    @UserID INT,
    @TotalDifferenceValue DECIMAL(18,3),
    @Notes NVARCHAR(500),
    @DetailsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @StockTakeID = 0 OR @StockTakeID IS NULL
        BEGIN
            INSERT INTO [Inventory].[StockTakeHeader] 
                (StockTakeDate, UserID, Status, TotalDifferenceValue, Notes, CreatedAt)
            VALUES 
                (@StockTakeDate, @UserID, 'Pending', @TotalDifferenceValue, @Notes, GETDATE());
            
            SET @StockTakeID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- التأكد من عدم تعديل جرد معتمد
            IF EXISTS (SELECT 1 FROM [Inventory].[StockTakeHeader] WHERE StockTakeID = @StockTakeID AND Status <> 'Pending')
                THROW 50000, N'لا يمكن تعديل تسوية جرد تم اعتمادها أو رفضها مسبقاً', 1;

            UPDATE [Inventory].[StockTakeHeader]
            SET StockTakeDate = @StockTakeDate,
                UserID = @UserID,
                TotalDifferenceValue = @TotalDifferenceValue,
                Notes = @Notes
            WHERE StockTakeID = @StockTakeID;
            
            -- حذف التفاصيل القديمة
            DELETE FROM [Inventory].[StockTakeDetails] WHERE StockTakeID = @StockTakeID;
        END

        -- إدراج التفاصيل الجديدة
        INSERT INTO [Inventory].[StockTakeDetails] (StockTakeID, ProductID, SystemQuantity, ActualQuantity, CostPrice)
        SELECT 
            @StockTakeID,
            x.item.value('@ProductID', 'INT'),
            x.item.value('@SystemQuantity', 'DECIMAL(18,3)'),
            x.item.value('@ActualQuantity', 'DECIMAL(18,3)'),
            x.item.value('@CostPrice', 'DECIMAL(18,3)')
        FROM @DetailsXml.nodes('/Details/Item') AS x(item);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم إنشاء الإجراء المخزن لحفظ مسودة الجرد sp_StockTake_Save_XML';
GO

-- ============================================================
-- 9. إجراء مخزن لاعتماد تسوية الجرد وتعديل المخزون
-- ============================================================
IF OBJECT_ID('[Inventory].[sp_StockTake_Approve]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_StockTake_Approve];
GO

CREATE PROCEDURE [Inventory].[sp_StockTake_Approve]
    @StockTakeID INT,
    @ApprovedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @Status NVARCHAR(50);
        SELECT @Status = Status FROM [Inventory].[StockTakeHeader] WHERE StockTakeID = @StockTakeID;
        
        IF @Status <> 'Pending'
            THROW 50000, N'تسوية الجرد هذه معتمدة أو مرفوضة بالفعل ولا يمكن تعديلها.', 1;

        -- تحديث حالة المستند إلى Approved
        UPDATE [Inventory].[StockTakeHeader] 
        SET Status = 'Approved', ApprovedBy = @ApprovedBy, ApprovedAt = GETDATE()
        WHERE StockTakeID = @StockTakeID;

        -- ** ملاحظة هامة **
        -- هنا يتم تعديل المخزون الفعلي بناءً على الفرق (DifferenceQuantity)
        -- إذا كان الفرق موجب (فائض)، يتم إضافة الكمية.
        -- إذا كان الفرق سالب (عجز)، يتم خصم الكمية.
        -- كما في إجراء الهوالك، يجب استبدال هذا التحديث بكود التحديث الفعلي لنظامك (مثل [Inventory].[Products])

        /*
        UPDATE p
        SET p.Quantity = p.Quantity + d.DifferenceQuantity
        FROM [Inventory].[Products] p
        INNER JOIN [Inventory].[StockTakeDetails] d ON p.ProductID = d.ProductID
        WHERE d.StockTakeID = @StockTakeID AND d.DifferenceQuantity <> 0;
        */

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم إنشاء الإجراء المخزن لاعتماد تسوية الجرد sp_StockTake_Approve';
GO
-- =============================================
-- تعديل الإجراء المخزن لجلب رصيد الصنف ليدعم اختيار المخزن مع التوافق مع الكود القديم
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Stock_GetByProduct]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Stock_GetByProduct];
GO
CREATE PROCEDURE [Inventory].[sp_Stock_GetByProduct]
    @ProductID INT,
    @WarehouseID INT = NULL -- جعلناها اختيارية (NULL) حتى لا يتعطل الكود القديم
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @WarehouseID IS NOT NULL AND @WarehouseID > 0
    BEGIN
        -- النظام الجديد: جلب الرصيد للمخزن المحدد فقط
        SELECT ISNULL(CurrentQty, 0)
        FROM [Inventory].[ProductStock] 
        WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;
    END
    ELSE
    BEGIN
        -- النظام القديم: جلب إجمالي الرصيد من جميع المخازن
        SELECT ISNULL(SUM(CurrentQty), 0)
        FROM [Inventory].[ProductStock]
        WHERE ProductID = @ProductID;
    END
END
GO
-- =============================================
-- تعديل الإجراء المخزن لجلب متوسط التكلفة ليدعم اختيار المخزن مع التوافق مع الكود القديم
-- =============================================
IF OBJECT_ID('[Inventory].[sp_Inventory_GetAvgCostByProduct]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Inventory_GetAvgCostByProduct];
GO
CREATE PROCEDURE [Inventory].[sp_Inventory_GetAvgCostByProduct]
    @ProductID INT,
    @WarehouseID INT = NULL -- اختيارية للتوافق مع العمليات القديمة
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @WarehouseID IS NOT NULL AND @WarehouseID > 0
    BEGIN
        -- النظام الجديد: جلب التكلفة الخاصة بالمخزن المحدد
        SELECT ISNULL(AvgCostPrice, 0) 
        FROM [Inventory].[ProductStock] 
        WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;
    END
    ELSE
    BEGIN
        -- النظام القديم: جلب أحدث أو أعلى تكلفة متوفرة للصنف
        SELECT ISNULL(MAX(AvgCostPrice), 0)
        FROM [Inventory].[ProductStock]
        WHERE ProductID = @ProductID;
    END
END
GO
-- ============================================================
-- 1. sp_Wastage_GetAll  (قائمة سجلات الهالك مع الصفحات)
-- ============================================================
IF OBJECT_ID('[Inventory].[sp_Wastage_GetAll]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_GetAll];
GO

CREATE PROCEDURE [Inventory].[sp_Wastage_GetAll]
    @PageNumber INT = 1,
    @PageSize   INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    -- النتيجة الأولى: إجمالي عدد السجلات
    SELECT COUNT(*) FROM [Inventory].[WastageHeader];

    -- النتيجة الثانية: البيانات مع الصفحات
    SELECT
        w.*,
        u.FullName AS UserName
    FROM [Inventory].[WastageHeader] w
    LEFT JOIN [Security].[Users] u ON w.UserID = u.UserID
    ORDER BY w.WastageDate DESC, w.WastageID DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ============================================================
-- 2. sp_Wastage_GetDetails  (تفاصيل الأصناف مع كود الصنف)
-- ============================================================
IF OBJECT_ID('[Inventory].[sp_Wastage_GetDetails]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_GetDetails];
GO

CREATE PROCEDURE [Inventory].[sp_Wastage_GetDetails]
    @WastageID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.*,
        p.ProductName,
        ISNULL(p.Barcode, CAST(p.ProductID AS NVARCHAR(50))) AS ProductCode
    FROM [Inventory].[WastageDetails] d
    LEFT JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    WHERE d.WastageID = @WastageID;
END
GO

IF OBJECT_ID('[Inventory].[sp_Wastage_Unpost]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_Unpost];
GO

CREATE PROCEDURE [Inventory].[sp_Wastage_Unpost]
    @WastageID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IsPosted BIT;
        SELECT @IsPosted = IsPosted 
        FROM [Inventory].[WastageHeader] 
        WHERE WastageID = @WastageID;

        IF @IsPosted = 0
            THROW 50001, N'هذا المستند غير مرحّل أصلاً.', 1;

        -- الـ Trigger يتولى: إعادة الكمية + حذف القيد المحاسبي
        UPDATE [Inventory].[WastageHeader] 
        SET IsPosted = 0 
        WHERE WastageID = @WastageID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ============================================================
-- Trigger: trg_Wastage_Post
-- Table  : [Inventory].[WastageHeader]
-- Event  : AFTER UPDATE on IsPosted
--
-- POST   (IsPosted: 0 → 1):
--   1. خصم الكمية من [Inventory].[ProductStock]
--   2. إنشاء قيد محاسبي:
--        من  / حساب مصروف الهالك   (AccountCode LIKE '64%')
--        إلى / حساب المخزن المخصوم منه (Settings.Warehouses.AccountID)
--
-- UNPOST (IsPosted: 1 → 0):
--   1. إعادة الكمية إلى [Inventory].[ProductStock]
--   2. حذف القيود المحاسبية المرتبطة (ReferenceType = 'Wastage')
-- ============================================================
-- ============================================================
-- Trigger: trg_Wastage_Post
-- Table  : [Inventory].[WastageHeader]
-- Event  : AFTER UPDATE on IsPosted
--
-- POST   (IsPosted: 0 → 1):
--   1. خصم الكمية من [Inventory].[ProductStock]
--   2. إنشاء قيد محاسبي:
--        من  / حساب مصروف الهالك   (AccountCode LIKE '64%')
--        إلى / حساب المخزن المخصوم منه (Settings.Warehouses.AccountID)
--
-- UNPOST (IsPosted: 1 → 0):
--   1. إعادة الكمية إلى [Inventory].[ProductStock]
--   2. حذف القيود المحاسبية المرتبطة (ReferenceType = 'Wastage')
--
-- ملاحظة: Trigger يعمل داخل transaction ضمني تلقائياً،
--         لكن BEGIN TRY + ROLLBACK يضمن التراجع الكامل عند أي خطأ.
-- ============================================================

IF OBJECT_ID('[Inventory].[trg_Wastage_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Inventory].[trg_Wastage_Post];
GO

CREATE TRIGGER [Inventory].[trg_Wastage_Post]
ON [Inventory].[WastageHeader]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(IsPosted) RETURN;

    BEGIN TRY

        -- ══════════════════════════════════════════════════════════════
        -- القسم الأول: ترحيل (IsPosted: 0 → 1)
        -- ══════════════════════════════════════════════════════════════
        IF EXISTS (
            SELECT 1 FROM inserted i
            INNER JOIN deleted del ON i.WastageID = del.WastageID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
        )
        BEGIN

            -- ──────────────────────────────────────────────────────────
            -- 1A. خصم الكمية من ProductStock (سجلات موجودة)
            -- ──────────────────────────────────────────────────────────
            UPDATE S
            SET S.CurrentQty = S.CurrentQty - D.Quantity
            FROM [Inventory].[ProductStock] S
            INNER JOIN [Inventory].[WastageDetails] D   ON S.ProductID  = D.ProductID
            INNER JOIN inserted                     i   ON D.WastageID  = i.WastageID
            INNER JOIN deleted                      del ON i.WastageID  = del.WastageID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
              AND S.WarehouseID = i.WarehouseID;

            -- ──────────────────────────────────────────────────────────
            -- 1B. إدراج سجل سالب إذا لم يكن الصنف موجوداً في المستودع
            -- ──────────────────────────────────────────────────────────
            INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
            SELECT
                D.ProductID,
                i.WarehouseID,
                -SUM(D.Quantity),
                0
            FROM [Inventory].[WastageDetails] D
            INNER JOIN inserted i   ON D.WastageID = i.WastageID
            INNER JOIN deleted  del ON i.WastageID = del.WastageID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] S2
                  WHERE S2.ProductID   = D.ProductID
                    AND S2.WarehouseID = i.WarehouseID
              )
            GROUP BY D.ProductID, i.WarehouseID;

            -- ──────────────────────────────────────────────────────────
            -- 2. القيد المحاسبي
            -- ──────────────────────────────────────────────────────────

            DECLARE @WastageExpenseAcc INT;
            SET @WastageExpenseAcc = ISNULL(
                (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts]
                 WHERE AccountCode LIKE '64%' AND IsTransactional = 1 ORDER BY AccountCode),
                (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts]
                 WHERE AccountCode LIKE '5%'  AND IsTransactional = 1 ORDER BY AccountCode DESC)
            );

            DECLARE @InventoryFallbackAcc INT;
            SET @InventoryFallbackAcc = ISNULL(
                (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts]
                 WHERE AccountCode LIKE '13%' AND IsTransactional = 1 ORDER BY AccountCode),
                (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts]
                 WHERE AccountCode = '13')
            );

            DECLARE @WastageEntryMap TABLE (WastageID INT, EntryNo INT);

            INSERT INTO @WastageEntryMap (WastageID, EntryNo)
            SELECT i.WastageID, NEXT VALUE FOR [Accounting].[seq_EntryNo]
            FROM inserted i
            INNER JOIN deleted del ON i.WastageID = del.WastageID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0;

            -- الطرف الأول: مدين / مصروف الهالك
            ;WITH WastageCost AS (
                SELECT D.WastageID, SUM(D.Quantity * D.CostPrice) AS TotalCost
                FROM [Inventory].[WastageDetails] D
                INNER JOIN inserted i   ON D.WastageID = i.WastageID
                INNER JOIN deleted  del ON i.WastageID = del.WastageID
                WHERE i.IsPosted = 1 AND del.IsPosted = 0
                GROUP BY D.WastageID
            )
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID,
                 AccountID, DebitAmount, CreditAmount, Description, UserID)
            SELECT
                m.EntryNo, i.WastageDate, 'Wastage', i.WastageID,
                @WastageExpenseAcc,
                wc.TotalCost, 0,
                N'هالك رقم ' + CAST(i.WastageID AS NVARCHAR) +
                    CASE WHEN i.Notes IS NOT NULL AND LEN(LTRIM(i.Notes)) > 0
                         THEN N' - ' + i.Notes ELSE N'' END,
                i.UserID
            FROM inserted i
            INNER JOIN deleted          del ON i.WastageID  = del.WastageID
            INNER JOIN @WastageEntryMap m   ON m.WastageID  = i.WastageID
            INNER JOIN WastageCost      wc  ON wc.WastageID = i.WastageID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0 AND wc.TotalCost > 0;

            -- الطرف الثاني: دائن / حساب المخزن
            ;WITH WastageCost AS (
                SELECT D.WastageID, SUM(D.Quantity * D.CostPrice) AS TotalCost
                FROM [Inventory].[WastageDetails] D
                INNER JOIN inserted i   ON D.WastageID = i.WastageID
                INNER JOIN deleted  del ON i.WastageID = del.WastageID
                WHERE i.IsPosted = 1 AND del.IsPosted = 0
                GROUP BY D.WastageID
            )
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID,
                 AccountID, DebitAmount, CreditAmount, Description, UserID)
            SELECT
                m.EntryNo, i.WastageDate, 'Wastage', i.WastageID,
                ISNULL(w.AccountID, @InventoryFallbackAcc),
                0, wc.TotalCost,
                N'هالك رقم ' + CAST(i.WastageID AS NVARCHAR) +
                    CASE WHEN i.Notes IS NOT NULL AND LEN(LTRIM(i.Notes)) > 0
                         THEN N' - ' + i.Notes ELSE N'' END,
                i.UserID
            FROM inserted i
            INNER JOIN deleted             del ON i.WastageID  = del.WastageID
            INNER JOIN @WastageEntryMap    m   ON m.WastageID  = i.WastageID
            INNER JOIN WastageCost         wc  ON wc.WastageID = i.WastageID
            LEFT JOIN  [Settings].[Warehouses] w ON w.WarehouseID = i.WarehouseID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0 AND wc.TotalCost > 0;

        END -- نهاية قسم الترحيل

        -- ══════════════════════════════════════════════════════════════
        -- القسم الثاني: إلغاء الترحيل (IsPosted: 1 → 0)
        -- ══════════════════════════════════════════════════════════════
        IF EXISTS (
            SELECT 1 FROM inserted i
            INNER JOIN deleted del ON i.WastageID = del.WastageID
            WHERE i.IsPosted = 0 AND del.IsPosted = 1
        )
        BEGIN
            -- 1A. إعادة الكمية (سجلات موجودة)
            UPDATE S
            SET S.CurrentQty = S.CurrentQty + D.Quantity
            FROM [Inventory].[ProductStock] S
            INNER JOIN [Inventory].[WastageDetails] D   ON S.ProductID  = D.ProductID
            INNER JOIN inserted                     i   ON D.WastageID  = i.WastageID
            INNER JOIN deleted                      del ON i.WastageID  = del.WastageID
            WHERE i.IsPosted = 0 AND del.IsPosted = 1
              AND S.WarehouseID = i.WarehouseID;

            -- 1B. إدراج سجل إيجابي إذا لم يكن موجوداً
            INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
            SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity), 0
            FROM [Inventory].[WastageDetails] D
            INNER JOIN inserted i   ON D.WastageID = i.WastageID
            INNER JOIN deleted  del ON i.WastageID = del.WastageID
            WHERE i.IsPosted = 0 AND del.IsPosted = 1
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] S2
                  WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
              )
            GROUP BY D.ProductID, i.WarehouseID;

            -- 2. حذف القيود المحاسبية
            DELETE JE
            FROM [Accounting].[JournalEntries] JE
            INNER JOIN inserted i   ON JE.ReferenceID = i.WastageID
            INNER JOIN deleted  del ON i.WastageID    = del.WastageID
            WHERE JE.ReferenceType = 'Wastage'
              AND i.IsPosted = 0 AND del.IsPosted = 1;

        END -- نهاية قسم إلغاء الترحيل

    END TRY
    BEGIN CATCH
        -- التراجع الكامل عن كل التغييرات في حالة أي خطأ
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW; -- إعادة رفع الخطأ للـ caller
    END CATCH

END
GO

PRINT N'✅ تم إنشاء Trigger ترحيل الهالك: trg_Wastage_Post (مع Transaction)';
GO
IF OBJECT_ID('[Inventory].[sp_Wastage_Report]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_Report];
GO
CREATE PROCEDURE [Inventory].[sp_Wastage_Report]
    @StartDate DATE,
    @EndDate   DATE,
    @WarehouseID INT = NULL,
    @ProductID   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.WastageID,
        h.WastageDate,
        h.Notes,
        h.IsPosted,
        w.WarehouseName,
        p.ProductName,
        ISNULL(p.Barcode, CAST(p.ProductID AS NVARCHAR)) AS ProductCode,
        d.Quantity,
        d.CostPrice,
        d.Quantity * d.CostPrice AS TotalCost
    FROM [Inventory].[WastageHeader] h
    INNER JOIN [Inventory].[WastageDetails] d ON h.WastageID = d.WastageID
    LEFT JOIN  [Settings].[Warehouses]      w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN  [Inventory].[Products]       p ON d.ProductID   = p.ProductID
    WHERE CAST(h.WastageDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND (@WarehouseID IS NULL OR h.WarehouseID = @WarehouseID)
      AND (@ProductID   IS NULL OR d.ProductID   = @ProductID)
    ORDER BY h.WastageDate DESC, h.WastageID;
END
GO

-- 1. إضافة عمود الرصيد قبل الهالك لجدول التفاصيل
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE Name = N'StockBefore' AND Object_ID = Object_ID(N'[Inventory].[WastageDetails]')
)
BEGIN
    ALTER TABLE [Inventory].[WastageDetails] ADD StockBefore DECIMAL(18,3) NOT NULL DEFAULT 0;
    PRINT N'✅ تم إضافة عمود StockBefore بنجاح';
END
GO
-- 2. تحديث إجراء جلب تفاصيل الهالك ليعرض الرصيد كـ AvailableQuantity
IF OBJECT_ID('[Inventory].[sp_Wastage_GetDetails]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_GetDetails];
GO
CREATE PROCEDURE [Inventory].[sp_Wastage_GetDetails]
    @WastageID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.DetailID,
        d.WastageID,
        d.ProductID,
        ISNULL(p.Barcode, CAST(p.ProductID AS NVARCHAR)) AS ProductCode,
        p.ProductName,
        d.Quantity,
        d.CostPrice,
        d.TotalCost,
        d.StockBefore AS AvailableQuantity -- <== الخدعة: نعرضه بهذا الاسم ليتعرف عليه الـ Dapper مباشرة
    FROM [Inventory].[WastageDetails] d
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    WHERE d.WastageID = @WastageID;
END
GO
PRINT N'✅ تم تحديث الإجراء [Inventory].[sp_Wastage_GetDetails]';
GO
-- 3. تحديث إجراء حفظ الهالك لقراءة الرصيد من الـ XML وحفظه
IF OBJECT_ID('[Inventory].[sp_Wastage_Save_XML]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Wastage_Save_XML];
GO
CREATE PROCEDURE [Inventory].[sp_Wastage_Save_XML]
    @WastageID INT OUTPUT,
    @WastageDate DATETIME,
    @UserID INT,
    @ShiftID INT = NULL,
    @WarehouseID INT = 1,
    @TotalValue DECIMAL(18,3),
    @Notes NVARCHAR(500),
    @DetailsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @WastageID = 0 OR @WastageID IS NULL
        BEGIN
            INSERT INTO [Inventory].[WastageHeader] 
                (WastageDate, UserID, ShiftID, WarehouseID, TotalValue, Notes, CreatedAt, IsPosted)
            VALUES 
                (@WastageDate, @UserID, @ShiftID, @WarehouseID, @TotalValue, @Notes, GETDATE(), 0);
            
            SET @WastageID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [Inventory].[WastageHeader]
            SET WastageDate = @WastageDate,
                UserID = @UserID,
                ShiftID = @ShiftID,
                WarehouseID = @WarehouseID,
                TotalValue = @TotalValue,
                Notes = @Notes
            WHERE WastageID = @WastageID;
            
            -- حذف التفاصيل القديمة
            DELETE FROM [Inventory].[WastageDetails] WHERE WastageID = @WastageID;
        END
        -- إدراج التفاصيل الجديدة مع حفظ الـ StockBefore
        INSERT INTO [Inventory].[WastageDetails] (WastageID, ProductID, Quantity, CostPrice, StockBefore)
        SELECT 
            @WastageID,
            x.item.value('@ProductID', 'INT'),
            x.item.value('@Quantity', 'DECIMAL(18,3)'),
            x.item.value('@CostPrice', 'DECIMAL(18,3)'),
            ISNULL(x.item.value('@StockBefore', 'DECIMAL(18,3)'), 0)
        FROM @DetailsXml.nodes('/Details/Item') AS x(item);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم تحديث الإجراء [Inventory].[sp_Wastage_Save_XML]';
GO


-- 1. إضافة عمود WarehouseID لجدول StockTakeHeader
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE Name = N'WarehouseID' AND Object_ID = Object_ID(N'[Inventory].[StockTakeHeader]')
)
BEGIN
    ALTER TABLE [Inventory].[StockTakeHeader] ADD WarehouseID INT NOT NULL DEFAULT 1;
    PRINT N'✅ تم إضافة عمود WarehouseID بنجاح';
END
GO
-- 2. إجراء جلب كل مسودات وسجلات الجرد (GetAll)
IF OBJECT_ID('[Inventory].[sp_StockTake_GetAll]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_StockTake_GetAll];
GO
CREATE PROCEDURE [Inventory].[sp_StockTake_GetAll]
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    -- Count total records
    SELECT COUNT(*) AS TotalCount 
    FROM [Inventory].[StockTakeHeader];
    -- Get paginated records
    SELECT 
        h.StockTakeID,
        h.StockTakeDate,
        h.UserID,
        h.WarehouseID,
        h.Status,
        h.TotalDifferenceValue,
        h.Notes,
        h.CreatedAt,
        h.ApprovedBy,
        h.ApprovedAt,
        u.FullName AS UserName,
        w.WarehouseName
    FROM [Inventory].[StockTakeHeader] h
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    ORDER BY h.StockTakeDate DESC, h.StockTakeID DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
PRINT N'✅ تم إنشاء [Inventory].[sp_StockTake_GetAll]';
GO
-- 3. إجراء جلب تفاصيل الجرد (GetDetails)
IF OBJECT_ID('[Inventory].[sp_StockTake_GetDetails]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_StockTake_GetDetails];
GO
CREATE PROCEDURE [Inventory].[sp_StockTake_GetDetails]
    @StockTakeID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.DetailID,
        d.StockTakeID,
        d.ProductID,
        ISNULL(p.Barcode, CAST(p.ProductID AS NVARCHAR)) AS ProductCode,
        p.ProductName,
        d.SystemQuantity,
        d.ActualQuantity,
        d.DifferenceQuantity,
        d.CostPrice,
        d.DifferenceValue
    FROM [Inventory].[StockTakeDetails] d
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    WHERE d.StockTakeID = @StockTakeID;
END
GO
PRINT N'✅ تم إنشاء [Inventory].[sp_StockTake_GetDetails]';
GO
-- 4. إجراء حفظ الجرد كمسودة باستخدام XML (Save_XML)
IF OBJECT_ID('[Inventory].[sp_StockTake_Save_XML]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_StockTake_Save_XML];
GO
CREATE PROCEDURE [Inventory].[sp_StockTake_Save_XML]
    @StockTakeID INT OUTPUT,
    @StockTakeDate DATETIME,
    @UserID INT,
    @WarehouseID INT = 1,
    @TotalDifferenceValue DECIMAL(18,3),
    @Notes NVARCHAR(500),
    @DetailsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @StockTakeID = 0 OR @StockTakeID IS NULL
        BEGIN
            INSERT INTO [Inventory].[StockTakeHeader] 
                (StockTakeDate, UserID, WarehouseID, TotalDifferenceValue, Notes, CreatedAt, Status)
            VALUES 
                (@StockTakeDate, @UserID, @WarehouseID, @TotalDifferenceValue, @Notes, GETDATE(), 'Pending');
            
            SET @StockTakeID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [Inventory].[StockTakeHeader]
            SET StockTakeDate = @StockTakeDate,
                UserID = @UserID,
                WarehouseID = @WarehouseID,
                TotalDifferenceValue = @TotalDifferenceValue,
                Notes = @Notes
            WHERE StockTakeID = @StockTakeID AND Status = 'Pending';
            
            -- حذف التفاصيل القديمة
            DELETE FROM [Inventory].[StockTakeDetails] WHERE StockTakeID = @StockTakeID;
        END
        -- إدراج التفاصيل الجديدة
        INSERT INTO [Inventory].[StockTakeDetails] (StockTakeID, ProductID, SystemQuantity, ActualQuantity, CostPrice)
        SELECT 
            @StockTakeID,
            x.item.value('@ProductID', 'INT'),
            x.item.value('@SystemQuantity', 'DECIMAL(18,3)'),
            x.item.value('@ActualQuantity', 'DECIMAL(18,3)'),
            x.item.value('@CostPrice', 'DECIMAL(18,3)')
        FROM @DetailsXml.nodes('/Details/Item') AS x(item);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم إنشاء [Inventory].[sp_StockTake_Save_XML]';
GO
-- 5. إجراء الاعتماد وتعديل الكميات (Approve)

IF OBJECT_ID('[Inventory].[sp_StockTake_Approve]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_StockTake_Approve];
GO
CREATE PROCEDURE [Inventory].[sp_StockTake_Approve]
    @StockTakeID INT,
    @ApprovedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Status NVARCHAR(50);
        DECLARE @WarehouseID INT;
        DECLARE @StockTakeDate DATETIME;
        DECLARE @Notes NVARCHAR(500);
        SELECT @Status = Status, @WarehouseID = WarehouseID, @StockTakeDate = StockTakeDate, @Notes = Notes 
        FROM [Inventory].[StockTakeHeader] 
        WHERE StockTakeID = @StockTakeID;
        IF @Status = 'Approved'
            THROW 50000, N'تم اعتماد الجرد مسبقاً ولا يمكن اعتماده مرة أخرى.', 1;
        -- 1. تعديل حالة المستند
        UPDATE [Inventory].[StockTakeHeader] 
        SET Status = 'Approved', 
            ApprovedBy = @ApprovedBy, 
            ApprovedAt = GETDATE() 
        WHERE StockTakeID = @StockTakeID;
        -- 2. تحديث الكميات في جدول ProductStock (المخزون حسب المستودع)
        -- إضافة الفرق (DifferenceQuantity) إلى الرصيد الحالي
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + D.DifferenceQuantity
        FROM [Inventory].[ProductStock] S
        INNER JOIN [Inventory].[StockTakeDetails] D ON S.ProductID = D.ProductID
        WHERE D.StockTakeID = @StockTakeID AND S.WarehouseID = @WarehouseID;
        -- إدراج سجل جديد للأصناف التي ليس لها رصيد سابق في هذا المستودع وكان فيها زيادة
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT D.ProductID, @WarehouseID, D.DifferenceQuantity, D.CostPrice
        FROM [Inventory].[StockTakeDetails] D
        WHERE D.StockTakeID = @StockTakeID 
          AND D.DifferenceQuantity <> 0
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = @WarehouseID
          );
        -- 3. تسجيل القيود المحاسبية
        -- حساب التسويات/الهالك (64xx) وحساب المخزون (13xx)
        DECLARE @AdjExpenseAcc INT = ISNULL(
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1 ORDER BY AccountCode),
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '5%'  AND IsTransactional = 1 ORDER BY AccountCode DESC)
        );
        DECLARE @InventoryAcc INT = ISNULL(
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1 ORDER BY AccountCode),
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13')
        );
        -- حساب إجمالي العجز (Difference < 0) وإجمالي الزيادة (Difference > 0)
        DECLARE @TotalDeficitValue DECIMAL(18,3) = 0; -- عجز (مدين مصروف)
        DECLARE @TotalSurplusValue DECIMAL(18,3) = 0; -- زيادة (دائن إيراد/مصروف بالسالب)
        SELECT 
            @TotalDeficitValue = ISNULL(SUM(ABS(DifferenceValue)), 0)
        FROM [Inventory].[StockTakeDetails] 
        WHERE StockTakeID = @StockTakeID AND DifferenceQuantity < 0;
        SELECT 
            @TotalSurplusValue = ISNULL(SUM(DifferenceValue), 0)
        FROM [Inventory].[StockTakeDetails] 
        WHERE StockTakeID = @StockTakeID AND DifferenceQuantity > 0;
        -- إنشاء رقم قيد جديد
        DECLARE @EntryNo INT = NEXT VALUE FOR [Accounting].[seq_EntryNo];
        DECLARE @Desc NVARCHAR(500) = N'تسوية جرد رقم ' + CAST(@StockTakeID AS NVARCHAR) + 
                                      CASE WHEN LEN(ISNULL(@Notes, '')) > 0 THEN N' - ' + @Notes ELSE N'' END;
        -- أ) تسجيل قيد العجز (نقص في المخزون -> مصروف مدين، المخزون دائن)
        IF @TotalDeficitValue > 0
        BEGIN
            -- الطرف المدين: مصروف التسوية (عجز)
            INSERT INTO [Accounting].[JournalEntries] 
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES 
                (@EntryNo, @StockTakeDate, 'StockTake', @StockTakeID, @AdjExpenseAcc, @TotalDeficitValue, 0, @Desc + N' (عجز)', @ApprovedBy);
            -- الطرف الدائن: المخزون
            INSERT INTO [Accounting].[JournalEntries] 
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES 
                (@EntryNo, @StockTakeDate, 'StockTake', @StockTakeID, @InventoryAcc, 0, @TotalDeficitValue, @Desc + N' (عجز)', @ApprovedBy);
        END
        -- ب) تسجيل قيد الزيادة (زيادة في المخزون -> المخزون مدين، إيراد أو عكس المصفوف دائن)
        IF @TotalSurplusValue > 0
        BEGIN
            -- الطرف المدين: المخزون
            INSERT INTO [Accounting].[JournalEntries] 
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES 
                (@EntryNo, @StockTakeDate, 'StockTake', @StockTakeID, @InventoryAcc, @TotalSurplusValue, 0, @Desc + N' (زيادة)', @ApprovedBy);
            -- الطرف الدائن: مصروف التسوية (زيادة)
            INSERT INTO [Accounting].[JournalEntries] 
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES 
                (@EntryNo, @StockTakeDate, 'StockTake', @StockTakeID, @AdjExpenseAcc, 0, @TotalSurplusValue, @Desc + N' (زيادة)', @ApprovedBy);
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT N'✅ تم تحديث [Inventory].[sp_StockTake_Approve] بالقيود وتحديث المستودع';
GO


-- =============================================
-- 1. تحديث ملخص بطاقة الصنف
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetSummary]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetSummary];
GO
create PROCEDURE [Inventory].[sp_ProductCard_GetSummary]
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
    DECLARE @AlertQty          DECIMAL(18,2) = 0;
    DECLARE @Barcode           NVARCHAR(50) = '';
    DECLARE @SalePrice         DECIMAL(18,2) = 0;

    -- معلومات الصنف
    SELECT 
        @AlertQty  = ISNULL(AlertQty, 0),
        @Barcode   = ISNULL(Barcode, ''),
        @SalePrice = ISNULL(SalePrice, 0)
    FROM [Inventory].[Products]
    WHERE ProductID = @ProductID;

    -- الرصيد الحالي التراكمي
    SELECT @Balance = ISNULL(SUM(CurrentQty), 0)
    FROM [Inventory].[ProductStock]
    WHERE ProductID = @ProductID;

    -- 1. إجمالي الوارد = فواتير الشراء
    SELECT
        @TotalInQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalInValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Purchase';

    -- إضافة زيادة الجرد المعتمدة
    DECLARE @StockTakeInQty DECIMAL(18,2) = 0;
    DECLARE @StockTakeInValue DECIMAL(18,2) = 0;
    SELECT 
        @StockTakeInQty = ISNULL(SUM(d.DifferenceQuantity), 0),
        @StockTakeInValue = ISNULL(SUM(d.DifferenceValue), 0)
    FROM [Inventory].[StockTakeDetails] d
    INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
    WHERE d.ProductID = @ProductID
      AND h.Status = 'Approved'
      AND d.DifferenceQuantity > 0;

    SET @TotalInQty = @TotalInQty + @StockTakeInQty;
    SET @TotalInValue = @TotalInValue + @StockTakeInValue;

    -- 2. إجمالي الصادر = فواتير البيع
    SELECT
        @TotalOutQty   = ISNULL(SUM(d.Quantity), 0),
        @TotalOutValue = ISNULL(SUM(d.TotalPrice), 0)
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted  = 1
      AND h.InvType   = 'Sales';

    -- إضافة الهوالك المرحلة
    DECLARE @WastageOutQty DECIMAL(18,2) = 0;
    DECLARE @WastageOutValue DECIMAL(18,2) = 0;
    SELECT
        @WastageOutQty = ISNULL(SUM(d.Quantity), 0),
        @WastageOutValue = ISNULL(SUM(d.Quantity * d.CostPrice), 0)
    FROM [Inventory].[WastageDetails] d
    INNER JOIN [Inventory].[WastageHeader] h ON d.WastageID = h.WastageID
    WHERE d.ProductID = @ProductID
      AND h.IsPosted = 1;

    -- إضافة عجز الجرد المعتمد
    DECLARE @StockTakeOutQty DECIMAL(18,2) = 0;
    DECLARE @StockTakeOutValue DECIMAL(18,2) = 0;
    SELECT
        @StockTakeOutQty = ISNULL(SUM(ABS(d.DifferenceQuantity)), 0),
        @StockTakeOutValue = ISNULL(SUM(ABS(d.DifferenceValue)), 0)
    FROM [Inventory].[StockTakeDetails] d
    INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
    WHERE d.ProductID = @ProductID
      AND h.Status = 'Approved'
      AND d.DifferenceQuantity < 0;

    SET @TotalOutQty = @TotalOutQty + @WastageOutQty + @StockTakeOutQty;
    SET @TotalOutValue = @TotalOutValue + @WastageOutValue + @StockTakeOutValue;

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
        @ProfitRate         AS ProfitRate,
        @AlertQty           AS AlertQty,
        @Barcode            AS Barcode,
        @SalePrice          AS SalePrice;
END
GO

-- =============================================
-- 2. تحديث أرصدة المستودعات مع إحصائيات الوارد والصادر والهالك
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetStockByWarehouse]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetStockByWarehouse];
GO
create PROCEDURE [Inventory].[sp_ProductCard_GetStockByWarehouse]
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @AlertQty DECIMAL(18,2) = 0;
    SELECT @AlertQty = ISNULL(AlertQty, 0)
    FROM [Inventory].[Products]
    WHERE ProductID = @ProductID;

    SELECT 
        w.WarehouseID,
        w.WarehouseName,
        ISNULL(s.CurrentQty, 0) AS CurrentQty,
        @AlertQty AS AlertQty,
        
        -- إجمالي الوارد (مشتريات للمستودع + زيادة الجرد)
        ISNULL((
            SELECT SUM(id.Quantity)
            FROM [Sales].[InvoiceDetails] id
            INNER JOIN [Sales].[InvoiceHeader] ih ON id.InvID = ih.InvID
            WHERE id.ProductID = @ProductID 
              AND ih.IsPosted = 1 
              AND ih.InvType = 'Purchase' 
              AND ih.WarehouseID = w.WarehouseID
        ), 0) +
        ISNULL((
            SELECT SUM(std.DifferenceQuantity)
            FROM [Inventory].[StockTakeDetails] std
            INNER JOIN [Inventory].[StockTakeHeader] sth ON std.StockTakeID = sth.StockTakeID
            WHERE std.ProductID = @ProductID 
              AND sth.Status = 'Approved' 
              AND sth.WarehouseID = w.WarehouseID
              AND std.DifferenceQuantity > 0
        ), 0) AS IncomingQty,

        -- إجمالي المنصرف (مبيعات للمستودع + هالك + عجز جرد)
        ISNULL((
            SELECT SUM(id.Quantity)
            FROM [Sales].[InvoiceDetails] id
            INNER JOIN [Sales].[InvoiceHeader] ih ON id.InvID = ih.InvID
            WHERE id.ProductID = @ProductID 
              AND ih.IsPosted = 1 
              AND ih.InvType = 'Sales' 
              AND ih.WarehouseID = w.WarehouseID
        ), 0) +
        ISNULL((
            SELECT SUM(wd.Quantity)
            FROM [Inventory].[WastageDetails] wd
            INNER JOIN [Inventory].[WastageHeader] wh ON wd.WastageID = wh.WastageID
            WHERE wd.ProductID = @ProductID 
              AND wh.IsPosted = 1 
              AND wh.WarehouseID = w.WarehouseID
        ), 0) +
        ISNULL((
            SELECT SUM(ABS(std.DifferenceQuantity))
            FROM [Inventory].[StockTakeDetails] std
            INNER JOIN [Inventory].[StockTakeHeader] sth ON std.StockTakeID = sth.StockTakeID
            WHERE std.ProductID = @ProductID 
              AND sth.Status = 'Approved' 
              AND sth.WarehouseID = w.WarehouseID
              AND std.DifferenceQuantity < 0
        ), 0) AS OutgoingQty,

        -- إجمالي الهالك الخاص بالمستودع
        ISNULL((
            SELECT SUM(wd.Quantity)
            FROM [Inventory].[WastageDetails] wd
            INNER JOIN [Inventory].[WastageHeader] wh ON wd.WastageID = wh.WastageID
            WHERE wd.ProductID = @ProductID 
              AND wh.IsPosted = 1 
              AND wh.WarehouseID = w.WarehouseID
        ), 0) AS WastageQty

    FROM [Settings].[Warehouses] w
    LEFT JOIN [Inventory].[ProductStock] s ON s.WarehouseID = w.WarehouseID AND s.ProductID = @ProductID
    ORDER BY w.WarehouseName;
END
GO

-- =============================================
-- 3. تحديث جلب حركات الصنف الموحدة
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetMovements]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetMovements];
GO
create PROCEDURE [Inventory].[sp_ProductCard_GetMovements]
    @ProductID   INT,
    @FilterType  NVARCHAR(10) = 'ALL',  -- 'ALL' | 'IN' | 'OUT'
    @PageNumber  INT          = 1,
    @PageSize    INT          = 15
AS
BEGIN
    SET NOCOUNT ON;

    WITH AllMovements AS (
        -- أ. الفواتير
        SELECT
            h.InvID,
            CAST(h.InvID AS NVARCHAR(50)) AS ReferenceNo,
            h.InvDate,
            h.InvType,
            CASE WHEN h.InvType = 'Purchase' THEN 'IN' ELSE 'OUT' END AS MovementDirection,
            CASE WHEN h.InvType = 'Purchase' THEN N'فاتورة شراء' ELSE N'فاتورة بيع' END AS InvTypeName,
            d.Quantity,
            d.UnitPrice,
            d.TotalPrice,
            p.PartnerName
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1

        UNION ALL

        -- ب. الهوالك (منصرف دائمًا)
        SELECT
            h.WastageID AS InvID,
            N'W-' + CAST(h.WastageID AS NVARCHAR(50)) AS ReferenceNo,
            h.WastageDate AS InvDate,
            'Wastage' AS InvType,
            'OUT' AS MovementDirection,
            N'إهلاك بضاعة' AS InvTypeName,
            d.Quantity,
            d.CostPrice AS UnitPrice,
            d.Quantity * d.CostPrice AS TotalPrice,
            w.WarehouseName AS PartnerName
        FROM [Inventory].[WastageDetails] d
        INNER JOIN [Inventory].[WastageHeader] h ON d.WastageID = h.WastageID
        LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1

        UNION ALL

        -- ج. الجرود (تسوية زيادة أو عجز)
        SELECT
            h.StockTakeID AS InvID,
            N'ST-' + CAST(h.StockTakeID AS NVARCHAR(50)) AS ReferenceNo,
            h.StockTakeDate AS InvDate,
            'StockTake' AS InvType,
            CASE WHEN d.DifferenceQuantity > 0 THEN 'IN' ELSE 'OUT' END AS MovementDirection,
            CASE WHEN d.DifferenceQuantity > 0 THEN N'تسوية جرد (زيادة)' ELSE N'تسوية جرد (عجز)' END AS InvTypeName,
            ABS(d.DifferenceQuantity) AS Quantity,
            d.CostPrice AS UnitPrice,
            ABS(d.DifferenceQuantity * d.CostPrice) AS TotalPrice,
            w.WarehouseName AS PartnerName
        FROM [Inventory].[StockTakeDetails] d
        INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
        LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID
          AND h.Status = 'Approved'
          AND d.DifferenceQuantity <> 0
    )
    SELECT 
        InvID,
        ReferenceNo,
        InvDate,
        InvType,
        MovementDirection,
        InvTypeName,
        Quantity,
        UnitPrice,
        TotalPrice,
        PartnerName,
        COUNT(*) OVER () AS TotalCount
    FROM AllMovements
    WHERE (
            @FilterType = 'ALL'
         OR (@FilterType = 'IN' AND MovementDirection = 'IN')
         OR (@FilterType = 'OUT' AND MovementDirection = 'OUT')
          )
    ORDER BY InvDate DESC, InvID DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- =============================================
-- 4. تحديث الرسم البياني
-- =============================================
IF OBJECT_ID('[Inventory].[sp_ProductCard_GetChartData]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_ProductCard_GetChartData];
GO
create PROCEDURE [Inventory].[sp_ProductCard_GetChartData]
    @ProductID  INT,
    @MonthsBack INT = 12
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FromDate DATE = DATEADD(MONTH, -@MonthsBack, CAST(GETDATE() AS DATE));

    WITH DailyTransactions AS (
        -- الفواتير
        SELECT
            CAST(h.InvDate AS DATE) AS MovementDate,
            CASE WHEN h.InvType = 'Purchase' THEN d.Quantity ELSE 0 END AS InQty,
            CASE WHEN h.InvType = 'Sales' THEN d.Quantity ELSE 0 END AS OutQty
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1
          AND CAST(h.InvDate AS DATE) >= @FromDate

        UNION ALL

        -- الهوالك
        SELECT
            CAST(h.WastageDate AS DATE) AS MovementDate,
            0 AS InQty,
            d.Quantity AS OutQty
        FROM [Inventory].[WastageDetails] d
        INNER JOIN [Inventory].[WastageHeader] h ON d.WastageID = h.WastageID
        WHERE d.ProductID = @ProductID
          AND h.IsPosted = 1
          AND CAST(h.WastageDate AS DATE) >= @FromDate

        UNION ALL

        -- الجرود
        SELECT
            CAST(h.StockTakeDate AS DATE) AS MovementDate,
            CASE WHEN d.DifferenceQuantity > 0 THEN d.DifferenceQuantity ELSE 0 END AS InQty,
            CASE WHEN d.DifferenceQuantity < 0 THEN ABS(d.DifferenceQuantity) ELSE 0 END AS OutQty
        FROM [Inventory].[StockTakeDetails] d
        INNER JOIN [Inventory].[StockTakeHeader] h ON d.StockTakeID = h.StockTakeID
        WHERE d.ProductID = @ProductID
          AND h.Status = 'Approved'
          AND d.DifferenceQuantity <> 0
          AND CAST(h.StockTakeDate AS DATE) >= @FromDate
    )
    SELECT
        CASE WHEN @MonthsBack <= 1 THEN MovementDate ELSE EOMONTH(MovementDate) END AS MovementDate,
        SUM(InQty) AS DailyInQty,
        SUM(OutQty) AS DailyOutQty,
        SUM(InQty - OutQty) AS NetDayMovement
    FROM DailyTransactions
    GROUP BY CASE WHEN @MonthsBack <= 1 THEN MovementDate ELSE EOMONTH(MovementDate) END
    ORDER BY MovementDate ASC;
END
GO


IF OBJECT_ID('[Inventory].[sp_Product_QuickAdd]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Product_QuickAdd];
GO

CREATE PROCEDURE [Inventory].[sp_Product_QuickAdd]
    @Barcode      NVARCHAR(50),
    @ProductName  NVARCHAR(200),
    @PurchasePrice DECIMAL(18,3) = 0,
    @SalePrice     DECIMAL(18,3) = 0,
    @ProductType   INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewID INT;

    INSERT INTO [Inventory].[Products] (
        ProductName,
        Barcode,
        CategoryID, -- الافتراضي 1 (غير محدد)
        UnitID,     -- الافتراضي 1 (حبة/قطعة)
        PurchasePrice,
        SalePrice,
        AlertQty,
        IsActive,
        ProductType
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
        ISNULL(@ProductType, 1)
    );

    SET @NewID = SCOPE_IDENTITY();
    SELECT @NewID AS ProductID;
END
GO


IF OBJECT_ID('[Sales].[sp_Invoice_Post]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post];
GO
create PROCEDURE [Sales].[sp_Invoice_Post]
    @InvID INT,
    @UserID INT
AS
BEGIN
    UPDATE [Sales].[InvoiceHeader]
    SET IsPosted = 1, UserID = @UserID
    WHERE InvID = @InvID;
END;
GO

IF OBJECT_ID('[Sales].[sp_Invoice_Unpost]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Unpost];
GO
create PROCEDURE [Sales].[sp_Invoice_Unpost]
    @InvID INT,
    @UserID INT
AS
BEGIN
    UPDATE [Sales].[InvoiceHeader]
    SET IsPosted = 0
    WHERE InvID = @InvID;
END;
go
 
 IF OBJECT_ID('[Sales].[trg_Invoice_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_Invoice_Post];
GO
 create TRIGGER [Sales].[trg_Invoice_Post]
ON [Sales].[InvoiceHeader]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- الفلترة الأساسية: العمل فقط عند تغير حالة IsPosted
    IF NOT UPDATE(IsPosted) RETURN;

    -- 1. متغيرات الحسابات الافتراضية
    DECLARE @InventoryAcc INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1 ORDER BY AccountCode);
    DECLARE @SalesAcc     INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1 ORDER BY AccountCode);
    DECLARE @COGSAcc      INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1 ORDER BY AccountCode);
    DECLARE @CustomerAcc  INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1 ORDER BY AccountCode);
    DECLARE @VendorAcc    INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1 ORDER BY AccountCode);

    -- ==========================================================
    -- أولاً: حالة الترحيل (POSTING: 0 -> 1)
    -- ==========================================================
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        
        -- أ. تحديث متوسط التكلفة (للمشتريات فقط)
        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (S.CurrentQty + T.TotalQty) > 0 
            THEN (S.CurrentQty * ISNULL(S.AvgCostPrice, 0) + T.TotalSum) / (S.CurrentQty + T.TotalQty)
            ELSE T.WeightedPrice END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum,
                   SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0) as WeightedPrice
            FROM [Sales].[InvoiceDetails] D
            JOIN inserted i ON D.InvID = i.InvID
            JOIN deleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND i.InvType = 'Purchase'
            GROUP BY D.ProductID, i.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        -- ب. تحديث الكميات (مشتريات تزيد / مبيعات تنقص)
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + (CASE WHEN i.InvType = 'Purchase' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, D.InvID, SUM(D.Quantity) as Qty 
            FROM [Sales].[InvoiceDetails] D GROUP BY D.ProductID, D.InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN inserted i ON T.InvID = i.InvID
        INNER JOIN deleted d_old ON i.InvID = d_old.InvID
        WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND S.WarehouseID = i.WarehouseID;

        -- ج. تسجيل التكلفة في تفاصيل الفاتورة (للمبيعات) لضبط الربحية
        UPDATE D
        SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
        FROM [Sales].[InvoiceDetails] D
        JOIN inserted i ON D.InvID = i.InvID
        JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID AND S.WarehouseID = i.WarehouseID
        WHERE i.IsPosted = 1 AND i.InvType = 'Sales';

        -- د. القيود المحاسبية (Journals)
        DECLARE @EntryMap TABLE (InvID INT, EntryNo INT);
        INSERT INTO @EntryMap SELECT i.InvID, NEXT VALUE FOR [Accounting].[seq_EntryNo] 
        FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0;

        -- قيد الفاتورة (مشتريات/مبيعات)
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        -- المشتريات: مخزن (مدين) / مورد (دائن)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(w.AccountID, @InventoryAcc), i.NetAmount, 0, N'مشتريات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID WHERE i.InvType = 'Purchase'
        UNION ALL
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(p.AccountID, @VendorAcc), 0, i.NetAmount, N'مشتريات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.InvType = 'Purchase'
        -- المبيعات: عميل (مدين) / مبيعات (دائن) + تكلفة (مدين) / مخزن (دائن)
        UNION ALL
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(p.AccountID, @CustomerAcc), i.NetAmount, 0, N'مبيعات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.InvType = 'Sales'
        UNION ALL
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, @SalesAcc, 0, i.NetAmount, N'مبيعات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID WHERE i.InvType = 'Sales';

		-- ----------------------------------------------------------------
-- و. قيد تكلفة البضاعة المباعة (للمبيعات فقط)
-- Dr COGS / Cr Inventory
-- ----------------------------------------------------------------
;WITH InvoiceCOGS AS (
    SELECT d.InvID, SUM(d.CostPrice * d.Quantity) AS TotalCost
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN inserted i ON d.InvID = i.InvID
    WHERE i.InvType = 'Sales'
    GROUP BY d.InvID
)
INSERT INTO [Accounting].[JournalEntries] 
    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
-- الطرف المدين: حساب تكلفة البضاعة المباعة
SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, @COGSAcc, cogs.TotalCost, 0, 
       N'تكلفة البضاعة المباعة فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
FROM inserted i
JOIN @EntryMap m ON i.InvID = m.InvID
JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
WHERE i.InvType = 'Sales' AND cogs.TotalCost > 0

UNION ALL

-- الطرف الدائن: حساب المخزن (الخاص بالمستودع)
SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(w.AccountID, @InventoryAcc), 0, cogs.TotalCost, 
       N'تكلفة البضاعة المباعة فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
FROM inserted i
JOIN @EntryMap m ON i.InvID = m.InvID
JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
WHERE i.InvType = 'Sales' AND cogs.TotalCost > 0;
        -- هـ. قيود السداد (Payments)
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, CASE WHEN i.InvType = 'Purchase' THEN ISNULL(p.AccountID, @VendorAcc) ELSE i.PaymentAccountID END, i.PaidAmount, 0, N'سداد فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL
        UNION ALL
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, CASE WHEN i.InvType = 'Purchase' THEN i.PaymentAccountID ELSE ISNULL(p.AccountID, @CustomerAcc) END, 0, i.PaidAmount, N'سداد فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;
    END
	
    -- ==========================================================
    -- ثانياً: حالة إلغاء الترحيل (UNPOSTING: 1 -> 0)
    -- ==========================================================
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        -- عكس تأثير المخزن (المبيعات تعيد للمخزن / المشتريات تخصم من المخزن)
        -- تم توحيد هذا الجزء لضمان عدم التكرار
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + (CASE WHEN d_old.InvType = 'Sales' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, D.InvID, SUM(D.Quantity) as Qty 
            FROM [Sales].[InvoiceDetails] D GROUP BY D.ProductID, D.InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN deleted d_old ON T.InvID = d_old.InvID
        INNER JOIN inserted i ON d_old.InvID = i.InvID
        WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND S.WarehouseID = d_old.WarehouseID;

        -- حذف القيود المحاسبية بالكامل
        DELETE JE FROM [Accounting].[JournalEntries] JE
        INNER JOIN deleted d_old ON JE.ReferenceID = d_old.InvID
        WHERE JE.ReferenceType IN ('Invoice', 'Payment') AND d_old.IsPosted = 1;
    END
END

go

 IF OBJECT_ID('[Sales].[trg_PreventDeletePostedInvoice]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_PreventDeletePostedInvoice]
GO
create TRIGGER [Sales].[trg_PreventDeletePostedInvoice] 
ON [Sales].[InvoiceHeader] 
FOR DELETE
 AS
  BEGIN 
  IF EXISTS (SELECT * FROM deleted WHERE IsPosted = 1) BEGIN RAISERROR ('لا يمكن حذف فاتورة مرحلة محاسبياً', 16, 1); ROLLBACK TRANSACTION;
   END ;
   END
   go

   -- 1. إضافة العمود لجدول الإعدادات بقيمة افتراضية False تلقائياً
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'UseDetailedInvoiceDesign')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD UseDetailedInvoiceDesign BIT NOT NULL DEFAULT 0;
END
GO

 IF OBJECT_ID('[Settings].[sp_CompanySettings_Get]', 'P') IS NOT NULL
    DROP procedure [Settings].[sp_CompanySettings_Get]
GO
-- 2. تحديث إجراء جلب البيانات (Get SP) ليشمل الحقل الجديد صراحة
create PROCEDURE [Settings].[sp_CompanySettings_Get]
AS
BEGIN
    SELECT TOP 1 
        SettingID, 
        CompanyName, 
        Address, 
        Phone, 
        Email, 
        Logo, 
        UnifiedPartnerSearch, 
        CurrencySymbol,
        UseDetailedInvoiceDesign,
        UseCustomInvoiceDesign,
        ISNULL(ProductionMode, 0) AS ProductionMode
    FROM [Settings].[CompanySettings];
END
GO

-- 3. تحديث إجراء حفظ البيانات (Save SP)
IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO

CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1,
    @CurrencySymbol NVARCHAR(100) = NULL,
    @UseDetailedInvoiceDesign BIT = 0,
    @UseCustomInvoiceDesign BIT = 0,
    @ProductionMode BIT = 0
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo,
            UnifiedPartnerSearch = @UnifiedPartnerSearch,
            CurrencySymbol = @CurrencySymbol,
            UseDetailedInvoiceDesign = @UseDetailedInvoiceDesign,
            UseCustomInvoiceDesign = @UseCustomInvoiceDesign,
            ProductionMode = @ProductionMode
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch, CurrencySymbol, UseDetailedInvoiceDesign, UseCustomInvoiceDesign, ProductionMode)
        VALUES (@CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch, @CurrencySymbol, @UseDetailedInvoiceDesign, @UseCustomInvoiceDesign, @ProductionMode);
    END
END
GO

IF EXISTS (SELECT 1 FROM [Security].[Roles] WHERE RoleID = 1)
BEGIN
    -- 1. إضافة أو تحديث صلاحيات فاتورة مشتريات (Purchases)
    IF NOT EXISTS (SELECT 1 FROM [Security].[RolePermissions] WHERE RoleID = 1 AND FormName = 'Purchases')
    BEGIN
        INSERT INTO [Security].[RolePermissions] (RoleID, FormName, CanView, CanAdd, CanEdit, CanDelete, CanPrint)
        VALUES (1, 'Purchases', 1, 1, 1, 1, 1);
        PRINT '✅ تم إضافة صلاحية "فاتورة مشتريات" (Purchases) لمدير النظام.';
    END
    ELSE
    BEGIN
        UPDATE [Security].[RolePermissions] 
        SET CanView = 1, CanAdd = 1, CanEdit = 1, CanDelete = 1, CanPrint = 1
        WHERE RoleID = 1 AND FormName = 'Purchases';
        PRINT '🔄 تم تحديث صلاحية "فاتورة مشتريات" (Purchases) لمدير النظام.';
    END

    -- 2. إضافة أو تحديث صلاحيات عروض المشتريات (PurchaseQuotes)
    IF NOT EXISTS (SELECT 1 FROM [Security].[RolePermissions] WHERE RoleID = 1 AND FormName = 'PurchaseQuotes')
    BEGIN
        INSERT INTO [Security].[RolePermissions] (RoleID, FormName, CanView, CanAdd, CanEdit, CanDelete, CanPrint)
        VALUES (1, 'PurchaseQuotes', 1, 1, 1, 1, 1);
        PRINT '✅ تم إضافة صلاحية "عروض المشتريات" (PurchaseQuotes) لمدير النظام.';
    END
    ELSE
    BEGIN
        UPDATE [Security].[RolePermissions] 
        SET CanView = 1, CanAdd = 1, CanEdit = 1, CanDelete = 1, CanPrint = 1
        WHERE RoleID = 1 AND FormName = 'PurchaseQuotes';
        PRINT '🔄 تم تحديث صلاحية "عروض المشتريات" (PurchaseQuotes) لمدير النظام.';
    END
END
GO



IF OBJECT_ID('[Sales].[sp_Report_InvoicePrint]', 'P') IS NOT NULL 
    DROP PROCEDURE [Sales].[sp_Report_InvoicePrint];
GO

CREATE PROCEDURE [Sales].[sp_Report_InvoicePrint]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. بيانات رأس الفاتورة الضرورية فقط للطباعة (تم إضافة المتبقي والمدفوع والصافي لتحديد نوع الفاتورة)
    SELECT 
        H.InvID, 
        H.InvDate, 
        H.TotalAmount, 
        P.PartnerName, 
        CH.AccountCode,
        H.Notes,
        H.Remainder,
        H.PaidAmount,
        H.NetAmount
    FROM [Sales].[InvoiceHeader] H
    LEFT JOIN [Sales].[Partners] P ON H.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] CH ON P.[AccountID] = CH.[AccountID]
    WHERE H.InvID = @InvID;

    -- 2. بيانات الأصناف المطلوبة فقط للجدول
    SELECT 
        PR.ProductName, 
        PR.ProductNameEn,
        UN.UnitName,
        D.Quantity, 
        D.UnitPrice, 
        D.TotalPrice
    FROM [Sales].[InvoiceDetails] D
    JOIN [Inventory].[Products] PR ON D.ProductID = PR.ProductID
    LEFT JOIN [Settings].[Units] UN ON PR.UnitID = UN.UnitID
    WHERE D.InvID = @InvID
    ORDER BY D.DetID;
END
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

    -- الفلترة الأساسية: العمل فقط عند تغير حالة IsPosted
    IF NOT UPDATE(IsPosted) RETURN;

    BEGIN TRY
        -- 1. متغيرات الحسابات الافتراضية
        DECLARE @InventoryAcc INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @SalesAcc     INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @COGSAcc      INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @CustomerAcc  INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @VendorAcc    INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1 ORDER BY AccountCode);

        -- ==========================================================
        -- أولاً: حالة الترحيل (POSTING: 0 -> 1)
        -- ==========================================================
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
        BEGIN
            
            -- أ. إدراج سجلات المنتجات المفقودة في جدول المخزون للمستودع المعين بقيم صفرية لمنع فشل التحديث
            INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
            SELECT DISTINCT D.ProductID, i.WarehouseID, 0, 0
            FROM [Sales].[InvoiceDetails] D
            JOIN inserted i ON D.InvID = i.InvID
            JOIN deleted del ON i.InvID = del.InvID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] S2 
                  WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
              );

            -- ب. تحديث متوسط التكلفة (للمشتريات فقط)
            UPDATE S
            SET S.AvgCostPrice = CASE 
                WHEN (ISNULL(S.CurrentQty, 0) + T.TotalQty) > 0 
                THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) + T.TotalSum) / (ISNULL(S.CurrentQty, 0) + T.TotalQty)
                ELSE T.WeightedPrice END
            FROM [Inventory].[ProductStock] S
            INNER JOIN (
                SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum,
                       SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0) as WeightedPrice
                FROM [Sales].[InvoiceDetails] D
                JOIN inserted i ON D.InvID = i.InvID
                JOIN deleted d_old ON i.InvID = d_old.InvID
                WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND i.InvType = 'Purchase'
                GROUP BY D.ProductID, i.WarehouseID
            ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

            -- ج. تحديث الكميات (مشتريات تزيد / مبيعات تنقص)
            UPDATE S
            SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN i.InvType = 'Purchase' THEN T.Qty ELSE -T.Qty END)
            FROM [Inventory].[ProductStock] S
            INNER JOIN (
                SELECT D.ProductID, D.InvID, SUM(D.Quantity) as Qty 
                FROM [Sales].[InvoiceDetails] D GROUP BY D.ProductID, D.InvID
            ) T ON S.ProductID = T.ProductID
            INNER JOIN inserted i ON T.InvID = i.InvID
            INNER JOIN deleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND S.WarehouseID = i.WarehouseID;

            -- د. تسجيل التكلفة في تفاصيل الفاتورة (للمبيعات) لضبط الربحية
            UPDATE D
            SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
            FROM [Sales].[InvoiceDetails] D
            JOIN inserted i ON D.InvID = i.InvID
            JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID AND S.WarehouseID = i.WarehouseID
            WHERE i.IsPosted = 1 AND i.InvType = 'Sales';

            -- هـ. القيود المحاسبية (Journals)
            DECLARE @EntryMap TABLE (InvID INT, EntryNo INT);
            INSERT INTO @EntryMap SELECT i.InvID, NEXT VALUE FOR [Accounting].[seq_EntryNo] 
            FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0;

            -- قيد الفاتورة (مشتريات/مبيعات)
            INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            -- المشتريات: مخزن (مدين) / مورد (دائن)
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(w.AccountID, @InventoryAcc), i.NetAmount, 0, N'مشتريات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID WHERE i.InvType = 'Purchase'
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(p.AccountID, @VendorAcc), 0, i.NetAmount, N'مشتريات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.InvType = 'Purchase'
            -- المبيعات: عميل (مدين) / مبيعات (دائن) + تكلفة (مدين) / مخزن (دائن)
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(p.AccountID, @CustomerAcc), i.NetAmount, 0, N'مبيعات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.InvType = 'Sales'
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, @SalesAcc, 0, i.NetAmount, N'مبيعات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID WHERE i.InvType = 'Sales';

            -- و. قيد تكلفة البضاعة المباعة (للمبيعات فقط)
            -- Dr COGS / Cr Inventory
            ;WITH InvoiceCOGS AS (
                SELECT d.InvID, SUM(d.CostPrice * d.Quantity) AS TotalCost
                FROM [Sales].[InvoiceDetails] d
                INNER JOIN inserted i ON d.InvID = i.InvID
                WHERE i.InvType = 'Sales'
                GROUP BY d.InvID
            )
            INSERT INTO [Accounting].[JournalEntries] 
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            -- الطرف المدين: حساب تكلفة البضاعة المباعة
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, @COGSAcc, cogs.TotalCost, 0, 
                   N'تكلفة البضاعة المباعة فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i
            JOIN @EntryMap m ON i.InvID = m.InvID
            JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
            WHERE i.InvType = 'Sales' AND cogs.TotalCost > 0

            UNION ALL

            -- الطرف الدائن: حساب المخزن (الخاص بالمستودع)
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(w.AccountID, @InventoryAcc), 0, cogs.TotalCost, 
                   N'تكلفة البضاعة المباعة فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i
            JOIN @EntryMap m ON i.InvID = m.InvID
            JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
            LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
            WHERE i.InvType = 'Sales' AND cogs.TotalCost > 0;

            -- ز. قيود السداد (Payments: دعم التجزئة Split والتحصيل المباشر)
            
            -- 1. مشتريات Split
            INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, ISNULL(p.AccountID, @VendorAcc), sp.Amount, 0, N'سداد [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID WHERE i.InvType = 'Purchase' AND sp.Amount > 0
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, sp.PaymentAccountID, 0, sp.Amount, N'سداد [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID WHERE i.InvType = 'Purchase' AND sp.Amount > 0;

            -- 2. مبيعات Split
            INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, sp.PaymentAccountID, sp.Amount, 0, N'تحصيل [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID WHERE i.InvType = 'Sales' AND sp.Amount > 0
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, ISNULL(p.AccountID, @CustomerAcc), 0, sp.Amount, N'تحصيل [' + ISNULL(c.AccountName, N'طريقة دفع') + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID LEFT JOIN [Accounting].[ChartOfAccounts] c ON c.AccountID = sp.PaymentAccountID WHERE i.InvType = 'Sales' AND sp.Amount > 0;

            -- 3. سداد/تحصيل مباشر Fallback (عند عدم وجود تجزئة)
            INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, CASE WHEN i.InvType = 'Purchase' THEN ISNULL(p.AccountID, @VendorAcc) ELSE i.PaymentAccountID END, i.PaidAmount, 0, N'سداد فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = i.InvID)
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, CASE WHEN i.InvType = 'Purchase' THEN i.PaymentAccountID ELSE ISNULL(p.AccountID, @CustomerAcc) END, 0, i.PaidAmount, N'سداد فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = i.InvID);
        End
        
        -- ==========================================================
        -- ثانياً: حالة إلغاء الترحيل (UNPOSTING: 1 -> 0)
        -- ==========================================================
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
        BEGIN
            -- إدراج سجلات المنتجات المفقودة لمنع فشل التحديث عند إلغاء الترحيل
            INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
            SELECT DISTINCT D.ProductID, d_old.WarehouseID, 0, 0
            FROM [Sales].[InvoiceDetails] D
            JOIN deleted d_old ON D.InvID = d_old.InvID
            JOIN inserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] S2 
                  WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = d_old.WarehouseID
              );

            -- أ. إعادة حساب وتخفيض متوسط التكلفة (عند إلغاء ترحيل المشتريات فقط)
            -- يجب أن تتم هذه العملية قبل تخفيض الكمية لأن المعادلة تعتمد على الكمية الحالية قبل التعديل
            UPDATE S
            SET S.AvgCostPrice = CASE 
                WHEN (ISNULL(S.CurrentQty, 0) - T.TotalQty) > 0 
                THEN (CASE 
                    WHEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) > 0 
                    THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) / (ISNULL(S.CurrentQty, 0) - T.TotalQty)
                    ELSE 0 END)
                ELSE 0 END
            FROM [Inventory].[ProductStock] S
            INNER JOIN (
                SELECT D.ProductID, d_old.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum
                FROM [Sales].[InvoiceDetails] D
                JOIN deleted d_old ON D.InvID = d_old.InvID
                JOIN inserted i ON d_old.InvID = i.InvID
                WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND d_old.InvType = 'Purchase'
                GROUP BY D.ProductID, d_old.WarehouseID
            ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

            -- ب. عكس تأثير المخزن (المبيعات تعيد للمخزن / المشتريات تخصم من المخزن)
            UPDATE S
            SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN d_old.InvType = 'Sales' THEN T.Qty ELSE -T.Qty END)
            FROM [Inventory].[ProductStock] S
            INNER JOIN (
                SELECT D.ProductID, D.InvID, SUM(D.Quantity) as Qty 
                FROM [Sales].[InvoiceDetails] D GROUP BY D.ProductID, D.InvID
            ) T ON S.ProductID = T.ProductID
            INNER JOIN deleted d_old ON T.InvID = d_old.InvID
            INNER JOIN inserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND S.WarehouseID = d_old.WarehouseID;

            -- حذف القيود المحاسبية بالكامل
            DELETE JE FROM [Accounting].[JournalEntries] JE
            INNER JOIN deleted d_old ON JE.ReferenceID = d_old.InvID
            WHERE JE.ReferenceType IN ('Invoice', 'Payment') AND d_old.IsPosted = 1;
        END
    END TRY
    BEGIN CATCH
        -- التراجع عن العمليات الحالية وإعادة إرسال الخطأ
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
-- 1. إضافة العمود لجدول الإعدادات
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'UseCustomInvoiceDesign')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD UseCustomInvoiceDesign BIT NOT NULL DEFAULT 0;
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'ProductionMode')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD ProductionMode BIT NOT NULL DEFAULT 0;
END
GO

-- 2. تحديث إجراء جلب البيانات (Get SP)
IF OBJECT_ID('[Settings].[sp_CompanySettings_Get]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Get];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Get]
AS
BEGIN
    SELECT TOP 1 
        SettingID,
        CompanyName,
        Address,
        Phone,
        Email,
        Logo,
        ISNULL(UnifiedPartnerSearch, 1) AS UnifiedPartnerSearch,
        ISNULL(CurrencySymbol, N'د.ك') AS CurrencySymbol,
        ISNULL(UseDetailedInvoiceDesign, 0) AS UseDetailedInvoiceDesign,
        ISNULL(UseCustomInvoiceDesign, 0) AS UseCustomInvoiceDesign,
        ISNULL(ProductionMode, 0) AS ProductionMode,
        ISNULL(EnableDailyOrders, 0) AS EnableDailyOrders,
        DeliverySystemMode
    FROM [Settings].[CompanySettings];
END
GO

-- 3. تحديث إجراء حفظ البيانات (Save SP)
IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO

CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1,
    @CurrencySymbol NVARCHAR(100) = NULL,
    @UseDetailedInvoiceDesign BIT = 0,
    @UseCustomInvoiceDesign BIT = 0,
    @ProductionMode BIT = 0,
    @EnableDailyOrders BIT = 0,
    @DeliverySystemMode NVARCHAR(50) = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo,
            UnifiedPartnerSearch = @UnifiedPartnerSearch,
            CurrencySymbol = @CurrencySymbol,
            UseDetailedInvoiceDesign = @UseDetailedInvoiceDesign,
            UseCustomInvoiceDesign = @UseCustomInvoiceDesign,
            ProductionMode = @ProductionMode,
            EnableDailyOrders = @EnableDailyOrders,
            DeliverySystemMode = @DeliverySystemMode
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch, CurrencySymbol, UseDetailedInvoiceDesign, UseCustomInvoiceDesign, ProductionMode, EnableDailyOrders, DeliverySystemMode)
        VALUES (@CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch, @CurrencySymbol, @UseDetailedInvoiceDesign, @UseCustomInvoiceDesign, @ProductionMode, @EnableDailyOrders, @DeliverySystemMode);
    END
END
GO
IF OBJECT_ID('[Sales].[sp_Report_InvoicePrint]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_InvoicePrint];
GO
create PROCEDURE [Sales].[sp_Report_InvoicePrint]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. بيانات رأس الفاتورة الضرورية فقط للطباعة (تم إضافة المتبقي والمدفوع والصافي لتحديد نوع الفاتورة)
    SELECT 
        H.InvID, 
        H.InvDate, 
        H.TotalAmount, 
        P.PartnerName, 
        CH.AccountCode,
        H.Notes,
        H.Remainder,
        H.PaidAmount,
        H.NetAmount
    FROM [Sales].[InvoiceHeader] H
    LEFT JOIN [Sales].[Partners] P ON H.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] CH ON P.[AccountID] = CH.[AccountID]
    WHERE H.InvID = @InvID;

    -- 2. بيانات الأصناف المطلوبة فقط للجدول
    SELECT 
        PR.ProductName, 
        PR.ProductNameEn,
        UN.UnitName,
        D.Quantity, 
        D.UnitPrice, 
        D.TotalPrice
    FROM [Sales].[InvoiceDetails] D
    JOIN [Inventory].[Products] PR ON D.ProductID = PR.ProductID
    LEFT JOIN [Settings].[Units] UN ON PR.UnitID = UN.UnitID
    WHERE D.InvID = @InvID
    ORDER BY D.DetID;
END
go
-- ============================================================
-- فحص وجود الجدول قبل إنشائه
-- 'U' = User Table (نوع الكائن: جدول مستخدم)
-- إذا كان موجوداً مسبقاً يتم التخطي بأمان دون حذف البيانات
-- ============================================================
IF OBJECT_ID('[Sales].[TempOrderInfo]', 'U') IS NOT NULL
BEGIN
    PRINT N'تنبيه: الجدول [Sales].[TempOrderInfo] موجود مسبقاً — تم تخطي الإنشاء للحفاظ على البيانات.';
END
ELSE
BEGIN
    -- جدول مستقل تماماً لا يؤثر على أي جدول أو إجراء موجود
    CREATE TABLE [Sales].[TempOrderInfo] (
        [TempOrderID]    INT           IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [InvID]          INT           NOT NULL UNIQUE,     -- ارتباط 1:1 مع رأس الفاتورة
        [CustomerName]   NVARCHAR(150) NULL,
        [Phone]          VARCHAR(20)   NULL,
        [Address]        NVARCHAR(255) NULL,
        [DeliveryDate]   DATE          NULL,
        [DeliveryTime]   VARCHAR(50)   NULL,
        [CreatedAt]      DATETIME      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT [FK_TempOrderInfo_InvoiceHeader]
            FOREIGN KEY ([InvID])
            REFERENCES [Sales].[InvoiceHeader]([InvID])
            ON DELETE CASCADE   -- حذف بيانات التوصيل تلقائياً عند حذف الفاتورة
    );
    PRINT N'تم إنشاء الجدول [Sales].[TempOrderInfo] بنجاح.';
END
GO

-- ============================================================
-- فحص وجود الإجراء المخزن قبل تعديله
-- يتوقف الكود ويُظهر رسالة واضحة إذا لم يُعثر على الإصدار الصحيح
-- ============================================================
IF OBJECT_ID('[Sales].[sp_Invoice_Save_XML]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Invoice_Save_XML];
GO

create PROCEDURE [Sales].[sp_Invoice_Save_XML]
    -- ═══════════════════════════════════════════
    --  المعاملات الأصلية (17 معامل — لا تغيير)
    -- ═══════════════════════════════════════════
    @InvID            INT OUTPUT,
    @InvType          NVARCHAR(20),
    @InvDate          DATETIME,
    @PartnerID        INT,
    @WarehouseID      INT,
    @TotalAmount      DECIMAL(18, 3),
    @Discount         DECIMAL(18, 3),
    @NetAmount        DECIMAL(18, 3),
    @PaidAmount       DECIMAL(18, 3),
    @Remainder        DECIMAL(18, 3),
    @UserID           INT,
    @Notes            NVARCHAR(255),
    @IsPosted         BIT           = 0,
    @ReferenceNo      NVARCHAR(50)  = NULL,
    @PaymentAccountID INT           = NULL,
    @ShiftID          INT           = NULL,   -- ← موجود في الإصدار الأخير
    @DetailsXml       XML,
    -- ═══════════════════════════════════════════
    --  المعاملات الجديدة — جميعها NULL افتراضياً
    --  لضمان التوافق الكامل مع كل استدعاء قديم
    --  (إذا لم تُرسَل → لا يُكتب أي شيء في TempOrderInfo)
    -- ═══════════════════════════════════════════
    @TempCustomerName NVARCHAR(150) = NULL,
    @TempPhone        VARCHAR(20)   = NULL,
    @TempAddress      NVARCHAR(255) = NULL,
    @TempDeliveryDate DATE          = NULL,
    @TempDeliveryTime VARCHAR(50)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ═══════════════════════════════════════════════════════════════
    --  بداية الـ Transaction الموحدة التي تشمل مسار الحفظ القديم
    --  والجديد معاً — إذا فشل أي جزء يتم التراجع عن الكل بأمان
    -- ═══════════════════════════════════════════════════════════════
    BEGIN TRANSACTION;

    BEGIN TRY

        -- ┌─────────────────────────────────────────────────────────┐
        -- │  المسار القديم — يعمل بنفس الطريقة الحالية بلا أي تغيير │
        -- │  سواء استُخدمت الطريقة الجديدة أم لا                   │
        -- └─────────────────────────────────────────────────────────┘

        -- حفظ أو تحديث رأس الفاتورة
        IF @InvID = 0
        BEGIN
            INSERT INTO [Sales].[InvoiceHeader]
                (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, Discount, NetAmount,
                 PaidAmount, Remainder, UserID, Notes, IsPosted, ReferenceNo, PaymentAccountID, ShiftID)
            VALUES
                (@InvType, @InvDate, @PartnerID, @WarehouseID, @TotalAmount, @Discount, @NetAmount,
                 @PaidAmount, @Remainder, @UserID, @Notes, @IsPosted, @ReferenceNo, @PaymentAccountID, @ShiftID);

            SET @InvID = CAST(SCOPE_IDENTITY() AS INT);

            -- التحقق من نجاح الإدراج
            IF @InvID IS NULL OR @InvID = 0
                THROW 50001, N'فشل حفظ رأس الفاتورة الجديدة — لم يتم إرجاع InvID صالح.', 1;
        END
        ELSE
        BEGIN
            UPDATE [Sales].[InvoiceHeader]
            SET InvType           = @InvType,
                InvDate           = @InvDate,
                PartnerID         = @PartnerID,
                WarehouseID       = @WarehouseID,
                TotalAmount       = @TotalAmount,
                Discount          = @Discount,
                NetAmount         = @NetAmount,
                PaidAmount        = @PaidAmount,
                Remainder         = @Remainder,
                UserID            = @UserID,
                Notes             = @Notes,
                IsPosted          = @IsPosted,
                ReferenceNo       = @ReferenceNo,
                PaymentAccountID  = @PaymentAccountID,
                ShiftID           = ISNULL(ShiftID, @ShiftID)
            WHERE InvID = @InvID;

            -- التحقق من أن الفاتورة المراد تعديلها موجودة فعلاً
            IF @@ROWCOUNT = 0
                THROW 50002, N'فشل تحديث الفاتورة — لم يُعثر على InvID المطلوب في InvoiceHeader.', 1;

            DELETE FROM [Sales].[InvoiceDetails] WHERE InvID = @InvID;
            DELETE FROM [Sales].[InvoicePaymentSplits] WHERE InvID = @InvID;
        END

        -- حفظ تفاصيل أصناف الفاتورة
        INSERT INTO [Sales].[InvoiceDetails]
            (InvID, ProductID, UnitPrice, Quantity, TotalPrice, CostPrice)
        SELECT
            @InvID,
            T.Item.value('@ProductID', 'INT'),
            T.Item.value('@UnitPrice', 'DECIMAL(18,3)'),
            T.Item.value('@Quantity', 'DECIMAL(18,3)'),
            T.Item.value('@TotalPrice', 'DECIMAL(18,3)'),
            T.Item.value('@CostPrice', 'DECIMAL(18,3)')
        FROM @DetailsXml.nodes('//Item') AS T(Item);

        -- ┌─────────────────────────────────────────────────────────────────┐
        -- │  المسار الجديد — يُنفَّذ فقط إذا أُرسلت بيانات الزبون المؤقت  │
        -- │  وإلا يُتجاوز تماماً — صفر أثر على الفواتير العادية            │
        -- └─────────────────────────────────────────────────────────────────┘
        IF @TempCustomerName IS NOT NULL
           OR @TempPhone      IS NOT NULL
           OR @TempAddress    IS NOT NULL
        BEGIN
            -- حذف السجل القديم إن وُجد (لضمان التعديل النظيف)
            DELETE FROM [Sales].[TempOrderInfo] WHERE InvID = @InvID;

            INSERT INTO [Sales].[TempOrderInfo]
                (InvID, CustomerName, Phone, Address, DeliveryDate, DeliveryTime)
            VALUES
                (@InvID, @TempCustomerName, @TempPhone, @TempAddress,
                 @TempDeliveryDate, @TempDeliveryTime);
        END
        -- وإلا: لا يُكتب أي شيء في TempOrderInfo — الفاتورة العادية محفوظة بالكامل

        -- إتمام الـ Transaction وإرجاع InvID الناتج
        COMMIT TRANSACTION;
        SELECT @InvID AS InvID;

    END TRY
    BEGIN CATCH
        -- ═══════════════════════════════════════════════════════════
        --  فحص حالة الـ Transaction قبل التراجع
        --  XACT_STATE() = 1  → Transaction قابلة للتراجع → ROLLBACK
        --  XACT_STATE() = -1 → Transaction محكومة بالفشل → ROLLBACK إلزامي
        --  XACT_STATE() = 0  → لا توجد Transaction مفتوحة → لا حاجة للـ ROLLBACK
        -- ═══════════════════════════════════════════════════════════
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- إعادة إرسال الخطأ الأصلي بكامل تفاصيله للـ API
        THROW;
    END CATCH
END
GO
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
        chart.AccountCode,
        temp.CustomerName AS TempCustomerName,
        temp.Phone AS TempPhone,
        temp.Address AS TempAddress,
        temp.DeliveryDate AS TempDeliveryDate,
        temp.DeliveryTime AS TempDeliveryTime
    FROM [Sales].[InvoiceHeader] inv
    LEFT JOIN [Sales].[Partners] par ON inv.[PartnerID] = par.[PartnerID]
    LEFT JOIN [Accounting].[ChartOfAccounts] chart ON par.[AccountID] = chart.[AccountID]
    LEFT JOIN [Sales].[TempOrderInfo] temp ON inv.InvID = temp.InvID
    WHERE inv.InvID = @InvID;
END
GO
-- 1. إجراء مخزن لجلب طلبات التوصيل اليومية مع تفاصيل الفاتورة
IF OBJECT_ID('[Sales].[sp_TempOrder_GetDailyDeliveries]', 'P') IS NOT NULL 
    DROP PROCEDURE [Sales].[sp_TempOrder_GetDailyDeliveries];
GO

CREATE PROCEDURE [Sales].[sp_TempOrder_GetDailyDeliveries]
    @DeliveryDate DATE
	
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        t.InvID,
        t.CustomerName,
        t.Phone,
        t.Address,
        t.DeliveryDate,
        t.DeliveryTime,
        i.Notes,
        i.NetAmount,
        i.PaidAmount,
        i.Remainder,
        i.InvType
    FROM [Sales].[TempOrderInfo] t
    INNER JOIN [Sales].[InvoiceHeader] i ON t.InvID = i.InvID
    WHERE CAST(t.DeliveryDate AS DATE) = @DeliveryDate
    ORDER BY t.DeliveryTime ASC;
END
GO

-- 2. إدراج الصلاحية الجديدة في جدول الشاشات المعتمد برمجياً إذا لزم الأمر
-- (سيتم معالجتها في واجهة الصلاحيات بالتطبيق تلقائياً بعد إدراجها بالقاموس البرمجي)
-- =========================================================================
-- 30. sp_Permission_AutoAssignAdmin (إسناد كامل الصلاحيات للمسؤول تلقائياً)
-- =========================================================================
IF OBJECT_ID('[Security].[sp_Permission_AutoAssignAdmin]', 'P') IS NOT NULL 
    DROP PROCEDURE [Security].[sp_Permission_AutoAssignAdmin]
GO

CREATE PROCEDURE [Security].[sp_Permission_AutoAssignAdmin]
    @UserID INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. جلب رقم الدور (RoleID) الخاص بالمستخدم المحدد
    DECLARE @RoleID INT;
    SELECT @RoleID = RoleID FROM [Security].[Users] WHERE UserID = @UserID;

    IF @RoleID IS NULL
    BEGIN
        RAISERROR(N'المستخدم غير موجود بقاعدة البيانات أو ليس لديه دور محدد.', 16, 1);
        RETURN;
    END

    -- 2. تعريف القائمة الكاملة لكافة صلاحيات شاشات النظام (27 صلاحية معتمدة)
    DECLARE @Permissions TABLE (FormName NVARCHAR(100));
    INSERT INTO @Permissions (FormName) VALUES 
    (N'Dashboard'),
    (N'Sales'),
    (N'Purchases'),
    (N'Inventory'),
    (N'InvoiceDashboard'),
    (N'Accounting'),
    (N'ChartOfAccounts'),
    (N'ReceiptVoucher'),
    (N'PaymentVoucher'),
    (N'JournalEntries'),
    (N'AccountStatement'),
    (N'TrialBalance'),
    (N'BalanceSheet'),
    (N'ProfitLoss'),
    (N'YearEndClose'),
    (N'Partners'),
    (N'Quotes'),
    (N'PurchaseQuotes'),
    (N'Shifts'),
    (N'Reports'),
    (N'SettingsParent'),
    (N'Settings'),
    (N'CompanySettings'),
    (N'UserManagement'),
    (N'Wastage'),
    (N'StockTaking'),
    (N'DailyOrders');

    -- 3. دمج وإدخال الصلاحيات غير الموجودة، وتحديث الحالية لمنح الصلاحيات الكاملة
    MERGE [Security].[RolePermissions] AS target
    USING @Permissions AS source
    ON (target.RoleID = @RoleID AND target.FormName = source.FormName)
    WHEN MATCHED THEN
        UPDATE SET 
            CanView = 1,
            CanAdd = 1,
            CanEdit = 1,
            CanDelete = 1,
            CanPrint = 1
    WHEN NOT MATCHED THEN
        INSERT (RoleID, FormName, CanView, CanAdd, CanEdit, CanDelete, CanPrint)
        VALUES (@RoleID, source.FormName, 1, 1, 1, 1, 1);

    PRINT N'تم إسناد كافة صلاحيات النظام بالكامل للدور (RoleID: ' + CAST(@RoleID AS VARCHAR(10)) + N') المرتبط بالمستخدم (UserID: ' + CAST(@UserID AS VARCHAR(10)) + N') بنجاح.';
END
GO
IF OBJECT_ID('[Accounting].[sp_GetPaymentAccounts]', 'P') IS NOT NULL 
    DROP PROCEDURE [Accounting].[sp_GetPaymentAccounts]
GO
CREATE PROCEDURE [Accounting].[sp_GetPaymentAccounts]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AccountID, AccountCode, AccountName 
    FROM [Accounting].[ChartOfAccounts] 
    WHERE AccountCode LIKE '11%' AND IsTransactional = 1 
    ORDER BY AccountCode;
END
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
--==================================================================
EXEC [Security].[sp_Permission_AutoAssignAdmin] @UserID = 1;
GO

-- 1. إضافة عمود وضع التصنيع في جدول إعدادات الشركة الحالي
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'ProductionMode')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD ProductionMode BIT DEFAULT 0;
END
GO

-- 2. إضافة نوع الصنف لجدول المنتجات (الافتراضي 1 للمنتجات القديمة)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Inventory].[Products]') AND name = 'ProductType')
BEGIN
    ALTER TABLE [Inventory].[Products] ADD ProductType INT DEFAULT 1;
END
GO

UPDATE [Inventory].[Products]
SET ProductType = 1
WHERE ProductType IS NULL;
GO

-- 3. جدول رأس الوصفة [Inventory].[Recipes]
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Recipes' AND schema_id = SCHEMA_ID('Inventory'))
BEGIN
    CREATE TABLE [Inventory].[Recipes] (
        RecipeID INT PRIMARY KEY IDENTITY(1,1),
        ProductID INT NOT NULL UNIQUE,                  -- المنتج المصنع أو المنتج الوسيط
        TotalCost DECIMAL(18, 3) DEFAULT 0,            -- التكلفة الكلية المحسوبة للمكونات
        Notes NVARCHAR(500),                           -- ملاحظات تحضير الوصفة
        CreatedDate DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID)
    );
END
GO

-- 4. جدول تفاصيل مكونات الوصفة [Inventory].[RecipeDetails]
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RecipeDetails' AND schema_id = SCHEMA_ID('Inventory'))
BEGIN
    CREATE TABLE [Inventory].[RecipeDetails] (
        RecipeDetailID INT PRIMARY KEY IDENTITY(1,1),
        RecipeID INT NOT NULL,
        IngredientProductID INT NOT NULL,               -- الصنف الأولي (مادة خام أو منتج وسيط)
        Qty DECIMAL(18, 4) NOT NULL,                    -- الكمية المطلوبة بدقة 4 خانات عشرية
        Cost DECIMAL(18, 3) DEFAULT 0,                  -- تكلفة المكون وقت التعريف
        FOREIGN KEY (RecipeID) REFERENCES [Inventory].[Recipes](RecipeID),
        FOREIGN KEY (IngredientProductID) REFERENCES [Inventory].[Products](ProductID)
    );
END
GO

-- ==========================================================
-- 5. الفهارس المخصصة لمنع القفول المتبادلة (Deadlock Prevention Indexes)
-- ==========================================================

-- أ. فهرس جدول رصيد المنتجات بالمخزن ProductStock
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ProductStock_ProductID_WarehouseID')
BEGIN
    CREATE NONCLUSTERED INDEX IX_ProductStock_ProductID_WarehouseID
    ON [Inventory].[ProductStock] (ProductID, WarehouseID)
    INCLUDE (CurrentQty, AvgCostPrice);
END
GO

-- ب. فهرس تفاصيل الوصفات RecipeDetails
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_RecipeDetails_RecipeID_Ingredient')
BEGIN
    CREATE NONCLUSTERED INDEX IX_RecipeDetails_RecipeID_Ingredient
    ON [Inventory].[RecipeDetails] (RecipeID, IngredientProductID)
    INCLUDE (Qty, Cost);
END
GO

-- ج. فهرس رأس الوصفات Recipes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Recipes_ProductID')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Recipes_ProductID
    ON [Inventory].[Recipes] (ProductID)
    INCLUDE (RecipeID, TotalCost);
END
GO

-- د. فهرس تفاصيل الفواتير InvoiceDetails
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceDetails_InvID_ProductID')
BEGIN
    CREATE NONCLUSTERED INDEX IX_InvoiceDetails_InvID_ProductID
    ON [Sales].[InvoiceDetails] (InvID, ProductID)
    INCLUDE (Quantity, UnitPrice, CostPrice);
END
GO

IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Update_Manufactured_Costs];
GO

CREATE PROCEDURE [Inventory].[sp_Update_Manufactured_Costs]
    @WarehouseID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- التحديث المتسلسل من الأسفل للأعلى (Bottom-Up) لتحديث تكاليف المنتجات الوسيطة ثم المنتجات النهائية
        DECLARE @Iteration INT = 1;
        WHILE @Iteration <= 5
        BEGIN
            UPDATE PS_Manuf
            SET PS_Manuf.AvgCostPrice = ISNULL((
                SELECT SUM(RD.Qty * ISNULL(PS_Ing.AvgCostPrice, 0))
                FROM [Inventory].[RecipeDetails] RD
                INNER JOIN [Inventory].[Recipes] R ON R.RecipeID = RD.RecipeID
                LEFT JOIN [Inventory].[ProductStock] PS_Ing 
                       ON PS_Ing.ProductID = RD.IngredientProductID 
                      AND PS_Ing.WarehouseID = PS_Manuf.WarehouseID
                WHERE R.ProductID = PS_Manuf.ProductID
            ), 0)
            FROM [Inventory].[ProductStock] PS_Manuf
            INNER JOIN [Inventory].[Recipes] R ON R.ProductID = PS_Manuf.ProductID
            WHERE (@WarehouseID IS NULL OR PS_Manuf.WarehouseID = @WarehouseID);

            SET @Iteration = @Iteration + 1;
        END

        -- إدراج أي سجلات مخزنية مفقودة للأصناف المصنعة
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT R.ProductID, W.WarehouseID, 0, ISNULL((
            SELECT SUM(RD.Qty * ISNULL(PS_Ing.AvgCostPrice, 0))
            FROM [Inventory].[RecipeDetails] RD
            LEFT JOIN [Inventory].[ProductStock] PS_Ing ON PS_Ing.ProductID = RD.IngredientProductID AND PS_Ing.WarehouseID = W.WarehouseID
            WHERE RD.RecipeID = R.RecipeID
        ), 0)
        FROM [Inventory].[Recipes] R
        CROSS JOIN [Settings].[Warehouses] W
        WHERE (@WarehouseID IS NULL OR W.WarehouseID = @WarehouseID)
          AND NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] PS2 
            WHERE PS2.ProductID = R.ProductID AND PS2.WarehouseID = W.WarehouseID
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
IF OBJECT_ID('[Sales].[trg_Invoice_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_Invoice_Post];
GO

-- =============================================
-- SP الطبقة الأولى — تحديث المخزن (Post & Unpost مع دعم التصنيع والتوزيع التكراري)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_Inventory]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_Inventory];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_Inventory]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    -- ─── 1. حالة الترحيل (POSTING: 0 -> 1) ──────────────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT DISTINCT TargetProductID, WarehouseID, 0, 0
        FROM (
            SELECT D.ProductID AS TargetProductID, i.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted del ON i.InvID = del.InvID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
            UNION
            SELECT RD.IngredientProductID AS TargetProductID, i.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted del ON i.InvID = del.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0 AND @ProductionMode = 1 AND i.InvType = 'Sales'
        ) MissingStock
        WHERE NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] S2 
            WHERE S2.ProductID = MissingStock.TargetProductID AND S2.WarehouseID = MissingStock.WarehouseID
        );

        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (ISNULL(S.CurrentQty, 0) + T.TotalQty) > 0 
            THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) + T.TotalSum) / (ISNULL(S.CurrentQty, 0) + T.TotalQty)
            ELSE T.WeightedPrice END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum,
                   SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0) as WeightedPrice
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND i.InvType = 'Purchase'
            GROUP BY D.ProductID, i.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        IF @ProductionMode = 1 AND EXISTS (SELECT 1 FROM #TrgInserted WHERE InvType = 'Purchase' AND IsPosted = 1)
        BEGIN
            DECLARE @PurchasedW INT = (SELECT TOP 1 WarehouseID FROM #TrgInserted WHERE InvType = 'Purchase' AND IsPosted = 1);
            IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
                EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @PurchasedW;
        END

        ;WITH ExplodedPost AS (
            SELECT 
                D.InvID,
                i.InvType,
                i.WarehouseID,
                D.ProductID AS TargetProductID,
                CAST(D.Quantity AS DECIMAL(18, 4)) AS TargetQty,
                0 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 
              AND (@ProductionMode = 0 OR i.InvType = 'Purchase' OR NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] WHERE ProductID = D.ProductID))

            UNION ALL

            SELECT 
                D.InvID,
                i.InvType,
                i.WarehouseID,
                RD.IngredientProductID AS TargetProductID,
                CAST((D.Quantity * RD.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                1 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND @ProductionMode = 1 AND i.InvType = 'Sales'

            UNION ALL

            SELECT 
                EP.InvID,
                EP.InvType,
                EP.WarehouseID,
                RD_Sub.IngredientProductID AS TargetProductID,
                CAST((EP.TargetQty * RD_Sub.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                EP.RecLevel + 1
            FROM ExplodedPost EP
            JOIN [Inventory].[Recipes] R_Sub ON R_Sub.ProductID = EP.TargetProductID
            JOIN [Inventory].[RecipeDetails] RD_Sub ON RD_Sub.RecipeID = R_Sub.RecipeID
            WHERE EP.RecLevel > 0 
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] PS 
                  WHERE PS.ProductID = EP.TargetProductID AND PS.WarehouseID = EP.WarehouseID AND PS.CurrentQty > 0
              )
        )
        UPDATE S
        SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN T.InvType = 'Purchase' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT TargetProductID, InvID, InvType, WarehouseID, SUM(TargetQty) as Qty 
            FROM ExplodedPost 
            GROUP BY TargetProductID, InvID, InvType, WarehouseID
        ) T ON S.ProductID = T.TargetProductID AND S.WarehouseID = T.WarehouseID;

        UPDATE D
        SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
        FROM [Sales].[InvoiceDetails] D
        JOIN #TrgInserted i ON D.InvID = i.InvID
        JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID AND S.WarehouseID = i.WarehouseID
        WHERE i.IsPosted = 1 AND i.InvType = 'Sales';
    END

    -- ─── 2. حالة إلغاء الترحيل (UNPOSTING: 1 -> 0) ──────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT DISTINCT TargetProductID, WarehouseID, 0, 0
        FROM (
            SELECT D.ProductID AS TargetProductID, d_old.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
            UNION
            SELECT RD.IngredientProductID AS TargetProductID, d_old.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND @ProductionMode = 1 AND d_old.InvType = 'Sales'
        ) MissingStockUnpost
        WHERE NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] S2 
            WHERE S2.ProductID = MissingStockUnpost.TargetProductID AND S2.WarehouseID = MissingStockUnpost.WarehouseID
        );

        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (ISNULL(S.CurrentQty, 0) - T.TotalQty) > 0 
            THEN (CASE 
                WHEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) > 0 
                THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) / (ISNULL(S.CurrentQty, 0) - T.TotalQty)
                ELSE 0 END)
            ELSE 0 END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, d_old.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND d_old.InvType = 'Purchase'
            GROUP BY D.ProductID, d_old.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        IF @ProductionMode = 1 AND EXISTS (SELECT 1 FROM #TrgDeleted WHERE InvType = 'Purchase' AND IsPosted = 1)
        BEGIN
            DECLARE @UnpostedW INT = (SELECT TOP 1 WarehouseID FROM #TrgDeleted WHERE InvType = 'Purchase' AND IsPosted = 1);
            IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
                EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @UnpostedW;
        END

        ;WITH ExplodedUnpost AS (
            SELECT 
                D.InvID,
                d_old.InvType,
                d_old.WarehouseID,
                D.ProductID AS TargetProductID,
                CAST(D.Quantity AS DECIMAL(18, 4)) AS TargetQty,
                0 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
              AND (@ProductionMode = 0 OR d_old.InvType = 'Purchase' OR NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] WHERE ProductID = D.ProductID))

            UNION ALL

            SELECT 
                D.InvID,
                d_old.InvType,
                d_old.WarehouseID,
                RD.IngredientProductID AS TargetProductID,
                CAST((D.Quantity * RD.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                1 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND @ProductionMode = 1 AND d_old.InvType = 'Sales'

            UNION ALL

            SELECT 
                EU.InvID,
                EU.InvType,
                EU.WarehouseID,
                RD_Sub.IngredientProductID AS TargetProductID,
                CAST((EU.TargetQty * RD_Sub.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                EU.RecLevel + 1
            FROM ExplodedUnpost EU
            JOIN [Inventory].[Recipes] R_Sub ON R_Sub.ProductID = EU.TargetProductID
            JOIN [Inventory].[RecipeDetails] RD_Sub ON RD_Sub.RecipeID = R_Sub.RecipeID
            WHERE EU.RecLevel > 0 
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] PS 
                  WHERE PS.ProductID = EU.TargetProductID AND PS.WarehouseID = EU.WarehouseID AND PS.CurrentQty > 0
              )
        )
        UPDATE S
        SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN T.InvType = 'Sales' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT TargetProductID, InvID, InvType, WarehouseID, SUM(TargetQty) as Qty 
            FROM ExplodedUnpost 
            GROUP BY TargetProductID, InvID, InvType, WarehouseID
        ) T ON S.ProductID = T.TargetProductID AND S.WarehouseID = T.WarehouseID;
    END
END
GO

-- =============================================
-- Trigger: trg_Invoice_Post (Thin Coordinator)
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

    IF NOT UPDATE(IsPosted) RETURN;

    SELECT * INTO #TrgInserted FROM inserted;
    SELECT * INTO #TrgDeleted  FROM deleted;

    -- ─── 1. حالة الترحيل (POSTING: 0 -> 1) ──────────────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        SELECT i.InvID, i.InvType,
               NEXT VALUE FOR [Accounting].[seq_EntryNo] AS EntryNo
        INTO #TrgEntryMap
        FROM #TrgInserted i
        INNER JOIN #TrgDeleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0;

        EXEC [Sales].[sp_Invoice_Post_Inventory];
        EXEC [Sales].[sp_Invoice_Post_InvoiceJournals];
        EXEC [Sales].[sp_Invoice_Post_PaymentJournals];

        DROP TABLE #TrgEntryMap;
    END

    -- ─── 2. حالة إلغاء الترحيل (UNPOSTING: 1 -> 0) ──────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        EXEC [Sales].[sp_Invoice_Post_Inventory];

        DELETE JE FROM [Accounting].[JournalEntries] JE
        INNER JOIN #TrgDeleted d ON JE.ReferenceID = d.InvID
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        WHERE i.IsPosted = 0 AND d.IsPosted = 1
          AND JE.ReferenceType IN ('Invoice', 'Payment');
    END

    DROP TABLE #TrgInserted;
    DROP TABLE #TrgDeleted;
END
GO
GO

-- 1. إجراء جلب جميع الوصفات
IF OBJECT_ID('[Inventory].[sp_Recipe_GetAll]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Recipe_GetAll];
GO

CREATE PROCEDURE [Inventory].[sp_Recipe_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        R.RecipeID,
        R.ProductID,
        P.ProductName,
        P.Barcode,
        P.ProductType,
        R.TotalCost,
        R.Notes,
        R.CreatedDate,
        (SELECT COUNT(1) FROM [Inventory].[RecipeDetails] RD WHERE RD.RecipeID = R.RecipeID) AS IngredientsCount
    FROM [Inventory].[Recipes] R
    INNER JOIN [Inventory].[Products] P ON R.ProductID = P.ProductID
    ORDER BY P.ProductName;
END
GO

-- 2. إجراء جلب تفاصيل وصفة صنف معين
IF OBJECT_ID('[Inventory].[sp_Recipe_GetByProduct]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Recipe_GetByProduct];
GO

CREATE PROCEDURE [Inventory].[sp_Recipe_GetByProduct]
    @ProductID INT,
    @WarehouseID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- الجدول 1: رأس الوصفة
    SELECT 
        R.RecipeID, 
        R.ProductID, 
        P.ProductName, 
        ISNULL((
            SELECT SUM(RD2.Qty * ISNULL(
                CASE 
                    WHEN @WarehouseID IS NOT NULL THEN PS2.AvgCostPrice
                    ELSE MinStock.MinCost
                END, 0))
            FROM [Inventory].[RecipeDetails] RD2
            LEFT JOIN [Inventory].[ProductStock] PS2 
                   ON PS2.ProductID = RD2.IngredientProductID 
                  AND PS2.WarehouseID = @WarehouseID
            OUTER APPLY (
                SELECT MIN(AvgCostPrice) AS MinCost
                FROM [Inventory].[ProductStock]
                WHERE ProductID = RD2.IngredientProductID AND AvgCostPrice > 0
            ) MinStock
            WHERE RD2.RecipeID = R.RecipeID
        ), 0) AS TotalCost,
        R.Notes
    FROM [Inventory].[Recipes] R
    INNER JOIN [Inventory].[Products] P ON R.ProductID = P.ProductID
    WHERE R.ProductID = @ProductID;

    -- الجدول 2: مكونات الوصفة مع تكلفة وحدة المادة الخام/المنتج الوسيط من ProductStock
    SELECT 
        RD.RecipeDetailID,
        RD.RecipeID,
        RD.IngredientProductID,
        P.ProductName AS IngredientName,
        P.Barcode AS IngredientBarcode,
        P.ProductType AS IngredientType,
        U.UnitName,
        RD.Qty,
        ISNULL(
            CASE 
                WHEN @WarehouseID IS NOT NULL THEN PS.AvgCostPrice
                ELSE MinStock.MinCost
            END, 0) AS UnitCost,
        (RD.Qty * ISNULL(
            CASE 
                WHEN @WarehouseID IS NOT NULL THEN PS.AvgCostPrice
                ELSE MinStock.MinCost
            END, 0)) AS LineCost
    FROM [Inventory].[RecipeDetails] RD
    INNER JOIN [Inventory].[Recipes] R ON RD.RecipeID = R.RecipeID
    INNER JOIN [Inventory].[Products] P ON RD.IngredientProductID = P.ProductID
    LEFT JOIN [Settings].[Units] U ON P.UnitID = U.UnitID
    LEFT JOIN [Inventory].[ProductStock] PS 
           ON PS.ProductID = P.ProductID 
          AND PS.WarehouseID = @WarehouseID
    OUTER APPLY (
        SELECT MIN(AvgCostPrice) AS MinCost
        FROM [Inventory].[ProductStock]
        WHERE ProductID = RD.IngredientProductID AND AvgCostPrice > 0
    ) MinStock
    WHERE R.ProductID = @ProductID;
END
GO

-- 3. إجراء حفظ الوصفة وتفاصيلها بأسلوب XML (يستدعي sp_Update_Manufactured_Costs للتحديث المتسلسل)
IF OBJECT_ID('[Inventory].[sp_Recipe_Save_XML]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Recipe_Save_XML];
GO

CREATE PROCEDURE [Inventory].[sp_Recipe_Save_XML]
    @ProductID INT,
    @Notes NVARCHAR(500),
    @DetailsXML XML,
    @WarehouseID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- فحص الحماية: منع إضافة الصنف كـ "مكون" لنفسه مباشرة
        IF EXISTS (
            SELECT 1 FROM @DetailsXML.nodes('/Details/Detail') AS T(c)
            WHERE T.c.value('(IngredientProductID)[1]', 'INT') = @ProductID
        )
        BEGIN
            RAISERROR(N'عذراً، لا يمكن إضافة المنتج كمكون لنفسه في الوصفة!', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @RecipeID INT;
        SELECT @RecipeID = RecipeID FROM [Inventory].[Recipes] WHERE ProductID = @ProductID;

        IF @RecipeID IS NULL
        BEGIN
            INSERT INTO [Inventory].[Recipes] (ProductID, Notes)
            VALUES (@ProductID, @Notes);
            SET @RecipeID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [Inventory].[Recipes] SET Notes = @Notes WHERE RecipeID = @RecipeID;
        END

        -- مسح المكونات القديمة وإعادة بناء المكونات
        DELETE FROM [Inventory].[RecipeDetails] WHERE RecipeID = @RecipeID;

        INSERT INTO [Inventory].[RecipeDetails] (RecipeID, IngredientProductID, Qty, Cost)
        SELECT 
            @RecipeID,
            T.c.value('(IngredientProductID)[1]', 'INT'),
            T.c.value('(Qty)[1]', 'DECIMAL(18, 4)'),
            ISNULL(T.c.value('(Cost)[1]', 'DECIMAL(18, 3)'), 0)
        FROM @DetailsXML.nodes('/Details/Detail') AS T(c);

        -- 1. تحديث التكلفة الكلية للوصفة في جدول الجذور Recipes
        DECLARE @RecipeTotalCost DECIMAL(18, 3) = 0;
        SELECT @RecipeTotalCost = ISNULL(SUM(RD.Qty * RD.Cost), 0)
        FROM [Inventory].[RecipeDetails] RD 
        WHERE RD.RecipeID = @RecipeID;

        UPDATE [Inventory].[Recipes]
        SET TotalCost = @RecipeTotalCost
        WHERE RecipeID = @RecipeID;

        -- 2. إذا لم يُحدد مستودع، يتم استخدام المستودع الرئيسي الافتراضي
        IF @WarehouseID IS NULL
        BEGIN
            SELECT TOP 1 @WarehouseID = WarehouseID FROM [Settings].[Warehouses] ORDER BY WarehouseID;
        END

        -- 3. إضافة/تحديث المنتج المصنع الجديد في ProductStock بالتكلفة المحسوبة ورصيد 0 إذا كان جديداً
        IF @WarehouseID IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM [Inventory].[ProductStock] WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID)
            BEGIN
                UPDATE [Inventory].[ProductStock]
                SET AvgCostPrice = @RecipeTotalCost
                WHERE ProductID = @ProductID AND WarehouseID = @WarehouseID;
            END
            ELSE
            BEGIN
                INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
                VALUES (@ProductID, @WarehouseID, 0, @RecipeTotalCost);
            END
        END

        -- 4. استدعاء الإجراء المتسلسل للتحديث الشامل لجميع المستويات في المخازن
        EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @WarehouseID;

        COMMIT TRANSACTION;
        SELECT @RecipeID AS RecipeID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 4. إجراء حذف وصفة
IF OBJECT_ID('[Inventory].[sp_Recipe_Delete]', 'P') IS NOT NULL
    DROP PROCEDURE [Inventory].[sp_Recipe_Delete];
GO

CREATE PROCEDURE [Inventory].[sp_Recipe_Delete]
    @RecipeID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM [Inventory].[RecipeDetails] WHERE RecipeID = @RecipeID;
        DELETE FROM [Inventory].[Recipes] WHERE RecipeID = @RecipeID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

UPDATE [Inventory].[Products]
SET ProductType = 1
WHERE ProductType IS NULL;
GO

-- 5. إجراء فواتير المشتريات (جلب المواد الخام والأصناف العادية واستثناء الأصناف المصنعة)
IF OBJECT_ID('[Inventory].[sp_Product_GetForPurchase]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetForPurchase];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetForPurchase]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName, p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1
      AND (@ProductionMode = 0 OR ISNULL(p.ProductType, 1) IN (0, 1))
    ORDER BY p.ProductName;
END
GO

-- 6. إجراء فواتير المبيعات (جلب المنتجات المصنعة 2 والأصناف العادية 1)
IF OBJECT_ID('[Inventory].[sp_Product_GetForSales]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetForSales];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetForSales]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    SELECT 
        p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
        p.CategoryID, c.CatName, p.UnitID, u.UnitName,
        p.PurchasePrice, p.SalePrice, p.AlertQty, p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1
      AND (@ProductionMode = 0 OR ISNULL(p.ProductType, 1) IN (1, 2))
    ORDER BY p.ProductName;
END
GO

-- 7. إجراء تفاصيل الوصفات (جلب المواد الخام والمنتجات الوسيطة والأصناف العادية مع تكلفة ProductStock)
IF OBJECT_ID('[Inventory].[sp_Product_GetForRecipeIngredients]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetForRecipeIngredients];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetForRecipeIngredients]
    @WarehouseID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    SELECT 
        p.ProductID, 
        p.ProductName, 
        p.ProductNameEn, 
        p.Barcode,
        p.CategoryID, 
        c.CatName, 
        p.UnitID, 
        u.UnitName,
        ISNULL(
            CASE 
                WHEN @WarehouseID IS NOT NULL THEN PS.AvgCostPrice
                ELSE MinStock.MinCost
            END, 0) AS PurchasePrice,  -- التكلفة المرجحة حصراً من جدول ProductStock (حتى لو من مخزن آخر)
        p.SalePrice, 
        p.AlertQty, 
        p.IsActive,
        ISNULL(p.ProductType, 1) AS ProductType
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    LEFT JOIN [Inventory].[ProductStock] PS ON PS.ProductID = p.ProductID AND PS.WarehouseID = @WarehouseID
    OUTER APPLY (
        SELECT MIN(AvgCostPrice) AS MinCost
        FROM [Inventory].[ProductStock]
        WHERE ProductID = p.ProductID AND AvgCostPrice > 0
    ) MinStock
    WHERE p.IsActive = 1
      AND (@ProductionMode = 0 OR ISNULL(p.ProductType, 1) IN (0, 1, 3))
    ORDER BY p.ProductName;
END
GO

-- 8. إجراء الأصناف المستهدفة للوصفات (جلب المنتجات المصنعة 2 والمنتجات الوسيطة 3 التي ليس لها وصفة مسجلة بعد)
IF OBJECT_ID('[Inventory].[sp_Product_GetForRecipeTarget]', 'P') IS NOT NULL DROP PROCEDURE [Inventory].[sp_Product_GetForRecipeTarget];
GO
CREATE PROCEDURE [Inventory].[sp_Product_GetForRecipeTarget]
    @WarehouseID INT = NULL,
    @IncludeAll  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    IF @IncludeAll = 1
    BEGIN
        -- جلب جميع المنتجات المصنعة (2) والوسيطة (3) سواء لها وصفة مسجلة أو لا (لقائمة البحث الشاملة)
        SELECT 
            p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
            p.CategoryID, c.CatName, p.UnitID, u.UnitName,
            ISNULL(
                CASE 
                    WHEN @WarehouseID IS NOT NULL THEN PS.AvgCostPrice
                    ELSE MinStock.MinCost
                END, 0) AS PurchasePrice,
            p.SalePrice, p.AlertQty, p.IsActive,
            ISNULL(p.ProductType, 1) AS ProductType,
            CASE WHEN EXISTS (SELECT 1 FROM [Inventory].[Recipes] r WHERE r.ProductID = p.ProductID) THEN 1 ELSE 0 END AS HasRecipe
        FROM [Inventory].[Products] p
        LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
        LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
        LEFT JOIN [Inventory].[ProductStock] PS ON PS.ProductID = p.ProductID AND PS.WarehouseID = @WarehouseID
        OUTER APPLY (
            SELECT MIN(AvgCostPrice) AS MinCost
            FROM [Inventory].[ProductStock]
            WHERE ProductID = p.ProductID AND AvgCostPrice > 0
        ) MinStock
        WHERE p.IsActive = 1
          AND ISNULL(p.ProductType, 1) IN (2, 3)
        ORDER BY p.ProductName;
    END
    ELSE
    BEGIN
        -- الوضع الافتراضي: جلب المنتجات المصنعة (2) والوسيطة (3) التي ليس لها وصفة مسجلة بعد فقط
        IF EXISTS (
            SELECT 1 FROM [Inventory].[Products] p 
            WHERE p.IsActive = 1 
              AND ISNULL(p.ProductType, 1) IN (2, 3)
              AND NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] r WHERE r.ProductID = p.ProductID)
        )
        BEGIN
            SELECT 
                p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
                p.CategoryID, c.CatName, p.UnitID, u.UnitName,
                ISNULL(
                    CASE 
                        WHEN @WarehouseID IS NOT NULL THEN PS.AvgCostPrice
                        ELSE MinStock.MinCost
                    END, 0) AS PurchasePrice,
                p.SalePrice, p.AlertQty, p.IsActive,
                ISNULL(p.ProductType, 1) AS ProductType,
                0 AS HasRecipe
            FROM [Inventory].[Products] p
            LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
            LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
            LEFT JOIN [Inventory].[ProductStock] PS ON PS.ProductID = p.ProductID AND PS.WarehouseID = @WarehouseID
            OUTER APPLY (
                SELECT MIN(AvgCostPrice) AS MinCost
                FROM [Inventory].[ProductStock]
                WHERE ProductID = p.ProductID AND AvgCostPrice > 0
            ) MinStock
            WHERE p.IsActive = 1
              AND ISNULL(p.ProductType, 1) IN (2, 3)
              AND NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] r WHERE r.ProductID = p.ProductID)
            ORDER BY p.ProductName;
        END
        ELSE
        BEGIN
            -- التراجع لشمول المنتجات العادية والمصنعة والوسيطة التي ليس لها وصفة مسجلة بعد
            SELECT 
                p.ProductID, p.ProductName, p.ProductNameEn, p.Barcode,
                p.CategoryID, c.CatName, p.UnitID, u.UnitName,
                ISNULL(
                    CASE 
                        WHEN @WarehouseID IS NOT NULL THEN PS.AvgCostPrice
                        ELSE MinStock.MinCost
                    END, 0) AS PurchasePrice,
                p.SalePrice, p.AlertQty, p.IsActive,
                ISNULL(p.ProductType, 1) AS ProductType,
                0 AS HasRecipe
            FROM [Inventory].[Products] p
            LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.CatID
            LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
            LEFT JOIN [Inventory].[ProductStock] PS ON PS.ProductID = p.ProductID AND PS.WarehouseID = @WarehouseID
            OUTER APPLY (
                SELECT MIN(AvgCostPrice) AS MinCost
                FROM [Inventory].[ProductStock]
                WHERE ProductID = p.ProductID AND AvgCostPrice > 0
            ) MinStock
            WHERE p.IsActive = 1
              AND ISNULL(p.ProductType, 1) IN (1, 2, 3)
              AND NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] r WHERE r.ProductID = p.ProductID)
            ORDER BY p.ProductName;
        END
    END
END
GO

-- =============================================
-- Control Panel Procedures for [Settings].[CompanySettings]
-- =============================================

IF OBJECT_ID('[Settings].[sp_CompanySettings_Get]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Get];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Get]
AS
BEGIN
    SELECT TOP 1 
        SettingID,
        CompanyName,
        Address,
        Phone,
        Email,
        Logo,
        ISNULL(UnifiedPartnerSearch, 1) AS UnifiedPartnerSearch,
        ISNULL(CurrencySymbol, N'د.ك') AS CurrencySymbol,
        ISNULL(UseDetailedInvoiceDesign, 0) AS UseDetailedInvoiceDesign,
        ISNULL(UseCustomInvoiceDesign, 0) AS UseCustomInvoiceDesign,
        ISNULL(ProductionMode, 0) AS ProductionMode,
        ISNULL(EnableDailyOrders, 0) AS EnableDailyOrders,
        DeliverySystemMode,
        ISNULL(EnableSalesDiscounts, 0) AS EnableSalesDiscounts
    FROM [Settings].[CompanySettings];
END
GO

IF OBJECT_ID('[Settings].[sp_CompanySettings_Save]', 'P') IS NOT NULL DROP PROCEDURE [Settings].[sp_CompanySettings_Save];
GO
CREATE PROCEDURE [Settings].[sp_CompanySettings_Save]
    @CompanyName NVARCHAR(200),
    @Address NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Logo VARBINARY(MAX) = NULL,
    @UnifiedPartnerSearch BIT = 1,
    @CurrencySymbol NVARCHAR(100) = NULL,
    @UseDetailedInvoiceDesign BIT = 0,
    @UseCustomInvoiceDesign BIT = 0,
    @ProductionMode BIT = 0,
    @EnableDailyOrders BIT = 0,
    @DeliverySystemMode NVARCHAR(50) = NULL,
    @EnableSalesDiscounts BIT = 0
AS
BEGIN
    IF EXISTS (SELECT 1 FROM [Settings].[CompanySettings])
    BEGIN
        UPDATE [Settings].[CompanySettings]
        SET CompanyName = @CompanyName,
            Address = @Address,
            Phone = @Phone,
            Email = @Email,
            Logo = @Logo,
            UnifiedPartnerSearch = @UnifiedPartnerSearch,
            CurrencySymbol = @CurrencySymbol,
            UseDetailedInvoiceDesign = @UseDetailedInvoiceDesign,
            UseCustomInvoiceDesign = @UseCustomInvoiceDesign,
            ProductionMode = @ProductionMode,
            EnableDailyOrders = @EnableDailyOrders,
            DeliverySystemMode = @DeliverySystemMode,
            EnableSalesDiscounts = @EnableSalesDiscounts
        WHERE SettingID = 1;
    END
    ELSE
    BEGIN
        INSERT INTO [Settings].[CompanySettings] (SettingID, CompanyName, Address, Phone, Email, Logo, UnifiedPartnerSearch, CurrencySymbol, UseDetailedInvoiceDesign, UseCustomInvoiceDesign, ProductionMode, EnableDailyOrders, DeliverySystemMode, EnableSalesDiscounts)
        VALUES (1, @CompanyName, @Address, @Phone, @Email, @Logo, @UnifiedPartnerSearch, @CurrencySymbol, @UseDetailedInvoiceDesign, @UseCustomInvoiceDesign, @ProductionMode, @EnableDailyOrders, @DeliverySystemMode, @EnableSalesDiscounts);
    END
END
GO

IF OBJECT_ID('[Settings].[sp_CompanySettings_Get_Ctrl]', 'P') IS NOT NULL
    DROP PROCEDURE [Settings].[sp_CompanySettings_Get_Ctrl];
GO

CREATE PROCEDURE [Settings].[sp_CompanySettings_Get_Ctrl]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 * FROM [Settings].[CompanySettings];
END
GO

IF OBJECT_ID('[Settings].[sp_CompanySettings_Save_Ctrl]', 'P') IS NOT NULL
    DROP PROCEDURE [Settings].[sp_CompanySettings_Save_Ctrl];
GO

CREATE PROCEDURE [Settings].[sp_CompanySettings_Save_Ctrl]
    @ProductionMode BIT = NULL,
    @UseCustomInvoiceDesign BIT = NULL,
    @UseDetailedInvoiceDesign BIT = NULL,
    @UnifiedPartnerSearch BIT = NULL,
    @CompanyName NVARCHAR(250) = NULL,
    @CurrencySymbol NVARCHAR(50) = NULL,
    @Address NVARCHAR(500) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @Email NVARCHAR(150) = NULL,
    @EnableDailyOrders BIT = NULL,
    @DeliverySystemMode NVARCHAR(50) = NULL,
    @EnableSalesDiscounts BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Settings].[CompanySettings]
    SET ProductionMode = ISNULL(@ProductionMode, ProductionMode),
        UseCustomInvoiceDesign = ISNULL(@UseCustomInvoiceDesign, UseCustomInvoiceDesign),
        UseDetailedInvoiceDesign = ISNULL(@UseDetailedInvoiceDesign, UseDetailedInvoiceDesign),
        UnifiedPartnerSearch = ISNULL(@UnifiedPartnerSearch, UnifiedPartnerSearch),
        CompanyName = COALESCE(@CompanyName, CompanyName),
        CurrencySymbol = COALESCE(@CurrencySymbol, CurrencySymbol),
        Address = COALESCE(@Address, Address),
        Phone = COALESCE(@Phone, Phone),
        Email = COALESCE(@Email, Email),
        EnableDailyOrders = ISNULL(@EnableDailyOrders, EnableDailyOrders),
        DeliverySystemMode = COALESCE(@DeliverySystemMode, DeliverySystemMode),
        EnableSalesDiscounts = ISNULL(@EnableSalesDiscounts, EnableSalesDiscounts);
END
GO





IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'EnableDailyOrders')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD EnableDailyOrders BIT NOT NULL DEFAULT 0;
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'DeliverySystemMode')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD DeliverySystemMode NVARCHAR(50) NULL DEFAULT NULL;
END
GO
IF OBJECT_ID('[Sales].[sp_InvoiceDetails_GetByInvID]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID];
GO
create PROCEDURE [Sales].[sp_InvoiceDetails_GetByInvID]
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
    WHERE d.InvID = @InvID
	order by [DetID];
END
GO
-- =============================================================================================================
-- 37. Payment Methods & Split Payment Support
-- MVVM-Style Trigger Refactoring: trg_Invoice_Post → 3 Layered SPs + Thin Trigger
-- =============================================================================================================
-- الفلسفة:
--   الـ Trigger يصبح "thin coordinator" فقط:
--     1. يُحوّل inserted/deleted إلى Temp Tables مرئية للـ SPs
--     2. يستدعي 3 SPs متخصصة (Inventory / InvoiceJournals / PaymentJournals)
--     3. المنطق الكامل الأصلي موجود بالكامل في الـ SPs بدون أي حذف
--
--   sp_Invoice_Post_Inventory      → نفس منطق المخزن تماماً
--   sp_Invoice_Post_InvoiceJournals → نفس قيود A و B تماماً
--   sp_Invoice_Post_PaymentJournals → قيود C + دعم Split Payment + Fallback للقديم
--
-- BACKWARD COMPATIBILITY:
--   فواتير WPF القديمة أو فواتير بدون Splits → تعمل عبر Fallback على PaymentAccountID الفردي
--   لا يوجد أي تغيير في جداول الإنتاج، فقط إضافة
-- =============================================================================================================

-- =============================================
-- STEP 1: جدول InvoicePaymentSplits
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'InvoicePaymentSplits' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE [Sales].[InvoicePaymentSplits] (
        SplitID          INT PRIMARY KEY IDENTITY(1,1),
        InvID            INT NOT NULL,
        PaymentAccountID INT NOT NULL,      -- حساب طريقة الدفع (AccountCode LIKE '11%')
        Amount           DECIMAL(18,3) NOT NULL,
        CreatedAt        DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (InvID)            REFERENCES [Sales].[InvoiceHeader](InvID)              ON DELETE CASCADE,
        FOREIGN KEY (PaymentAccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID)
    );

    CREATE NONCLUSTERED INDEX [IX_InvoicePaymentSplits_InvID]
        ON [Sales].[InvoicePaymentSplits] (InvID);

    PRINT N'[Sales].[InvoicePaymentSplits] created successfully.';
END
ELSE
    PRINT N'[Sales].[InvoicePaymentSplits] already exists — skipped.';
GO

-- =============================================
-- STEP 2: SP الطبقة الأولى — تحديث المخزن (Post & Unpost مع دعم التصنيع والتوزيع التكراري)
-- يستخدم Temp Tables: #TrgInserted, #TrgDeleted (تُنشأ من الـ Trigger)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_Inventory]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_Inventory];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_Inventory]
AS
BEGIN
    SET NOCOUNT ON;

    -- جلب وضع التصنيع المسجل في إعدادات الشركة (0 = عادي / بيع مباشر، 1 = تصنيع ووصفات)
    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    -- ==========================================================
    -- أولاً: حالة الترحيل (POSTING: 0 -> 1)
    -- ==========================================================
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        -- أ. إدراج سجلات المنتجات المفقودة للمستودع المعين بقيم صفرية لمنع فشل التحديث (يشمل مكونات الوصفات عند التفعيل)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT DISTINCT TargetProductID, WarehouseID, 0, 0
        FROM (
            SELECT D.ProductID AS TargetProductID, i.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted del ON i.InvID = del.InvID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
            UNION
            SELECT RD.IngredientProductID AS TargetProductID, i.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted del ON i.InvID = del.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0 AND @ProductionMode = 1 AND i.InvType = 'Sales'
        ) MissingStock
        WHERE NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] S2 
            WHERE S2.ProductID = MissingStock.TargetProductID AND S2.WarehouseID = MissingStock.WarehouseID
        );

        -- ب. تحديث متوسط التكلفة الأصلي (للمشتريات فقط - قبل زيادة الكمية)
        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (ISNULL(S.CurrentQty, 0) + T.TotalQty) > 0 
            THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) + T.TotalSum) / (ISNULL(S.CurrentQty, 0) + T.TotalQty)
            ELSE T.WeightedPrice END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum,
                   SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0) as WeightedPrice
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND i.InvType = 'Purchase'
            GROUP BY D.ProductID, i.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        -- ب.1. تحديث تكاليف كافة المنتجات المصنعة عند ترحيل المشتريات (إذا كان وضع التصنيع مفعلاً)
        IF @ProductionMode = 1 AND EXISTS (SELECT 1 FROM #TrgInserted WHERE InvType = 'Purchase' AND IsPosted = 1)
        BEGIN
            DECLARE @PurchasedW INT = (SELECT TOP 1 WarehouseID FROM #TrgInserted WHERE InvType = 'Purchase' AND IsPosted = 1);
            IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
                EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @PurchasedW;
        END

        -- ج. تحديث الكميات في المخزن مع الدعم التكراري للوصفات (ExplodedPost CTE)
        ;WITH ExplodedPost AS (
            SELECT 
                D.InvID,
                i.InvType,
                i.WarehouseID,
                D.ProductID AS TargetProductID,
                CAST(D.Quantity AS DECIMAL(18, 4)) AS TargetQty,
                0 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 
              AND (@ProductionMode = 0 OR i.InvType = 'Purchase' OR NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] WHERE ProductID = D.ProductID))

            UNION ALL

            SELECT 
                D.InvID,
                i.InvType,
                i.WarehouseID,
                RD.IngredientProductID AS TargetProductID,
                CAST((D.Quantity * RD.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                1 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND @ProductionMode = 1 AND i.InvType = 'Sales'

            UNION ALL

            SELECT 
                EP.InvID,
                EP.InvType,
                EP.WarehouseID,
                RD_Sub.IngredientProductID AS TargetProductID,
                CAST((EP.TargetQty * RD_Sub.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                EP.RecLevel + 1
            FROM ExplodedPost EP
            JOIN [Inventory].[Recipes] R_Sub ON R_Sub.ProductID = EP.TargetProductID
            JOIN [Inventory].[RecipeDetails] RD_Sub ON RD_Sub.RecipeID = R_Sub.RecipeID
            WHERE EP.RecLevel > 0 
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] PS 
                  WHERE PS.ProductID = EP.TargetProductID AND PS.WarehouseID = EP.WarehouseID AND PS.CurrentQty > 0
              )
        )
        UPDATE S
        SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN T.InvType = 'Purchase' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT TargetProductID, InvID, InvType, WarehouseID, SUM(TargetQty) as Qty 
            FROM ExplodedPost 
            GROUP BY TargetProductID, InvID, InvType, WarehouseID
        ) T ON S.ProductID = T.TargetProductID AND S.WarehouseID = T.WarehouseID;

        -- د. تسجيل التكلفة المباشرة في تفاصيل الفاتورة (للمبيعات) لضبط الربحية
        UPDATE D
        SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
        FROM [Sales].[InvoiceDetails] D
        JOIN #TrgInserted i ON D.InvID = i.InvID
        JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID AND S.WarehouseID = i.WarehouseID
        WHERE i.IsPosted = 1 AND i.InvType = 'Sales';
    END

    -- ==========================================================
    -- ثانياً: حالة إلغاء الترحيل (UNPOSTING: 1 -> 0)
    -- ==========================================================
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        -- أ. إدراج سجلات المخزون المفقودة لمنع فشل التحديث عند إلغاء الترحيل
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT DISTINCT TargetProductID, WarehouseID, 0, 0
        FROM (
            SELECT D.ProductID AS TargetProductID, d_old.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
            UNION
            SELECT RD.IngredientProductID AS TargetProductID, d_old.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND @ProductionMode = 1 AND d_old.InvType = 'Sales'
        ) MissingStockUnpost
        WHERE NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] S2 
            WHERE S2.ProductID = MissingStockUnpost.TargetProductID AND S2.WarehouseID = MissingStockUnpost.WarehouseID
        );

        -- ب. إعادة حساب وتخفيض متوسط التكلفة (عند إلغاء ترحيل المشتريات فقط)
        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (ISNULL(S.CurrentQty, 0) - T.TotalQty) > 0 
            THEN (CASE 
                WHEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) > 0 
                THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) / (ISNULL(S.CurrentQty, 0) - T.TotalQty)
                ELSE 0 END)
            ELSE 0 END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, d_old.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND d_old.InvType = 'Purchase'
            GROUP BY D.ProductID, d_old.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        -- ب.1. إعادة حساب تكاليف المنتجات المصنعة بعد إلغاء ترحيل المشتريات
        IF @ProductionMode = 1 AND EXISTS (SELECT 1 FROM #TrgDeleted WHERE InvType = 'Purchase' AND IsPosted = 1)
        BEGIN
            DECLARE @UnpostedW INT = (SELECT TOP 1 WarehouseID FROM #TrgDeleted WHERE InvType = 'Purchase' AND IsPosted = 1);
            IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
                EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @UnpostedW;
        END

        -- ج. عكس تأثير المخزن عند إلغاء الترحيل (المبيعات تعيد للمخزن / المشتريات تقتطع)
        ;WITH ExplodedUnpost AS (
            SELECT 
                D.InvID,
                d_old.InvType,
                d_old.WarehouseID,
                D.ProductID AS TargetProductID,
                CAST(D.Quantity AS DECIMAL(18, 4)) AS TargetQty,
                0 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
              AND (@ProductionMode = 0 OR d_old.InvType = 'Purchase' OR NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] WHERE ProductID = D.ProductID))

            UNION ALL

            SELECT 
                D.InvID,
                d_old.InvType,
                d_old.WarehouseID,
                RD.IngredientProductID AS TargetProductID,
                CAST((D.Quantity * RD.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                1 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND @ProductionMode = 1 AND d_old.InvType = 'Sales'

            UNION ALL

            SELECT 
                EU.InvID,
                EU.InvType,
                EU.WarehouseID,
                RD_Sub.IngredientProductID AS TargetProductID,
                CAST((EU.TargetQty * RD_Sub.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                EU.RecLevel + 1
            FROM ExplodedUnpost EU
            JOIN [Inventory].[Recipes] R_Sub ON R_Sub.ProductID = EU.TargetProductID
            JOIN [Inventory].[RecipeDetails] RD_Sub ON RD_Sub.RecipeID = R_Sub.RecipeID
            WHERE EU.RecLevel > 0 
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] PS 
                  WHERE PS.ProductID = EU.TargetProductID AND PS.WarehouseID = EU.WarehouseID AND PS.CurrentQty > 0
              )
        )
        UPDATE S
        SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN T.InvType = 'Sales' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT TargetProductID, InvID, InvType, WarehouseID, SUM(TargetQty) as Qty 
            FROM ExplodedUnpost 
            GROUP BY TargetProductID, InvID, InvType, WarehouseID
        ) T ON S.ProductID = T.TargetProductID AND S.WarehouseID = T.WarehouseID;
    END
END
GO

-- =============================================
-- STEP 3: SP الطبقة الثانية — قيود الفاتورة (A + B)
-- يستخدم: #TrgInserted, #TrgDeleted, #TrgEntryMap
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_InvoiceJournals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_InvoiceJournals];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_InvoiceJournals]
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── حسابات الفالباك (نفس الأصل تماماً) ─────────────────────────────────
    DECLARE @InventoryAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13'));

    DECLARE @SalesAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '41'));

    DECLARE @COGSAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5101'),
        ISNULL(
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1),
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '51')));

    DECLARE @CustomerAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'));

    DECLARE @VendorAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'));

    -- ─── A. قيود فواتير المشتريات ─────────────────────────────────────────────

    -- Leg 1: Dr المخزن (Inventory)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(w.AccountID, @InventoryAcc),
           i.NetAmount, 0,
           N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
    WHERE i.InvType = 'Purchase';

    -- Leg 2: Cr المورد (Vendor)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(p.AccountID, @VendorAcc),
           0, i.NetAmount,
           N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Purchase';

    -- ─── B. قيود فواتير المبيعات ──────────────────────────────────────────────

    -- Leg 1: Dr العميل (Customer)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(p.AccountID, @CustomerAcc),
           i.NetAmount, 0,
           N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Sales';

    -- Leg 2: Cr المبيعات (Sales Revenue)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           @SalesAcc,
           0, i.NetAmount,
           N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    WHERE i.InvType = 'Sales';

    -- Leg 3: Dr تكلفة البضاعة المباعة COGS
    ;WITH InvoiceCOGS AS (
        SELECT d.InvID,
               SUM(s.AvgCostPrice * d.Quantity) AS TotalCOGS
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        LEFT JOIN [Inventory].[ProductStock] s
            ON s.ProductID = d.ProductID AND s.WarehouseID = i.WarehouseID
        GROUP BY d.InvID
    )
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           @COGSAcc,
           cogs.TotalCOGS, 0,
           N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
    WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

    -- Leg 4: Cr المخزن (Inventory — بحساب المستودع)
    ;WITH InvoiceCOGS AS (
        SELECT d.InvID,
               SUM(s.AvgCostPrice * d.Quantity) AS TotalCOGS
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        LEFT JOIN [Inventory].[ProductStock] s
            ON s.ProductID = d.ProductID AND s.WarehouseID = i.WarehouseID
        GROUP BY d.InvID
    )
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(w.AccountID, @InventoryAcc),
           0, cogs.TotalCOGS,
           N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
    LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
    WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;
END
GO

-- =============================================
-- STEP 4: SP الطبقة الثالثة — قيود السداد (C) مع دعم Split Payment
-- يستخدم: #TrgInserted, #TrgDeleted, #TrgEntryMap
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_PaymentJournals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_PaymentJournals];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_PaymentJournals]
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── حسابات الفالباك ───────────────────────────────────────────────────────
    DECLARE @CustomerAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'));

    DECLARE @VendorAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'));

    -- ─────────────────────────────────────────────────────────────────────────────
    -- مسار 1: SPLIT PAYMENT
    -- ─────────────────────────────────────────────────────────────────────────────

    -- ── مشتريات Split ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @VendorAcc),   -- Dr المورد
           sp.Amount, 0,
           N'سداد [' + c.AccountName + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0;

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           sp.PaymentAccountID,                -- Cr حساب طريقة الدفع
           0, sp.Amount,
           N'سداد [' + c.AccountName + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0;

    -- ── مبيعات Split ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           sp.PaymentAccountID,                -- Dr حساب طريقة الدفع
           sp.Amount, 0,
           N'سداد [' + c.AccountName + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Sales' AND i.PaidAmount > 0;

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @CustomerAcc), -- Cr العميل
           0, sp.Amount,
           N'تحصيل [' + c.AccountName + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Sales' AND sp.Amount > 0;

    -- ─────────────────────────────────────────────────────────────────────────────
    -- مسار 2: FALLBACK — PaymentAccountID الفردي
    -- ─────────────────────────────────────────────────────────────────────────────

    -- ── مشتريات Fallback ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @VendorAcc),
           i.PaidAmount, 0,
           N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Purchase'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           i.PaymentAccountID,
           0, i.PaidAmount,
           N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    WHERE i.InvType = 'Purchase'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    -- ── مبيعات Fallback ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           i.PaymentAccountID,
           i.PaidAmount, 0,
           N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    WHERE i.InvType = 'Sales'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @CustomerAcc),
           0, i.PaidAmount,
           N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Sales'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);
END
GO

-- =============================================
-- STEP 5: الـ Trigger الجديد (Thin Coordinator)
-- ينشئ Temp Tables ويستدعي الـ SPs للترحيل وإلغاء الترحيل
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

    -- فحص: هل تم تغيير IsPosted؟
    IF NOT UPDATE(IsPosted) RETURN;

    -- تحميل inserted/deleted إلى Temp Tables مرئية للـ SPs
    SELECT * INTO #TrgInserted FROM inserted;
    SELECT * INTO #TrgDeleted  FROM deleted;

    -- ─── 1. حالة الترحيل (POSTING: 0 -> 1) ──────────────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        SELECT i.InvID, i.InvType,
               NEXT VALUE FOR [Accounting].[seq_EntryNo] AS EntryNo
        INTO #TrgEntryMap
        FROM #TrgInserted i
        INNER JOIN #TrgDeleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0;

        -- أ. تحديث المخزن المباشر ومكونات الوصفات عند التفعيل
        EXEC [Sales].[sp_Invoice_Post_Inventory];

        -- ب. إنشاء قيود الفاتورة (إيرادات + تكلفة البضاعة المباعة)
        EXEC [Sales].[sp_Invoice_Post_InvoiceJournals];

        -- ج. إنشاء قيود السداد (Split + Fallback)
        EXEC [Sales].[sp_Invoice_Post_PaymentJournals];

        DROP TABLE #TrgEntryMap;
    END

    -- ─── 2. حالة إلغاء الترحيل (UNPOSTING: 1 -> 0) ──────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        -- أ. عكس تأثير المخزن وإعادة حساب التكلفة المرجحة وتكلفة المصنعات (مباشر + تصنيع ووصفات)
        EXEC [Sales].[sp_Invoice_Post_Inventory];

        -- ب. حذف كافة القيود المحاسبية بالفاتورة والمدفوعات التابعة لها بالكامل
        DELETE JE FROM [Accounting].[JournalEntries] JE
        INNER JOIN #TrgDeleted d ON JE.ReferenceID = d.InvID
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        WHERE i.IsPosted = 0 AND d.IsPosted = 1
          AND JE.ReferenceType IN ('Invoice', 'Payment');
    END

    -- تنظيف Temp Tables
    DROP TABLE #TrgInserted;
    DROP TABLE #TrgDeleted;
END
GO

-- =============================================
-- STEP 6: SPs API — حفظ وجلب Splits
-- =============================================

IF OBJECT_ID('[Sales].[sp_InvoicePaymentSplits_Save]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_InvoicePaymentSplits_Save];
GO
CREATE PROCEDURE [Sales].[sp_InvoicePaymentSplits_Save]
    @InvID            INT,
    @PaymentAccountID INT,
    @Amount           DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Sales].[InvoicePaymentSplits] (InvID, PaymentAccountID, Amount)
    VALUES (@InvID, @PaymentAccountID, @Amount);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS SplitID;
END
GO

IF OBJECT_ID('[Sales].[sp_InvoicePaymentSplits_GetByInvID]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_InvoicePaymentSplits_GetByInvID];
GO
CREATE PROCEDURE [Sales].[sp_InvoicePaymentSplits_GetByInvID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.SplitID,
        s.InvID,
        s.PaymentAccountID,
        s.Amount,
        s.CreatedAt,
        c.AccountName AS PaymentMethodName,
        c.AccountCode
    FROM [Sales].[InvoicePaymentSplits] s
    INNER JOIN [Accounting].[ChartOfAccounts] c ON s.PaymentAccountID = c.AccountID
    WHERE s.InvID = @InvID
    ORDER BY s.SplitID;
END
GO

-- =============================================
-- STEP 7: تعديل sp_Invoice_AddPayment لإضافة Split عند سداد الآجل
-- (نفس المنطق الأصلي + INSERT في InvoicePaymentSplits)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_AddPayment]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_AddPayment];
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

        -- 1. تحديث الأرصدة في الفاتورة (كما هو بالضبط)
        UPDATE [Sales].[InvoiceHeader]
        SET PaidAmount = PaidAmount + @PaymentAmount,
            Remainder  = Remainder  - @PaymentAmount
        WHERE InvID = @InvID;

        -- 2. ✅ [جديد] تسجيل طريقة الدفع في جدول الـ Splits
        INSERT INTO [Sales].[InvoicePaymentSplits] (InvID, PaymentAccountID, Amount)
        VALUES (@InvID, @PaymentAccountID, @PaymentAmount);

        -- 3. حساب الشريك (كما هو بالضبط)
        DECLARE @PartnerAccountID INT;
        SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

        -- 4. القيود المحاسبية (كما هي بالضبط)
        DECLARE @EntryNo   INT           = NEXT VALUE FOR [Accounting].[seq_EntryNo];
        DECLARE @EntryDate DATE          = CAST(GETDATE() AS DATE);
        DECLARE @AccName   NVARCHAR(100) = ISNULL((SELECT AccountName FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @PaymentAccountID), N'');
        DECLARE @Desc      NVARCHAR(255) = N'سداد [' + @AccName + N'] - فاتورة رقم ' + CAST(@InvID AS NVARCHAR);

        IF @InvType = 'Sales'
        BEGIN
            -- Dr Cash / Cr Customer
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID, @PaymentAmount, 0,             @Desc, @UserID),
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  0,             @PaymentAmount, @Desc, @UserID);
        END
        ELSE
        BEGIN
            -- Dr Vendor / Cr Cash
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  @PaymentAmount, 0,             @Desc, @UserID),
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID,  0,             @PaymentAmount, @Desc, @UserID);
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

IF OBJECT_ID('[Sales].[sp_Invoice_AddPayment_pos]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_AddPayment_pos];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_AddPayment_pos]
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

        IF @InvID IS NULL OR @Remainder IS NULL
        BEGIN RAISERROR(N'الفاتورة غير موجودة', 16, 1); RETURN; END

        IF @PaymentAmount <= 0 OR @PaymentAmount > @Remainder
        BEGIN RAISERROR(N'مبلغ السداد غير صحيح أو يتجاوز المتبقي', 16, 1); RETURN; END

        -- 1. تحديث الأرصدة وحساب السداد المختار
        UPDATE [Sales].[InvoiceHeader]
        SET PaidAmount = PaidAmount + @PaymentAmount,
            Remainder  = Remainder  - @PaymentAmount,
            PaymentAccountID = @PaymentAccountID
        WHERE InvID = @InvID;

        -- 2. ✅ تسجيل طريقة الدفع في جدول الـ Splits
        INSERT INTO [Sales].[InvoicePaymentSplits] (InvID, PaymentAccountID, Amount)
        VALUES (@InvID, @PaymentAccountID, @PaymentAmount);

        -- 3. إضافة قيود محاسبية فقط إذا كانت الفاتورة مرحّلة
        IF @IsPosted = 1
        BEGIN
            DECLARE @PartnerAccountID INT;
            SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

            DECLARE @EntryNo   INT           = NEXT VALUE FOR [Accounting].[seq_EntryNo];
            DECLARE @EntryDate DATE          = CAST(GETDATE() AS DATE);
            DECLARE @AccName   NVARCHAR(100) = ISNULL((SELECT AccountName FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @PaymentAccountID), N'');
            DECLARE @Desc      NVARCHAR(255) = N'سداد [' + @AccName + N'] - فاتورة رقم ' + CAST(@InvID AS NVARCHAR);

            IF @InvType = 'Sales'
            BEGIN
                INSERT INTO [Accounting].[JournalEntries]
                    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
                VALUES
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID, @PaymentAmount, 0,              @Desc, @UserID),
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  0,              @PaymentAmount, @Desc, @UserID);
            END
            ELSE
            BEGIN
                INSERT INTO [Accounting].[JournalEntries]
                    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
                VALUES
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  @PaymentAmount, 0,              @Desc, @UserID),
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID,  0,              @PaymentAmount, @Desc, @UserID);
            END
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
-- STEP 8: SP الإجماليات حسب طريقة الدفع في الوردية
-- =============================================
IF OBJECT_ID('[Sales].[sp_Shift_GetPaymentMethodTotals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetPaymentMethodTotals];
GO
CREATE PROCEDURE [Sales].[sp_Shift_GetPaymentMethodTotals]
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DefaultCashID INT;
    DECLARE @DefaultCashCode NVARCHAR(50) = '1101';
    DECLARE @DefaultCashName NVARCHAR(100) = N'نقدي (كاش)';

    SELECT TOP 1 
        @DefaultCashID = AccountID,
        @DefaultCashCode = AccountCode,
        @DefaultCashName = AccountName
    FROM [Accounting].[ChartOfAccounts]
    WHERE (AccountCode = '1101' OR AccountName LIKE N'%صندوق%' OR AccountName LIKE N'%كاش%' OR AccountCode LIKE '110%')
      AND IsTransactional = 1;

    SELECT 
        AccountID,
        AccountCode,
        PaymentMethodName,
        InvType,
        SUM(TotalAmount) AS TotalAmount,
        MAX(SourceType)  AS SourceType
    FROM (
        -- 1. إجماليات طرق الدفع من فواتير المبيعات/المشتريات المقسمة (Splits)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            h.InvType,
            SUM(CAST(sp.Amount AS DECIMAL(18,3)))   AS TotalAmount,
            'InvoiceSplit' AS SourceType
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader]          h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON sp.PaymentAccountID = c.AccountID
        WHERE h.ShiftID = @ShiftID
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), h.InvType

        UNION ALL

        -- 2. إجماليات طرق الدفع المباشرة من فواتير المبيعات/المشتريات (غير المقسمة / Direct)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            h.InvType,
            SUM(CAST(h.PaidAmount AS DECIMAL(18,3))) AS TotalAmount,
            'InvoiceDirect' AS SourceType
        FROM [Sales].[InvoiceHeader]                h
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON h.PaymentAccountID = c.AccountID
        WHERE h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (
              SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID
          )
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), h.InvType

        UNION ALL

        -- 3. إجماليات طرق الدفع من السندات المالية (قبض وصرف)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            v.VoucherType  AS InvType,
            SUM(CAST(v.Amount AS DECIMAL(18,3))) AS TotalAmount,
            'Voucher'      AS SourceType
        FROM [Accounting].[Vouchers]                v
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON v.AccountID = c.AccountID
        WHERE v.ShiftID = @ShiftID
          AND (c.AccountCode LIKE '11%' OR c.AccountID IS NULL)
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), v.VoucherType
    ) CombinedPaymentTotals
    GROUP BY AccountID, AccountCode, PaymentMethodName, InvType
    ORDER BY AccountCode, InvType;
END
GO

PRINT N'=== [37] Payment Methods & Split Payment — All Objects Created Successfully ===';

-- =============================================
-- STEP 9: تحديث استعلامات الفواتير لإرجاع اسم حساب الدفع ديناميكياً
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetByID]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_GetByID];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetByID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName,
        acc.AccountName AS PaymentAccountName,
        acc.AccountCode AS PaymentAccountCode,
        temp.CustomerName AS TempCustomerName,
        temp.Phone AS TempPhone,
        temp.Address AS TempAddress,
        temp.DeliveryDate AS TempDeliveryDate,
        temp.DeliveryTime AS TempDeliveryTime
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
    LEFT JOIN [Sales].[TempOrderInfo] temp ON h.InvID = temp.InvID
    WHERE h.InvID = @InvID;
END
GO

IF OBJECT_ID('[Sales].[sp_Invoice_GetAll_Pos]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_GetAll_Pos];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetAll_Pos]  
    @InvType NVARCHAR(20),
    @ShiftID int = null
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName,
        acc.AccountName AS PaymentAccountName,
        acc.AccountCode AS PaymentAccountCode
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
    WHERE h.InvType = @InvType AND (@ShiftID IS NULL OR h.ShiftID = @ShiftID)
    ORDER BY h.InvID DESC;
END
GO

PRINT N'=== [37] Payment Methods & Split Payment — All Objects Created Successfully ===';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 38. Sales Discounts & Product Bundles System (نظام خصومات وباقات المبيعات)
-- ══════════════════════════════════════════════════════════════════════════════

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Settings].[CompanySettings]') AND name = 'EnableSalesDiscounts')
BEGIN
    ALTER TABLE [Settings].[CompanySettings] ADD EnableSalesDiscounts BIT NOT NULL DEFAULT 0;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('[Sales].[ProductDiscounts]') AND type = 'U')
BEGIN
    CREATE TABLE [Sales].[ProductDiscounts] (
        DiscountID INT IDENTITY(1,1) PRIMARY KEY,
        DiscountName NVARCHAR(100) NOT NULL,
        DiscountType TINYINT NOT NULL DEFAULT 1, -- 1: Percentage %, 2: Fixed Amount, 3: Bundle/Qty Tier
        DiscountValue DECIMAL(18, 3) NOT NULL DEFAULT 0.000,
        MinQuantity DECIMAL(18, 3) NOT NULL DEFAULT 1.000,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('[Sales].[ProductDiscountItems]') AND type = 'U')
BEGIN
    CREATE TABLE [Sales].[ProductDiscountItems] (
        DiscountItemID INT IDENTITY(1,1) PRIMARY KEY,
        DiscountID INT NOT NULL CONSTRAINT FK_DiscountItems_Discount REFERENCES [Sales].[ProductDiscounts](DiscountID) ON DELETE CASCADE,
        ProductID INT NOT NULL CONSTRAINT FK_DiscountItems_Product REFERENCES [Inventory].[Products](ProductID) ON DELETE CASCADE,
        CONSTRAINT UQ_Discount_Product UNIQUE (DiscountID, ProductID)
    );
END
GO

-- Procedure: Get Products For Discounts Page (Type 1: Normal, Type 2: Final Manufactured)
IF OBJECT_ID('[Sales].[sp_Products_GetForDiscounts]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Products_GetForDiscounts];
GO
CREATE PROCEDURE [Sales].[sp_Products_GetForDiscounts]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.ProductID,
        p.ProductName,
        p.Barcode,
        p.ProductType,
        p.SalePrice,
        p.PurchasePrice,
        p.IsActive,
        ISNULL(u.UnitName, N'حبه') AS UnitName
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE p.IsActive = 1 AND p.ProductType IN (1, 2)
    ORDER BY p.ProductName ASC;
END
GO

-- Procedure: Get All Discounts with Attached Products
IF OBJECT_ID('[Sales].[sp_ProductDiscounts_GetAll]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_ProductDiscounts_GetAll];
GO
CREATE PROCEDURE [Sales].[sp_ProductDiscounts_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.DiscountID,
        d.DiscountName,
        d.DiscountType,
        d.DiscountValue,
        d.MinQuantity,
        d.IsActive,
        d.CreatedDate,
        COUNT(di.ProductID) AS ProductCount
    FROM [Sales].[ProductDiscounts] d
    LEFT JOIN [Sales].[ProductDiscountItems] di ON d.DiscountID = di.DiscountID
    GROUP BY d.DiscountID, d.DiscountName, d.DiscountType, d.DiscountValue, d.MinQuantity, d.IsActive, d.CreatedDate
    ORDER BY d.DiscountID DESC;
END
GO

-- Procedure: Get Active Discounts for POS
IF OBJECT_ID('[Sales].[sp_ProductDiscounts_GetActiveForPos]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_ProductDiscounts_GetActiveForPos];
GO
CREATE PROCEDURE [Sales].[sp_ProductDiscounts_GetActiveForPos]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.DiscountID,
        d.DiscountName,
        d.DiscountType,
        d.DiscountValue,
        d.MinQuantity,
        di.ProductID
    FROM [Sales].[ProductDiscounts] d
    INNER JOIN [Sales].[ProductDiscountItems] di ON d.DiscountID = di.DiscountID
    WHERE d.IsActive = 1
    ORDER BY d.DiscountID DESC;
END
GO

-- Procedure: Get Product IDs for a specific Discount
IF OBJECT_ID('[Sales].[sp_ProductDiscounts_GetProductIDs]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_ProductDiscounts_GetProductIDs];
GO
CREATE PROCEDURE [Sales].[sp_ProductDiscounts_GetProductIDs]
    @DiscountID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductID FROM [Sales].[ProductDiscountItems] WHERE DiscountID = @DiscountID;
END
GO

-- Procedure: Save/Update Discount with Products (XML Payload)
IF OBJECT_ID('[Sales].[sp_ProductDiscounts_Save_XML]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_ProductDiscounts_Save_XML];
GO
CREATE PROCEDURE [Sales].[sp_ProductDiscounts_Save_XML]
    @DiscountID INT OUTPUT,
    @DiscountName NVARCHAR(100),
    @DiscountType TINYINT,
    @DiscountValue DECIMAL(18, 3),
    @MinQuantity DECIMAL(18, 3),
    @IsActive BIT,
    @ProductIDsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        IF @DiscountID IS NULL OR @DiscountID <= 0
        BEGIN
            INSERT INTO [Sales].[ProductDiscounts] (DiscountName, DiscountType, DiscountValue, MinQuantity, IsActive)
            VALUES (@DiscountName, @DiscountType, @DiscountValue, ISNULL(@MinQuantity, 1.0), ISNULL(@IsActive, 1));

            SET @DiscountID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [Sales].[ProductDiscounts]
            SET DiscountName = @DiscountName,
                DiscountType = @DiscountType,
                DiscountValue = @DiscountValue,
                MinQuantity = ISNULL(@MinQuantity, 1.0),
                IsActive = ISNULL(@IsActive, 1)
            WHERE DiscountID = @DiscountID;
        END

        -- Sync ProductDiscountItems from XML
        DELETE FROM [Sales].[ProductDiscountItems] WHERE DiscountID = @DiscountID;

        IF @ProductIDsXml IS NOT NULL
        BEGIN
            INSERT INTO [Sales].[ProductDiscountItems] (DiscountID, ProductID)
            SELECT DISTINCT @DiscountID, Item.ref.value('@ProductID', 'INT')
            FROM @ProductIDsXml.nodes('/Products/Product') AS Item(ref)
            WHERE Item.ref.value('@ProductID', 'INT') IS NOT NULL;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Procedure: Delete Discount
IF OBJECT_ID('[Sales].[sp_ProductDiscounts_Delete]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_ProductDiscounts_Delete];
GO
CREATE PROCEDURE [Sales].[sp_ProductDiscounts_Delete]
    @DiscountID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DELETE FROM [Sales].[ProductDiscountItems] WHERE DiscountID = @DiscountID;
        DELETE FROM [Sales].[ProductDiscounts] WHERE DiscountID = @DiscountID;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT N'=== [38] Sales Discounts & Product Bundles System Created Successfully ===';
GO

-- ============================================================
-- [39] Trigger: Cascading Deletion for InvoiceHeader
-- Automatically deletes details, payment splits, and delivery info
-- ============================================================
IF OBJECT_ID('[Sales].[trg_InvoiceHeader_DeleteCascade]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_InvoiceHeader_DeleteCascade];
GO

CREATE TRIGGER [Sales].[trg_InvoiceHeader_DeleteCascade]
ON [Sales].[InvoiceHeader]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. حذف تفاصيل الأصناف المرتبطة بالفواتير المحذوفة
    DELETE d
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN deleted del ON d.InvID = del.InvID;

    -- 2. حذف تقسيمات طرق الدفع المرتبطة بالفواتير المحذوفة
    DELETE s
    FROM [Sales].[InvoicePaymentSplits] s
    INNER JOIN deleted del ON s.InvID = del.InvID;

    -- 3. حذف بيانات التوصيل المرتبطة إن وُجدت
    DELETE t
    FROM [Sales].[TempOrderInfo] t
    INNER JOIN deleted del ON t.InvID = del.InvID;
END
GO

PRINT N'=== [39] InvoiceHeader Cascading Delete Trigger Created Successfully ===';


