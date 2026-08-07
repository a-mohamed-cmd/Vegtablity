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

    ' ─── حالة الترقيم عبر الصفحات ───────────────────────
    Private _currentItemIndex As Integer
    Private _currentPageNumber As Integer
    Private _totalPages As Integer
    Private _currencySymbol As String = "دينار كويتي"
    Private _companyInfo As Models.CompanyInfo
    Private _useDetailedDesign As Boolean = False

    ' ─── ثوابت التخطيط (سنتيمتر → مم بضربها × 10) ──
    Private Const ITEM_START_CM As Single = 7.0F   ' بداية جدول الأصناف
    Private Const ITEM_END_CM As Single = 22.0F    ' نهاية جدول الأصناف
    Private Const ROW_H_MM As Single = 5.0F        ' ارتفاع الصف
    Private Const PAGE_W_MM As Single = 210.0F     ' عرض الصفحة (21 سم)

    ' عدد الأصناف في الصفحة
    Private Shared ReadOnly ITEMS_PER_PAGE As Integer = CInt(Math.Floor((ITEM_END_CM - ITEM_START_CM) * 10 / ROW_H_MM))

    ' ══════════════════════════════════════════════════════
    '  نقطة الدخول الرئيسية
    ' ══════════════════════════════════════════════════════
    Public Sub PrintSalesInvoice(reportData As Models.InvoiceReportData)
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

        Try
            Dim svc As New Services.SettingsService()
            Dim company = svc.GetCompanyInfo()
            If company IsNot Nothing Then
                _companyInfo = company
                If Not String.IsNullOrWhiteSpace(company.CurrencySymbol) Then
                    _currencySymbol = company.CurrencySymbol
                End If
                _useDetailedDesign = company.UseDetailedInvoiceDesign
            End If
        Catch ex As Exception
            ' Fallback if DB not ready
        End Try

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

    ' ══════════════════════════════════════════════════════
    '  حدث رسم الصفحة
    ' ══════════════════════════════════════════════════════
    Private Sub OnPrintPage(sender As Object, e As PrintPageEventArgs)
        Try
            e.Graphics.PageUnit = GraphicsUnit.Millimeter

            Dim g As Graphics = e.Graphics
            Dim brush As Brush = Brushes.Black

            ' تنسيق النص العادي (من اليسار)
            Dim fLeft As New StringFormat() With {.Alignment = StringAlignment.Near}

            ' تنسيق النص العربي (من اليمين) - مهم لعرض العربية صحيحاً
            Dim fRight As New StringFormat() With {
                .Alignment = StringAlignment.Far,
                .FormatFlags = StringFormatFlags.DirectionRightToLeft
            }

            ' تنسيق توسيط
            Dim fCtr As New StringFormat() With {
                .Alignment = StringAlignment.Center,
                .LineAlignment = StringAlignment.Center
            }

            ' دوال تحويل سم → مم
            Dim gl As Func(Of Single, Single) = Function(cm) cm * 10.0F   ' X
            Dim gt As Func(Of Single, Single) = Function(cm) cm * 10.0F   ' Y

            ' قلم نحيف بسمك 1 بكسل (Cosmetic Pen)
            Using p1 As New Pen(Color.Black, 0.0F)
                If _useDetailedDesign Then
                    ' ─────────────────────────────────────────────
                    '  التصميم الجديد (التفصيلي مع خطوط الجدول والشعار الموسط)
                    ' ─────────────────────────────────────────────

                    ' 1. خط أيسر ممتد وهيكل الشعار (موضع الشعار مزاح 20 مم لليمين ومكبر بمقدار 2)
                    g.DrawLine(p1, 10.0F, 18.0F, 32.0F, 18.0F)

                    If _companyInfo IsNot Nothing AndAlso _companyInfo.Logo IsNot Nothing AndAlso _companyInfo.Logo.Length > 0 Then
                        Try
                            Using ms As New System.IO.MemoryStream(_companyInfo.Logo)
                                Using img As Image = Image.FromStream(ms)
                                    Using bmp As New Bitmap(img)
                                        bmp.MakeTransparent()
                                        g.DrawImage(bmp, New RectangleF(33.0F, 9.0F, 18.0F, 18.0F))
                                    End Using
                                End Using
                            End Using
                        Catch ex As Exception
                        End Try
                    End If

                    ' اسم الشركة المختصر بالإنجليزية بجوار الشعار مباشرة
                    Dim abbrevFont As New Font("Arial", 14, System.Drawing.FontStyle.Bold)
                    g.DrawString("I.G.C", abbrevFont, brush, New RectangleF(53.0F, 14.5F, 16.0F, 6.0F), fLeft)

                    ' 2. اسم وعنوان الشركة والخط الأفقي على نفس السطر
                    If _companyInfo IsNot Nothing Then
                        ' تنسيق عربي محاذى لأقصى اليمين (Near + RTL) لتفادي الانعكاس البرمجي لـ Far في GDI+
                        Dim fCompanyRight As New StringFormat() With {
                            .Alignment = StringAlignment.Near,
                            .FormatFlags = StringFormatFlags.DirectionRightToLeft
                        }

                        Dim companyNameFont As New Font("Arial", 16, System.Drawing.FontStyle.Bold)
                        g.DrawString(_companyInfo.CompanyName, companyNameFont, brush, New RectangleF(75.0F, 9.0F, 125.0F, 8.0F), fCompanyRight)

                        ' خط أفقي على نفس سطر الشعار يبدأ بعد الاسم المختصر
                        g.DrawLine(p1, 70.0F, 18.0F, 200.0F, 18.0F)
                        
                        If Not String.IsNullOrWhiteSpace(_companyInfo.Address) Then
                            Dim addressFont As New Font("Arial", 11, System.Drawing.FontStyle.Bold)
                            Using orangeBrush As New SolidBrush(Color.FromArgb(220, 53, 69)) ' لون أحمر برتقالي متناسق
                                g.DrawString(_companyInfo.Address, addressFont, orangeBrush, New RectangleF(75.0F, 20.0F, 125.0F, 6.0F), fCompanyRight)
                            End Using
                        End If

                        ' خط أفقي ثانٍ أسفل العنوان بعرض الصفحة ينقطع عند الشعار (Y = 27.0 مم)
                        g.DrawLine(p1, 10.0F, 27.0F, 32.0F, 27.0F)
                        g.DrawLine(p1, 52.0F, 27.0F, 200.0F, 27.0F)
                    End If

                    ' 3. عنوان الفاتورة
                    g.FillRectangle(Brushes.WhiteSmoke, 10.0F, 41.0F, 190.0F, 7.0F)
                    g.DrawRectangle(p1, 10.0F, 41.0F, 190.0F, 7.0F)
                    Dim titleFont As New Font("Arial", 11, System.Drawing.FontStyle.Bold)
                    g.DrawString("فاتورة مبيعات / SALES INVOICE", titleFont, brush, New RectangleF(10.0F, 41.0F, 190.0F, 7.0F), fCtr)

                    ' 4. صناديق بيانات العميل والفاتورة (تبديل اليمين واليسار مع إدراج الحساب باليسار)
                    g.DrawRectangle(p1, 10.0F, 50.0F, 92.5F, 20.0F)
                    g.DrawRectangle(p1, 107.5F, 50.0F, 92.5F, 20.0F)

                    ' اليسار: اسم العميل والنوع والملحوظات (محاذاة لليمين)
                    Dim rectCustName As New RectangleF(12.0F, 52.0F, 88.5F, 5.0F)
                    g.DrawString("العميل: " & If(_reportData.Header.PartnerName, ""), _printFontBold, brush, rectCustName, fRight)

                    ' نوع الفاتورة / (cash أو credit)
                    Dim isCash As Boolean = (_reportData.Header.Remainder <= 0)
                    Dim paymentTypeText As String = If(isCash, "cash", "credit")
                    Dim rectPaymentType As New RectangleF(12.0F, 57.0F, 88.5F, 5.0F)
                    g.DrawString("نوع الفاتورة / " & paymentTypeText, _printFontBold, brush, rectPaymentType, fRight)

                    If Not String.IsNullOrWhiteSpace(_reportData.Header.Notes) Then
                        Dim rectNotesText As New RectangleF(12.0F, 62.0F, 88.5F, 7.0F)
                        g.DrawString("ملاحظات: " & _reportData.Header.Notes, _printFontNormal, brush, rectNotesText, fRight)
                    End If

                    ' اليمين: رقم وتاريخ الفاتورة ورقم الحساب (محاذاة لليسار)
                    g.DrawString("Invoice No: " & _reportData.Header.InvID.ToString(), _printFontBold, brush, 110.5F, 52.0F, fLeft)
                    g.DrawString("Invoice Date: " & _reportData.Header.InvDate.ToString("dd/MM/yyyy"), _printFontNormal, brush, 110.5F, 57.0F, fLeft)
                    g.DrawString("Account No: " & If(_reportData.Header.AccountCode, ""), _printFontNormal, brush, 110.5F, 62.0F, fLeft)

                    ' 5. ترويسة الجدول ورسم حدود الجدول للأصناف (ارتفاع الرأس 10 مم بدلاً من 5 مم)
                    Dim tableHeaderY As Single = gt(7.5F)
                    Dim limitY As Single = gt(ITEM_END_CM) ' 220.0 mm
                    Dim headerHeight As Single = 10.0F
                    g.FillRectangle(Brushes.WhiteSmoke, 10.0F, tableHeaderY, 190.0F, headerHeight)

                    ' رسم الخط الأفقي الفاصل بين الرأس والأسطر
                    g.DrawLine(p1, 10.0F, tableHeaderY + headerHeight, 200.0F, tableHeaderY + headerHeight)

                    Dim colX As Single() = {10.0F, 20.0F, 70.0F, 120.0F, 140.0F, 160.0F, 180.0F, 200.0F}
                    ' رسم الخطوط الرأسية الفاصلة للأعمدة ممتدة من رأس الجدول لأسفل الجدول بالكامل
                    For i As Integer = 1 To colX.Length - 2
                        g.DrawLine(p1, colX(i), tableHeaderY, colX(i), limitY)
                    Next

                    g.DrawString("م / Seq", _printFontNormal, brush, New RectangleF(10.0F, tableHeaderY, 10.0F, headerHeight), fCtr)
                    g.DrawString("Description (EN)", _printFontNormal, brush, New RectangleF(20.0F, tableHeaderY, 50.0F, headerHeight), fCtr)
                    g.DrawString("وصف الصنف / (AR)", _printFontNormal, brush, New RectangleF(70.0F, tableHeaderY, 50.0F, headerHeight), fCtr)
                    g.DrawString("الوحدة / Unit", _printFontNormal, brush, New RectangleF(120.0F, tableHeaderY, 20.0F, headerHeight), fCtr)
                    g.DrawString("الكمية / Qty", _printFontNormal, brush, New RectangleF(140.0F, tableHeaderY, 20.0F, headerHeight), fCtr)
                    g.DrawString("السعر / Price", _printFontNormal, brush, New RectangleF(160.0F, tableHeaderY, 20.0F, headerHeight), fCtr)
                    g.DrawString("الإجمالي / Total", _printFontNormal, brush, New RectangleF(180.0F, tableHeaderY, 20.0F, headerHeight), fCtr)

                    ' 6. رسم الأصناف بالجدول التفصيلي (الأسطر تبدأ بعد 10 مم من ترويسة الجدول)
                    Dim itemsLimitY As Single = limitY - ROW_H_MM ' 215.0 mm
                    Dim curY As Single = gt(8.5F) ' 85.0 mm
                    Dim hasMore As Boolean = False

                    While _currentItemIndex < _reportData.Details.Count
                        If curY + ROW_H_MM > itemsLimitY Then
                            hasMore = True
                            Exit While
                        End If

                        DrawDetailedItemRow(g, brush, fLeft, fRight, fCtr, curY, _reportData.Details(_currentItemIndex), _currentItemIndex + 1)
                        curY += ROW_H_MM
                        _currentItemIndex += 1
                    End While

                    ' 7. رسم إطار الجدول المزدوج (Double Outer Border) بارتفاع ثابت لقصى حد (145 مم)
                    Dim tableHeight As Single = limitY - tableHeaderY
                    g.DrawRectangle(p1, 10.0F, tableHeaderY, 190.0F, tableHeight)
                    g.DrawRectangle(p1, 10.4F, tableHeaderY + 0.4F, 189.2F, tableHeight - 0.8F)

                    ' 7.1. رسم خط أفقي لصف الإجمالي أسفل الجدول (عند 215.0 مم)
                    Dim totalRowY As Single = limitY - ROW_H_MM ' 215.0 mm
                    g.DrawLine(p1, 10.0F, totalRowY, 200.0F, totalRowY)

                    ' كتابة المجموع داخل الصف الأخير من الجدول
                    Dim rectTotalLabel As New RectangleF(10.0F, totalRowY, 170.0F, ROW_H_MM)
                    If Not hasMore Then
                        g.DrawString("الإجمالي / TOTAL", _printFontBold, brush, rectTotalLabel, fRight)
                        g.DrawString(_reportData.Header.TotalAmount.ToString("N3"), _printFontBold, brush, New RectangleF(180.0F, totalRowY, 20.0F, ROW_H_MM), fCtr)
                    Else
                        g.DrawString("يتبع / Continued...", _printFontNormal, brush, rectTotalLabel, fRight)
                    End If

                    ' 8. رسم المجموع والتفقيط في نهاية الصفحة الأخيرة
                    If Not hasMore Then
                        Dim totalBoxY As Single = gt(ITEM_END_CM + 0.2F)
                        g.FillRectangle(Brushes.WhiteSmoke, 10.0F, totalBoxY, 190.0F, 12.0F)

                        ' إطار مزدوج لصندوق الإجماليات
                        g.DrawRectangle(p1, 10.0F, totalBoxY, 190.0F, 12.0F)
                        g.DrawRectangle(p1, 10.4F, totalBoxY + 0.4F, 189.2F, 11.2F)

                        Dim netText As String = $"الصافي الإجمالي: {_reportData.Header.TotalAmount.ToString("N3")} {_currencySymbol}"
                        Dim tafqeet As String = CurrencyToLetters.Convert(_reportData.Header.TotalAmount, _currencySymbol, "", 3)
                        Dim tafqeetText As String = $"فقط {tafqeet} لا غير"

                        g.DrawString(netText, _printFontBold, brush, New RectangleF(12.0F, totalBoxY + 2.0F, 186.0F, 4.0F), fRight)
                        g.DrawString(tafqeetText, _printFontNormal, brush, New RectangleF(12.0F, totalBoxY + 7.0F, 186.0F, 4.0F), fRight)

                        ' 8.1. حقول التوقيعات (اسم وتوقيع البائع والمستلم) أسفل صندوق الإجمالي
                        Dim sigY1 As Single = totalBoxY + 15.0F
                        Dim sigY2 As Single = totalBoxY + 21.0F

                        ' اليمين: البائع (محاذاة لأقصى اليمين)
                        Dim rectSellerName As New RectangleF(107.5F, sigY1, 92.5F, 5.0F)
                        g.DrawString("اسم البائع: ....................................................", _printFontNormal, brush, rectSellerName, fRight)

                        Dim rectSellerSig As New RectangleF(107.5F, sigY2, 92.5F, 5.0F)
                        g.DrawString("توقيع البائع: ..................................................", _printFontNormal, brush, rectSellerSig, fRight)

                        ' اليسار: المستلم (محاذاة لأقصى اليسار)
                        Dim rectBuyerName As New RectangleF(10.0F, sigY1, 92.5F, 5.0F)
                        g.DrawString("اسم المستلم: ..................................................", _printFontNormal, brush, rectBuyerName, fLeft)

                        Dim rectBuyerSig As New RectangleF(10.0F, sigY2, 92.5F, 5.0F)
                        g.DrawString("توقيع المستلم: ..................................................", _printFontNormal, brush, rectBuyerSig, fLeft)
                    End If

                    ' 9. تذييل الشركة موسطاً بالأسفل (يتكرر في كل صفحة)
                    If _companyInfo IsNot Nothing Then
                        g.DrawLine(p1, 10.0F, gt(25.3F), 200.0F, gt(25.3F))
                        Dim footerInfoText As String = $"الهاتف: {If(_companyInfo.Phone, "لا يوجد")}    |    {If(_companyInfo.Email, "لا يوجد")}"
                        g.DrawString(footerInfoText, _printFontNormal, brush, New RectangleF(10.0F, gt(25.5F), 190.0F, 5.0F), fCtr)
                    End If

                    Dim pageText As String = $"صفحة {_currentPageNumber} من {_totalPages}    |    رقم الفاتورة: {_reportData.Header.InvID}"
                    g.DrawString(pageText, _printFontNormal, brush, New RectangleF(10.0F, gt(26.2F), 190.0F, 5.0F), fCtr)

                    ' 10. الانتقال للصفحة التالية
                    If hasMore Then
                        _currentPageNumber += 1
                        e.HasMorePages = True
                    Else
                        e.HasMorePages = False
                    End If

                Else
                    ' ─────────────────────────────────────────────
                    '  التصميم القديم (بدون أي تعديل لتفادي التأثير على الوضع القائم)
                    ' ─────────────────────────────────────────────
                    DrawHeader(g, brush, fLeft, fRight, gl, gt)

                    Dim curY As Single = gt(ITEM_START_CM)
                    Dim limitY As Single = gt(ITEM_END_CM)
                    Dim hasMore As Boolean = False

                    While _currentItemIndex < _reportData.Details.Count
                        If curY + ROW_H_MM > limitY Then
                            hasMore = True
                            Exit While
                        End If

                        DrawItemRow(g, brush, fLeft, fRight, gl, curY, _reportData.Details(_currentItemIndex), _currentItemIndex + 1)
                        curY += ROW_H_MM
                        _currentItemIndex += 1
                    End While

                    Dim footerY As Single = gt(22.5F)
                    If Not hasMore Then
                        g.DrawString(_reportData.Header.TotalAmount.ToString("N3"),
                                     _printFontBold, brush, gl(18.0F), footerY, fLeft)
                        Dim tafqeet As String = CurrencyToLetters.Convert(
                            _reportData.Header.TotalAmount, _currencySymbol, "", 3)
                        Dim rectTafq As New RectangleF(gl(2.5F), footerY, 150.0F, 8.0F)
                        g.DrawString(tafqeet, _printFontBold, brush, rectTafq, fRight)
                    End If

                    Dim pageText As String = $"Invoice No: {_reportData.Header.InvID}    |    صفحة {_currentPageNumber} من {_totalPages}"
                    Dim pageRect As New RectangleF(0, gt(24.7F), PAGE_W_MM, 8.0F)
                    g.DrawString(pageText, _printFontNormal, brush, pageRect, fCtr)

                    If hasMore Then
                        _currentPageNumber += 1
                        e.HasMorePages = True
                    Else
                        e.HasMorePages = False
                    End If
                End If
            End Using

        Catch ex As Exception
            System.Windows.MessageBox.Show("خطأ أثناء الطباعة: " & ex.Message & vbCrLf & ex.StackTrace,
                                           "خطأ طباعة", MessageBoxButton.OK, MessageBoxImage.Error)
        End Try
    End Sub

    ' ══════════════════════════════════════════════════════
    '  رسم ترويسة الفاتورة
    ' ══════════════════════════════════════════════════════
    Private Sub DrawHeader(g As Graphics, brush As SolidBrush, fLeft As StringFormat, fRight As StringFormat,
                           gl As Func(Of Single, Single), gt As Func(Of Single, Single))

        ' اسم العميل (عربي - RTL)
        Dim rectCust As New RectangleF(gl(2.0F), gt(3.0F), 80.0F, 8.0F)
        g.DrawString(If(_reportData.Header.PartnerName, ""), _printfontname, brush, rectCust, fRight)

        ' نوع الفاتورة / Payment Type (في منتصف الصفحة وعلى نفس سطر Invoice No)
        Dim isCash As Boolean = (_reportData.Header.Remainder <= 0)
        Dim paymentTypeText As String = If(isCash, "cash", "credit")
        Dim fCenter As New StringFormat() With {.Alignment = StringAlignment.Center}
        Dim rectPaymentType As New RectangleF(gl(7.0F), gt(5.0F), 70.0F, 8.0F)
        g.DrawString("نوع الفاتورة / " & paymentTypeText, _printFontBold, brush, rectPaymentType, fCenter)

        ' الملاحظات (عربي - RTL) (تحت اسم العميل مباشرة)
        If Not String.IsNullOrWhiteSpace(_reportData.Header.Notes) Then
            Dim rectNotes As New RectangleF(gl(2.0F), gt(4.0F), 100.0F, 8.0F)
            g.DrawString("ملاحظات: " & _reportData.Header.Notes, _printFontNormal, brush, rectNotes, fRight)
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

    ' ══════════════════════════════════════════════════════
    '  رسم صف صنف واحد
    ' ══════════════════════════════════════════════════════
    Private Sub DrawItemRow(g As Graphics, brush As SolidBrush, fLeft As StringFormat, fRight As StringFormat,
                            gl As Func(Of Single, Single), y As Single,
                            item As Models.InvoiceReportItem, seq As Integer)

        ' التسلسل
        g.DrawString(seq.ToString(), _printFontNormal, brush, gl(0.8F), y, fLeft)

        ' ─── عمود الاسم الإنجليزي (3سم → 8.5سم، عرض 55مم) ───
        Dim enName As String = If(item.ProductNameEn, "")
        Dim rectEN As New RectangleF(gl(1.7F), y, 55.0F, ROW_H_MM)
        g.DrawString(enName, _printFontNormal, brush, rectEN, fLeft)

        ' ─── عمود الاسم العربي (8.5سم → 13.5سم، RTL) ─────────
        Dim arName As String = If(item.ProductName, "")
        Dim rectAR As New RectangleF(gl(6.7F), y, 50.0F, ROW_H_MM)
        g.DrawString(arName, _printFontNormal, brush, rectAR, fRight)

        ' الوحدة (عربي - RTL)
        Dim rectUnit As New RectangleF(gl(10.7F), y, 20.0F, ROW_H_MM)
        g.DrawString(If(item.UnitName, ""), _printFontNormal, brush, rectUnit, fRight)

        ' الكمية
        g.DrawString(item.Quantity.ToString("N2"), _printFontNormal, brush, gl(13.2F), y, fLeft)

        ' السعر
        g.DrawString(item.UnitPrice.ToString("N3"), _printFontNormal, brush, gl(15.4F), y, fLeft)

        ' الإجمالي
        g.DrawString(item.TotalPrice.ToString("N3"), _printFontNormal, brush, gl(18.5F), y, fLeft)
    End Sub

    Private Sub DrawDetailedItemRow(g As Graphics, brush As SolidBrush, fLeft As StringFormat, fRight As StringFormat, fCtr As StringFormat,
                                    y As Single, item As Models.InvoiceReportItem, seq As Integer)
        ' Seq
        g.DrawString(seq.ToString(), _printFontNormal, brush, New RectangleF(10.0F, y, 10.0F, ROW_H_MM), fCtr)

        ' EN Name (left-aligned, padding 1mm)
        Dim rectEN As New RectangleF(21.0F, y, 48.0F, ROW_H_MM)
        g.DrawString(If(item.ProductNameEn, ""), _printFontNormal, brush, rectEN, fLeft)

        ' AR Name (right-aligned, padding 1mm, RTL)
        Dim rectAR As New RectangleF(71.0F, y, 48.0F, ROW_H_MM)
        g.DrawString(If(item.ProductName, ""), _printFontNormal, brush, rectAR, fRight)

        ' Unit (centered)
        g.DrawString(If(item.UnitName, ""), _printFontNormal, brush, New RectangleF(120.0F, y, 20.0F, ROW_H_MM), fCtr)

        ' Qty (centered)
        g.DrawString(item.Quantity.ToString("N2"), _printFontNormal, brush, New RectangleF(140.0F, y, 20.0F, ROW_H_MM), fCtr)

        ' Price (centered)
        g.DrawString(item.UnitPrice.ToString("N3"), _printFontNormal, brush, New RectangleF(160.0F, y, 20.0F, ROW_H_MM), fCtr)

        ' Total (centered)
        g.DrawString(item.TotalPrice.ToString("N3"), _printFontNormal, brush, New RectangleF(180.0F, y, 20.0F, ROW_H_MM), fCtr)
    End Sub

End Class

