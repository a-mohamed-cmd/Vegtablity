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

-- 4. إجراء ترحيل القيد اليدوي لجدول الحركات العام
IF OBJECT_ID('[Accounting].[sp_JournalEntry_Post]', 'P') IS NOT NULL DROP PROCEDURE [Accounting].[sp_JournalEntry_Post];
GO

CREATE PROCEDURE [Accounting].[sp_JournalEntry_Post]
    @JID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM [Accounting].[JournalHeader] WHERE JID = @JID AND IsPosted = 1)
    BEGIN
        RAISERROR(N'القيد مرحّل بالفعل', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- نستخدم نفس رقم القيد الموجود في الرأس ليكون هو رقم الحركة في القيد العام
        -- هذا يضمن الشفافية وتوحيد الترقيم
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT 
            H.JournalNo,
            H.JDate,
            'Manual',
            H.JID,
            D.AccountID,
            D.Debit,
            D.Credit,
            ISNULL(D.Notes, H.Description),
            H.UserID
        FROM [Accounting].[JournalHeader] H
        JOIN [Accounting].[JournalDetails] D ON H.JID = D.JID
        WHERE H.JID = @JID;

        UPDATE [Accounting].[JournalHeader] SET IsPosted = 1 WHERE JID = @JID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
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
