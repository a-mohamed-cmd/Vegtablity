-- =============================================
-- Journal Entries - جدول القيود المحاسبية + Triggers
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- 1. تسلسل أرقام القيود + إنشاء جدول القيود المحاسبية
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.sequences WHERE name = 'seq_EntryNo' AND schema_id = SCHEMA_ID('Accounting'))
    CREATE SEQUENCE [Accounting].[seq_EntryNo] AS INT START WITH 1 INCREMENT BY 1;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalEntries' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalEntries] (
        EntryID INT PRIMARY KEY IDENTITY(1,1),
        EntryNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_EntryNo]),
        EntryDate DATETIME DEFAULT GETDATE(),
        ReferenceType NVARCHAR(20) NOT NULL,       -- 'Voucher' / 'Invoice'
        ReferenceID INT NOT NULL,                    -- رقم السند أو الفاتورة
        AccountID INT NOT NULL,
        DebitAmount DECIMAL(18, 2) DEFAULT 0,
        CreditAmount DECIMAL(18, 2) DEFAULT 0,
        Description NVARCHAR(255),
        UserID INT NULL,
        CreatedAt DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID),
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END
GO

-- =============================================
-- نحتاج حساب صندوق وحساب بنك افتراضيين
-- يمكنك تعديل الأرقام حسب شجرة حساباتك
-- =============================================
-- سنستخدم PaymentMethod لتحديد الحساب:
--   Cash => أول حساب اسمه 'الصندوق' (أو AccountID يُحدد يدوياً)
--   Bank => أول حساب اسمه 'البنك'
-- =============================================

-- =============================================
-- 2. Trigger: عند INSERT أو UPDATE على Vouchers
--    إذا أصبح IsPosted = 1 => ينشئ قيدين
--    إذا تغير IsPosted من 1 إلى 0 => يحذف القيود
--    إذا تعدّل سند مرحّل => يحدّث القيود
-- =============================================
IF OBJECT_ID('[Accounting].[trg_Voucher_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_Voucher_Post];
GO

CREATE TRIGGER [Accounting].[trg_Voucher_Post]
ON [Accounting].[Vouchers]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Handle Unposting (IsPosted 1 -> 0): Delete entries
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted d ON JE.ReferenceID = d.VoucherID AND JE.ReferenceType = 'Voucher'
    INNER JOIN inserted i ON i.VoucherID = d.VoucherID
    WHERE d.IsPosted = 1 AND i.IsPosted = 0;

    -- 2. Handle Updates to Posted Vouchers (IsPosted 1 -> 1 with changes): Delete old entries
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted d ON JE.ReferenceID = d.VoucherID AND JE.ReferenceType = 'Voucher'
    INNER JOIN inserted i ON i.VoucherID = d.VoucherID
    WHERE d.IsPosted = 1 AND i.IsPosted = 1
      AND (d.Amount <> i.Amount OR ISNULL(d.AccountID,0) <> ISNULL(i.AccountID,0)
           OR ISNULL(d.PaymentMethod,'') <> ISNULL(i.PaymentMethod,''));

    -- 3. Prepare for Insertion: Assign ONE EntryNo per Voucher
    DECLARE @VoucherEntryMap TABLE (VoucherID INT, EntryNo INT);

    INSERT INTO @VoucherEntryMap (VoucherID, EntryNo)
    SELECT i.VoucherID, NEXT VALUE FOR [Accounting].[seq_EntryNo]
    FROM inserted i
    LEFT JOIN deleted d ON d.VoucherID = i.VoucherID
    WHERE i.IsPosted = 1
      AND (
          -- New Post
          ISNULL(d.IsPosted, 0) = 0
          -- OR Re-Post (Modified)
          OR (d.IsPosted = 1 AND (d.Amount <> i.Amount OR ISNULL(d.AccountID,0) <> ISNULL(i.AccountID,0) OR ISNULL(d.PaymentMethod,'') <> ISNULL(i.PaymentMethod,'')))
      );

    -- 4. Insert Journal Entries (Both Legs)

    -- Leg 1: The Selected Account (Customer/Vendor/Expense/etc.)
    
    INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT
        m.EntryNo,
        i.VoucherDate,
        'Voucher',
        i.VoucherID,
        i.AccountID,
        CASE WHEN i.VoucherType = 'Payment' THEN i.Amount ELSE 0 END, -- Payment: Dr Account
        CASE WHEN i.VoucherType = 'Receipt' THEN i.Amount ELSE 0 END, -- Receipt: Cr Account
        ISNULL(i.Description, '') + N' - سند رقم ' + CAST(i.VoucherNo AS NVARCHAR),
        i.UserID
    FROM inserted i
    JOIN @VoucherEntryMap m ON m.VoucherID = i.VoucherID;

    -- Leg 2: The Fund Account (Cash/Bank)
    -- Receipt -> Debit | Payment -> Credit
    INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT
        m.EntryNo,
        i.VoucherDate,
        'Voucher',
        i.VoucherID,
        CASE
            WHEN i.PaymentMethod = 'Cash' THEN
                ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountName LIKE N'%صندوق%' AND IsTransactional = 1), i.AccountID)
            ELSE
                ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountName LIKE N'%بنك%' AND IsTransactional = 1), i.AccountID)
        END,
        CASE WHEN i.VoucherType = 'Receipt' THEN i.Amount ELSE 0 END, -- Receipt: Dr Cash
        CASE WHEN i.VoucherType = 'Payment' THEN i.Amount ELSE 0 END, -- Payment: Cr Cash
        ISNULL(i.Description, '') + N' - سند رقم ' + CAST(i.VoucherNo AS NVARCHAR),
        i.UserID
    FROM inserted i
    JOIN @VoucherEntryMap m ON m.VoucherID = i.VoucherID;
END
GO

-- =============================================
-- 3. Trigger: عند DELETE على Vouchers
--    يحذف جميع القيود المرتبطة بالسند
-- =============================================
IF OBJECT_ID('[Accounting].[trg_Voucher_Delete]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_Voucher_Delete];
GO

CREATE TRIGGER [Accounting].[trg_Voucher_Delete]
ON [Accounting].[Vouchers]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DELETE FROM [Accounting].[JournalEntries]
    WHERE ReferenceType = 'Voucher' 
      AND ReferenceID IN (SELECT VoucherID FROM deleted);
END
GO

PRINT N'✅ تم إنشاء جدول القيود والـ Triggers بنجاح';
GO
