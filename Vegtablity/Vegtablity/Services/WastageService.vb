Imports System.Data
Imports Dapper
Imports Vegtablity.Models
Imports System.Xml.Linq

Namespace Services
    Public Class WastageService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ' Get paginated wastage history
        Public Function GetWastageHistory(pageNumber As Integer, pageSize As Integer) As PagedResult(Of WastageHeader)
            Dim result As New PagedResult(Of WastageHeader)()
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_WASTAGE_GETALL, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of WastageHeader)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                ' Log error
            End Try
            Return result
        End Function

        ' Get Wastage Details
        Public Function GetWastageDetails(wastageID As Integer) As List(Of WastageDetails)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@WastageID", wastageID)
                    Return conn.Query(Of WastageDetails)(
                        Helpers.StoredProcedures.SP_WASTAGE_GETDETAILS, p,
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of WastageDetails)()
            End Try
        End Function

        ' Save Wastage
        Public Function SaveWastage(header As WastageHeader, details As List(Of WastageDetails)) As Integer
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim xml As New XElement("Details",
                        From d In details
                        Select New XElement("Item",
                            New XAttribute("ProductID", d.ProductID),
                            New XAttribute("Quantity", d.Quantity),
                            New XAttribute("CostPrice", d.CostPrice),
                            New XAttribute("StockBefore", d.AvailableQuantity)
                        )
                    )

                    Dim p As New DynamicParameters()
                    p.Add("@WastageID", header.WastageID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                    p.Add("@WastageDate", header.WastageDate)
                    p.Add("@UserID", header.UserID)
                    p.Add("@ShiftID", header.ShiftID)
                    p.Add("@WarehouseID", header.WarehouseID)
                    p.Add("@TotalValue", header.TotalValue)
                    p.Add("@Notes", header.Notes)
                    p.Add("@DetailsXml", xml.ToString(), dbType:=DbType.Xml)

                    conn.Execute(Helpers.StoredProcedures.SP_WASTAGE_SAVE_XML, p, commandType:=CommandType.StoredProcedure)
                    
                    Return p.Get(Of Integer)("@WastageID")
                End Using
            Catch ex As Exception
                Throw New Exception("حدث خطأ أثناء حفظ التوالف: " & ex.Message)
            End Try
        End Function

        ' Post Wastage (Deduct from Stock via Trigger)
        Public Sub PostWastage(wastageID As Integer)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@WastageID", wastageID)
                    conn.Execute(Helpers.StoredProcedures.SP_WASTAGE_POST, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Throw New Exception("حدث خطأ أثناء ترحيل التوالف: " & ex.Message)
            End Try
        End Sub

        ' Unpost Wastage (Restore Stock and Delete Journal Entry via Trigger)
        Public Sub UnpostWastage(wastageID As Integer)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@WastageID", wastageID)
                    conn.Execute(Helpers.StoredProcedures.SP_WASTAGE_UNPOST, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Throw New Exception("حدث خطأ أثناء إلغاء ترحيل التوالف: " & ex.Message)
            End Try
        End Sub
    End Class
End Namespace
