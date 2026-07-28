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
        ' Sales Schema - Shifts
        ' =============================================
        Public Const SP_SHIFT_GETALL As String = "[Sales].[sp_Shift_GetAll]"
        Public Const SP_SHIFT_GETSUMMARY As String = "[Sales].[sp_Shift_GetSummary]"
        Public Const SP_SHIFT_GETVOUCHERS As String = "[Sales].[sp_Shift_GetVouchers]"
        Public Const SP_INVOICE_GETALL_POS As String = "[Sales].[sp_Invoice_GetAll_Pos]"

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
        Public Const SP_PRODUCT_GETPAGED As String = "[Inventory].[sp_Product_GetPaged]"
        Public Const SP_PRODUCTCARD_UPDATEQUICKDETAILS As String = "[Inventory].[sp_ProductCard_UpdateQuickDetails]"
        Public Const SP_PRODUCT_QUICKADD As String = "[Inventory].[sp_Product_QuickAdd]"
        Public Const SP_PRODUCT_GETFORPURCHASE As String = "[Inventory].[sp_Product_GetForPurchase]"
        Public Const SP_PRODUCT_GETFORSALES As String = "[Inventory].[sp_Product_GetForSales]"
        Public Const SP_PRODUCT_GETFORRECIPEINGREDIENTS As String = "[Inventory].[sp_Product_GetForRecipeIngredients]"
        Public Const SP_PRODUCT_GETFORRECIPETARGET As String = "[Inventory].[sp_Product_GetForRecipeTarget]"
        Public Const SP_RECIPE_GETALL As String = "[Inventory].[sp_Recipe_GetAll]"
        Public Const SP_RECIPE_GETBYPRODUCT As String = "[Inventory].[sp_Recipe_GetByProduct]"
        Public Const SP_RECIPE_SAVE_XML As String = "[Inventory].[sp_Recipe_Save_XML]"
        Public Const SP_RECIPE_DELETE As String = "[Inventory].[sp_Recipe_Delete]"
        Public Const SP_UPDATE_MANUFACTURED_COSTS As String = "[Inventory].[sp_Update_Manufactured_Costs]"

        ' =============================================
        ' Sales Schema - Partners
        ' =============================================
        Public Const SP_PARTNER_GETALL As String = "[Sales].[sp_Partner_GetAll]"
        Public Const SP_PARTNER_GETBYID As String = "[Sales].[sp_Partner_GetByID]"
        Public Const SP_PARTNER_SAVE As String = "[Sales].[sp_Partner_Save]"
        Public Const SP_PARTNER_DELETE As String = "[Sales].[sp_Partner_Delete]"
        Public Const SP_PARTNER_SEARCH As String = "[Sales].[sp_Partner_Search]"
        Public Const SP_PARTNER_SEARCH_ALL As String = "[Sales].[sp_Partner_SearchAll]"   ' بحث موحد (عملاء + موردون)

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
        Public Const SP_REPORT_PROFITLOSS As String = "[Accounting].[sp_Report_ProfitLoss]"
        Public Const SP_REPORT_BALANCESHEET As String = "[Accounting].[sp_Report_BalanceSheet]"
        
        Public Const SP_DASHBOARD_GETSUMMARY As String = "[Reports].[sp_Dashboard_GetSummary]"
        Public Const SP_DASHBOARD_GETSALESCHART As String = "[Reports].[sp_Dashboard_GetSalesChart]"
        Public Const SP_DASHBOARD_GETALERTPRODUCTS As String = "[Reports].[sp_Dashboard_GetAlertProducts]"
        Public Const SP_DASHBOARD_GETCUSTOMERDEBTS As String = "[Reports].[sp_Dashboard_GetCustomerDebts]"
        Public Const SP_DASHBOARD_GETSUPPLIERDEBTS As String = "[Reports].[sp_Dashboard_GetSupplierDebts]"
        
        Public Const SP_ACCOUNTING_YEARENDCLOSE As String = "[Accounting].[sp_Accounting_YearEndClose]"

        ' =============================================
        ' Settings Schema - Company Settings
        ' =============================================
        Public Const SP_COMPANY_SETTINGS_GET As String = "Settings.sp_CompanySettings_Get"
        Public Const SP_COMPANY_SETTINGS_SAVE As String = "Settings.sp_CompanySettings_Save"

        ' =============================================
        ' Sales Schema - Invoices
        ' =============================================
        Public Const SP_INVOICE_GETALL As String = "[Sales].[sp_Invoice_GetAll]"
        Public Const SP_INVOICE_GETBYID As String = "[Sales].[sp_Invoice_GetByID]"
        Public Const SP_INVOICE_SAVE As String = "[Sales].[sp_Invoice_Save]"
        Public Const SP_INVOICE_SAVE_XML As String = "[Sales].[sp_Invoice_Save_XML]"
        Public Const SP_INVOICE_DELETE As String = "[Sales].[sp_Invoice_Delete]"
        Public Const SP_INVOICE_GETPAGED As String = "[Sales].[sp_Invoice_GetPaged]"
        Public Const SP_SALES_GETPRODUCTPRICING_INVOICE As String = "[Sales].[sp_GetProductPricingForInvoice]"
        
        Public Const SP_INVOICEDETAIL_GETBYINVID As String = "[Sales].[sp_InvoiceDetails_GetByInvID]"
        Public Const SP_INVOICEDETAIL_SAVE As String = "[Sales].[sp_InvoiceDetail_Save]"
        Public Const SP_INVOICEDETAIL_DELETEBYINVID As String = "[Sales].[sp_InvoiceDetails_DeleteByInvID]"
        Public Const SP_INVOICE_POST As String = "[Sales].[sp_Invoice_Post]"
        Public Const SP_INVOICE_UNPOST As String = "[Sales].[sp_Invoice_Unpost]"

        ' =============================================
        ' Sales Schema - Temp Orders
        ' =============================================
        Public Const SP_TEMPORDER_GETDAILYDELIVERIES As String = "[Sales].[sp_TempOrder_GetDailyDeliveries]"

        ' =============================================
        ' Sales Schema - Quotations
        ' =============================================
        Public Const SP_QUOTATION_GETALL As String = "[Sales].[sp_Quotations_GetAll]"
        Public Const SP_QUOTATION_GETBYPARTNER As String = "[Sales].[sp_Quotations_GetByPartner]"
        Public Const SP_QUOTATION_UPSERT As String = "[Sales].[sp_Quotations_Upsert]"
        Public Const SP_QUOTATION_UPSERT_XML As String = "[Sales].[sp_Quotations_Upsert_XML]"
        Public Const SP_QUOTATION_DELETE As String = "[Sales].[sp_Quotations_Delete]"
        Public Const SP_QUOTATIONDETAILS_GETBYQUOTEID As String = "[Sales].[sp_QuotationDetails_GetByQuoteID]"
        Public Const SP_QUOTATIONDETAILS_INSERT As String = "[Sales].[sp_QuotationDetails_Insert]"
        Public Const SP_QUOTATIONDETAILS_DELETEBYQUOTEID As String = "[Sales].[sp_QuotationDetails_DeleteByQuoteID]"
        Public Const SP_QUOTATION_GETACTIVEPRICE As String = "[Sales].[sp_Quotations_GetActivePrice]"
        Public Const SP_QUOTATION_GETPAGED As String = "[Sales].[sp_Quotations_GetPaged]"

        ' =============================================
        ' Inventory Schema - Stock/Cost
        ' =============================================
        Public Const SP_STOCK_GETBYPRODUCT As String = "[Inventory].[sp_Stock_GetByProduct]"
        Public Const SP_INVENTORY_GETAVGCOSTByPRODUCT As String = "[Inventory].[sp_Inventory_GetAvgCostByProduct]"

        ' =============================================
        ' Sales Schema - Invoice Dashboard
        ' =============================================
        Public Const SP_INVOICE_GET_FILTERED As String = "[Sales].[sp_Invoice_GetFiltered]"
        Public Const SP_INVOICE_GET_DASHBOARD_STATS As String = "[Sales].[sp_Invoice_GetDashboardStats]"
        Public Const SP_INVOICE_ADD_PAYMENT As String = "[Sales].[sp_Invoice_AddPayment]"
        Public Const SP_INVOICEDETAILS_GETBYINVID As String = "[Sales].[sp_InvoiceDetails_GetByInvID]"

        ' =============================================
        ' Inventory Schema - Product Card (بطاقة الصنف)
        ' =============================================
        Public Const SP_PRODUCTCARD_GETSUMMARY As String = "[Inventory].[sp_ProductCard_GetSummary]"
        Public Const SP_PRODUCTCARD_GETMOVEMENTS As String = "[Inventory].[sp_ProductCard_GetMovements]"
        Public Const SP_PRODUCTCARD_GETCHARTDATA As String = "[Inventory].[sp_ProductCard_GetChartData]"
        Public Const SP_PRODUCTCARD_GETSTOCKBYWAREHOUSE As String = "[Inventory].[sp_ProductCard_GetStockByWarehouse]"
        ' =============================================
        ' New Comprehensive Reports System
        ' =============================================
        Public Const SP_REPORT_PRODUCTPROFITS As String = "[Reports].[sp_Report_ProductProfits]"
        Public Const SP_REPORT_INVOICEPROFITS As String = "[Reports].[sp_Report_InvoiceProfits]"
        Public Const SP_REPORT_SALESSUMMARYBYPERIOD As String = "[Reports].[sp_Report_SalesSummaryByPeriod]"
        Public Const SP_REPORT_TOPCUSTOMERS As String = "[Reports].[sp_Report_TopCustomers]"
        Public Const SP_REPORT_UNPAIDINVOICESAGING As String = "[Reports].[sp_Report_UnpaidInvoicesAging]"
        Public Const SP_REPORT_INVENTORYVALUATION As String = "[Reports].[sp_Report_InventoryValuation]"
        Public Const SP_REPORT_SLOWMOVINGSTOCK As String = "[Reports].[sp_Report_SlowMovingStock]"
        Public Const SP_REPORT_STOCKMOVEMENT As String = "[Reports].[sp_Report_StockMovement]"
        Public Const SP_REPORT_EXPENSESANALYSIS As String = "[Reports].[sp_Report_ExpensesAnalysis]"
        Public Const SP_REPORT_QUOTATIONSSTATUS As String = "[Reports].[sp_Report_QuotationsStatus]"
        Public Const SP_REPORT_TOPSUPPLIERS As String = "[Reports].[topSuppliers]"

        ' --- Customer Profitability Reports ---
        Public Const SP_REPORT_CUSTOMERSALESSUMMARY As String = "[Sales].[sp_Report_CustomerSalesSummary]"
        Public Const SP_REPORT_CUSTOMERINVOICESDETAIL As String = "[Sales].[sp_Report_CustomerInvoicesDetail]"
        Public Const SP_REPORT_CUSTOMERPRODUCTSALES As String = "[Sales].[sp_Report_CustomerProductSales]"

        Public Const SP_REPORT_INVOICE_PRINT As String = "[Sales].[sp_Report_InvoicePrint]"

        ' =============================================
        ' Purchases Schema - Purchase Quotations
        ' =============================================
        Public Const SP_PURCHASEQUOTE_SAVE As String = "[Purchases].[sp_PurchaseQuote_Save]"
        Public Const SP_PURCHASEQUOTE_GETALL As String = "[Purchases].[sp_PurchaseQuote_GetAll]"
        Public Const SP_PURCHASEQUOTE_GETBYID As String = "[Purchases].[sp_PurchaseQuote_GetByID]"
        Public Const SP_PURCHASEQUOTE_GETDETAILS As String = "[Purchases].[sp_PurchaseQuote_GetDetails]"
        Public Const SP_PURCHASEQUOTE_GETPAGED As String = "[Purchases].[sp_PurchaseQuote_GetPaged]"
        Public Const SP_PURCHASEQUOTE_GETBYPARTNER As String = "[Purchases].[sp_PurchaseQuote_GetByPartner]"
        Public Const SP_PURCHASEQUOTE_DELETE As String = "[Purchases].[sp_PurchaseQuote_Delete]"
        Public Const SP_PURCHASEQUOTE_GETITEMPRICE As String = "[Purchases].[sp_Purchases_quoteItems_Price]"

        ' =============================================
        ' Inventory Schema - Wastage
        ' =============================================
        Public Const SP_WASTAGE_GETALL As String = "[Inventory].[sp_Wastage_GetAll]"
        Public Const SP_WASTAGE_GETDETAILS As String = "[Inventory].[sp_Wastage_GetDetails]"
        Public Const SP_WASTAGE_SAVE_XML As String = "[Inventory].[sp_Wastage_Save_XML]"
        Public Const SP_WASTAGE_POST As String = "[Inventory].[sp_Wastage_Post]"
        Public Const SP_WASTAGE_UNPOST As String = "[Inventory].[sp_Wastage_Unpost]"
        Public Const SP_WASTAGE_REPORT As String = "[Inventory].[sp_Wastage_Report]"

        ' =============================================
        ' Inventory Schema - StockTake
        ' =============================================
        Public Const SP_STOCKTAKE_GETALL As String = "[Inventory].[sp_StockTake_GetAll]"
        Public Const SP_STOCKTAKE_GETDETAILS As String = "[Inventory].[sp_StockTake_GetDetails]"
        Public Const SP_STOCKTAKE_SAVE_XML As String = "[Inventory].[sp_StockTake_Save_XML]"
        Public Const SP_STOCKTAKE_APPROVE As String = "[Inventory].[sp_StockTake_Approve]"
    End Class
End Namespace
