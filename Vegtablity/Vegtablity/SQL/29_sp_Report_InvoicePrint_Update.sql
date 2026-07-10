-- =========================================================================
-- UPDATE: Add Remainder, PaidAmount, and NetAmount to sp_Report_InvoicePrint
-- =========================================================================
USE [VegtablityDB]
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
