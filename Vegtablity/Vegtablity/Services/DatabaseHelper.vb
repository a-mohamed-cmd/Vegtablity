Imports System.Data
Imports System.Data.SqlClient
Imports System.Configuration

Namespace Services
    Public Class DatabaseHelper
        Private ReadOnly _connectionString As String

        Public Sub New()
            _connectionString = ConfigurationManager.ConnectionStrings("MainConn").ConnectionString
        End Sub

        Public Function GetConnection() As IDbConnection
            Return New SqlConnection(_connectionString)
        End Function
        
        ' Dapper extensions will be available on the IDbConnection object returned by GetConnection.
        ' We don't need to wrap every method, but we can provide a helper property for ConnectionString if needed.
    End Class
End Namespace
