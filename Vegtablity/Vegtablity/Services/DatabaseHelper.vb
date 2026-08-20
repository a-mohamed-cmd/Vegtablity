Imports System.Data
Imports System.Data.SqlClient

Namespace Services
    Public Class DatabaseHelper
        Private ReadOnly _connectionString As String
        Private ReadOnly _databaseName As String
        Private ReadOnly _tenantFlavor As String

        Private Const CONFIG_FILE_NAME As String = "dbconfig.dat"
        Private Const AES_KEY_STRING As String = "V3gT@bl1ty#2026!S3cur3DbK3y99XQZ" ' 32 bytes AES-256 Key
        Private Const AES_IV_STRING As String = "V3gTabl1tyIV2026"                ' 16 bytes AES IV (128-bit block)

        ' نص الاتصال القياسي مشفر بالكامل داخلياً لحماية بيانات السيرفر والمستخدم وكلمة المرور
        Private Const ENCODED_CONN_TEMPLATE As String = "RGF0YSBTb3VyY2U9MTg1LjIxNi4yMDMuNTAsMTQyMjtJbml0aWFsIENhdGFsb2c9ezB9O1VzZXIgSUQ9TW9oYW1lZDtQYXNzd29yZD0xMjU2MzA7VHJ1c3RTZXJ2ZXJDZXJ0aWZpY2F0ZT1UcnVlOw=="

        Public Sub New()
            _connectionString = LoadEncryptedConnectionString()

            ' Extract database name from connection string
            Try
                Dim builder As New SqlConnectionStringBuilder(_connectionString)
                If String.IsNullOrWhiteSpace(builder.InitialCatalog) Then
                    Throw New InvalidOperationException("نص الاتصال المستخرج من ملف (dbconfig.dat) لا يحتوي على اسم قاعدة بيانات (Initial Catalog) صالح.")
                End If
                _databaseName = builder.InitialCatalog
            Catch ex As Exception
                Throw New InvalidOperationException("فشل قراءة بيانات الاتصال من ملف (dbconfig.dat): " & ex.Message, ex)
            End Try

            _tenantFlavor = ResolveTenantFlavor(_databaseName)
        End Sub

        Public ReadOnly Property ConnectionString As String
            Get
                Return _connectionString
            End Get
        End Property

        Public ReadOnly Property DatabaseName As String
            Get
                Return _databaseName
            End Get
        End Property

        Public ReadOnly Property TenantFlavor As String
            Get
                Return _tenantFlavor
            End Get
        End Property

        ''' <summary>
        ''' تحميل وفك تشفير اسم قاعدة البيانات من ملف dbconfig.dat — يرمي استثناء صريح إذا لم يوجد الملف أو كان تالفاً
        ''' </summary>
        Private Function LoadEncryptedConnectionString() As String
            Dim configPath As String = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, CONFIG_FILE_NAME)

            ' 1. التحقق من وجود الملف — بدون أي قيم افتراضية
            If Not System.IO.File.Exists(configPath) Then
                Throw New System.IO.FileNotFoundException($"خطأ فادح: ملف إعدادات الاتصال بقاعدة البيانات ({CONFIG_FILE_NAME}) غير موجود في مسار البرنامج!" & vbCrLf &
                                                          $"المسار المتوقع: {configPath}" & vbCrLf &
                                                          "يرجى توفير ملف التهيئة الخاص بالشركة لتشغيل البرنامج.")
            End If

            Dim rawContent As String = System.IO.File.ReadAllText(configPath).Trim()
            If String.IsNullOrWhiteSpace(rawContent) Then
                Throw New System.IO.InvalidDataException($"خطأ فادح: ملف إعدادات الاتصال ({CONFIG_FILE_NAME}) فارغ تماماً!")
            End If

            ' 2. محاولة فك التشفير (AES أو Base64 كطبقة إضافية)
            Dim decrypted As String = ""
            Try
                decrypted = DecryptStringAES(rawContent)
            Catch ex As Exception
                ' في حال كان مشفراً بـ Base64 فقط يتم فكه ودعمه
                Try
                    Dim b64Bytes As Byte() = Convert.FromBase64String(rawContent)
                    decrypted = System.Text.Encoding.UTF8.GetString(b64Bytes).Trim()
                Catch
                    Throw New System.Security.SecurityException($"خطأ فادح: فشل فك تشفير ملف ({CONFIG_FILE_NAME}). الملف تالف أو غير صالح!", ex)
                End Try
            End Try

            If String.IsNullOrWhiteSpace(decrypted) Then
                Throw New System.IO.InvalidDataException($"خطأ فادح: محتوى ملف ({CONFIG_FILE_NAME}) غير صالح بعد فك التشفير.")
            End If

            ' 3. استيراد اسم قاعدة البيانات فقط وبناء نص الاتصال المشفر داخلياً
            Dim targetDbName As String = decrypted.Trim()

            ' إذا كان المحتوى المستورد نص اتصال كامل مسبقاً
            If targetDbName.IndexOf("Data Source=", StringComparison.OrdinalIgnoreCase) >= 0 OrElse
               targetDbName.IndexOf("Initial Catalog=", StringComparison.OrdinalIgnoreCase) >= 0 Then
                Return targetDbName
            Else
                ' دمج اسم قاعدة البيانات المستورد من الخارج مع قالب السيرفر المشفر داخلياً
                Return BuildSecureConnectionString(targetDbName)
            End If
        End Function

        ''' <summary>
        ''' بناء نص الاتصال الآمن بدمج اسم قاعدة البيانات مع بيانات السيرفر المشفرة
        ''' </summary>
        Private Shared Function BuildSecureConnectionString(dbName As String) As String
            Try
                Dim templateBytes As Byte() = Convert.FromBase64String(ENCODED_CONN_TEMPLATE)
                Dim template As String = System.Text.Encoding.UTF8.GetString(templateBytes)
                Return String.Format(template, dbName.Trim())
            Catch ex As Exception
                Throw New InvalidOperationException("فشل بناء نص الاتصال الآمن: " & ex.Message, ex)
            End Try
        End Function

        ''' <summary>
        ''' تشفير نص اتصال وحفظه في ملف dbconfig.dat باستخدام AES
        ''' </summary>
        Public Shared Sub SaveEncryptedConfig(connectionStringOrDbName As String, Optional targetFilePath As String = Nothing)
            If String.IsNullOrWhiteSpace(connectionStringOrDbName) Then
                Throw New ArgumentException("لا يمكن حفظ إعدادات فارغة.")
            End If

            Dim destPath As String = If(String.IsNullOrWhiteSpace(targetFilePath),
                                         System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, CONFIG_FILE_NAME),
                                         targetFilePath)

            Dim encryptedText As String = EncryptStringAES(connectionStringOrDbName.Trim())
            System.IO.File.WriteAllText(destPath, encryptedText)
        End Sub

        ''' <summary>
        ''' دالة تشفير النصوص باستخدام خوارزمية AES-256
        ''' </summary>
        Public Shared Function EncryptStringAES(plainText As String) As String
            If String.IsNullOrEmpty(plainText) Then Return ""

            Dim keyBytes As Byte() = System.Text.Encoding.UTF8.GetBytes(AES_KEY_STRING)
            Dim ivBytes As Byte() = System.Text.Encoding.UTF8.GetBytes(AES_IV_STRING)

            Using aesAlg As System.Security.Cryptography.Aes = System.Security.Cryptography.Aes.Create()
                aesAlg.Key = keyBytes
                aesAlg.IV = ivBytes

                Dim encryptor As System.Security.Cryptography.ICryptoTransform = aesAlg.CreateEncryptor(aesAlg.Key, aesAlg.IV)
                Using msEncrypt As New System.IO.MemoryStream()
                    Using csEncrypt As New System.Security.Cryptography.CryptoStream(msEncrypt, encryptor, System.Security.Cryptography.CryptoStreamMode.Write)
                        Using swEncrypt As New System.IO.StreamWriter(csEncrypt)
                            swEncrypt.Write(plainText)
                        End Using
                        Return Convert.ToBase64String(msEncrypt.ToArray())
                    End Using
                End Using
            End Using
        End Function

        ''' <summary>
        ''' دالة فك تشفير النصوص باستخدام خوارزمية AES-256
        ''' </summary>
        Public Shared Function DecryptStringAES(cipherTextBase64 As String) As String
            If String.IsNullOrEmpty(cipherTextBase64) Then Return ""

            Dim keyBytes As Byte() = System.Text.Encoding.UTF8.GetBytes(AES_KEY_STRING)
            Dim ivBytes As Byte() = System.Text.Encoding.UTF8.GetBytes(AES_IV_STRING)
            Dim cipherBytes As Byte() = Convert.FromBase64String(cipherTextBase64.Trim())

            Using aesAlg As System.Security.Cryptography.Aes = System.Security.Cryptography.Aes.Create()
                aesAlg.Key = keyBytes
                aesAlg.IV = ivBytes

                Dim decryptor As System.Security.Cryptography.ICryptoTransform = aesAlg.CreateDecryptor(aesAlg.Key, aesAlg.IV)
                Using msDecrypt As New System.IO.MemoryStream(cipherBytes)
                    Using csDecrypt As New System.Security.Cryptography.CryptoStream(msDecrypt, decryptor, System.Security.Cryptography.CryptoStreamMode.Read)
                        Using srDecrypt As New System.IO.StreamReader(csDecrypt)
                            Return srDecrypt.ReadToEnd()
                        End Using
                    End Using
                End Using
            End Using
        End Function

        ''' <summary>
        ''' تحويل اسم قاعدة البيانات إلى نكهة النظام (Tenant Flavor) المعتمدة للتحديثات والـ API
        ''' </summary>
        Public Shared Function ResolveTenantFlavor(dbName As String) As String
            If String.IsNullOrWhiteSpace(dbName) Then Return "vegtablity"
            Dim normalized As String = dbName.Trim().ToLowerInvariant()

            If normalized.Contains("washa") Then
                Return "washa"
            ElseIf normalized.Contains("jawhara") Then
                Return "jawhara"
            ElseIf normalized.Contains("zatter") Then
                Return "zatter"
            ElseIf normalized.Contains("oman") Then
                Return "oman"
            Else
                Return "vegtablity"
            End If
        End Function

        Public Function GetConnection() As IDbConnection
            Return New SqlConnection(_connectionString)
        End Function

        ' Helper to get the raw connection string
        Private Function GetConnectionString() As String
            Return _connectionString
        End Function

        ' Dapper extensions will be available on the IDbConnection object returned by GetConnection.
        ' We don't need to wrap every method, but we can provide a helper property for ConnectionString if needed.

        Public Sub BackupDatabase(backupPath As String)
            Try
                Dim query As String = $"BACKUP DATABASE [{_databaseName}] TO DISK = '{backupPath}' WITH INIT, NAME = 'Full Backup of {_databaseName}', STATS = 10"
                Using conn As New SqlConnection(GetConnectionString())
                    Using cmd As New SqlCommand(query, conn)
                        conn.Open()
                        cmd.CommandTimeout = 300 ' 5 minutes timeout for backup
                        cmd.ExecuteNonQuery()
                    End Using
                End Using
            Catch ex As Exception
                Throw New Exception("فشل في أخذ نسخة احتياطية: " & ex.Message, ex)
            End Try
        End Sub

        ' ===================================================
        ' Execute Raw SQL Scripts (Supports 'GO' Separators)
        ' Useful for applying DB Updates or running DLLs/Scripts
        ' ===================================================
        Public Sub ExecuteSqlScript(scriptContent As String)
            Try
                ' Split the script on "GO" (case insensitive, full word)
                Dim scriptSplitter As New System.Text.RegularExpressions.Regex("^\s*GO\s*$", System.Text.RegularExpressions.RegexOptions.IgnoreCase Or System.Text.RegularExpressions.RegexOptions.Multiline)
                Dim commands As String() = scriptSplitter.Split(scriptContent)

                Using conn As New SqlConnection(GetConnectionString())
                    conn.Open()
                    For Each cmdText As String In commands
                        If Not String.IsNullOrWhiteSpace(cmdText) Then
                            Using cmd As New SqlCommand(cmdText, conn)
                                ' Increase timeout for large index creations or proc updates
                                cmd.CommandTimeout = 120
                                cmd.ExecuteNonQuery()
                            End Using
                        End If
                    Next
                End Using
            Catch ex As Exception
                Throw New Exception("فشل تنفيذ سكربت قاعدة البيانات: " & ex.Message, ex)
            End Try
        End Sub

    End Class
End Namespace
