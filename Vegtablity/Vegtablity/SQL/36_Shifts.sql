-- =============================================
-- Shifts Module (POS)
-- =============================================
USE [VegtablityDB];
GO

IF OBJECT_ID('Sales.Shifts', 'U') IS NULL
BEGIN
    CREATE TABLE [Sales].[Shifts] (
        [ShiftID] INT IDENTITY(1,1) PRIMARY KEY,
        [UserID] INT NOT NULL,
        [StartTime] DATETIME NOT NULL DEFAULT GETDATE(),
        [EndTime] DATETIME NULL,
        [StartingCash] DECIMAL(18, 2) NOT NULL DEFAULT 0,
        [EndingCash] DECIMAL(18, 2) NULL,
        [Status] NVARCHAR(20) NOT NULL DEFAULT 'Open', -- 'Open', 'Closed'
        FOREIGN KEY ([UserID]) REFERENCES [Security].[Users]([UserID])
    );
END
GO

-- 1. Open Shift
IF OBJECT_ID('[Sales].[sp_Shift_Open]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_Open];
GO
CREATE PROCEDURE [Sales].[sp_Shift_Open]
    @UserID INT,
    @StartingCash DECIMAL(18, 2),
    @ShiftID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if user already has an open shift
    IF EXISTS (SELECT 1 FROM [Sales].[Shifts] WHERE UserID = @UserID AND Status = 'Open')
    BEGIN
        RAISERROR('المستخدم لديه وردية مفتوحة بالفعل.', 16, 1);
        RETURN;
    END

    INSERT INTO [Sales].[Shifts] (UserID, StartingCash, Status)
    VALUES (@UserID, @StartingCash, 'Open');
    
    SET @ShiftID = SCOPE_IDENTITY();
END
GO

-- 2. Close Shift
IF OBJECT_ID('[Sales].[sp_Shift_Close]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_Close];
GO
CREATE PROCEDURE [Sales].[sp_Shift_Close]
    @ShiftID INT,
    @EndingCash DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [Sales].[Shifts]
    SET EndTime = GETDATE(),
        EndingCash = @EndingCash,
        Status = 'Closed'
    WHERE ShiftID = @ShiftID AND Status = 'Open';
END
GO

-- 3. Get Active Shift for User
IF OBJECT_ID('[Sales].[sp_Shift_GetActive]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Shift_GetActive];
GO
CREATE PROCEDURE [Sales].[sp_Shift_GetActive]
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP 1 ShiftID, UserID, StartTime, StartingCash, Status
    FROM [Sales].[Shifts]
    WHERE UserID = @UserID AND Status = 'Open'
    ORDER BY ShiftID DESC, StartTime DESC;
END
GO
