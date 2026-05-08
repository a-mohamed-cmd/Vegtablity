Imports System.Data
Imports Dapper
Imports Vegtablity.Models

Namespace Services
    Public Class PartnerService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        Public Function GetAllPartners(partnerType As String) As List(Of Partner)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Partner)(
                    Helpers.StoredProcedures.SP_PARTNER_GETALL,
                    New With {.PartnerType = partnerType},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        Public Function GetPartnerByID(partnerID As Integer) As Partner
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.QueryFirstOrDefault(Of Partner)(
                    Helpers.StoredProcedures.SP_PARTNER_GETBYID,
                    New With {.PartnerID = partnerID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Function SavePartner(p As Partner) As Integer
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.ExecuteScalar(Of Integer)(
                    Helpers.StoredProcedures.SP_PARTNER_SAVE,
                    New With {p.PartnerID, p.PartnerName, p.PartnerType, p.Phone, p.Address, p.AccountID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Function

        Public Sub DeletePartner(partnerID As Integer)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                conn.Execute(
                    Helpers.StoredProcedures.SP_PARTNER_DELETE,
                    New With {.PartnerID = partnerID},
                    commandType:=CommandType.StoredProcedure)
            End Using
        End Sub

        Public Function SearchPartners(partnerType As String, searchText As String) As List(Of Partner)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Partner)(
                    Helpers.StoredProcedures.SP_PARTNER_SEARCH,
                    New With {.PartnerType = partnerType, .SearchText = searchText},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function

        ''' <summary>
        ''' جلب جميع الشركاء (عملاء + موردون) مع دعم البحث بالاسم أو رقم الحساب.
        ''' </summary>
        Public Function SearchAllPartners(Optional searchText As String = "") As List(Of Partner)
            Using conn As IDbConnection = _dbHelper.GetConnection()
                Return conn.Query(Of Partner)(
                    Helpers.StoredProcedures.SP_PARTNER_SEARCH_ALL,
                    New With {.SearchText = searchText},
                    commandType:=CommandType.StoredProcedure).AsList()
            End Using
        End Function
    End Class
End Namespace
