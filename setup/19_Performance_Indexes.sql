-- ======================================================================
-- Vegtablity ERP - Comprehensive Performance Indexes Script
-- ======================================================================
-- This script creates Non-Clustered and Filtered indexes across all
-- schema tables to optimize JOINs, WHERE clauses, and ORDER BY operations.
-- It checks for the existence of each index before creating it to ensure
-- idempotency (can be run multiple times safely).
-- ======================================================================

USE [VegtablityDB]
GO

PRINT '====================================================='
PRINT '1. SECURITY SCHEMA INDEXES'
PRINT '====================================================='



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
