Imports System.Data.SqlClient
Imports System.Configuration

Namespace Services
    Public Class DatabaseHelper
        Private ReadOnly _connectionString As String

        Public Sub New()
            _connectionString = ConfigurationManager.ConnectionStrings("MainConn").ConnectionString
        End Sub

        Public Function GetConnection() As SqlConnection
            Return New SqlConnection(_connectionString)
        End Function

        Public Function ExecuteNonQuery(query As String, Optional parameters As Dictionary(Of String, Object) = Nothing, Optional isStoredProcedure As Boolean = False) As Integer
            Using conn As New SqlConnection(_connectionString)
                Using cmd As New SqlCommand(query, conn)
                    cmd.CommandType = If(isStoredProcedure, CommandType.StoredProcedure, CommandType.Text)
                    If parameters IsNot Nothing Then
                        For Each param In parameters
                            cmd.Parameters.AddWithValue(param.Key, param.Value)
                        Next
                    End If
                    conn.Open()
                    Return cmd.ExecuteNonQuery()
                End Using
            End Using
        End Function

        Public Function ExecuteReader(query As String, Optional parameters As Dictionary(Of String, Object) = Nothing, Optional isStoredProcedure As Boolean = False) As DataTable
            Dim dt As New DataTable()
            Using conn As New SqlConnection(_connectionString)
                Using cmd As New SqlCommand(query, conn)
                    cmd.CommandType = If(isStoredProcedure, CommandType.StoredProcedure, CommandType.Text)
                    If parameters IsNot Nothing Then
                        For Each param In parameters
                            cmd.Parameters.AddWithValue(param.Key, param.Value)
                        Next
                    End If
                    conn.Open()
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        dt.Load(reader)
                    End Using
                End Using
            End Using
            Return dt
        End Function
        
        Public Function ExecuteScalar(query As String, Optional parameters As Dictionary(Of String, Object) = Nothing, Optional isStoredProcedure As Boolean = False) As Object
            Using conn As New SqlConnection(_connectionString)
                Using cmd As New SqlCommand(query, conn)
                    cmd.CommandType = If(isStoredProcedure, CommandType.StoredProcedure, CommandType.Text)
                    If parameters IsNot Nothing Then
                        For Each param In parameters
                            cmd.Parameters.AddWithValue(param.Key, param.Value)
                        Next
                    End If
                    conn.Open()
                    Return cmd.ExecuteScalar()
                End Using
            End Using
        End Function

    End Class
End Namespace
