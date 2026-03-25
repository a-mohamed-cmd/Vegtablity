-- =============================================
-- 32_DatabasePerformanceIndexes.sql
-- =============================================
-- This script adds non-clustered indexes to optimize 
-- report performance and general sales lookup.

-- 1. Index for Invoice Header filtering (Dates, Statuses, Partners)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceHeader_ReportFilter' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_InvoiceHeader_ReportFilter 
    ON [Sales].[InvoiceHeader] (InvType, IsPosted, InvDate) 
    INCLUDE (PartnerID, NetAmount, TotalAmount, Discount, ReferenceNo);
    PRINT '✅ Created IX_InvoiceHeader_ReportFilter';
END
GO

-- 2. Index for Invoice Details - joining and grouping by Product
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceDetails_QueryOptimize' AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_InvoiceDetails_QueryOptimize 
    ON [Sales].[InvoiceDetails] (InvID, ProductID) 
    INCLUDE (Quantity, UnitPrice, CostPrice, TotalPrice);
    PRINT '✅ Created IX_InvoiceDetails_QueryOptimize';
END
GO

-- 3. Index for Partner Filtering by Type (Customer/Supplier)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Partners_Type_Lookup' AND object_id = OBJECT_ID('[Sales].[Partners]'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Partners_Type_Lookup 
    ON [Sales].[Partners] (PartnerType) 
    INCLUDE (PartnerName, Phone, CurrentBalance);
    PRINT '✅ Created IX_Partners_Type_Lookup';
END
GO

-- 4. Index for Products Name/Category (Sorting/Filtering)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_Name_Sort' AND object_id = OBJECT_ID('[Inventory].[Products]'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Products_Name_Sort 
    ON [Inventory].[Products] (ProductName) 
    INCLUDE (Barcode, CategoryID);
    PRINT '✅ Created IX_Products_Name_Sort';
END
GO

PRINT '✅ Done: Performance Optimization Indexes Applied.';
GO
