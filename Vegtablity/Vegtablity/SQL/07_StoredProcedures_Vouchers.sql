-- =============================================
-- Vouchers (سندات القبض والصرف) - Stored Procedures
-- =============================================
USE VegtablityDB;
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
    @Amount DECIMAL(18,3),
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

