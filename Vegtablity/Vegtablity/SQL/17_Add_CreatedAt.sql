USE VegtablityDB;
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
