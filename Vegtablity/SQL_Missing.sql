
-- Missing Object: Security.sp_CheckDeviceLicense
IF OBJECT_ID('[Security].[sp_CheckDeviceLicense]', 'P') IS NOT NULL DROP PROCEDURE [Security].[sp_CheckDeviceLicense];
GO

CREATE PROCEDURE [Security].[sp_CheckDeviceLicense] 
@MachineHWID NVARCHAR(255) 
AS 
BEGIN 
-- يرجع 1 إذا كان الجهاز مرخصاً ونشطاً 
IF EXISTS (SELECT 1 FROM [Security].[DeviceLicenses] 
WHERE MachineHWID = @MachineHWID AND IsActive = 1) 
BEGIN 
SELECT 1 AS IsLicensed, ExpiryDate FROM [Security].[DeviceLicenses] 
WHERE MachineHWID = @MachineHWID; 
END
 ELSE
  BEGIN 
  SELECT 0 AS IsLicensed, NULL AS ExpiryDate; 
  END
   END 

GO

