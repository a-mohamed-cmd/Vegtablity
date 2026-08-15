Imports System.Drawing
Imports System.Drawing.Printing
Imports System.Windows
Imports Vegtablity.Models
Imports Vegtablity.Helpers

Namespace Helpers
    Public Class JournalPrinter

        Private _journal As JournalHeader
        Private _companyInfo As CompanyInfo
        Private _printFontNormal As Font
        Private _printFontBold As Font
        Private _printFontTitle As Font
        Private _printFontHeader As Font
        Private _printFontSmall As Font

        ' ─── Pagination State ───
        Private _currentItemIndex As Integer
        Private _currentPageNumber As Integer
        Private _totalPages As Integer

        ' ─── Layout Constants (in Millimeters) ───
        Private Const MARGIN_X_MM As Single = 10.0F
        Private Const PAGE_W_MM As Single = 210.0F
        Private Const CONTENT_W_MM As Single = 190.0F ' 210 - 20
        Private Const TABLE_START_Y_MM As Single = 72.0F
        Private Const TABLE_BOTTOM_LIMIT_MM As Single = 245.0F
        Private Const ROW_H_MM As Single = 7.0F

        Public Sub PrintJournal(journal As JournalHeader)
            If journal Is Nothing OrElse journal.Details Is Nothing OrElse journal.Details.Count = 0 Then
                MessageBox.Show("لا توجد بيانات أو سطور في القيد لطباعتها.", "تنبيه طباعة",
                                MessageBoxButton.OK, MessageBoxImage.Warning)
                Return
            End If

            _journal = journal
            _currentItemIndex = 0
            _currentPageNumber = 1

            ' حساب عدد السطور الممكنة في كل صفحة
            Dim rowsPerPage = CInt(Math.Floor((TABLE_BOTTOM_LIMIT_MM - TABLE_START_Y_MM) / ROW_H_MM))
            If rowsPerPage <= 0 Then rowsPerPage = 20
            _totalPages = Math.Max(1, CInt(Math.Ceiling(journal.Details.Count / CDbl(rowsPerPage))))

            Try
                Dim svc As New Services.SettingsService()
                _companyInfo = svc.GetCompanyInfo()
            Catch ex As Exception
                _companyInfo = Nothing
            End Try

            _printFontSmall = New Font("Arial", 8, System.Drawing.FontStyle.Regular)
            _printFontNormal = New Font("Arial", 9.5F, System.Drawing.FontStyle.Regular)
            _printFontBold = New Font("Arial", 9.5F, System.Drawing.FontStyle.Bold)
            _printFontHeader = New Font("Arial", 11, System.Drawing.FontStyle.Bold)
            _printFontTitle = New Font("Arial", 14, System.Drawing.FontStyle.Bold)

            Dim pd As New PrintDocument()
            pd.DocumentName = "سند_قيد_" & journal.JournalNo
            pd.DefaultPageSettings.PaperSize = New PaperSize("A4", 827, 1169)
            pd.DefaultPageSettings.Margins = New Margins(25, 25, 25, 25)
            AddHandler pd.PrintPage, AddressOf OnPrintPage

            ' إظهار نافذة إعدادات واختيار الطابعة القياسية
            Dim dlg As New System.Windows.Forms.PrintDialog()
            dlg.Document = pd
            dlg.AllowSomePages = True
            dlg.UseEXDialog = True

            If dlg.ShowDialog() = System.Windows.Forms.DialogResult.OK Then
                Try
                    pd.Print()
                Catch ex As Exception
                    MessageBox.Show("حدث خطأ أثناء إرسال أمر الطباعة إلى الطابعة: " & vbCrLf & ex.Message,
                                    "خطأ في الطباعة", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        Private Sub OnPrintPage(sender As Object, e As PrintPageEventArgs)
            Try
                e.Graphics.PageUnit = GraphicsUnit.Millimeter
                Dim g As Graphics = e.Graphics
                Dim brush As Brush = Brushes.Black

                ' تنسيقات النصوص
                Dim fLeft As New StringFormat() With {.Alignment = StringAlignment.Near, .LineAlignment = StringAlignment.Center}
                Dim fRight As New StringFormat() With {
                    .Alignment = StringAlignment.Far,
                    .LineAlignment = StringAlignment.Center,
                    .FormatFlags = StringFormatFlags.DirectionRightToLeft
                }
                Dim fRightNear As New StringFormat() With {
                    .Alignment = StringAlignment.Near,
                    .LineAlignment = StringAlignment.Center,
                    .FormatFlags = StringFormatFlags.DirectionRightToLeft
                }
                Dim fCenter As New StringFormat() With {
                    .Alignment = StringAlignment.Center,
                    .LineAlignment = StringAlignment.Center
                }

                Using p1 As New Pen(Color.FromArgb(50, 50, 50), 0.2F),
                      pBorder As New Pen(Color.FromArgb(120, 120, 120), 0.3F),
                      pLight As New Pen(Color.FromArgb(220, 220, 220), 0.2F)

                    ' ─────────────────────────────────────────────
                    ' 1. ترويسة الشركة (Company Header)
                    ' ─────────────────────────────────────────────
                    Dim headerY As Single = 10.0F

                    ' شعار الشركة (إذا وجد)
                    If _companyInfo IsNot Nothing AndAlso _companyInfo.Logo IsNot Nothing AndAlso _companyInfo.Logo.Length > 0 Then
                        Try
                            Using ms As New System.IO.MemoryStream(_companyInfo.Logo)
                                Using img As Image = Image.FromStream(ms)
                                    g.DrawImage(img, New RectangleF(MARGIN_X_MM, headerY, 22.0F, 22.0F))
                                End Using
                            End Using
                        Catch
                        End Try
                    End If

                    ' بيانات الشركة من اليمين
                    If _companyInfo IsNot Nothing Then
                        Dim compName = If(String.IsNullOrWhiteSpace(_companyInfo.CompanyName), "مؤسسة تجارية", _companyInfo.CompanyName)
                        g.DrawString(compName, _printFontTitle, brush, New RectangleF(40.0F, headerY, 160.0F, 7.0F), fRightNear)

                        Dim subDetails As String = ""
                        If Not String.IsNullOrWhiteSpace(_companyInfo.Phone) Then subDetails &= "هاتف: " & _companyInfo.Phone & "   "
                        If Not String.IsNullOrWhiteSpace(_companyInfo.Email) Then subDetails &= "البريد: " & _companyInfo.Email

                        If subDetails.Length > 0 Then
                            g.DrawString(subDetails, _printFontSmall, Brushes.DimGray, New RectangleF(40.0F, headerY + 7.5F, 160.0F, 5.0F), fRightNear)
                        End If

                        If Not String.IsNullOrWhiteSpace(_companyInfo.Address) Then
                            g.DrawString("العنوان: " & _companyInfo.Address, _printFontSmall, Brushes.DimGray, New RectangleF(40.0F, headerY + 12.5F, 160.0F, 5.0F), fRightNear)
                        End If
                    End If

                    ' خط فاصل تحت الترويسة
                    g.DrawLine(pBorder, MARGIN_X_MM, 33.0F, MARGIN_X_MM + CONTENT_W_MM, 33.0F)

                    ' ─────────────────────────────────────────────
                    ' 2. عنوان السند (Voucher Title Box)
                    ' ─────────────────────────────────────────────
                    Dim titleBoxY As Single = 36.0F
                    Dim titleBoxH As Single = 8.5F
                    Using bgBrush As New SolidBrush(Color.FromArgb(245, 247, 250))
                        g.FillRectangle(bgBrush, MARGIN_X_MM, titleBoxY, CONTENT_W_MM, titleBoxH)
                    End Using
                    g.DrawRectangle(pBorder, MARGIN_X_MM, titleBoxY, CONTENT_W_MM, titleBoxH)

                    Dim titleText As String = "سند قيد محاسبي  /  JOURNAL VOUCHER"
                    If _journal.IsPosted Then
                        titleText &= " (مرحل)"
                    Else
                        titleText &= " (قيد الانتظار)"
                    End If
                    g.DrawString(titleText, _printFontHeader, brush, New RectangleF(MARGIN_X_MM, titleBoxY, CONTENT_W_MM, titleBoxH), fCenter)

                    ' ─────────────────────────────────────────────
                    ' 3. صناديق بيانات القيد (Journal Metadata)
                    ' ─────────────────────────────────────────────
                    Dim metaY As Single = 47.0F
                    Dim metaH As Single = 20.0F
                    Dim halfW As Single = (CONTENT_W_MM - 4.0F) / 2.0F

                    ' الإطار الأيمن: رقم القيد، التاريخ، المستخدم
                    g.DrawRectangle(pLight, MARGIN_X_MM + halfW + 4.0F, metaY, halfW, metaH)
                    Dim rightBoxX = MARGIN_X_MM + halfW + 4.0F
                    
                    g.DrawString("رقم القيد:", _printFontBold, brush, New RectangleF(rightBoxX + halfW - 28.0F, metaY + 2.0F, 26.0F, 5.0F), fRight)
                    g.DrawString(_journal.JournalNo.ToString(), _printFontBold, Brushes.DarkBlue, New RectangleF(rightBoxX + 4.0F, metaY + 2.0F, halfW - 32.0F, 5.0F), fRight)

                    g.DrawString("التاريخ:", _printFontBold, brush, New RectangleF(rightBoxX + halfW - 28.0F, metaY + 7.5F, 26.0F, 5.0F), fRight)
                    g.DrawString(_journal.JDate.ToString("yyyy/MM/dd"), _printFontNormal, brush, New RectangleF(rightBoxX + 4.0F, metaY + 7.5F, halfW - 32.0F, 5.0F), fRight)

                    Dim statusText = If(_journal.IsPosted, "مرحل للدفتر العام", "مسودة / غير مرحل")
                    g.DrawString("الحالة:", _printFontBold, brush, New RectangleF(rightBoxX + halfW - 28.0F, metaY + 13.0F, 26.0F, 5.0F), fRight)
                    g.DrawString(statusText, _printFontNormal, If(_journal.IsPosted, Brushes.ForestGreen, Brushes.DarkGoldenrod), New RectangleF(rightBoxX + 4.0F, metaY + 13.0F, halfW - 32.0F, 5.0F), fRight)

                    ' الإطار الأيسر: البيان العام للقيد
                    g.DrawRectangle(pLight, MARGIN_X_MM, metaY, halfW, metaH)
                    g.DrawString("البيان العام:", _printFontBold, brush, New RectangleF(MARGIN_X_MM + halfW - 25.0F, metaY + 2.0F, 23.0F, 5.0F), fRight)
                    Dim descRect As New RectangleF(MARGIN_X_MM + 3.0F, metaY + 2.0F, halfW - 28.0F, metaH - 4.0F)
                    Dim fDesc As New StringFormat() With {
                        .Alignment = StringAlignment.Near,
                        .LineAlignment = StringAlignment.Near,
                        .FormatFlags = StringFormatFlags.DirectionRightToLeft
                    }
                    g.DrawString(If(_journal.Description, ""), _printFontNormal, brush, descRect, fDesc)

                    ' ─────────────────────────────────────────────
                    ' 4. ترويسة جدول تفاصيل القيد (Table Header)
                    ' ─────────────────────────────────────────────
                    Dim tableY As Single = TABLE_START_Y_MM
                    Dim tableHeaderH As Single = 8.0F

                    ' تقسيم الأعمدة (المجموع 190 مم)
                    ' [0]: م = 10 مم
                    ' [1]: رقم الحساب = 25 مم
                    ' [2]: اسم الحساب = 45 مم
                    ' [3]: البيان / ملاحظات السطر = 60 مم
                    ' [4]: مدين = 25 مم
                    ' [5]: دائن = 25 مم
                    Dim colW As Single() = {10.0F, 25.0F, 45.0F, 60.0F, 25.0F, 25.0F}
                    Dim colX(6) As Single
                    colX(0) = MARGIN_X_MM
                    For i As Integer = 1 To 6
                        colX(i) = colX(i - 1) + colW(i - 1)
                    Next

                    Using headerBg As New SolidBrush(Color.FromArgb(235, 240, 245))
                        g.FillRectangle(headerBg, MARGIN_X_MM, tableY, CONTENT_W_MM, tableHeaderH)
                    End Using
                    g.DrawRectangle(pBorder, MARGIN_X_MM, tableY, CONTENT_W_MM, tableHeaderH)

                    ' رسم خطوط الأعمدة الرأسية في الرأس
                    For i As Integer = 1 To 5
                        g.DrawLine(pBorder, colX(i), tableY, colX(i), tableY + tableHeaderH)
                    Next

                    g.DrawString("م", _printFontBold, brush, New RectangleF(colX(0), tableY, colW(0), tableHeaderH), fCenter)
                    g.DrawString("رقم الحساب", _printFontBold, brush, New RectangleF(colX(1), tableY, colW(1), tableHeaderH), fCenter)
                    g.DrawString("اسم الحساب", _printFontBold, brush, New RectangleF(colX(2), tableY, colW(2), tableHeaderH), fCenter)
                    g.DrawString("البيان / ملاحظات السطر", _printFontBold, brush, New RectangleF(colX(3), tableY, colW(3), tableHeaderH), fCenter)
                    g.DrawString("مدين (Debit)", _printFontBold, Brushes.Maroon, New RectangleF(colX(4), tableY, colW(4), tableHeaderH), fCenter)
                    g.DrawString("دائن (Credit)", _printFontBold, Brushes.DarkGreen, New RectangleF(colX(5), tableY, colW(5), tableHeaderH), fCenter)

                    ' ─────────────────────────────────────────────
                    ' 5. أسطر تفاصيل القيد (Table Rows)
                    ' ─────────────────────────────────────────────
                    Dim curY As Single = tableY + tableHeaderH
                    Dim seq As Integer = _currentItemIndex + 1
                    Dim hasMorePages As Boolean = False

                    While _currentItemIndex < _journal.Details.Count
                        If curY + ROW_H_MM > TABLE_BOTTOM_LIMIT_MM Then
                            hasMorePages = True
                            Exit While
                        End If

                        Dim detail = _journal.Details(_currentItemIndex)

                        ' تلوين خفيف متبادل للأسطر
                        If _currentItemIndex Mod 2 = 1 Then
                            Using zebraBrush As New SolidBrush(Color.FromArgb(250, 252, 255))
                                g.FillRectangle(zebraBrush, MARGIN_X_MM, curY, CONTENT_W_MM, ROW_H_MM)
                            End Using
                        End If

                        ' رسم إطار السطر والخطوط الفاصلة
                        g.DrawRectangle(pLight, MARGIN_X_MM, curY, CONTENT_W_MM, ROW_H_MM)
                        For i As Integer = 1 To 5
                            g.DrawLine(pLight, colX(i), curY, colX(i), curY + ROW_H_MM)
                        Next

                        ' كتابة البيانات
                        g.DrawString(seq.ToString(), _printFontSmall, brush, New RectangleF(colX(0), curY, colW(0), ROW_H_MM), fCenter)
                        g.DrawString(If(detail.AccountCode, ""), _printFontNormal, brush, New RectangleF(colX(1), curY, colW(1), ROW_H_MM), fCenter)
                        g.DrawString(If(detail.AccountName, ""), _printFontNormal, brush, New RectangleF(colX(2) + 2.0F, curY, colW(2) - 4.0F, ROW_H_MM), fRight)
                        g.DrawString(If(detail.Notes, ""), _printFontSmall, brush, New RectangleF(colX(3) + 2.0F, curY, colW(3) - 4.0F, ROW_H_MM), fRight)

                        Dim debitStr = If(detail.Debit > 0, detail.Debit.ToString("N3"), "-")
                        Dim creditStr = If(detail.Credit > 0, detail.Credit.ToString("N3"), "-")

                        g.DrawString(debitStr, _printFontBold, If(detail.Debit > 0, Brushes.Maroon, Brushes.DarkGray), New RectangleF(colX(4), curY, colW(4), ROW_H_MM), fCenter)
                        g.DrawString(creditStr, _printFontBold, If(detail.Credit > 0, Brushes.DarkGreen, Brushes.DarkGray), New RectangleF(colX(5), curY, colW(5), ROW_H_MM), fCenter)

                        curY += ROW_H_MM
                        seq += 1
                        _currentItemIndex += 1
                    End While

                    ' ─────────────────────────────────────────────
                    ' 6. صندوق الإجماليات (Totals Box - في آخر صفحة فقط)
                    ' ─────────────────────────────────────────────
                    If Not hasMorePages Then
                        Dim totalsH As Single = 8.5F
                        Using totalBg As New SolidBrush(Color.FromArgb(240, 244, 248))
                            g.FillRectangle(totalBg, MARGIN_X_MM, curY, CONTENT_W_MM, totalsH)
                        End Using
                        g.DrawRectangle(pBorder, MARGIN_X_MM, curY, CONTENT_W_MM, totalsH)

                        ' خطوط الأعمدة للإجماليات
                        g.DrawLine(pBorder, colX(4), curY, colX(4), curY + totalsH)
                        g.DrawLine(pBorder, colX(5), curY, colX(5), curY + totalsH)

                        ' كلمة الإجمالي وحالة الاتزان
                        Dim totalDebitVal = _journal.Details.Sum(Function(d) d.Debit)
                        Dim totalCreditVal = _journal.Details.Sum(Function(d) d.Credit)
                        Dim isBalanced = (totalDebitVal = totalCreditVal)
                        Dim balanceMsg = If(isBalanced, "القيد متزن  ✔", "القيد غير متزن ⚠ (الفرق: " & Math.Abs(totalDebitVal - totalCreditVal).ToString("N3") & ")")

                        g.DrawString("الإجمالي العام:  " & balanceMsg, _printFontBold, If(isBalanced, Brushes.DarkSlateGray, Brushes.Crimson), New RectangleF(MARGIN_X_MM + 5.0F, curY, colX(4) - MARGIN_X_MM - 10.0F, totalsH), fRight)

                        g.DrawString(totalDebitVal.ToString("N3"), _printFontBold, Brushes.Maroon, New RectangleF(colX(4), curY, colW(4), totalsH), fCenter)
                        g.DrawString(totalCreditVal.ToString("N3"), _printFontBold, Brushes.DarkGreen, New RectangleF(colX(5), curY, colW(5), totalsH), fCenter)

                        curY += totalsH + 12.0F

                        ' ─────────────────────────────────────────────
                        ' 7. توقيعات الاعتماد (Signatures)
                        ' ─────────────────────────────────────────────
                        Dim sigBoxW As Single = CONTENT_W_MM / 3.0F
                        Dim sigY As Single = 262.0F

                        g.DrawLine(pBorder, MARGIN_X_MM, sigY - 4.0F, MARGIN_X_MM + CONTENT_W_MM, sigY - 4.0F)

                        ' المحاسب
                        g.DrawString("المحاسب المسؤول", _printFontBold, brush, New RectangleF(MARGIN_X_MM + sigBoxW * 2.0F, sigY, sigBoxW, 5.0F), fCenter)
                        g.DrawLine(pLight, MARGIN_X_MM + sigBoxW * 2.0F + 10.0F, sigY + 14.0F, MARGIN_X_MM + sigBoxW * 3.0F - 10.0F, sigY + 14.0F)

                        ' المراجعة المالية
                        g.DrawString("المراجعة والتدقيق", _printFontBold, brush, New RectangleF(MARGIN_X_MM + sigBoxW, sigY, sigBoxW, 5.0F), fCenter)
                        g.DrawLine(pLight, MARGIN_X_MM + sigBoxW + 10.0F, sigY + 14.0F, MARGIN_X_MM + sigBoxW * 2.0F - 10.0F, sigY + 14.0F)

                        ' اعتماد المدير
                        g.DrawString("اعتماد الإدارة المالية / المدير", _printFontBold, brush, New RectangleF(MARGIN_X_MM, sigY, sigBoxW, 5.0F), fCenter)
                        g.DrawLine(pLight, MARGIN_X_MM + 10.0F, sigY + 14.0F, MARGIN_X_MM + sigBoxW - 10.0F, sigY + 14.0F)
                    End If

                    ' ─────────────────────────────────────────────
                    ' 8. تذييل الصفحة ورقم الصفحة
                    ' ─────────────────────────────────────────────
                    Dim footerY As Single = 282.0F
                    Dim printDateStr = "تاريخ الطباعة: " & DateTime.Now.ToString("yyyy/MM/dd HH:mm")
                    Dim pageNumStr = "صفحة " & _currentPageNumber & " من " & _totalPages

                    g.DrawString(printDateStr, _printFontSmall, Brushes.Gray, New RectangleF(MARGIN_X_MM + CONTENT_W_MM - 60.0F, footerY, 60.0F, 5.0F), fRight)
                    g.DrawString(pageNumStr, _printFontSmall, Brushes.Gray, New RectangleF(MARGIN_X_MM, footerY, 60.0F, 5.0F), fLeft)
                    g.DrawString("نظام فيجتابلتي المحاسبي", _printFontSmall, Brushes.LightGray, New RectangleF(MARGIN_X_MM + 60.0F, footerY, CONTENT_W_MM - 120.0F, 5.0F), fCenter)

                    ' هل توجد صفحات أخرى؟
                    If hasMorePages Then
                        _currentPageNumber += 1
                        e.HasMorePages = True
                    Else
                        e.HasMorePages = False
                        _currentItemIndex = 0
                        _currentPageNumber = 1
                    End If
                End Using

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء رسم صفحة الطباعة: " & ex.Message, "خطأ",
                                MessageBoxButton.OK, MessageBoxImage.Error)
                e.HasMorePages = False
            End Try
        End Sub

    End Class
End Namespace
