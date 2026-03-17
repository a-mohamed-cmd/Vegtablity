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
    CREATE INDEX IX_Products_Search ON [Inventory].[Products] (Barcode) INCLUDE (ProductName, SalePrice, UnitName);
END
GO
