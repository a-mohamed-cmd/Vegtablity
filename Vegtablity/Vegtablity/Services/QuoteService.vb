Imports Dapper
Imports System.Data
Imports Vegtablity.Models

Namespace Services
    Public Class QuoteService
        Private ReadOnly db As New DatabaseHelper()

        Public Function GetAllQuotes() As List(Of QuoteHeader)
            Try
                Using conn = db.GetConnection()
                    Return conn.Query(Of QuoteHeader)(Helpers.StoredProcedures.SP_QUOTATION_GETALL, commandType:=CommandType.StoredProcedure).ToList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error retrieving quotations: " & ex.Message)
            End Try
        End Function

        Public Function GetQuotesPaged(pageNumber As Integer, pageSize As Integer, Optional searchText As String = Nothing, Optional partnerID As Integer? = Nothing) As PagedResult(Of QuoteHeader)
            Dim result As New PagedResult(Of QuoteHeader)()
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)
                    p.Add("@SearchText", searchText)
                    p.Add("@PartnerID", partnerID)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_QUOTATION_GETPAGED, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of QuoteHeader)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                ' Log or handle
            End Try
            Return result
        End Function

        Public Function GetQuotesByPartner(partnerID As Integer) As List(Of QuoteHeader)
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PartnerID", partnerID)
                    Return conn.Query(Of QuoteHeader)(Helpers.StoredProcedures.SP_QUOTATION_GETBYPARTNER, p, commandType:=CommandType.StoredProcedure).ToList()
                End Using
            Catch ex As Exception
                Return New List(Of QuoteHeader)()
            End Try
        End Function

        Public Function GetQuoteDetails(quoteId As Integer, pageNumber As Integer, pageSize As Integer) As PagedResult(Of QuoteDetail)
            Dim result As New PagedResult(Of QuoteDetail)()
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@QuoteID", quoteId)
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_QUOTATIONDETAILS_GETBYQUOTEID, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of QuoteDetail)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                Throw New Exception("Error retrieving quotation details: " & ex.Message)
            End Try
            Return result
        End Function

        Public Function SaveQuote(quote As QuoteHeader) As Integer
            Using conn = db.GetConnection()
                conn.Open()
                Using trans = conn.BeginTransaction()
                    Try
                        Dim p As New DynamicParameters()
                        p.Add("@QuoteID", quote.QuoteID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                        p.Add("@PartnerID", quote.PartnerID)
                        p.Add("@QuoteDate", quote.QuoteDate)
                        p.Add("@ExpiryDate", quote.ExpiryDate)
                        p.Add("@IsActive", quote.IsActive)
                        p.Add("@Notes", quote.Notes)

                        conn.Execute(Helpers.StoredProcedures.SP_QUOTATION_UPSERT, p, transaction:=trans, commandType:=CommandType.StoredProcedure)
                        Dim newId = p.Get(Of Integer)("@QuoteID")

                        ' Delete old details if updating
                        If quote.QuoteID > 0 Then
                            Dim pDel As New DynamicParameters()
                            pDel.Add("@QuoteID", newId)
                            conn.Execute(Helpers.StoredProcedures.SP_QUOTATIONDETAILS_DELETEBYQUOTEID, pDel, transaction:=trans, commandType:=CommandType.StoredProcedure)
                        End If

                        ' Insert new details
                        For Each detail In quote.Details
                            Dim pDet As New DynamicParameters()
                            pDet.Add("@QuoteID", newId)
                            pDet.Add("@ProductID", detail.ProductID)
                            pDet.Add("@QuotedPrice", detail.QuotedPrice)
                            pDet.Add("@Quantity", detail.Quantity)
                            conn.Execute(Helpers.StoredProcedures.SP_QUOTATIONDETAILS_INSERT, pDet, transaction:=trans, commandType:=CommandType.StoredProcedure)
                        Next

                        trans.Commit()
                        Return newId
                    Catch ex As Exception
                        trans.Rollback()
                        Throw New Exception("Error saving quotation: " & ex.Message)
                    End Try
                End Using
            End Using
        End Function

        Public Sub DeleteQuote(quoteId As Integer)
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@QuoteID", quoteId)
                    conn.Execute(Helpers.StoredProcedures.SP_QUOTATION_DELETE, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Throw New Exception("Error deleting quotation: " & ex.Message)
            End Try
        End Sub

        ' This is the critical function used by SalesInvoiceViewModel to check for a custom quoted price
        Public Function GetActiveQuotePrice(partnerId As Integer, productId As Integer) As Decimal?
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PartnerID", partnerId)
                    p.Add("@ProductID", productId)
                    ' Returns a scalar value or null if nothing is found
                    Return conn.QueryFirstOrDefault(Of Decimal?)(Helpers.StoredProcedures.SP_QUOTATION_GETACTIVEPRICE, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                ' Silent failure, fallback to default price if error occurs
                Return Nothing
            End Try
        End Function

    End Class
End Namespace
