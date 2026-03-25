Imports System.Drawing
Imports System.Drawing.Printing
Imports System.Windows
Imports Vegtablity.Models
Imports Vegtablity.Helpers

Public Class InvoicePrinter
        Private _invoice As InvoiceHeader
        Private _customerName As String
        Private _printFontNormal As Font
        Private _printFontBold As Font
        Private _printFontHeader As Font

        ' Position tracking for pagination
        Private _currentItemIndex As Integer = 0
        Private _currentPageNumber As Integer = 1

        ' Y-Coordinate for items
        Private Const START_Y_ITEMS As Single = 100 ' mm
        Private Const END_Y_ITEMS As Single = 230 ' mm (Leave space for footer)
        Private Const ROW_HEIGHT As Single = 8 ' mm

        Public Sub PrintSalesInvoice(invoice As InvoiceHeader, customerName As String)
            If invoice Is Nothing OrElse invoice.Details Is Nothing OrElse invoice.Details.Count = 0 Then
                MessageBox.Show("لا يوجد بيانات لطباعتها.", "خطأ طباعة", MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            _invoice = invoice
            _customerName = customerName
            _currentItemIndex = 0
            _currentPageNumber = 1

            ' Fonts (Suitable for Dot Matrix Epson)
            ' Using Arial or Courier New, size defined in Points, but GraphicsUnit is Millimeter
            ' 10pt is generally legible on Dot Matrix
            _printFontNormal = New Font("Arial", 10, System.Drawing.FontStyle.Regular)
            _printFontBold = New Font("Arial", 10, System.Drawing.FontStyle.Bold)
            _printFontHeader = New Font("Arial", 12, System.Drawing.FontStyle.Bold)

            Dim pd As New PrintDocument()
            
            ' Set Paper Size to Custom 21cm x 28cm (Width x Height)
            ' 21cm = 8.27 inches = 827 hundredths
            ' 28cm = 11.02 inches = 1102 hundredths
            pd.DefaultPageSettings.PaperSize = New PaperSize("Custom", 827, 1102)
            
            AddHandler pd.PrintPage, AddressOf PrintPage_PrintSalesInvoice

            ' Show Print Dialog
            Dim printDialog As New System.Windows.Controls.PrintDialog()
            If printDialog.ShowDialog() = True Then
                pd.PrinterSettings.PrinterName = printDialog.PrintQueue.FullName
                Try
                    pd.Print()
                Catch ex As Exception
                    MessageBox.Show("حدث خطأ أثناء الطباعة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Sub PrintPage_PrintSalesInvoice(sender As Object, e As PrintPageEventArgs)
            Try
                ' Set Unit to Millimeter for exact positioning based on user specs
            e.Graphics.PageUnit = GraphicsUnit.Millimeter

            Dim g As Graphics = e.Graphics
            Dim brush As SolidBrush = New SolidBrush(Color.Black)
            Dim formatCenter As New StringFormat() With {.Alignment = StringAlignment.Center, .LineAlignment = StringAlignment.Center}
            Dim formatRight As New StringFormat() With {.Alignment = StringAlignment.Far}
            Dim formatLeft As New StringFormat() With {.Alignment = StringAlignment.Near}

            ' ==========================================
            ' HEADER SECTION (Repeats on every page)
            ' ==========================================
            ' Coordinate Function: Left Margin (User Y in mm) -> GDI X
            Dim getLeft As Func(Of Single, Single) = Function(leftCm) leftCm * 10.0F
            ' Coordinate Function: Top Margin (User X in mm) -> GDI Y
            Dim getTop As Func(Of Single, Single) = Function(topCm) topCm * 10.0F

            ' If this is a continued page, show a header marker
            Dim topOffset As Single = 15.0F
            If _currentPageNumber > 1 Then
                g.DrawString("( مـلـحـق فـاتـورة )", _printFontBold, brush, getLeft(10.5F), topOffset, formatCenter)
            End If

            ' 1. Customer Name (User Y=2cm to 7cm -> Width=50mm)
            Dim rectCustomer As New RectangleF(getLeft(2.0F), getTop(3.0F), 50.0F, 20.0F)
            g.DrawString(If(_customerName, ""), _printFontBold, brush, rectCustomer, formatLeft)

            ' 2. Invoice No (Text at Y=14.5, X=3.0 / Val at Y=18.0, X=3.0)
            g.DrawString("Invoice No:", _printFontNormal, brush, getLeft(14.5F), getTop(3.0F), formatLeft)
            g.DrawString(_invoice.InvID.ToString(), _printFontBold, brush, getLeft(18.0F), getTop(3.0F), formatLeft)

            ' 3. Invoice Date (Text at Y=14.0, X=4.0 / Val at Y=18.0, X=4.0)
            g.DrawString("Invoice Date:", _printFontNormal, brush, getLeft(14.0F), getTop(4.0F), formatLeft)
            g.DrawString(_invoice.InvDate.ToString("dd/MM/yyyy"), _printFontNormal, brush, getLeft(18.0F), getTop(4.0F), formatLeft)

            ' 4. Account No (Text at Y=14.0, X=5.0 / Val at Y=18.0, X=5.0)
            g.DrawString("Account No:", _printFontNormal, brush, getLeft(14.0F), getTop(5.0F), formatLeft)
            g.DrawString(If(String.IsNullOrEmpty(_invoice.AccountCode), "", _invoice.AccountCode), _printFontNormal, brush, getLeft(18.0F), getTop(5.0F), formatLeft)

            ' ==========================================
            ' ITEMS DESCRIPTIONS (Grid items)
            ' ==========================================
            Dim currentY As Single = getTop(7.0F) ' User X=7cm
            Dim endY As Single = getTop(22.0F) ' User X=22cm
            Dim rowHeight As Single = 12.0F

            Dim hasMorePages As Boolean = False

            While _currentItemIndex < _invoice.Details.Count
                Dim item = _invoice.Details(_currentItemIndex)
                
                ' If we exceed the page printable area for items, stop and trigger next page
                If currentY > endY Then
                    hasMorePages = True
                    Exit While
                End If

                ' Sequence (User Y = 1cm)
                g.DrawString((_currentItemIndex + 1).ToString(), _printFontNormal, brush, getLeft(1.0F), currentY, formatLeft)
                
                ' Name & Barcode (Multi-line, User Y = 3cm to 10cm bounds -> Width=7cm)
                Dim rectName As New RectangleF(getLeft(3.0F), currentY, 70.0F, rowHeight + 4)
                Dim enNameStr As String = If(String.IsNullOrEmpty(item.ProductNameEn), "", item.ProductNameEn)
                
                Dim prdName As String = If(item.ProductName, "")
                Dim combinedText As String
                If String.IsNullOrEmpty(enNameStr) Then
                    combinedText = prdName
                Else
                    combinedText = $"{enNameStr}{vbCrLf}{prdName}"
                End If
                
                g.DrawString(combinedText, _printFontNormal, brush, rectName, formatLeft)
                
                ' Unit (User Y = 14cm)
                g.DrawString(If(item.UnitName, "حبة"), _printFontNormal, brush, getLeft(14.0F), currentY, formatLeft)
                
                ' Qty (Interpolated between Unit and Price)
                g.DrawString(item.Quantity.ToString("N2"), _printFontNormal, brush, getLeft(15.25F), currentY, formatLeft)
                
                ' Price (User Y = 16.5cm)
                g.DrawString(item.UnitPrice.ToString("N3"), _printFontNormal, brush, getLeft(16.5F), currentY, formatLeft)
                
                ' Total (User Y = 19cm)
                g.DrawString(item.TotalPrice.ToString("N3"), _printFontNormal, brush, getLeft(19.0F), currentY, formatLeft)

                currentY += rowHeight
                _currentItemIndex += 1
            End While

            ' ==========================================
            ' FOOTER SECTION
            ' ==========================================
            ' If there are more pages, skip total and carry over
            If hasMorePages Then
                e.HasMorePages = True
                _currentPageNumber += 1
            Else
                ' If this is the final page, print the Totals
                Dim yTotal As Single = getTop(23.0F) ' User X=23cm

                ' Total Amount Numeric (User Y=18cm)
                g.DrawString(_invoice.TotalAmount.ToString("N3"), _printFontBold, brush, getLeft(18.0F), yTotal, formatLeft)
                
                ' Arabic Text (Tafqeet) (User Y=12cm)
                Dim textAmount As String = CurrencyToLetters.Convert(_invoice.TotalAmount, "دينار كويتي", "فلس")
                g.DrawString(textAmount, _printFontBold, brush, getLeft(12.0F), yTotal, formatLeft)

                e.HasMorePages = False
            End If

            Catch ex As Exception
                System.Windows.MessageBox.Show("خطأ تفصيلي أثناء إنشاء الفاتورة: " & ex.Message & vbCrLf & ex.StackTrace, "خطأ طباعة", MessageBoxButton.OK, MessageBoxImage.Error)
                e.Cancel = True
            End Try
        End Sub
    End Class
