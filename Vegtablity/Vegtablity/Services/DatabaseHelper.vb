Imports System.Data
Imports System.Data.SqlClient

Namespace Services
    Public Class DatabaseHelper
        Private ReadOnly _connectionString As String
        Private ReadOnly _databaseName As String ' Added for BackupDatabase function

        Public Sub New()
            ' Base64 Encoded connection string to protect credentials from easy extraction on VPS
            'vegtabilty
            '  Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTg1LjIxNi4yMDMuNTAsMTQyMjtJbml0aWFsIENhdGFsb2c9VmVndGFibGl0eURCO1VzZXIgSUQ9TW9oYW1lZDtQYXNzd29yZD0xMjU2MzA7VHJ1c3RTZXJ2ZXJDZXJ0aWZpY2F0ZT1UcnVlOw=="
            'zatterDB
            '  Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTg1LjIxNi4yMDMuNTAsMTQyMjtJbml0aWFsIENhdGFsb2c9emF0dGVyREI7VXNlciBJRD1Nb2hhbWVkO1Bhc3N3b3JkPTEyNTYzMDtUcnVzdFNlcnZlckNlcnRpZmljYXRlPVRydWU7"
            'OmanCustomerDB
            Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTg1LjIxNi4yMDMuNTAsMTQyMjtJbml0aWFsIENhdGFsb2c9T21hbkN1c3RtZXJEQjtVc2VyIElEPU1vaGFtZWQ7UGFzc3dvcmQ9MTI1NjMwO1RydXN0U2VydmVyQ2VydGlmaWNhdGU9VHJ1ZTs="
            'localtest
            ' Old Local Connection String (192.168.43.129\SQLEXPRESS):
            'Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTkyLjE2OC40My4xMjlcU1FMRVhQUkVTUztJbml0aWFsIENhdGFsb2c9VmVndGFibGl0eURCO1VzZXIgSUQ9TW9oYW1lZDtQYXNzd29yZD0xMjU2MzA7VHJ1c3RTZXJ2ZXJDZXJ0aWZpY2F0ZT1UcnVlOw=="
            'washaDB
            ' Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTg1LjIxNi4yMDMuNTAsMTQyMjtJbml0aWFsIENhdGFsb2c9V2FzaGFEQjtVc2VyIElEPU1vaGFtZWQ7UGFzc3dvcmQ9MTI1NjMwO1RydXN0U2VydmVyQ2VydGlmaWNhdGU9VHJ1ZTs="
            _connectionString = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(encodedConn))


            ' Extract database name from connection string
            Dim builder As New SqlConnectionStringBuilder(_connectionString)
            _databaseName = builder.InitialCatalog
        End Sub

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
