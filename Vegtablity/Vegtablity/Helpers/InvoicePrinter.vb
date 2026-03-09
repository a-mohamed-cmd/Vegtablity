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
            
            ' Set Paper Size to A4
            ' A4 size in hundredths of an inch is 827 x 1169
            pd.DefaultPageSettings.PaperSize = New PaperSize("A4", 827, 1169)
            
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
            ' 1. Customer Name (Left: X=20, Y=60)
            ' Since it's Arabic, 'Right' alignment is technically standard, but X=20 from Left Margin means we draw at X=20.
            ' However, WPF FlowDirection is RightToLeft. In WinForms GDI+ (PrintDocument), 0,0 is Top-Left.
            ' If the user meant "Right" by the "Left" side due to Arabic physical paper orientation, we might need to adjust.
            ' Let's assume standard GDI+ coordinates: 0,0 is Top-Left of the paper.
            Dim xCustomer As Single = 20
            Dim yHeader As Single = 60
            g.DrawString(_customerName, _printFontBold, brush, xCustomer, yHeader, formatLeft)

            ' 2. Invoice Date (Right side: X=150, Y=60)
            Dim xDate As Single = 150
            g.DrawString(_invoice.InvDate.ToString("dd/MM/yyyy"), _printFontNormal, brush, xDate, yHeader, formatLeft)

            ' 3. Invoice Number (Center: X=105, Y=60) or specific X=60
            ' User mentioned: "في منتصف الصفحه و x=60 طباعه رقم الفاتوره" 
            ' If X=60 is the exact coordinate they want:
            Dim xInvoiceNo As Single = 60
            g.DrawString(_invoice.InvID.ToString(), _printFontBold, brush, xInvoiceNo, yHeader, formatLeft)

            ' If this is a continued page, show a header marker
            If _currentPageNumber > 1 Then
                g.DrawString("(تابع فاتورة رقم " & _invoice.InvID & " - صفحة " & _currentPageNumber & ")", _printFontNormal, brush, 105, yHeader - 10, formatCenter)
            End If

            ' ==========================================
            ' ITEMS DESCRIPTIONS (Grid items)
            ' ==========================================
            ' User requested: "طباعه في جدول اصناف الفاتوره علي بعد x=100"
            ' "طباعه التسلسل للاصناف و كود الصنف barcode , اسم الصنف و الوحده و الكميه و سعر الوحده و المجموع"
            ' Since A4 width is 210mm, X=100 is the middle of the page. They probably meant the table *starts* at Y=100.
            
            Dim currentY As Single = START_Y_ITEMS

            ' Assume a standard distribution of columns across the 210mm width.
            ' GDI+ 0 is left. Arabic reads Right to Left. 
            ' We will draw the columns from Left (smaller X) to Right (larger X)
            Dim colSeq As Single = 15
            Dim colBarcode As Single = 30
            Dim colName As Single = 70
            Dim colUnit As Single = 130
            Dim colQty As Single = 150
            Dim colPrice As Single = 170
            Dim colTotal As Single = 190

            Dim hasMorePages As Boolean = False

            While _currentItemIndex < _invoice.Details.Count
                Dim item = _invoice.Details(_currentItemIndex)
                
                ' If we exceed the page printable area for items, stop and trigger next page
                If currentY > END_Y_ITEMS Then
                    hasMorePages = True
                    Exit While
                End If

                ' Sequence
                g.DrawString((_currentItemIndex + 1).ToString(), _printFontNormal, brush, colSeq, currentY, formatLeft)
                
                ' Barcode
                g.DrawString(If(item.Barcode, ""), _printFontNormal, brush, colBarcode, currentY, formatLeft)
                
                ' Name
                ' Safely assuming ProductName is populated or we need an abstraction
                g.DrawString(item.ProductName, _printFontNormal, brush, colName, currentY, formatLeft)
                
                ' Unit (Static "حبه" for now or mapped if exist)
                g.DrawString("حبة", _printFontNormal, brush, colUnit, currentY, formatLeft)
                
                ' Qty
                g.DrawString(item.Quantity.ToString("N2"), _printFontNormal, brush, colQty, currentY, formatLeft)
                
                ' Price
                g.DrawString(item.UnitPrice.ToString("N2"), _printFontNormal, brush, colPrice, currentY, formatLeft)
                
                ' Total
                g.DrawString(item.TotalPrice.ToString("N2"), _printFontNormal, brush, colTotal, currentY, formatLeft)

                currentY += ROW_HEIGHT
                _currentItemIndex += 1
            End While

            ' ==========================================
            ' FOOTER SECTION
            ' ==========================================
            ' If there are more pages, print "Continued..."
            If hasMorePages Then
                g.DrawString("... يتبع في الصفحة التالية ...", _printFontBold, brush, 105, END_Y_ITEMS + 10, formatCenter)
                e.HasMorePages = True
                _currentPageNumber += 1
            Else
                ' If this is the final page, print the Totals
                ' "علي بعد x= طول الصفحه -60"  (Y = 297 - 60 = 237)
                Dim yTotal As Single = 237
                
                ' Total Amount Numeric
                g.DrawString(_invoice.TotalAmount.ToString("N3"), _printFontBold, brush, colTotal, yTotal, formatLeft)
                
                ' Arabic Text (Tafqeet)
                Dim textAmount As String = CurrencyToLetters.Convert(_invoice.TotalAmount, "دينار كويتي", "فلس")
                g.DrawString(textAmount, _printFontBold, brush, colName, yTotal, formatRight)

                e.HasMorePages = False
            End If
        End Sub
    End Class
