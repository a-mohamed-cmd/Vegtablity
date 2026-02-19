-- =============================================
-- Vegtablity - All Stored Procedures
-- Schema: [Security]
-- Execute this script in SQL Server Management Studio (SSMS)
-- =============================================

USE [VegtablityDB]
GO

-- =============================================
-- 1. sp_User_Login
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Login]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Login]
GO
CREATE PROCEDURE [Security].[sp_User_Login]
    @Username NVARCHAR(100),
    @PasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserID, u.RoleID, r.RoleName, u.Username, u.FullName, u.IsActive, u.CreatedAt
    FROM [Security].[Users] u
    INNER JOIN [Security].[Roles] r ON u.RoleID = r.RoleID
    WHERE u.Username = @Username AND u.PasswordHash = @PasswordHash AND u.IsActive = 1
END
GO

-- =============================================
-- 2. sp_User_GetAll
-- =============================================
IF OBJECT_ID('[Security].[sp_User_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_GetAll]
GO
CREATE PROCEDURE [Security].[sp_User_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserID, u.RoleID, r.RoleName, u.Username, u.FullName, u.IsActive, u.CreatedAt
    FROM [Security].[Users] u
    INNER JOIN [Security].[Roles] r ON u.RoleID = r.RoleID
    ORDER BY u.UserID
END
GO

-- =============================================
-- 3. sp_User_Add
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Add]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Add]
GO
CREATE PROCEDURE [Security].[sp_User_Add]
    @RoleID INT,
    @Username NVARCHAR(100),
    @PasswordHash NVARCHAR(256),
    @FullName NVARCHAR(200),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Security].[Users] (RoleID, Username, PasswordHash, FullName, IsActive)
    VALUES (@RoleID, @Username, @PasswordHash, @FullName, @IsActive);
    SELECT SCOPE_IDENTITY();
END
GO

-- =============================================
-- 4. sp_User_Update
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Update]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Update]
GO
CREATE PROCEDURE [Security].[sp_User_Update]
    @UserID INT,
    @RoleID INT,
    @Username NVARCHAR(100),
    @FullName NVARCHAR(200),
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Security].[Users]
    SET RoleID = @RoleID, Username = @Username, FullName = @FullName, IsActive = @IsActive
    WHERE UserID = @UserID
END
GO

-- =============================================
-- 5. sp_User_Delete
-- =============================================
IF OBJECT_ID('[Security].[sp_User_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_Delete]
GO
CREATE PROCEDURE [Security].[sp_User_Delete]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Security].[Users] WHERE UserID = @UserID
END
GO

-- =============================================
-- 6. sp_User_ResetPassword
-- =============================================
IF OBJECT_ID('[Security].[sp_User_ResetPassword]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_User_ResetPassword]
GO
CREATE PROCEDURE [Security].[sp_User_ResetPassword]
    @UserID INT,
    @NewPasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Security].[Users] SET PasswordHash = @NewPasswordHash WHERE UserID = @UserID
END
GO

-- =============================================
-- 7. sp_Role_GetAll
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_GetAll]
GO
CREATE PROCEDURE [Security].[sp_Role_GetAll]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM [Security].[Roles] ORDER BY RoleName
END
GO

-- =============================================
-- 8. sp_Role_Add
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_Add]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_Add]
GO
CREATE PROCEDURE [Security].[sp_Role_Add]
    @RoleName NVARCHAR(100),
    @Description NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Security].[Roles] (RoleName, Description) VALUES (@RoleName, @Description);
    SELECT SCOPE_IDENTITY();
END
GO

-- =============================================
-- 9. sp_Role_Update
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_Update]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_Update]
GO
CREATE PROCEDURE [Security].[sp_Role_Update]
    @RoleID INT,
    @RoleName NVARCHAR(100),
    @Description NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [Security].[Roles] SET RoleName = @RoleName, Description = @Description WHERE RoleID = @RoleID
END
GO

-- =============================================
-- 10. sp_Role_Delete (Deletes role + its permissions)
-- =============================================
IF OBJECT_ID('[Security].[sp_Role_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Role_Delete]
GO
CREATE PROCEDURE [Security].[sp_Role_Delete]
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION
        DELETE FROM [Security].[RolePermissions] WHERE RoleID = @RoleID;
        DELETE FROM [Security].[Roles] WHERE RoleID = @RoleID;
    COMMIT TRANSACTION
END
GO

-- =============================================
-- 11. sp_Permission_GetByRole
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_GetByRole]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_GetByRole]
GO
CREATE PROCEDURE [Security].[sp_Permission_GetByRole]
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM [Security].[RolePermissions] WHERE RoleID = @RoleID
END
GO

-- =============================================
-- 12. sp_Permission_Save (Insert or Update)
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_Save]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_Save]
GO
CREATE PROCEDURE [Security].[sp_Permission_Save]
    @PermID INT,
    @RoleID INT,
    @FormName NVARCHAR(100),
    @CanAdd BIT,
    @CanEdit BIT,
    @CanDelete BIT,
    @CanView BIT,
    @CanPrint BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF @PermID > 0
    BEGIN
        UPDATE [Security].[RolePermissions]
        SET CanAdd = @CanAdd, CanEdit = @CanEdit, CanDelete = @CanDelete, CanView = @CanView, CanPrint = @CanPrint
        WHERE PermID = @PermID
    END
    ELSE
    BEGIN
        INSERT INTO [Security].[RolePermissions] (RoleID, FormName, CanAdd, CanEdit, CanDelete, CanView, CanPrint)
        VALUES (@RoleID, @FormName, @CanAdd, @CanEdit, @CanDelete, @CanView, @CanPrint)
    END
END
GO

-- =============================================
-- 13. sp_Permission_CanView
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_CanView]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_CanView]
GO
CREATE PROCEDURE [Security].[sp_Permission_CanView]
    @RoleID INT,
    @FormName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CanView FROM [Security].[RolePermissions] WHERE RoleID = @RoleID AND FormName = @FormName
END
GO

-- =============================================
-- 14. sp_Permission_Delete
-- =============================================
IF OBJECT_ID('[Security].[sp_Permission_Delete]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_Permission_Delete]
GO
CREATE PROCEDURE [Security].[sp_Permission_Delete]
    @PermID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Security].[RolePermissions] WHERE PermID = @PermID
END
GO

-- =============================================
-- 15. sp_License_Check
-- =============================================
IF OBJECT_ID('[Security].[sp_License_Check]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_License_Check]
GO
CREATE PROCEDURE [Security].[sp_License_Check]
    @MachineHWID NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS BIT) AS IsLicensed
    FROM [Security].[DeviceLicenses]
    WHERE MachineHWID = @MachineHWID AND IsActive = 1
END
GO

PRINT '✅ All 15 Stored Procedures created successfully!'
GO
