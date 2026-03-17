-- =============================================
-- UPDATE: Add "Reports" to Security.Permissions
-- =============================================

-- First, check if the permission already exists to avoid duplicates
IF NOT EXISTS (SELECT 1 FROM [Security].[Permissions] WHERE [PermName] = 'Reports')
BEGIN
    INSERT INTO [Security].[Permissions] ([PermName], [ArName], [Description])
    VALUES ('Reports', N'التقارير الشاملة', N'صلاحية الدخول إلى واجهة التقارير الشاملة واستخراج البيانات وتصديرها');
    
    PRINT '✅ تم إضافة صلاحية "التقارير الشاملة" بنجاح.'
END
ELSE
BEGIN
    PRINT 'ℹ️ صلاحية "التقارير الشاملة" موجودة مسبقاً.'
END
GO
