class StoredProcedures:
    """
    A centralized class containing all Stored Procedures used across the application.
    This helps in maintaining consistency, avoiding typos, and documenting database operations.
    """

    # =========================================================================
    # Security & Authentication
    # =========================================================================
    
    # Used to authenticate a user by username and password
    USER_LOGIN = "{CALL [Security].[sp_User_Login] (?, ?)}"
    
    # Used to verify if a POS machine hardware ID is licensed and active
    DEVICE_LICENSE_CHECK = "SELECT IsActive, ExpiryDate FROM [Security].[DeviceLicenses] WHERE MachineHWID = ?"

    # =========================================================================
    # Shifts Management
    # =========================================================================
    
    # Opens a new shift for the current user and records the starting cash
    SHIFT_OPEN = """
    DECLARE @ShiftID INT;
    EXEC [Sales].[sp_Shift_Open] @UserID=?, @StartingCash=?, @ShiftID=@ShiftID OUTPUT;
    SELECT @ShiftID AS ShiftID;
    """
    
    # Retrieves the currently active shift for the user, if any
    SHIFT_GET_ACTIVE = "EXEC [Sales].[sp_Shift_GetActive] @UserID=?"
    
    # Closes an active shift and records the ending cash
    SHIFT_CLOSE = "EXEC [Sales].[sp_Shift_Close] @ShiftID=?, @EndingCash=?"
    
    # Retrieves a complete summary of the shift (sales, purchases, cash flows)
    SHIFT_GET_SUMMARY = "EXEC [Sales].[sp_Shift_GetSummary] @ShiftID=?"
    
    # Retrieves all vouchers linked to a specific shift
    SHIFT_GET_VOUCHERS = "EXEC [Sales].[sp_Shift_GetVouchers] @ShiftID=?"

    # =========================================================================
    # Products & Inventory
    # =========================================================================
    
    # Accounting
    ACCOUNT_REVENUE = "EXEC [Accounting].[sp_Account_Revenue]"
    ACCOUNT_EXPENSES = "EXEC [Accounting].[sp_Account_Expenses]"
    VOUCHER_GET_ACCOUNTS = "EXEC [Accounting].[sp_GetPaymentAccounts]"
    SP_GET_PARTNER_GENERAL = "EXEC [Sales].[sp_GetCode_PartnerGeneral]"  # جلب بيانات العميل الثابت 'سند مباشر'
    VOUCHER_SAVE = """
        EXEC [Accounting].[sp_Voucher_Save]
            @VoucherID=?, @VoucherType=?, @VoucherDate=?, @PartnerID=?, 
            @AccountID=?, @Amount=?, @Description=?, @PaymentMethod=?, @UserID=?
    """
    
    VOUCHER_GENERAL_SAVE = """
        EXEC [Accounting].[sp_VoucherGeneral_Save]
            @VoucherType=?, @VoucherDate=?, @AccountID=?, @Amount=?, 
            @Description=?, @PaymentMethod=?, @UserID=?, @ShiftID=?
    """
    
    # Searches for products based on a text query
    PRODUCT_SEARCH = "{CALL [Inventory].[sp_Product_Search] (?)}"
    
    # Retrieves all available products
    PRODUCT_GET_ALL = "{CALL [Inventory].[sp_Product_GetAll]}"
    
    # Retrieves a specific product using its barcode
    PRODUCT_GET_BY_BARCODE = "{CALL [Inventory].[sp_Product_GetByBarcode] (?)}"

    # Retrieves product stock for a specific warehouse
    PRODUCT_STOCK_GET = "EXEC [Inventory].[sp_Stock_GetByProduct] @ProductID=?, @WarehouseID=?"
    
    # Retrieves average cost of a product for a specific warehouse
    PRODUCT_AVGCOST_GET = "EXEC [Inventory].[sp_Inventory_GetAvgCostByProduct] @ProductID=?, @WarehouseID=?"

    # Product filtering procedures
    PRODUCT_GET_FOR_PURCHASE = "EXEC [Inventory].[sp_Product_GetForPurchase]"
    PRODUCT_GET_FOR_SALES = "EXEC [Inventory].[sp_Product_GetForSales]"
    PRODUCT_GET_FOR_RECIPE_INGREDIENTS = "EXEC [Inventory].[sp_Product_GetForRecipeIngredients] @WarehouseID=?"
    PRODUCT_GET_FOR_RECIPE_TARGET = "EXEC [Inventory].[sp_Product_GetForRecipeTarget] @WarehouseID=?, @IncludeAll=?"

    # Recipe procedures
    RECIPE_GET_ALL = "EXEC [Inventory].[sp_Recipe_GetAll]"
    RECIPE_GET_BY_PRODUCT = "EXEC [Inventory].[sp_Recipe_GetByProduct] @ProductID=?, @WarehouseID=?"
    RECIPE_SAVE_XML = "EXEC [Inventory].[sp_Recipe_Save_XML] @ProductID=?, @Notes=?, @DetailsXML=?, @WarehouseID=?"
    RECIPE_DELETE = "EXEC [Inventory].[sp_Recipe_Delete] @RecipeID=?"


    # =========================================================================
    # Partners (Customers & Vendors)
    # =========================================================================
    
    # Searches for partners (Customers/Vendors) by name or phone
    PARTNER_SEARCH = "{CALL [Sales].[sp_Partner_Search] (?, ?)}"
    
    # Retrieves all partners of a specific type
    PARTNER_GET_ALL = "{CALL [Sales].[sp_Partner_GetAll] (?)}"
    
    # Retrieves vendors that have active purchase quotes
    PURCHASE_ACTIVE_PARTNERS = "EXEC [Purchases].[sp_PurchaseQuote_GetActivePartners]"
    
    # Retrieves customers that have active sales quotes
    SALES_ACTIVE_PARTNERS = "EXEC [Sales].[sp_SalesQuote_GetActivePartners]"

    # =========================================================================
    # Quotes (Sales & Purchases)
    # =========================================================================
    
    # Retrieves paginated sales quotations
    SALES_QUOTES_GET_PAGED = "EXEC [Sales].[sp_Quotations_GetPaged] @PageNumber=?, @PageSize=?, @SearchText=?"
    
    # Retrieves details/items for a specific sales quotation
    SALES_QUOTE_DETAILS = "EXEC [Sales].[sp_QuotationDetails_GetByQuoteID] @QuoteID=?, @PageNumber=?, @PageSize=?"
    
    # Retrieves purchase quotations based on a search text
    PURCHASE_QUOTES_GET_ALL = "{CALL [Purchases].[sp_PurchaseQuote_GetAll] (?)}"
    
    # Retrieves details/items for a specific purchase quotation
    PURCHASE_QUOTE_DETAILS = "EXEC [Purchases].[sp_PurchaseQuote_GetDetails] @PurchaseQuoteID=?"

    # =========================================================================
    # Invoices (Sales & Purchases)
    # =========================================================================
    
    # Retrieves all invoices for a specific type (Sales/Purchase) and optionally filters by shift
    INVOICE_GET_ALL_POS = "EXEC [Sales].[sp_Invoice_GetAll_Pos] @InvType=?, @ShiftID=?"
    
    # Adds a payment allocation to a specific invoice
    INVOICE_ADD_PAYMENT = "EXEC [Sales].[sp_Invoice_AddPayment_pos] @InvID=?, @PaymentAmount=?, @PaymentAccountID=?, @UserID=?"
    
    # Retrieves the header details of a specific invoice
    INVOICE_GET_BY_ID = "{CALL [Sales].[sp_Invoice_GetByID] (?)}"
    
    # Retrieves the line items for a specific invoice
    INVOICE_DETAILS_GET = "{CALL [Sales].[sp_InvoiceDetails_GetByInvID] (?)}"
    
    # Retrieves daily delivery orders by date
    TEMPORDER_GETDAILYDELIVERIES = "EXEC [Sales].[sp_TempOrder_GetDailyDeliveries] @DeliveryDate=?"
    
    # Saves a new invoice and its line items using XML format
    INVOICE_SAVE_XML = """
        DECLARE @InvID INT = 0;
        EXEC [Sales].[sp_Invoice_Save_XML] 
            @InvID = @InvID OUTPUT,
            @InvType = ?,
            @InvDate = ?,
            @PartnerID = ?,
            @WarehouseID = ?,
            @TotalAmount = ?,
            @Discount = ?,
            @NetAmount = ?,
            @PaidAmount = ?,
            @Remainder = ?,
            @UserID = ?,
            @Notes = ?,
            @IsPosted = ?,
            @ReferenceNo = ?,
            @PaymentAccountID = ?,
            @ShiftID = ?,
            @DetailsXml = ?,
            @TempCustomerName = ?,
            @TempPhone = ?,
            @TempAddress = ?,
            @TempDeliveryDate = ?,
            @TempDeliveryTime = ?;
        SELECT @InvID as InvID;
    """

    # =========================================================================
    # Vouchers & Accounts
    # =========================================================================
    
    # Retrieves all unpaid invoices for a specific partner (for partial/bulk payments)
    VOUCHER_GET_UNPAID_INVOICES = "EXEC [Sales].[sp_Partner_GetUnpaidInvoices] @PartnerID=?, @InvType=?"
    
    # Performs a bulk payment and creates a voucher allocating amounts to multiple invoices
    VOUCHER_BULK_PAYMENT = """
        EXEC [Sales].[sp_Partner_BulkPayment_pos]
            @PartnerID=?, @VoucherType=?, @TotalAmount=?, @AccountID=?, 
            @UserID=?, @ShiftID=?, @Description=?, @AllocationsXML=?
    """
    
    # Retrieves the full Chart of Accounts (All levels and types)
    ACCOUNT_GET_ALL = "EXEC [Accounting].[sp_Account_GetAll]"
    
    # Retrieves transactional accounts suitable for vouchers (Cash/Bank)
    ACCOUNT_GET_TRANSACTIONAL = """
        SELECT AccountID, AccountCode, AccountName
        FROM [Accounting].[ChartOfAccounts]
        WHERE IsTransactional = 1
          AND (AccountName LIKE N'%صندوق%' OR AccountName LIKE N'%بنك%' OR AccountName LIKE N'%كاش%')
        ORDER BY AccountCode
    """
    
    # Retrieves the invoice allocations tied to a specific voucher
    VOUCHER_GET_ALLOCATIONS = """
        SELECT v.InvID, v.Amount, h.InvDate
        FROM [Accounting].[VoucherAllocations] v
        LEFT JOIN [Sales].[InvoiceHeader] h ON v.InvID = h.InvID
        WHERE v.VoucherID = ?
    """

    # =========================================================================
    # Settings
    # =========================================================================
    
    # Retrieves global company settings and defaults
    SETTINGS_COMPANY_GET = "{CALL [Settings].[sp_CompanySettings_Get]}"
    
    # Saves or updates printer settings for a specific POS hardware ID
    SETTINGS_PRINTER_SAVE = "{CALL [Settings].[sp_PrinterSettings_Save] (?, ?, ?, ?, ?)}"
    
    # Retrieves printer settings for a specific POS hardware ID
    SETTINGS_PRINTER_GET = "{CALL [Settings].[sp_PrinterSettings_Get] (?)}"

    # Retrieves all warehouses from settings
    WAREHOUSE_GETALL = "EXEC [Settings].[sp_Warehouse_GetAll]"


    # =========================================================================
    # Inventory Operations (Wastage & Stock Take)
    # =========================================================================
    
    # Saves a wastage document (draft/pending) with details using XML
    WASTAGE_SAVE_XML = """
        DECLARE @WastageID INT = ?;
        EXEC [Inventory].[sp_Wastage_Save_XML]
            @WastageID = @WastageID OUTPUT,
            @WastageDate = ?,
            @UserID = ?,
            @ShiftID = ?,
            @WarehouseID = ?,
            @TotalValue = ?,
            @Notes = ?,
            @DetailsXml = ?;
        SELECT @WastageID as WastageID;
    """

    # Saves a stocktake document (draft/pending) with details using XML
    STOCKTAKE_SAVE_XML = """
        DECLARE @StockTakeID INT = ?;
        EXEC [Inventory].[sp_StockTake_Save_XML]
            @StockTakeID = @StockTakeID OUTPUT,
            @StockTakeDate = ?,
            @UserID = ?,
            @WarehouseID = ?,
            @TotalDifferenceValue = ?,
            @Notes = ?,
            @DetailsXml = ?;
        SELECT @StockTakeID as StockTakeID;
    """

