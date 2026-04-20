Imports System.Drawing
Imports System.Drawing.Printing
Imports System.Windows
Imports Vegtablity.Models
Imports Vegtablity.Helpers

Public Class InvoicePrinter

    Private _reportData As Vegtablity.Models.InvoiceReportData
    Private _printFontNormal As Font
    Private _printFontBold As Font
    Private _printfontname As Font

    ' ─── حالة الترقيم عبر الصفحات ───────────────────
    Private _currentItemIndex As Integer
    Private _currentPageNumber As Integer
    Private _totalPages As Integer

    ' ─── ثوابت التخطيط (سنتيمتر → مم بضربها × 10) ──
    Private Const ITEM_START_CM As Single = 7.0F   ' بداية جدول الأصناف
    Private Const ITEM_END_CM As Single = 22.0F  ' نهاية جدول الأصناف
    Private Const ROW_H_MM As Single = 5.0F  ' ارتفاع الصف (تم تقليص المسافة)
    Private Const PAGE_W_MM As Single = 210.0F ' عرض الصفحة (21 سم)

    ' عدد الأصناف في الصفحة = (22-7)*10 / 7 = ~21
    Private Shared ReadOnly ITEMS_PER_PAGE As Integer = CInt(Math.Floor((ITEM_END_CM - ITEM_START_CM) * 10 / ROW_H_MM))

    ' ══════════════════════════════════════════════════
    '  نقطة الدخول الرئيسية
    ' ══════════════════════════════════════════════════
    Public Sub PrintSalesInvoice(reportData As Vegtablity.Models.InvoiceReportData)
        If reportData Is Nothing OrElse reportData.Header Is Nothing OrElse
           reportData.Details Is Nothing OrElse reportData.Details.Count = 0 Then
            MessageBox.Show("لا يوجد بيانات لطباعتها.", "خطأ طباعة",
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
        pd.DefaultPageSettings.PaperSize = New PaperSize("Custom", 827, 1102)  ' 21×28 سم
        AddHandler pd.PrintPage, AddressOf OnPrintPage

        Dim dlg As New System.Windows.Forms.PrintDialog()
        dlg.Document = pd
        If dlg.ShowDialog() = System.Windows.Forms.DialogResult.OK Then
            Try
                pd.Print()
            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء الطباعة: " & ex.Message,
                                "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End If
    End Sub

    ' ══════════════════════════════════════════════════
    '  حدث رسم الصفحة
    ' ══════════════════════════════════════════════════
    Private Sub OnPrintPage(sender As Object, e As PrintPageEventArgs)
        Try
            e.Graphics.PageUnit = GraphicsUnit.Millimeter

            Dim g As Graphics = e.Graphics
            Dim brush As Brush = Brushes.Black
            Dim fLeft As New StringFormat() With {.Alignment = StringAlignment.Near}
            Dim fCtr As New StringFormat() With {.Alignment = StringAlignment.Center,
                                                    .LineAlignment = StringAlignment.Center}

            ' دوال تحويل سم → مم
            Dim gl As Func(Of Single, Single) = Function(cm) cm * 10.0F   ' X
            Dim gt As Func(Of Single, Single) = Function(cm) cm * 10.0F   ' Y

            ' ─── ترويسة الفاتورة (تتكرر في كل صفحة) ────────
            DrawHeader(g, brush, fLeft, gl, gt)

            ' ─── جدول الأصناف ────────────────────────────────
            Dim curY As Single = gt(ITEM_START_CM)
            Dim limitY As Single = gt(ITEM_END_CM)
            Dim hasMore As Boolean = False

            While _currentItemIndex < _reportData.Details.Count
                ' هل تجاوزنا حد 22 سم؟
                If curY + ROW_H_MM > limitY Then
                    hasMore = True
                    Exit While
                End If

                DrawItemRow(g, brush, fLeft, gl, curY, _reportData.Details(_currentItemIndex), _currentItemIndex + 1)
                curY += ROW_H_MM
                _currentItemIndex += 1
            End While

            ' ─── تذييل الصفحة (25 سم) ────────────────────────
            Dim footerY As Single = gt(22.5F)

            ' المجموع فقط في الصفحة الأخيرة
            If Not hasMore Then
                g.DrawString(_reportData.Header.TotalAmount.ToString("N3"),
                             _printFontBold, brush, gl(18.0F), footerY, fLeft)
                Dim tafqeet As String = CurrencyToLetters.Convert(
                    _reportData.Header.TotalAmount, "دينار كويتي", "فلس")
                g.DrawString(tafqeet, _printFontBold, brush, gl(2.5F), footerY, fLeft)
            End If

            ' ─── رقم الصفحة + رقم الفاتورة في المنتصف ────────
            Dim pageText As String = $"Invoice No: {_reportData.Header.InvID}    |    صفحة {_currentPageNumber} من {_totalPages}"
            Dim pageRect As New RectangleF(0, gt(24.7F), PAGE_W_MM, 8.0F)
            g.DrawString(pageText, _printFontNormal, brush, pageRect, fCtr)

            ' ─── هل هناك صفحات أخرى؟ ─────────────────────────
            If hasMore Then
                _currentPageNumber += 1
                e.HasMorePages = True
            Else
                e.HasMorePages = False
            End If

        Catch ex As Exception
            System.Windows.MessageBox.Show("خطأ أثناء الطباعة: " & ex.Message & vbCrLf & ex.StackTrace,
                                           "خطأ طباعة", MessageBoxButton.OK, MessageBoxImage.Error)
        End Try
    End Sub

    ' ══════════════════════════════════════════════════
    '  رسم ترويسة الفاتورة
    ' ══════════════════════════════════════════════════
    Private Sub DrawHeader(g As Graphics, brush As SolidBrush, fLeft As StringFormat,
                           gl As Func(Of Single, Single), gt As Func(Of Single, Single))
        ' اسم العميل
        Dim rectCust As New RectangleF(gl(2.0F), gt(3.0F), 50.0F, 20.0F)
        g.DrawString(If(_reportData.Header.PartnerName, ""), _printfontname, brush, rectCust, fLeft)

        ' الملاحظات
        If Not String.IsNullOrWhiteSpace(_reportData.Header.Notes) Then
            Dim rectNotes As New RectangleF(gl(2.0F), gt(4.0F), 100.0F, 15.0F)
            g.DrawString("ملاحظات: " & _reportData.Header.Notes, _printFontNormal, brush, rectNotes, fLeft)
        End If

        ' رقم الفاتورة
        g.DrawString("Invoice No:", _printFontNormal, brush, gl(14.5F), gt(3.0F), fLeft)
        g.DrawString(_reportData.Header.InvID.ToString(), _printFontBold, brush, gl(18.0F), gt(3.0F), fLeft)

        ' التاريخ
        g.DrawString("Invoice Date:", _printFontNormal, brush, gl(14.0F), gt(4.0F), fLeft)
        g.DrawString(_reportData.Header.InvDate.ToString("dd/MM/yyyy"), _printFontNormal, brush, gl(18.0F), gt(4.0F), fLeft)

        ' رقم الحساب
        g.DrawString("Account No:", _printFontNormal, brush, gl(14.0F), gt(5.0F), fLeft)
        g.DrawString(If(_reportData.Header.AccountCode, ""), _printFontNormal, brush, gl(18.0F), gt(5.0F), fLeft)
    End Sub

    ' ══════════════════════════════════════════════════
    '  رسم صف صنف واحد
    ' ══════════════════════════════════════════════════
    Private Sub DrawItemRow(g As Graphics, brush As SolidBrush, fLeft As StringFormat,
                            gl As Func(Of Single, Single), y As Single,
                            item As Vegtablity.Models.InvoiceReportItem, seq As Integer)
        ' التسلسل
        g.DrawString(seq.ToString(), _printFontNormal, brush, gl(0.8F), y, fLeft)

        ' ─── عمود الاسم الإنجليزي (3سم → 8.5سم, عرض 55مم) ───
        Dim enName As String = If(item.ProductNameEn, "")
        Dim rectEN As New RectangleF(gl(1.7F), y, 55.0F, ROW_H_MM)
        g.DrawString(enName, _printFontNormal, brush, rectEN, fLeft)

        ' ─── عمود الاسم العربي (8.5سم → 13.5سم, عرض 50مم) ───
        Dim arName As String = If(item.ProductName, "")
        Dim rectAR As New RectangleF(gl(6.7F), y, 50.0F, ROW_H_MM)
        g.DrawString(arName, _printFontNormal, brush, rectAR, fLeft)

        ' الوحدة
        g.DrawString(If(item.UnitName, ""), _printFontNormal, brush, gl(10.7F), y, fLeft)

        ' الكمية
        g.DrawString(item.Quantity.ToString("N2"), _printFontNormal, brush, gl(13.2F), y, fLeft)

        ' السعر
        g.DrawString(item.UnitPrice.ToString("N3"), _printFontNormal, brush, gl(15.4F), y, fLeft)

        ' الإجمالي
        g.DrawString(item.TotalPrice.ToString("N3"), _printFontNormal, brush, gl(18.5F), y, fLeft)
    End Sub

End Class
