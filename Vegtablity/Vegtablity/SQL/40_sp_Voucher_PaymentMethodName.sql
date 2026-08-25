-- =============================================
-- Migration: 40_sp_Voucher_PaymentMethodName.sql
-- Description: جلب اسم حساب طريقة الدفع (PaymentMethodName) بدلاً من رقمه
-- =============================================

-- 1. جلب جميع السندات
IF OBJECT_ID('[Accounting].[sp_Voucher_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_GetAll];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_GetAll]
    @VoucherType NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT V.VoucherID, V.VoucherNo, V.VoucherType, V.VoucherDate, V.PartnerID,
           P.PartnerName, V.AccountID, A.AccountName,
           V.Amount, V.Description, V.PaymentMethod,
           ISNULL(PM.AccountName, V.PaymentMethod) AS PaymentMethodName,
           V.UserID, U.FullName AS UserName, V.IsPosted
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] A ON V.AccountID = A.AccountID
    LEFT JOIN [Accounting].[ChartOfAccounts] PM ON TRY_CAST(V.PaymentMethod AS INT) = PM.AccountID
    LEFT JOIN [Security].[Users] U ON V.UserID = U.UserID
    WHERE V.VoucherType = @VoucherType
    ORDER BY V.VoucherID DESC;
END
GO

-- 2. جلب سند بالـ ID
IF OBJECT_ID('[Accounting].[sp_Voucher_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Voucher_GetByID];
GO
CREATE PROCEDURE [Accounting].[sp_Voucher_GetByID]
    @VoucherID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT V.VoucherID, V.VoucherNo, V.VoucherType, V.VoucherDate, V.PartnerID,
           P.PartnerName, V.AccountID, A.AccountName,
           V.Amount, V.Description, V.PaymentMethod,
           ISNULL(PM.AccountName, V.PaymentMethod) AS PaymentMethodName,
           V.UserID, U.FullName AS UserName, V.IsPosted
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] A ON V.AccountID = A.AccountID
    LEFT JOIN [Accounting].[ChartOfAccounts] PM ON TRY_CAST(V.PaymentMethod AS INT) = PM.AccountID
    LEFT JOIN [Security].[Users] U ON V.UserID = U.UserID
    WHERE V.VoucherID = @VoucherID;
END
GO

-- 3. بحث في السندات
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
           V.Amount, V.Description, V.PaymentMethod,
           ISNULL(PM.AccountName, V.PaymentMethod) AS PaymentMethodName,
           V.UserID, U.FullName AS UserName, V.IsPosted
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] A ON V.AccountID = A.AccountID
    LEFT JOIN [Accounting].[ChartOfAccounts] PM ON TRY_CAST(V.PaymentMethod AS INT) = PM.AccountID
    LEFT JOIN [Security].[Users] U ON V.UserID = U.UserID
    WHERE V.VoucherType = @VoucherType
      AND (V.Description LIKE '%' + @SearchText + '%' 
           OR P.PartnerName LIKE '%' + @SearchText + '%'
           OR PM.AccountName LIKE '%' + @SearchText + '%'
           OR CAST(V.VoucherID AS NVARCHAR) = @SearchText
           OR CAST(V.VoucherNo AS NVARCHAR) = @SearchText)
    ORDER BY V.VoucherID DESC;
END
GO
