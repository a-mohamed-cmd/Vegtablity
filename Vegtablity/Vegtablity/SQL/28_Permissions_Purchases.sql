-- =========================================================================
-- إعطاء صلاحيات كاملة لمدير النظام (RoleID = 1) على شاشات المشتريات الجديدة
-- =========================================================================
USE [VegtablityDB]
GO

IF EXISTS (SELECT 1 FROM [Security].[Roles] WHERE RoleID = 1)
BEGIN
    -- 1. إضافة أو تحديث صلاحيات فاتورة مشتريات (Purchases)
    IF NOT EXISTS (SELECT 1 FROM [Security].[RolePermissions] WHERE RoleID = 1 AND FormName = 'Purchases')
    BEGIN
        INSERT INTO [Security].[RolePermissions] (RoleID, FormName, CanView, CanAdd, CanEdit, CanDelete, CanPrint)
        VALUES (1, 'Purchases', 1, 1, 1, 1, 1);
        PRINT '✅ تم إضافة صلاحية "فاتورة مشتريات" (Purchases) لمدير النظام.';
    END
    ELSE
    BEGIN
        UPDATE [Security].[RolePermissions] 
        SET CanView = 1, CanAdd = 1, CanEdit = 1, CanDelete = 1, CanPrint = 1
        WHERE RoleID = 1 AND FormName = 'Purchases';
        PRINT '🔄 تم تحديث صلاحية "فاتورة مشتريات" (Purchases) لمدير النظام.';
    END

    -- 2. إضافة أو تحديث صلاحيات عروض المشتريات (PurchaseQuotes)
    IF NOT EXISTS (SELECT 1 FROM [Security].[RolePermissions] WHERE RoleID = 1 AND FormName = 'PurchaseQuotes')
    BEGIN
        INSERT INTO [Security].[RolePermissions] (RoleID, FormName, CanView, CanAdd, CanEdit, CanDelete, CanPrint)
        VALUES (1, 'PurchaseQuotes', 1, 1, 1, 1, 1);
        PRINT '✅ تم إضافة صلاحية "عروض المشتريات" (PurchaseQuotes) لمدير النظام.';
    END
    ELSE
    BEGIN
        UPDATE [Security].[RolePermissions] 
        SET CanView = 1, CanAdd = 1, CanEdit = 1, CanDelete = 1, CanPrint = 1
        WHERE RoleID = 1 AND FormName = 'PurchaseQuotes';
        PRINT '🔄 تم تحديث صلاحية "عروض المشتريات" (PurchaseQuotes) لمدير النظام.';
    END
END
GO
