Imports System.Management
Imports System.Security.Cryptography
Imports System.Text
Imports System.Data
Imports Dapper

Namespace Services
    Public Class LicenseService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetHardwareID() As String
            Dim hwid As String = ""
            Try
                Dim mc As New ManagementClass("Win32_Processor")
                For Each mo As ManagementObject In mc.GetInstances()
                    hwid = mo.Properties("ProcessorId").Value.ToString()
                    Exit For
                Next

                Dim mc2 As New ManagementClass("Win32_BaseBoard")
                For Each mo As ManagementObject In mc2.GetInstances()
                    hwid &= mo.Properties("SerialNumber").Value.ToString()
                    Exit For
                Next
            Catch ex As Exception
                hwid = Environment.MachineName
            End Try

            Return HashString(hwid)
        End Function

        Private Function HashString(input As String) As String
            Using sha256 As SHA256 = SHA256.Create()
                Dim bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(input))
                Return BitConverter.ToString(bytes).Replace("-", "").Substring(0, 16).ToUpper()
            End Using
        End Function

        Public Function IsLicensed(hardwareID As String) As Boolean
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim result = conn.QueryFirstOrDefault(Of Boolean?)(
                        Helpers.StoredProcedures.SP_LICENSE_CHECK,
                        New With {.MachineHWID = hardwareID},
                        commandType:=CommandType.StoredProcedure)
                    Return result.HasValue AndAlso result.Value
                End Using
            Catch ex As Exception
                Return False
            End Try
        End Function
    End Class
End Namespace
