-- ======================================================================
-- Vegtablity ERP - Index Maintenance Script (Reorganize & Rebuild)
-- ======================================================================
-- This script dynamically checks the fragmentation level of all indexes
-- in the VegtablityDB database and applies the appropriate maintenance:
-- 1. Fragmentation between 5% and 30% -> REORGANIZE (Online, fast)
-- 2. Fragmentation > 30% -> REBUILD (Recreates the index entirely)
-- It generates an execution log via PRINT messages.
-- You can schedule this to run weekly or monthly.
-- ======================================================================

USE [VegtablityDB]
GO

SET NOCOUNT ON;

DECLARE @objectid int;
DECLARE @indexid int;
DECLARE @partitioncount bigint;
DECLARE @schemaname nvarchar(130);
DECLARE @objectname nvarchar(130);
DECLARE @indexname nvarchar(130);
DECLARE @partitionnum bigint;
DECLARE @partitions bigint;
DECLARE @frag float;
DECLARE @command nvarchar(4000);

-- Ensure the temporary table doesn't already exist
IF OBJECT_ID('tempdb..#work_to_do') IS NOT NULL
    DROP TABLE #work_to_do;

PRINT 'Starting Index Maintenance (Fragmentation Check & Rebuild)...';
PRINT 'Timestamp: ' + CAST(GETDATE() AS VARCHAR(50));
PRINT '---------------------------------------------------------';

-- 1. Gather fragmentation statistics for all indexes in the current DB
-- Ignoring heaps (index_id = 0) and small tables (page_count <= 10)
SELECT
    [object_id] AS objectid,
    index_id AS indexid,
    partition_number AS partitionnum,
    avg_fragmentation_in_percent AS frag
INTO #work_to_do
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'LIMITED')
WHERE avg_fragmentation_in_percent > 5.0 -- Only care if fragmentation > 5%
  AND index_id > 0;

-- Declare the cursor for the list of partitions to be processed
DECLARE partitions CURSOR FOR 
    SELECT * FROM #work_to_do;

-- Open the cursor and begin looping
OPEN partitions;
FETCH NEXT FROM partitions
    INTO @objectid, @indexid, @partitionnum, @frag;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Build the names of the schema, object, and index
    SELECT @objectname = QUOTENAME(o.name), @schemaname = QUOTENAME(s.name)
    FROM sys.objects AS o
    JOIN sys.schemas AS s ON s.schema_id = o.schema_id
    WHERE o.object_id = @objectid;

    SELECT @indexname = QUOTENAME(name)
    FROM sys.indexes
    WHERE object_id = @objectid AND index_id = @indexid;

    -- Count partitions for the index
    SELECT @partitioncount = count (*)
    FROM sys.partitions
    WHERE object_id = @objectid AND index_id = @indexid;

    -- Decide the command. Reorganize if <= 30%, Rebuild if > 30%
    IF @frag < 30.0
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE';
    IF @frag >= 30.0
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD';

    -- Append partition information if necessary
    IF @partitioncount > 1
        SET @command = @command + N' PARTITION=' + CAST(@partitionnum AS nvarchar(10));

    -- Execute the command
    PRINT 'Executing: ' + @command + ' (Frag: ' + CAST(CAST(@frag AS DECIMAL(5,2)) AS VARCHAR) + '%)';
    EXEC (@command);

    FETCH NEXT FROM partitions INTO @objectid, @indexid, @partitionnum, @frag;
END;


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
-- Clean up
CLOSE partitions;
DEALLOCATE partitions;
DROP TABLE #work_to_do;

PRINT '---------------------------------------------------------';
PRINT 'Index Maintenance Completed Successfully!';
PRINT 'Timestamp: ' + CAST(GETDATE() AS VARCHAR(50));
GO
