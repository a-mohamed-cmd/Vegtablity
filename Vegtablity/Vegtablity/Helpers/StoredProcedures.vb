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

        ' =============================================
        ' Settings Schema - Units
        ' =============================================
        Public Const SP_UNIT_GETALL As String = "[Settings].[sp_Unit_GetAll]"
        Public Const SP_UNIT_SAVE As String = "[Settings].[sp_Unit_Save]"
        Public Const SP_UNIT_DELETE As String = "[Settings].[sp_Unit_Delete]"

        ' =============================================
        ' Settings Schema - Categories
        ' =============================================
        Public Const SP_CATEGORY_GETALL As String = "[Settings].[sp_Category_GetAll]"
        Public Const SP_CATEGORY_SAVE As String = "[Settings].[sp_Category_Save]"
        Public Const SP_CATEGORY_DELETE As String = "[Settings].[sp_Category_Delete]"

        ' =============================================
        ' Settings Schema - Warehouses
        ' =============================================
        Public Const SP_WAREHOUSE_GETALL As String = "[Settings].[sp_Warehouse_GetAll]"
        Public Const SP_WAREHOUSE_SAVE As String = "[Settings].[sp_Warehouse_Save]"
        Public Const SP_WAREHOUSE_DELETE As String = "[Settings].[sp_Warehouse_Delete]"

        ' =============================================
        ' Inventory Schema - Products
        ' =============================================
        Public Const SP_PRODUCT_GETALL As String = "[Inventory].[sp_Product_GetAll]"
        Public Const SP_PRODUCT_GETBYID As String = "[Inventory].[sp_Product_GetByID]"
        Public Const SP_PRODUCT_SAVE As String = "[Inventory].[sp_Product_Save]"
        Public Const SP_PRODUCT_DELETE As String = "[Inventory].[sp_Product_Delete]"
        Public Const SP_PRODUCT_GETBYBARCODE As String = "[Inventory].[sp_Product_GetByBarcode]"
        Public Const SP_PRODUCT_SEARCH As String = "[Inventory].[sp_Product_Search]"

        ' =============================================
        ' Sales Schema - Partners
        ' =============================================
        Public Const SP_PARTNER_GETALL As String = "[Sales].[sp_Partner_GetAll]"
        Public Const SP_PARTNER_GETBYID As String = "[Sales].[sp_Partner_GetByID]"
        Public Const SP_PARTNER_SAVE As String = "[Sales].[sp_Partner_Save]"
        Public Const SP_PARTNER_DELETE As String = "[Sales].[sp_Partner_Delete]"
        Public Const SP_PARTNER_SEARCH As String = "[Sales].[sp_Partner_Search]"

        ' =============================================
        ' Accounting Schema - Chart of Accounts
        ' =============================================
        Public Const SP_ACCOUNT_GETALL As String = "[Accounting].[sp_Account_GetAll]"
        Public Const SP_ACCOUNT_GETBYID As String = "[Accounting].[sp_Account_GetByID]"
        Public Const SP_ACCOUNT_SAVE As String = "[Accounting].[sp_Account_Save]"
        Public Const SP_ACCOUNT_UPDATE As String = "[Accounting].[sp_Account_Update]"
        Public Const SP_ACCOUNT_DELETE As String = "[Accounting].[sp_Account_Delete]"
        Public Const SP_ACCOUNT_SEARCH As String = "[Accounting].[sp_Account_Search]"
        Public Const SP_ACCOUNT_GETPARENTS As String = "[Accounting].[sp_Account_GetParents]"

        ' =============================================
        ' Accounting Schema - Vouchers
        ' =============================================
        Public Const SP_VOUCHER_GETALL As String = "[Accounting].[sp_Voucher_GetAll]"
        Public Const SP_VOUCHER_GETBYID As String = "[Accounting].[sp_Voucher_GetByID]"
        Public Const SP_VOUCHER_SAVE As String = "[Accounting].[sp_Voucher_Save]"
        Public Const SP_VOUCHER_DELETE As String = "[Accounting].[sp_Voucher_Delete]"
        Public Const SP_VOUCHER_SEARCH As String = "[Accounting].[sp_Voucher_Search]"
        Public Const SP_VOUCHER_POST As String = "[Accounting].[sp_Voucher_Post]"

        ' =============================================
        ' Accounting Schema - Journal Entries
        ' =============================================
        Public Const SP_JOURNALENTRY_GETALL As String = "[Accounting].[sp_JournalEntry_GetAll]"
        Public Const SP_JOURNALENTRY_GETDETAILS As String = "[Accounting].[sp_JournalEntry_GetDetails]"
        Public Const SP_JOURNALENTRY_SAVE As String = "[Accounting].[sp_JournalEntry_Save]"
        Public Const SP_JOURNALENTRY_POST As String = "[Accounting].[sp_JournalEntry_Post]"

        ' =============================================
        ' Reports Schema
        ' =============================================
        Public Const SP_REPORT_ACCOUNTSTATEMENT As String = "[Accounting].[sp_Report_AccountStatement]"
        Public Const SP_REPORT_TRIALBALANCE As String = "[Accounting].[sp_Report_TrialBalance]"

        ' =============================================
        ' Settings Schema - Company Settings
        ' =============================================
        Public Const SP_COMPANY_SETTINGS_GET As String = "Settings.sp_CompanySettings_Get"
        Public Const SP_COMPANY_SETTINGS_SAVE As String = "Settings.sp_CompanySettings_Save"
    End Class
End Namespace
