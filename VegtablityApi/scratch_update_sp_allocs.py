import pyodbc
from app.core.config import settings

def main():
    conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={settings.DB_SERVER};DATABASE={settings.DB_NAME};UID={settings.DB_USER};PWD={settings.DB_PASSWORD}"
    conn = pyodbc.connect(conn_str, autocommit=True)
    cursor = conn.cursor()
    
    sp_sql = """
    ALTER PROCEDURE [Sales].[sp_Partner_BulkPayment_pos]
        @PartnerID    INT,
        @VoucherType  NVARCHAR(20),
        @TotalAmount  DECIMAL(18,3),
        @AccountID    INT,             -- حساب الصندوق/البنك المستخدم
        @UserID       INT,
        @ShiftID      INT,
        @Description  NVARCHAR(255) = NULL,
        @AllocationsXML NVARCHAR(MAX) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;
        BEGIN TRY
            BEGIN TRANSACTION;

            -- 0. جلب حساب العميل/المورد
            DECLARE @PartnerAccountID INT;
            SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

            IF @PartnerAccountID IS NULL
            BEGIN
                RAISERROR(N'الشريك ليس لديه حساب مالي مرتبط', 16, 1);
                RETURN;
            END

            -- ① تحليل XML لجدول مؤقت
            DECLARE @Allocs TABLE (InvID INT, Amount DECIMAL(18,3));

            IF @AllocationsXML IS NOT NULL AND LTRIM(RTRIM(@AllocationsXML)) <> '' AND @AllocationsXML <> '<Allocations></Allocations>' AND @AllocationsXML <> '<Allocations />'
            BEGIN
                INSERT INTO @Allocs (InvID, Amount)
                SELECT
                    x.item.value('@InvID',  'INT'),
                    x.item.value('@Amount', 'DECIMAL(18,3)')
                FROM (SELECT CAST(@AllocationsXML AS XML)) T(x)
                CROSS APPLY T.x.nodes('/Allocations/Item') AS x(item);

                -- ② التحقق من مجموع المبالغ
                DECLARE @SumCheck DECIMAL(18,3);
                SELECT @SumCheck = SUM(Amount) FROM @Allocs;

                IF ABS(@SumCheck - @TotalAmount) > 0.01
                BEGIN
                    RAISERROR(N'مجموع مبالغ الفواتير لا يساوي المبلغ الإجمالي المُدخل', 16, 1);
                    RETURN;
                END

                -- ③ التحقق من أن كل فاتورة: مرحّلة، Remainder >= المبلغ المراد سداده
                IF EXISTS (
                    SELECT 1 FROM @Allocs a
                    INNER JOIN [Sales].[InvoiceHeader] h ON a.InvID = h.InvID
                    WHERE h.IsPosted = 0 OR h.Remainder < a.Amount OR a.Amount <= 0
                )
                BEGIN
                    RAISERROR(N'إحدى الفواتير غير مرحّلة أو المبلغ يتجاوز المتبقي', 16, 1);
                    RETURN;
                END

                -- ④ تحديث VoucherPaidAmount و Remainder في الفواتير المحددة
                UPDATE h
                SET h.VoucherPaidAmount = h.VoucherPaidAmount + a.Amount,
                    h.Remainder         = h.Remainder         - a.Amount
                FROM [Sales].[InvoiceHeader] h
                INNER JOIN @Allocs a ON h.InvID = a.InvID;
            END

            -- ⑤ إنشاء السند في حالة غير مرحّلة (IsPosted = 0)
            -- سيتم الترحيل جماعياً عند إغلاق الوردية
            INSERT INTO [Accounting].[Vouchers]
                (VoucherType, VoucherDate, PartnerID, AccountID,
                 Amount, Description, PaymentMethod, UserID, IsPosted, ShiftID)
            VALUES
                (@VoucherType, GETDATE(), @PartnerID, @PartnerAccountID,
                 @TotalAmount,
                 ISNULL(@Description,
                    CASE @VoucherType
                        WHEN 'Receipt' THEN N'سند قبض - سداد مديونيات'
                        ELSE                N'سند صرف - سداد مستحقات'
                    END),
                 CAST(@AccountID AS NVARCHAR(50)), -- يتم حفظ حساب الصندوق/البنك هنا لتستخدمه الـ Trigger
                 @UserID, 0, @ShiftID);

            DECLARE @VoucherID INT = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            -- إرجاع رقم السند المُنشأ للطباعة
            SELECT
                v.VoucherID,
                v.VoucherType,
                v.VoucherDate,
                v.Amount,
                v.Description,
                v.ShiftID,
                p.PartnerName,
                u.FullName AS UserName,
                a.AccountName
            FROM [Accounting].[Vouchers] v
            LEFT JOIN [Sales].[Partners]             p ON v.PartnerID = p.PartnerID
            LEFT JOIN [Security].[Users]             u ON v.UserID    = u.UserID
            LEFT JOIN [Accounting].[ChartOfAccounts] a ON v.AccountID = a.AccountID
            WHERE v.VoucherID = @VoucherID;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH
    END
    """
    
    cursor.execute(sp_sql)
    print("Successfully updated sp_Partner_BulkPayment_pos with empty allocations support")

if __name__ == "__main__":
    main()
