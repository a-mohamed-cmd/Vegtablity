-- ============================================================
-- Migration: 41_sp_Voucher_GetPaged.sql
-- Description: تقسيم السندات إلى صفحات ودعم البحث المتقدم (Pagination & Search)
-- Fully backward-compatible with all existing versions
-- ============================================================

IF OBJECT_ID('[Accounting].[sp_Voucher_GetPaged]', 'P') IS NOT NULL 
    DROP PROCEDURE [Accounting].[sp_Voucher_GetPaged];
GO

CREATE PROCEDURE [Accounting].[sp_Voucher_GetPaged]
    @VoucherType NVARCHAR(20),
    @PageIndex   INT = 1,
    @PageSize    INT = 15,
    @SearchText  NVARCHAR(150) = NULL,
    @TotalCount  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchText = NULLIF(LTRIM(RTRIM(@SearchText)), '');

    -- 1. حساب إجمالي عدد السندات المطابقة
    SELECT @TotalCount = COUNT(1)
    FROM [Accounting].[Vouchers] V
    LEFT JOIN [Sales].[Partners] P ON V.PartnerID = P.PartnerID
    LEFT JOIN [Accounting].[ChartOfAccounts] PM ON TRY_CAST(V.PaymentMethod AS INT) = PM.AccountID
    WHERE V.VoucherType = @VoucherType
      AND (@SearchText IS NULL 
           OR V.Description LIKE '%' + @SearchText + '%' 
           OR P.PartnerName LIKE '%' + @SearchText + '%'
           OR PM.AccountName LIKE '%' + @SearchText + '%'
           OR CAST(V.VoucherID AS NVARCHAR) = @SearchText
           OR CAST(V.VoucherNo AS NVARCHAR) = @SearchText);

    -- 2. جلب صفحة السندات المطلوبة مع الترقيم
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
      AND (@SearchText IS NULL 
           OR V.Description LIKE '%' + @SearchText + '%' 
           OR P.PartnerName LIKE '%' + @SearchText + '%'
           OR PM.AccountName LIKE '%' + @SearchText + '%'
           OR CAST(V.VoucherID AS NVARCHAR) = @SearchText
           OR CAST(V.VoucherNo AS NVARCHAR) = @SearchText)
    ORDER BY V.VoucherID DESC
    OFFSET (@PageIndex - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);
END
GO

PRINT N'=== [Accounting].[sp_Voucher_GetPaged] created successfully ===';
