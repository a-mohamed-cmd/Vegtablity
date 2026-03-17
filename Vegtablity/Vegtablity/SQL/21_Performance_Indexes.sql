-- =============================================
-- Performance Optimization - Indexes
-- =============================================
USE VegtablityDB;
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
    INCLUDE ([ProductID], [QuotedPrice], [Quantity]);
END
GO
