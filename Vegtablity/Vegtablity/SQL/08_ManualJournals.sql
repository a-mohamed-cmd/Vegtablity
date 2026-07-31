-- =============================================
-- Manual Journal Entries - رؤوس وتفاصيل القيود اليدوية
-- =============================================
USE VegtablityDB;
GO

-- 1. إضافة تسلسل لأرقام القيود اليدوية إذا لم يوجد
-- 1. (تمت الإزالة) تم توحيد التسلسل مع جدول الحركات العام
GO

-- 2. التحقق من وجود جدول رأس القيد (JournalHeader)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalHeader' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalHeader] (
        JID INT PRIMARY KEY IDENTITY(1,1),
        JournalNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_EntryNo]),
        JDate DATETIME DEFAULT GETDATE(),
        Description NVARCHAR(255),
        UserID INT,
        IsPosted BIT DEFAULT 0,
        TotalAmount DECIMAL(18, 2) DEFAULT 0,
        ReferenceType NVARCHAR(50) DEFAULT 'Manual', 
        ReferenceID INT NULL, 
        FOREIGN KEY (UserID) REFERENCES [Security].[Users](UserID)
    );
END
ELSE
BEGIN
    -- تعديل الترقيم ليستخدم التسلسل العام إذا كان جديداً
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Accounting].[JournalHeader]') AND name = 'JournalNo')
        ALTER TABLE [Accounting].[JournalHeader] ADD JournalNo INT NOT NULL DEFAULT (NEXT VALUE FOR [Accounting].[seq_EntryNo]);
    
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Accounting].[JournalHeader]') AND name = 'TotalAmount')
        ALTER TABLE [Accounting].[JournalHeader] ADD TotalAmount DECIMAL(18, 2) DEFAULT 0;
END
GO

-- 2.2 التحقق من وجود جدول تفاصيل القيد (JournalDetails)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'JournalDetails' AND schema_id = SCHEMA_ID('Accounting'))
BEGIN
    CREATE TABLE [Accounting].[JournalDetails] (
        JDID INT PRIMARY KEY IDENTITY(1,1),
        JID INT NOT NULL,
        AccountID INT NOT NULL,
        Debit DECIMAL(18, 2) DEFAULT 0,
        Credit DECIMAL(18, 2) DEFAULT 0,
        Notes NVARCHAR(200),
        FOREIGN KEY (JID) REFERENCES [Accounting].[JournalHeader](JID),
        FOREIGN KEY (AccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID)
    );
END
GO

-- 3. إجراء مخزن لحفظ القيد اليدوي (رأس وتفاصيل)
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Save]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Save];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Save]
    @JID INT = 0,
    @JDate DATETIME,
    @Description NVARCHAR(255),
    @UserID INT,
    @TotalAmount DECIMAL(18, 2),
    @DetailsXml XML
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @JID = 0
        BEGIN
            INSERT INTO [Accounting].[JournalHeader] (JDate, Description, UserID, TotalAmount, IsPosted, ReferenceType)
            VALUES (@JDate, @Description, @UserID, @TotalAmount, 0, 'Manual');
            SET @JID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- تحديث الرأس (فقط إذا لم يُرحّل)
            IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 1)
            BEGIN
                RAISERROR(N'لا يمكن تعديل قيد مرحّل', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            UPDATE [Accounting].[JournalHeader] 
            SET JDate = @JDate, Description = @Description, TotalAmount = @TotalAmount
            WHERE JID = @JID;

            DELETE FROM [Accounting].[JournalDetails] WHERE JID = @JID;
        END

        -- إدخال التفاصيل من الـ XML
        -- ملاحظة: يعمل على كافة نسخ SQL Server الحديثة والقديمة
        INSERT INTO [Accounting].[JournalDetails] (JID, AccountID, Debit, Credit, Notes)
        SELECT 
            @JID,
            T.c.value('@AccountID', 'INT'),
            T.c.value('@Debit', 'DECIMAL(18,2)'),
            T.c.value('@Credit', 'DECIMAL(18,2)'),
            T.c.value('@Notes', 'NVARCHAR(200)')
        FROM @DetailsXml.nodes('/details/item') T(c);

        COMMIT TRANSACTION;
        SELECT @JID AS JID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- 4. Trigger: ترحيل وإلغاء ترحيل القيد اليدوي تلقائياً عند تغيير IsPosted
IF OBJECT_ID('[Accounting].[trg_JournalHeader_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_JournalHeader_Post];
GO

CREATE TRIGGER [Accounting].[trg_JournalHeader_Post]
ON [Accounting].[JournalHeader]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. حالة إلغاء الترحيل (UNPOSTING: IsPosted 1 -> 0): حذف القيد من [Accounting].[JournalEntries]
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted del ON JE.ReferenceID = del.JID AND JE.ReferenceType = 'Manual'
    INNER JOIN inserted ins ON ins.JID = del.JID
    WHERE del.IsPosted = 1 AND ins.IsPosted = 0;

    -- 2. حالة التعديل على قيد مرحل (IsPosted 1 -> 1 مع التغيير): حذف القيود القديمة
    DELETE JE
    FROM [Accounting].[JournalEntries] JE
    INNER JOIN deleted del ON JE.ReferenceID = del.JID AND JE.ReferenceType = 'Manual'
    INNER JOIN inserted ins ON ins.JID = del.JID
    WHERE del.IsPosted = 1 AND ins.IsPosted = 1
      AND (del.JDate <> ins.JDate OR ISNULL(del.Description,'') <> ISNULL(ins.Description,'') OR del.TotalAmount <> ins.TotalAmount);

    -- 3. حالة الترحيل (POSTING: 0 -> 1 أو Re-Post): إدخال القيود في [Accounting].[JournalEntries]
    INSERT INTO [Accounting].[JournalEntries] (
        EntryNo, 
        EntryDate, 
        ReferenceType, 
        ReferenceID, 
        AccountID, 
        DebitAmount, 
        CreditAmount, 
        Description, 
        UserID
    )
    SELECT 
        ins.JournalNo,
        ins.JDate,
        'Manual',
        ins.JID,
        jd.AccountID,
        jd.Debit,
        jd.Credit,
        ISNULL(jd.Notes, ins.Description),
        ins.UserID
    FROM inserted ins
    JOIN [Accounting].[JournalDetails] jd ON ins.JID = jd.JID
    LEFT JOIN deleted del ON del.JID = ins.JID
    WHERE ins.IsPosted = 1
      AND (
          ISNULL(del.IsPosted, 0) = 0 -- الترحيل من جديد (0 -> 1)
          OR (del.IsPosted = 1 AND (del.JDate <> ins.JDate OR ISNULL(del.Description,'') <> ISNULL(ins.Description,'') OR del.TotalAmount <> ins.TotalAmount)) -- إعادة الترحيل عند التعديل
      );
END
GO

-- 4.1 Trigger: حذف القيود من [Accounting].[JournalEntries] عند حذف رأس القيد اليدوي
IF OBJECT_ID('[Accounting].[trg_JournalHeader_Delete]', 'TR') IS NOT NULL
    DROP TRIGGER [Accounting].[trg_JournalHeader_Delete];
GO

CREATE TRIGGER [Accounting].[trg_JournalHeader_Delete]
ON [Accounting].[JournalHeader]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [Accounting].[JournalEntries]
    WHERE ReferenceType = 'Manual' 
      AND ReferenceID IN (SELECT JID FROM deleted);
END
GO

-- 4.2 إجراء ترحيل القيد اليدوي لجدول الحركات العام
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Post]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Post];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Post]
    @JID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID)
    BEGIN
        RAISERROR(N'القيد غير موجود', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 1)
    BEGIN
        RAISERROR(N'القيد مرحّل بالفعل', 16, 1);
        RETURN;
    END

    -- تحديث IsPosted يُفعّل الـ Trigger تلقائياً لإنشاء القيود
    UPDATE [Accounting].[JournalHeader] SET IsPosted = 1 WHERE JID = @JID;
END
GO

-- 4.3 إجراء إلغاء ترحيل القيد اليدوي (حذف القيود من JournalEntries وإرجاع الحالة إلى غير مرحل)
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Unpost]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Unpost];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Unpost]
    @JID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID)
    BEGIN
        RAISERROR(N'القيد غير موجود', 16, 1);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 0)
    BEGIN
        RAISERROR(N'القيد غير مرحّل بالأساس', 16, 1);
        RETURN;
    END

    -- تحديث IsPosted يُفعّل الـ Trigger تلقائياً لحذف القيد من JournalEntries
    UPDATE [Accounting].[JournalHeader] SET IsPosted = 0 WHERE JID = @JID;
END
GO

-- 5. جلب كافة القيود اليدوية
IF OBJECT_ID('[Accounting].[sp_JournalEntry_GetAll]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_GetAll];
GO
CREATE PROCEDURE [Accounting].[sp_JournalEntry_GetAll]
AS
BEGIN
    SELECT JID, JournalNo, JDate, Description, TotalAmount, IsPosted, ReferenceType
    FROM [Accounting].[JournalHeader]
    WHERE ReferenceType = 'Manual'
    ORDER BY JID DESC;
END
GO

-- 6. جلب تفاصيل قيد معين
IF OBJECT_ID('[Accounting].[sp_JournalEntry_GetDetails]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_GetDetails];
GO
CREATE PROCEDURE [Accounting].[sp_JournalEntry_GetDetails]
    @JID INT
AS
BEGIN
    SELECT JD.JDID, JD.JID, JD.AccountID, A.AccountName, A.AccountCode, JD.Debit, JD.Credit, JD.Notes
    FROM [Accounting].[JournalDetails] JD
    JOIN [Accounting].[ChartOfAccounts] A ON JD.AccountID = A.AccountID
    WHERE JD.JID = @JID;
END
GO
