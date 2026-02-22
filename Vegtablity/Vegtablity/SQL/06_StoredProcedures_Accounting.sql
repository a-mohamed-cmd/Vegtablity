-- =============================================
-- Chart of Accounts (شجرة الحسابات) - Stored Procedures
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 1. جلب جميع الحسابات
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_GetAll];
GO
CREATE PROCEDURE [Accounting].[sp_Account_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID, 
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
    ORDER BY A.AccountCode;
END
GO

-- =============================================
-- 2. جلب حساب بالـ ID
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_GetByID]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_GetByID];
GO
CREATE PROCEDURE [Accounting].[sp_Account_GetByID]
    @AccountID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID,
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
    WHERE A.AccountID = @AccountID;
END
GO

-- =============================================
-- 3. حفظ حساب (إضافة)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Save]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Save];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Save]
    @AccountID INT = 0,
    @AccountCode NVARCHAR(20),
    @AccountName NVARCHAR(150),
    @ParentAccountID INT = NULL,
    @AccountType NVARCHAR(50),
    @AccountLevel INT = 1,
    @IsTransactional BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- التحقق: إذا كان الحساب مراد جعله "فرعي/يقبل قيود" ولكن له أبناء بالفعل في الشجرة
    IF @AccountID <> 0 AND @IsTransactional = 1
    BEGIN
        IF EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @AccountID)
        BEGIN
            RAISERROR(N'لا يمكن جعل الحساب "فرعي" لأنه أب لحسابات أخرى في الشجرة.', 16, 1);
            RETURN;
        END
    END

    IF @AccountID = 0
    BEGIN
        INSERT INTO [Accounting].[ChartOfAccounts] (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional)
        VALUES (@AccountCode, @AccountName, @ParentAccountID, @AccountType, @AccountLevel, @IsTransactional);
        SELECT SCOPE_IDENTITY() AS AccountID;
    END
    ELSE
    BEGIN
        UPDATE [Accounting].[ChartOfAccounts] 
        SET AccountCode = @AccountCode, AccountName = @AccountName, ParentAccountID = @ParentAccountID,
            AccountType = @AccountType, AccountLevel = @AccountLevel, IsTransactional = @IsTransactional
        WHERE AccountID = @AccountID;
        SELECT @AccountID AS AccountID;
    END
END
GO

-- =============================================
-- 4. تعديل بيانات حساب (Explicit Update)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Update]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Update];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Update]
    @AccountID INT,
    @AccountCode NVARCHAR(20),
    @AccountName NVARCHAR(150),
    @ParentAccountID INT = NULL,
    @AccountType NVARCHAR(50),
    @AccountLevel INT = 1,
    @IsTransactional BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- التحقق من وجود الحساب
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @AccountID)
    BEGIN
        RAISERROR(N'الحساب غير موجود.', 16, 1);
        RETURN;
    END

    -- التحقق: إذا كان الحساب له أبناء، لا يمكن جعله "فرعي"
    IF @IsTransactional = 1 AND EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @AccountID)
    BEGIN
        RAISERROR(N'لا يمكن جعل الحساب "فرعي" لأنه أب لحسابات أخرى.', 16, 1);
        RETURN;
    END

    UPDATE [Accounting].[ChartOfAccounts] 
    SET AccountCode = @AccountCode, 
        AccountName = @AccountName, 
        ParentAccountID = @ParentAccountID,
        AccountType = @AccountType, 
        AccountLevel = @AccountLevel, 
        IsTransactional = @IsTransactional
    WHERE AccountID = @AccountID;

    SELECT @AccountID AS AccountID;
END
GO

-- =============================================
-- 4. حذف حساب (فقط إذا لم يُستخدم في قيود)
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Delete];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Delete]
    @AccountID INT
AS
BEGIN
    SET NOCOUNT ON;
    -- منع الحذف إذا تم استخدام الحساب في قيود
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalDetails] WHERE AccountID = @AccountID)
    BEGIN
        RAISERROR(N'لا يمكن حذف حساب مستخدم في قيود محاسبية', 16, 1);
        RETURN;
    END
    -- منع الحذف إذا له حسابات فرعية
    IF EXISTS (SELECT 1 FROM [Accounting].[ChartOfAccounts] WHERE ParentAccountID = @AccountID)
    BEGIN
        RAISERROR(N'لا يمكن حذف حساب له حسابات فرعية', 16, 1);
        RETURN;
    END
    DELETE FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @AccountID;
END
GO

-- =============================================
-- 5. بحث بالكود أو الاسم
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_Search]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_Search];
GO
CREATE PROCEDURE [Accounting].[sp_Account_Search]
    @SearchText NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT A.AccountID, A.AccountCode, A.AccountName, A.ParentAccountID,
           P.AccountName AS ParentAccountName,
           A.AccountType, A.AccountLevel, A.IsTransactional
    FROM [Accounting].[ChartOfAccounts] A
    LEFT JOIN [Accounting].[ChartOfAccounts] P ON A.ParentAccountID = P.AccountID
    WHERE A.AccountCode LIKE '%' + @SearchText + '%' OR A.AccountName LIKE '%' + @SearchText + '%'
    ORDER BY A.AccountCode;
END
GO

-- =============================================
-- 6. جلب الحسابات الأب فقط (غير الفرعية) للـ ComboBox
-- =============================================
IF OBJECT_ID('[Accounting].[sp_Account_GetParents]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_Account_GetParents];
GO
CREATE PROCEDURE [Accounting].[sp_Account_GetParents]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AccountID, AccountCode, AccountName, AccountType, AccountLevel
    FROM [Accounting].[ChartOfAccounts]
    ORDER BY AccountCode;
END
GO
