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
            Try
                ' Convert details to XML for high-performance batch processing
                Dim detailsXml As String = ConvertDetailsToXml(quote.Details)

                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@QuoteID", quote.QuoteID, dbType:=DbType.Int32, direction:=ParameterDirection.InputOutput)
                    p.Add("@PartnerID", quote.PartnerID)
                    p.Add("@QuoteDate", quote.QuoteDate)
                    p.Add("@ExpiryDate", quote.ExpiryDate)
                    p.Add("@IsActive", quote.IsActive)
                    p.Add("@Notes", quote.Notes)
                    p.Add("@DetailsXml", detailsXml, dbType:=DbType.Xml)

                    ' استخدام الإجراء الجديد _XML
                    conn.Execute(Helpers.StoredProcedures.SP_QUOTATION_UPSERT_XML, p, commandType:=CommandType.StoredProcedure)
                    Return p.Get(Of Integer)("@QuoteID")
                End Using
            Catch ex As Exception
                Throw New Exception("Error saving quotation with XML: " & ex.Message)
            End Try
        End Function

        Private Function ConvertDetailsToXml(details As IEnumerable(Of QuoteDetail)) As String
            Dim sb As New Text.StringBuilder()
            sb.Append("<Details>")
            For Each d In details
                If d.ProductID > 0 Then
                    sb.AppendFormat("<Item ProductID=""{0}"" QuotedPrice=""{1}"" />",
                                    d.ProductID,
                                    d.QuotedPrice.ToString("F3", System.Globalization.CultureInfo.InvariantCulture))
                End If
            Next
            sb.Append("</Details>")
            Return sb.ToString()
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
