class ControlStoredProcedures:
    """
    Centralized Stored Procedures used specifically for the isolated LicenseManager control endpoints.
    """
    
    # Get all database names on the SQL server instance
    CTRL_GET_DATABASES = "EXEC [master].dbo.sp_GetDatabases_Ctrl"
    
    # Get all licensed devices from a selected database (executed on dynamic database connection)
    CTRL_LICENSE_GETALL = "EXEC [Security].[sp_License_GetAll_Ctrl]"
    
    # Save (create or update) a device license
    CTRL_LICENSE_SAVE = "EXEC [Security].[sp_License_Save_Ctrl] @LicenseID=?, @MachineName=?, @MachineHWID=?, @LicenseKey=?, @IsActive=?, @ExpiryDate=?"
    
    # Delete a device license
    CTRL_LICENSE_DELETE = "EXEC [Security].[sp_License_Delete_Ctrl] @LicenseID=?"
