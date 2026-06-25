Imports System.Data
Imports Dapper
Imports Vegtablity.Models
Imports System.Xml.Linq

Namespace Services
    Public Class StockTakeService
        Private ReadOnly _dbHelper As DatabaseHelper

        Public Sub New()
            _dbHelper = New DatabaseHelper()
        End Sub

        ' Get paginated stock take history
        Public Function GetStockTakeHistory(pageNumber As Integer, pageSize As Integer) As PagedResult(Of StockTakeHeader)
            Dim result As New PagedResult(Of StockTakeHeader)()
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_STOCKTAKE_GETALL, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of StockTakeHeader)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                ' Log error
            End Try
            Return result
        End Function

        ' Get Stock Take Details
        Public Function GetStockTakeDetails(stockTakeID As Integer) As List(Of StockTakeDetails)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@StockTakeID", stockTakeID)
                    Return conn.Query(Of StockTakeDetails)(
                        Helpers.StoredProcedures.SP_STOCKTAKE_GETDETAILS, p,
                        commandType:=CommandType.StoredProcedure).AsList()
                End Using
            Catch ex As Exception
                Return New List(Of StockTakeDetails)()
            End Try
        End Function

        ' Save Stock Take (Draft)
        Public Function SaveStockTake(header As StockTakeHeader, details As List(Of StockTakeDetails)) As Integer
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim xml As New XElement("Details",
                        From d In details
                        Select New XElement("Item",
                            New XAttribute("ProductID", d.ProductID),
                            New XAttribute("SystemQuantity", d.SystemQuantity),
                            New XAttribute("ActualQuantity", d.ActualQuantity),
                            New XAttribute("CostPrice", d.CostPrice)
                        )
                    )

                    Dim p As New DynamicParameters()
                    p.Add("@StockTakeID", header.StockTakeID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                    p.Add("@StockTakeDate", header.StockTakeDate)
                    p.Add("@UserID", header.UserID)
                    p.Add("@WarehouseID", header.WarehouseID)
                    p.Add("@TotalDifferenceValue", header.TotalDifferenceValue)
                    p.Add("@Notes", header.Notes)
                    p.Add("@DetailsXml", xml.ToString(), dbType:=DbType.Xml)

                    conn.Execute(Helpers.StoredProcedures.SP_STOCKTAKE_SAVE_XML, p, commandType:=CommandType.StoredProcedure)
                    
                    Return p.Get(Of Integer)("@StockTakeID")
                End Using
            Catch ex As Exception
                Throw New Exception("حدث خطأ أثناء حفظ الجرد: " & ex.Message)
            End Try
        End Function

        ' Approve Stock Take
        Public Sub ApproveStockTake(stockTakeID As Integer, approvedBy As Integer)
            Try
                Using conn As IDbConnection = _dbHelper.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@StockTakeID", stockTakeID)
                    p.Add("@ApprovedBy", approvedBy)
                    conn.Execute(Helpers.StoredProcedures.SP_STOCKTAKE_APPROVE, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Throw New Exception("حدث خطأ أثناء اعتماد الجرد: " & ex.Message)
            End Try
        End Sub
    End Class
End Namespace
