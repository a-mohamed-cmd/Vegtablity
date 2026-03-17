-- =========================================================================
-- UPDATE: sp_License_Check 
-- DESCRIPTION: Check both IsActive AND ExpiryDate for valid subscriptions
-- =========================================================================

IF OBJECT_ID('[Security].[sp_License_Check]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_License_Check]
GO
CREATE PROCEDURE [Security].[sp_License_Check]
    @MachineHWID NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Returns 1 if there's an active license that has NOT expired.
    -- Assuming ExpiryDate > GETDATE() determines validity.
    -- Note: If ExpiryDate is NULL, we might consider it permanent, 
    -- but usually subscriptions have an ExpiryDate. Let's handle NULL as Permanent for safety.
    
    SELECT CAST(CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS BIT) AS IsLicensed
    FROM [Security].[DeviceLicenses]
    WHERE MachineHWID = @MachineHWID 
      AND IsActive = 1
      AND (ExpiryDate IS NULL OR ExpiryDate >= CAST(GETDATE() AS DATE))
END
GO
