-- =========================================================================
-- 30. sp_Permission_AutoAssignAdmin (إسناد كامل الصلاحيات للمسؤول تلقائياً)
-- =========================================================================
IF OBJECT_ID('[Security].[sp_Permission_AutoAssignAdmin]', 'P') IS NOT NULL 
    DROP PROCEDURE [Security].[sp_Permission_AutoAssignAdmin]
GO

CREATE PROCEDURE [Security].[sp_Permission_AutoAssignAdmin]
    @UserID INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. جلب رقم الدور (RoleID) الخاص بالمستخدم المحدد
    DECLARE @RoleID INT;
    SELECT @RoleID = RoleID FROM [Security].[Users] WHERE UserID = @UserID;

    IF @RoleID IS NULL
    BEGIN
        RAISERROR(N'المستخدم غير موجود بقاعدة البيانات أو ليس لديه دور محدد.', 16, 1);
        RETURN;
    END

    -- 2. تعريف القائمة الكاملة لكافة صلاحيات شاشات النظام (27 صلاحية معتمدة)
    DECLARE @Permissions TABLE (FormName NVARCHAR(100));
    INSERT INTO @Permissions (FormName) VALUES 
    (N'Dashboard'),
    (N'Sales'),
    (N'Purchases'),
    (N'Inventory'),
    (N'InvoiceDashboard'),
    (N'Accounting'),
    (N'ChartOfAccounts'),
    (N'ReceiptVoucher'),
    (N'PaymentVoucher'),
    (N'JournalEntries'),
    (N'AccountStatement'),
    (N'TrialBalance'),
    (N'BalanceSheet'),
    (N'ProfitLoss'),
    (N'YearEndClose'),
    (N'Partners'),
    (N'Quotes'),
    (N'PurchaseQuotes'),
    (N'Shifts'),
    (N'Reports'),
    (N'SettingsParent'),
    (N'Settings'),
    (N'CompanySettings'),
    (N'UserManagement'),
    (N'Wastage'),
    (N'StockTaking'),
    (N'DailyOrders'),
    (N'SalesDiscounts');

    -- 3. دمج وإدخال الصلاحيات غير الموجودة، وتحديث الحالية لمنح الصلاحيات الكاملة (العرض، الإضافة، التعديل، الحذف، والطباعة)
    MERGE [Security].[RolePermissions] AS target
    USING @Permissions AS source
    ON (target.RoleID = @RoleID AND target.FormName = source.FormName)
    WHEN MATCHED THEN
        UPDATE SET 
            CanView = 1,
            CanAdd = 1,
            CanEdit = 1,
            CanDelete = 1,
            CanPrint = 1
    WHEN NOT MATCHED THEN
        INSERT (RoleID, FormName, CanView, CanAdd, CanEdit, CanDelete, CanPrint)
        VALUES (@RoleID, source.FormName, 1, 1, 1, 1, 1);

    PRINT N'تم إسناد كافة صلاحيات النظام بالكامل للدور (RoleID: ' + CAST(@RoleID AS VARCHAR(10)) + N') المرتبط بالمستخدم (UserID: ' + CAST(@UserID AS VARCHAR(10)) + N') بنجاح.';
END
GO
