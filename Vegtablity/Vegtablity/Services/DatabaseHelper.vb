Imports System.Data
Imports System.Data.SqlClient

Namespace Services
    Public Class DatabaseHelper
        Private ReadOnly _connectionString As String

        Public Sub New()
            ' Base64 Encoded connection string to protect credentials from easy extraction on VPS
            Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTg1LjIxNi4yMDMuNTAsMTQyMjtJbml0aWFsIENhdGFsb2c9VmVndGFibGl0eURCO1VzZXIgSUQ9TW9oYW1lZDtQYXNzd29yZD0xMjU2MzA7VHJ1c3RTZXJ2ZXJDZXJ0aWZpY2F0ZT1UcnVlOw=="
            
            ' Old Local Connection String (192.168.43.129\SQLEXPRESS):
            'Dim encodedConn As String = "RGF0YSBTb3VyY2U9MTkyLjE2OC40My4xMjlcU1FMRVhQUkVTUztJbml0aWFsIENhdGFsb2c9VmVndGFibGl0eURCO1VzZXIgSUQ9TW9oYW1lZDtQYXNzd29yZD0xMjU2MzA7VHJ1c3RTZXJ2ZXJDZXJ0aWZpY2F0ZT1UcnVlOw=="
            
            _connectionString = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(encodedConn))
        End Sub

        Public Function GetConnection() As IDbConnection
            Return New SqlConnection(_connectionString)
        End Function
        
        ' Dapper extensions will be available on the IDbConnection object returned by GetConnection.
        ' We don't need to wrap every method, but we can provide a helper property for ConnectionString if needed.
    End Class
End Namespace
