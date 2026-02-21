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
        KeeperName NVARCHAR(100)
    );
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
        IsActive BIT DEFAULT 1
    );
END

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


-- إضافة الحسابات الرئيسية 
INSERT INTO [Accounting].ChartOfAccounts (AccountCode, AccountName, AccountType, AccountLevel, IsTransactional) VALUES (N'1', N'الأصول', N'Assets', 0, 0), (N'2', N'الخصوم', N'Liabilities', 0, 0), (N'3', N'المصروفات', N'Expenses', 0, 0), (N'4', N'الإيرادات', N'Revenue', 0, 0);
-- أصول متداولة -> نقدية 
INSERT INTO Accounting.ChartOfAccounts(AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional) VALUES (N'1101', N'الصندوق الرئيسي', 1, N'Assets', 1, 1);


end
go


IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalHeader' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalHeader] (
        JID INT PRIMARY KEY IDENTITY(1,1),
        JDate DATETIME DEFAULT GETDATE(),
        Description NVARCHAR(255),
        UserID INT,
        IsPosted BIT DEFAULT 0,
        ReferenceType NVARCHAR(50), 
        ReferenceID INT, 
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalDetails' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalDetails] (
        JDID INT PRIMARY KEY IDENTITY(1,1),
        JID INT NOT NULL,
        AccountID INT NOT NULL,
        Debit DECIMAL(18, 2) DEFAULT 0,
        Credit DECIMAL(18, 2) DEFAULT 0,
        Notes NVARCHAR(200),
        FOREIGN KEY (JID) REFERENCES [Accounting].[JournalHeader](JID) ON DELETE CASCADE,
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID)
    );
END

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
        FOREIGN KEY (ProductID) REFERENCES [Inventory].[Products](ProductID),
        FOREIGN KEY (WarehouseID) REFERENCES [Settings].[Warehouses](WarehouseID),
        UNIQUE(ProductID, WarehouseID)
    );
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
        FOREIGN KEY (PartnerID) REFERENCES [Sales].[Partners](PartnerID),
        FOREIGN KEY (WarehouseID) REFERENCES [Settings].[Warehouses](WarehouseID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
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

-- 2. حفظ فاتورة (رأس وتفاصيل) + القيد المحاسبي
 IF OBJECT_ID('[Sales].[sp_Invoice_Save]', 'P') IS NOT NULL 
 DROP PROCEDURE [Sales].[sp_Invoice_Save]; 
 GO

CREATE PROCEDURE [Sales].[sp_Invoice_Save]
 @InvType NVARCHAR(20), @PartnerID INT,
  @WarehouseID INT,
   @TotalAmount DECIMAL(18,2), -- ... باقي البارامترات
    @UserID INT,
	 @InvoiceID INT OUTPUT -- يرجع رقم الفاتورة الجديدة 
	 AS
	  BEGIN 
	  SET NOCOUNT ON;
	   BEGIN TRY
	    BEGIN TRANSACTION;

-- أ. حفظ الرأس
    INSERT INTO [Sales].InvoiceHeader (InvType, InvDate, PartnerID, WarehouseID, TotalAmount, UserID)
    VALUES (@InvType, GETDATE(), @PartnerID, @WarehouseID, @TotalAmount, @UserID);
    
    SET @InvoiceID = SCOPE_IDENTITY();
    
    -- ب. التفاصيل... (كود الإدراج سيكون هنا)
    
    -- ج. تحديث المخزون...
    
    -- د. إنشاء القيد الآلي
    DECLARE @JID INT;
    INSERT INTO [Accounting].[JournalHeader] (JDate, Description, UserID, ReferenceType, ReferenceID)
    VALUES (GETDATE(), N'فاتورة ' + @InvType + N' رقم ' + CAST(@InvoiceID AS NVARCHAR), @UserID, 'Invoice', @InvoiceID);
    
    SET @JID = SCOPE_IDENTITY();
    
    -- تفاصيل القيد (مثال مبسط لمبيعات نقدية)
    IF @InvType = 'Sales'
    BEGIN
        -- من ح/ الصندوق (1101)
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit)
        VALUES (@JID, 1, @TotalAmount, 0); 
        
        -- إلى ح/ المبيعات (4101)
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit)
        VALUES (@JID, 2, 0, @TotalAmount); 
    END
    
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH
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

