Imports Dapper
Imports System.Data
Imports Vegtablity.Models

Namespace Services
    Public Class PurchaseQuoteService
        Private ReadOnly db As New DatabaseHelper()

        Public Function GetAllQuotes(Optional searchText As String = Nothing) As List(Of PurchaseQuoteHeader)
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@SearchText", searchText)
                    Return conn.Query(Of PurchaseQuoteHeader)(Helpers.StoredProcedures.SP_PURCHASEQUOTE_GETALL, p, commandType:=CommandType.StoredProcedure).ToList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error retrieving purchase quotations: " & ex.Message)
            End Try
        End Function

        Public Function GetQuotesByPartner(partnerID As Integer) As List(Of PurchaseQuoteHeader)
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PartnerID", partnerID)
                    Return conn.Query(Of PurchaseQuoteHeader)(Helpers.StoredProcedures.SP_PURCHASEQUOTE_GETBYPARTNER, p, commandType:=CommandType.StoredProcedure).ToList()
                End Using
            Catch ex As Exception
                Return New List(Of PurchaseQuoteHeader)()
            End Try
        End Function

        Public Function GetQuoteDetails(quoteId As Integer) As List(Of PurchaseQuoteDetail)
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PurchaseQuoteID", quoteId)
                    Return conn.Query(Of PurchaseQuoteDetail)(Helpers.StoredProcedures.SP_PURCHASEQUOTE_GETDETAILS, p, commandType:=CommandType.StoredProcedure).ToList()
                End Using
            Catch ex As Exception
                Throw New Exception("Error retrieving purchase quote details: " & ex.Message)
            End Try
        End Function

        Public Function SaveQuote(quote As PurchaseQuoteHeader) As Integer
            Try
                Using conn = db.GetConnection()
                    Dim detailsXml = ConvertDetailsToXml(quote.Details)
                    
                    Dim p As New DynamicParameters()
                    p.Add("@PurchaseQuoteID", quote.PurchaseQuoteID)
                    p.Add("@PartnerID", quote.PartnerID)
                    p.Add("@QuoteDate", quote.QuoteDate)
                    p.Add("@ExpiryDate", quote.ExpiryDate)
                    p.Add("@Notes", quote.Notes)
                    p.Add("@DetailsXml", detailsXml, dbType:=DbType.Xml)

                    ' الإجراء يقوم بالإرجاع باستخدام SELECT @PurchaseQuoteID
                    Return conn.QueryFirstOrDefault(Of Integer)(Helpers.StoredProcedures.SP_PURCHASEQUOTE_SAVE, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Throw New Exception("Error saving purchase quotation: " & ex.Message)
            End Try
        End Function

        Public Sub DeleteQuote(quoteId As Integer)
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PurchaseQuoteID", quoteId)
                    conn.Execute(Helpers.StoredProcedures.SP_PURCHASEQUOTE_DELETE, p, commandType:=CommandType.StoredProcedure)
                End Using
            Catch ex As Exception
                Throw New Exception("Error deleting purchase quotation: " & ex.Message)
            End Try
        End Sub

        Public Function GetQuotesPaged(pageNumber As Integer, pageSize As Integer, Optional searchText As String = Nothing) As PagedResult(Of PurchaseQuoteHeader)
            Dim result As New PagedResult(Of PurchaseQuoteHeader)()
            Try
                Using conn = db.GetConnection()
                    Dim p As New DynamicParameters()
                    p.Add("@PageNumber", pageNumber)
                    p.Add("@PageSize", pageSize)
                    p.Add("@SearchText", searchText)

                    Using multi = conn.QueryMultiple(Helpers.StoredProcedures.SP_PURCHASEQUOTE_GETPAGED, p, commandType:=CommandType.StoredProcedure)
                        result.TotalCount = multi.Read(Of Integer)().FirstOrDefault()
                        result.Data = multi.Read(Of PurchaseQuoteHeader)().ToList()
                    End Using
                End Using
            Catch ex As Exception
                ' Error handling
            End Try
            Return result
        End Function

        Private Function ConvertDetailsToXml(details As IEnumerable(Of PurchaseQuoteDetail)) As String
            If details Is Nothing Then Return "<Details />"
            
            Dim xml = New System.Text.StringBuilder()
            xml.Append("<Details>")
            For Each item In details
                If item.ProductID > 0 Then
                    xml.AppendFormat("<Item ProductID=""{0}"" UnitPrice=""{1}"" />",
                                     item.ProductID,
                                     item.UnitPrice.ToString("F2", System.Globalization.CultureInfo.InvariantCulture))
                End If
            Next
            xml.Append("</Details>")
            Return xml.ToString()
        End Function
    End Class
End Namespace
