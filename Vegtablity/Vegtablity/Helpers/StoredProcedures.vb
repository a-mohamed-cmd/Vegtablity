Namespace Helpers
    ''' <summary>
    ''' Centralized class containing all SQL Stored Procedure names.
    ''' This ensures consistency across the application and makes maintenance easier.
    ''' </summary>
    Public NotInheritable Class StoredProcedures

        Private Sub New()
        End Sub

        ' =============================================
        ' Security Schema - Users
        ' =============================================
        Public Const SP_USER_LOGIN As String = "[Security].[sp_User_Login]"
        Public Const SP_USER_GETALL As String = "[Security].[sp_User_GetAll]"
        Public Const SP_USER_ADD As String = "[Security].[sp_User_Add]"
        Public Const SP_USER_UPDATE As String = "[Security].[sp_User_Update]"
        Public Const SP_USER_DELETE As String = "[Security].[sp_User_Delete]"
        Public Const SP_USER_RESETPASSWORD As String = "[Security].[sp_User_ResetPassword]"

        ' =============================================
        ' Security Schema - Roles
        ' =============================================
        Public Const SP_ROLE_GETALL As String = "[Security].[sp_Role_GetAll]"
        Public Const SP_ROLE_ADD As String = "[Security].[sp_Role_Add]"
        Public Const SP_ROLE_UPDATE As String = "[Security].[sp_Role_Update]"
        Public Const SP_ROLE_DELETE As String = "[Security].[sp_Role_Delete]"

        ' =============================================
        ' Security Schema - Permissions
        ' =============================================
        Public Const SP_PERMISSION_GETBYROLE As String = "[Security].[sp_Permission_GetByRole]"
        Public Const SP_PERMISSION_SAVE As String = "[Security].[sp_Permission_Save]"
        Public Const SP_PERMISSION_CANVIEW As String = "[Security].[sp_Permission_CanView]"
        Public Const SP_PERMISSION_DELETE As String = "[Security].[sp_Permission_Delete]"

        ' =============================================
        ' Security Schema - Licensing
        ' =============================================
        Public Const SP_LICENSE_CHECK As String = "[Security].[sp_License_Check]"

    End Class
End Namespace
