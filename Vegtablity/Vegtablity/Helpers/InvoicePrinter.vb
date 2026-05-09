Imports System.Drawing
Imports System.Drawing.Printing
Imports System.Windows
Imports Vegtablity.Models
Imports Vegtablity.Helpers

Public Class InvoicePrinter

    Private _reportData As Models.InvoiceReportData
    Private _printFontNormal As Font
    Private _printFontBold As Font
    Private _printfontname As Font

    ' â”€â”€â”€ Ø­Ø§Ù„Ø© Ø§Ù„ØªØ±Ù‚ÙŠÙ… Ø¹Ø¨Ø± Ø§Ù„ØµÙØ­Ø§Øª â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Private _currentItemIndex As Integer
    Private _currentPageNumber As Integer
    Private _totalPages As Integer

    ' â”€â”€â”€ Ø«ÙˆØ§Ø¨Øª Ø§Ù„ØªØ®Ø·ÙŠØ· (Ø³Ù†ØªÙŠÙ…ØªØ± â†’ Ù…Ù… Ø¨Ø¶Ø±Ø¨Ù‡Ø§ Ã— 10) â”€â”€
    Private Const ITEM_START_CM As Single = 7.0F   ' Ø¨Ø¯Ø§ÙŠØ© Ø¬Ø¯ÙˆÙ„ Ø§Ù„Ø£ØµÙ†Ø§Ù
    Private Const ITEM_END_CM As Single = 22.0F  ' Ù†Ù‡Ø§ÙŠØ© Ø¬Ø¯ÙˆÙ„ Ø§Ù„Ø£ØµÙ†Ø§Ù
    Private Const ROW_H_MM As Single = 5.0F  ' Ø§Ø±ØªÙØ§Ø¹ Ø§Ù„ØµÙ (ØªÙ… ØªÙ‚Ù„ÙŠØµ Ø§Ù„Ù…Ø³Ø§ÙØ©)
    Private Const PAGE_W_MM As Single = 210.0F ' Ø¹Ø±Ø¶ Ø§Ù„ØµÙØ­Ø© (21 Ø³Ù…)

    ' Ø¹Ø¯Ø¯ Ø§Ù„Ø£ØµÙ†Ø§Ù ÙÙŠ Ø§Ù„ØµÙØ­Ø© = (22-7)*10 / 7 = ~21
    Private Shared ReadOnly ITEMS_PER_PAGE As Integer = CInt(Math.Floor((ITEM_END_CM - ITEM_START_CM) * 10 / ROW_H_MM))

    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    '  Ù†Ù‚Ø·Ø© Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©
    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Public Sub PrintSalesInvoice(reportData As Models.InvoiceReportData)
        If reportData Is Nothing OrElse reportData.Header Is Nothing OrElse
           reportData.Details Is Nothing OrElse reportData.Details.Count = 0 Then
            MessageBox.Show("Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø¨ÙŠØ§Ù†Ø§Øª Ù„Ø·Ø¨Ø§Ø¹ØªÙ‡Ø§.", "Ø®Ø·Ø£ Ø·Ø¨Ø§Ø¹Ø©",
                            MessageBoxButton.OK, MessageBoxImage.Warning)
            Return
        End If

        _reportData = reportData
        _currentItemIndex = 0
        _currentPageNumber = 1
        _totalPages = Math.Max(1, CInt(Math.Ceiling(reportData.Details.Count / CDbl(ITEMS_PER_PAGE))))

        _printFontNormal = New Font("Arial", 10, System.Drawing.FontStyle.Bold)
        _printFontBold = New Font("Arial", 10, System.Drawing.FontStyle.Bold)
        _printfontname = New Font("Arial", 12, System.Drawing.FontStyle.Bold)
        Dim pd As New PrintDocument()
        pd.DefaultPageSettings.PaperSize = New PaperSize("Custom", 827, 1102)  ' 21Ã—28 Ø³Ù…
        AddHandler pd.PrintPage, AddressOf OnPrintPage

        Dim dlg As New System.Windows.Forms.PrintDialog()
        dlg.Document = pd
        If dlg.ShowDialog() = System.Windows.Forms.DialogResult.OK Then
            Try
                pd.Print()
            Catch ex As Exception
                MessageBox.Show("Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø·Ø¨Ø§Ø¹Ø©: " & ex.Message,
                                "Ø®Ø·Ø£", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End If
    End Sub

    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    '  Ø­Ø¯Ø« Ø±Ø³Ù… Ø§Ù„ØµÙØ­Ø©
    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Private Sub OnPrintPage(sender As Object, e As PrintPageEventArgs)
        Try
            e.Graphics.PageUnit = GraphicsUnit.Millimeter

            Dim g As Graphics = e.Graphics
            Dim brush As Brush = Brushes.Black
            Dim fLeft As New StringFormat() With {.Alignment = StringAlignment.Near}
            Dim fCtr As New StringFormat() With {.Alignment = StringAlignment.Center,
                                                    .LineAlignment = StringAlignment.Center}

            ' Ø¯ÙˆØ§Ù„ ØªØ­ÙˆÙŠÙ„ Ø³Ù… â†’ Ù…Ù…
            Dim gl As Func(Of Single, Single) = Function(cm) cm * 10.0F   ' X
            Dim gt As Func(Of Single, Single) = Function(cm) cm * 10.0F   ' Y

            ' â”€â”€â”€ ØªØ±ÙˆÙŠØ³Ø© Ø§Ù„ÙØ§ØªÙˆØ±Ø© (ØªØªÙƒØ±Ø± ÙÙŠ ÙƒÙ„ ØµÙØ­Ø©) â”€â”€â”€â”€â”€â”€â”€â”€
            DrawHeader(g, brush, fLeft, gl, gt)

            ' â”€â”€â”€ Ø¬Ø¯ÙˆÙ„ Ø§Ù„Ø£ØµÙ†Ø§Ù â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Dim curY As Single = gt(ITEM_START_CM)
            Dim limitY As Single = gt(ITEM_END_CM)
            Dim hasMore As Boolean = False

            While _currentItemIndex < _reportData.Details.Count
                ' Ù‡Ù„ ØªØ¬Ø§ÙˆØ²Ù†Ø§ Ø­Ø¯ 22 Ø³Ù…ØŸ
                If curY + ROW_H_MM > limitY Then
                    hasMore = True
                    Exit While
                End If

                DrawItemRow(g, brush, fLeft, gl, curY, _reportData.Details(_currentItemIndex), _currentItemIndex + 1)
                curY += ROW_H_MM
                _currentItemIndex += 1
            End While

            ' â”€â”€â”€ ØªØ°ÙŠÙŠÙ„ Ø§Ù„ØµÙØ­Ø© (25 Ø³Ù…) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Dim footerY As Single = gt(22.5F)

            ' Ø§Ù„Ù…Ø¬Ù…ÙˆØ¹ ÙÙ‚Ø· ÙÙŠ Ø§Ù„ØµÙØ­Ø© Ø§Ù„Ø£Ø®ÙŠØ±Ø©
            If Not hasMore Then
                g.DrawString(_reportData.Header.TotalAmount.ToString("N3"),
                             _printFontBold, brush, gl(18.0F), footerY, fLeft)
                Dim tafqeet As String = CurrencyToLetters.Convert(
                    _reportData.Header.TotalAmount, "Ø¯ÙŠÙ†Ø§Ø± ÙƒÙˆÙŠØªÙŠ", "ÙÙ„Ø³")
                g.DrawString(tafqeet, _printFontBold, brush, gl(2.5F), footerY, fLeft)
            End If

            ' â”€â”€â”€ Ø±Ù‚Ù… Ø§Ù„ØµÙØ­Ø© + Ø±Ù‚Ù… Ø§Ù„ÙØ§ØªÙˆØ±Ø© ÙÙŠ Ø§Ù„Ù…Ù†ØªØµÙ â”€â”€â”€â”€â”€â”€â”€â”€
            Dim pageText As String = $"Invoice No: {_reportData.Header.InvID}    |    ØµÙØ­Ø© {_currentPageNumber} Ù…Ù† {_totalPages}"
            Dim pageRect As New RectangleF(0, gt(24.7F), PAGE_W_MM, 8.0F)
            g.DrawString(pageText, _printFontNormal, brush, pageRect, fCtr)

            ' â”€â”€â”€ Ù‡Ù„ Ù‡Ù†Ø§Ùƒ ØµÙØ­Ø§Øª Ø£Ø®Ø±Ù‰ØŸ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            If hasMore Then
                _currentPageNumber += 1
                e.HasMorePages = True
            Else
                e.HasMorePages = False
            End If

        Catch ex As Exception
            System.Windows.MessageBox.Show("Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø·Ø¨Ø§Ø¹Ø©: " & ex.Message & vbCrLf & ex.StackTrace,
                                           "Ø®Ø·Ø£ Ø·Ø¨Ø§Ø¹Ø©", MessageBoxButton.OK, MessageBoxImage.Error)
        End Try
    End Sub

    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    '  Ø±Ø³Ù… ØªØ±ÙˆÙŠØ³Ø© Ø§Ù„ÙØ§ØªÙˆØ±Ø©
    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Private Sub DrawHeader(g As Graphics, brush As SolidBrush, fLeft As StringFormat,
                           gl As Func(Of Single, Single), gt As Func(Of Single, Single))
        ' Ø§Ø³Ù… Ø§Ù„Ø¹Ù…ÙŠÙ„
        Dim rectCust As New RectangleF(gl(2.0F), gt(3.0F), 50.0F, 20.0F)
        g.DrawString(If(_reportData.Header.PartnerName, ""), _printfontname, brush, rectCust, fLeft)

        ' Ø§Ù„Ù…Ù„Ø§Ø­Ø¸Ø§Øª
        If Not String.IsNullOrWhiteSpace(_reportData.Header.Notes) Then
            Dim rectNotes As New RectangleF(gl(2.0F), gt(4.0F), 100.0F, 15.0F)
            g.DrawString("ملحوظاتª: " & _reportData.Header.Notes, _printFontNormal, brush, rectNotes, fLeft)
        End If

        ' Ø±Ù‚Ù… Ø§Ù„ÙØ§ØªÙˆØ±Ø©
        g.DrawString("Invoice No:", _printFontNormal, brush, gl(14.5F), gt(3.0F), fLeft)
        g.DrawString(_reportData.Header.InvID.ToString(), _printFontBold, brush, gl(18.0F), gt(3.0F), fLeft)

        ' Ø§Ù„ØªØ§Ø±ÙŠØ®
        g.DrawString("Invoice Date:", _printFontNormal, brush, gl(14.0F), gt(4.0F), fLeft)
        g.DrawString(_reportData.Header.InvDate.ToString("dd/MM/yyyy"), _printFontNormal, brush, gl(18.0F), gt(4.0F), fLeft)

        ' Ø±Ù‚Ù… Ø§Ù„Ø­Ø³Ø§Ø¨
        g.DrawString("Account No:", _printFontNormal, brush, gl(14.0F), gt(5.0F), fLeft)
        g.DrawString(If(_reportData.Header.AccountCode, ""), _printFontNormal, brush, gl(18.0F), gt(5.0F), fLeft)
    End Sub

    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    '  Ø±Ø³Ù… ØµÙ ØµÙ†Ù ÙˆØ§Ø­Ø¯
    ' â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    Private Sub DrawItemRow(g As Graphics, brush As SolidBrush, fLeft As StringFormat,
                            gl As Func(Of Single, Single), y As Single,
                            item As Models.InvoiceReportItem, seq As Integer)
        ' Ø§Ù„ØªØ³Ù„Ø³Ù„
        g.DrawString(seq.ToString(), _printFontNormal, brush, gl(0.8F), y, fLeft)

        ' â”€â”€â”€ Ø¹Ù…ÙˆØ¯ Ø§Ù„Ø§Ø³Ù… Ø§Ù„Ø¥Ù†Ø¬Ù„ÙŠØ²ÙŠ (3Ø³Ù… â†’ 8.5Ø³Ù…, Ø¹Ø±Ø¶ 55Ù…Ù…) â”€â”€â”€
        Dim enName As String = If(item.ProductNameEn, "")
        Dim rectEN As New RectangleF(gl(1.7F), y, 55.0F, ROW_H_MM)
        g.DrawString(enName, _printFontNormal, brush, rectEN, fLeft)

        ' â”€â”€â”€ Ø¹Ù…ÙˆØ¯ Ø§Ù„Ø§Ø³Ù… Ø§Ù„Ø¹Ø±Ø¨ÙŠ (8.5Ø³Ù… â†’ 13.5Ø³Ù…, Ø¹Ø±Ø¶ 50Ù…Ù…) â”€â”€â”€
        Dim arName As String = If(item.ProductName, "")
        Dim rectAR As New RectangleF(gl(6.7F), y, 50.0F, ROW_H_MM)
        g.DrawString(arName, _printFontNormal, brush, rectAR, fLeft)

        ' Ø§Ù„ÙˆØ­Ø¯Ø©
        g.DrawString(If(item.UnitName, ""), _printFontNormal, brush, gl(10.7F), y, fLeft)

        ' Ø§Ù„ÙƒÙ…ÙŠØ©
        g.DrawString(item.Quantity.ToString("N2"), _printFontNormal, brush, gl(13.2F), y, fLeft)

        ' Ø§Ù„Ø³Ø¹Ø±
        g.DrawString(item.UnitPrice.ToString("N3"), _printFontNormal, brush, gl(15.4F), y, fLeft)

        ' Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ
        g.DrawString(item.TotalPrice.ToString("N3"), _printFontNormal, brush, gl(18.5F), y, fLeft)
    End Sub

End Class

