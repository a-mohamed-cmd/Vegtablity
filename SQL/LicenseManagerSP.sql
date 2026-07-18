-- =========================================================================
-- 1. تهيئة وجلب قواعد البيانات (تُنفذ في قاعدة master)
-- =========================================================================
USE [master];
GO

IF OBJECT_ID('dbo.sp_GetDatabases_Ctrl', 'P') IS NOT NULL 
    DROP PROCEDURE dbo.sp_GetDatabases_Ctrl;
GO

CREATE PROCEDURE dbo.sp_GetDatabases_Ctrl 
AS
BEGIN
    SET NOCOUNT ON;
    SELECT name AS DatabaseName FROM sys.databases
    WHERE name NOT IN ('master','tempdb','model','msdb') 
      AND state_desc='ONLINE'
    ORDER BY name;
END;
GO

-- =========================================================================
-- 2. تهيئة دوال التراخيص (تُنفذ في قاعدة البيانات المستهدفة WashaDB)
-- =========================================================================
