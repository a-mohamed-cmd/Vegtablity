Imports System.IO
Imports System.Text
Imports PdfSharp.Pdf
Imports PdfSharp.Drawing
Imports PdfSharp
Imports System.Linq
Imports Microsoft.Win32
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports ClosedXML.Excel

Namespace Helpers
    Public Class ReportExporter
        Private Shared ReadOnly fontBold As New XFont("Arial", 11, XFontStyle.Bold)
        Private Shared ReadOnly fontReg As New XFont("Arial", 9, XFontStyle.Regular)
        Private Shared ReadOnly fontSmall As New XFont("Arial", 8, XFontStyle.Regular)
        Private Shared ReadOnly fontLarge As New XFont("Arial", 18, XFontStyle.Bold)
        Private Shared ReadOnly fontTitle As New XFont("Arial", 16, XFontStyle.Bold)
        Private Shared ReadOnly headerFont As New XFont("Arial", 11, XFontStyle.Bold)

        ' Helper to format financial amounts (parentheses for negative)
        Private Shared Function FormatAmount(amt As Decimal) As String
            If amt < 0 Then
                Return "(" & Math.Abs(amt).ToString("N3") & ")"
            Else
                Return amt.ToString("N3")
            End If
        End Function

        ' ===================================================
        ' Export to CSV using StreamWriter (Arabic Support)
        ' ===================================================
        Public Shared Sub ExportToCsv(report As AccountStatementReport, accountName As String, startDate As Date, endDate As Date)
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير إلى CSV"
                dlg.Filter = "CSV Files (*.csv)|*.csv"

                ' Sanitize filename to avoid invalid characters
                Dim safeName = accountName
                For Each c In Path.GetInvalidFileNameChars()
                    safeName = safeName.Replace(c, "_"c)
                Next
                dlg.FileName = "كشف_حساب_" & safeName & "_" & startDate.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                ' Use UTF8 with BOM to ensure Excel opens it correctly with Arabic characters
                Using sw As New StreamWriter(dlg.FileName, False, New UTF8Encoding(True))
                    ' --- Header ---
                    Dim settingsSvc As New SettingsService()
                    Dim company = settingsSvc.GetCompanyInfo()


                    sw.WriteLine("كشف حساب: " & accountName)
                    sw.WriteLine("الفترة: " & startDate.ToString("yyyy/MM/dd") & " - " & endDate.ToString("yyyy/MM/dd"))
                    sw.WriteLine("الرصيد الافتتاحي: " & report.OpeningBalance.ToString("F3"))
                    sw.WriteLine()

                    ' --- Table Headers ---
                    Dim headers = {"#", "التاريخ", "نوع السند", "البيان", "مدين", "دائن", "الرصيد"}
                    sw.WriteLine(String.Join(",", headers))

                    ' --- Data Rows ---
                    For Each item In report.Transactions
                        Dim row = {
                            item.EntryNo.ToString(),
                            item.EntryDate.ToString("yyyy/MM/dd"),
                            """" & If(item.ReferenceType, "").Replace("""", """""") & """",
                            """" & If(item.Description, "").Replace("""", """""") & """",
                            item.DebitAmount.ToString("F3"),
                            item.CreditAmount.ToString("F3"),
                            item.Balance.ToString("F3")
                        }
                        sw.WriteLine(String.Join(",", row))
                    Next

                    ' --- Totals ---
                    sw.WriteLine()
                    Dim totals = {"", "", "", "الإجمالي", report.TotalDebit.ToString("F3"), report.TotalCredit.ToString("F3"), report.EndingBalance.ToString("F3")}
                    sw.WriteLine(String.Join(",", totals))
                End Using

                ' Open the file after saving if it exists
                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                Else
                    MessageBox.Show("عذراً، تعذر العثور على الملف بعد الحفظ.", "خطأ", MessageBoxButton.OK, MessageBoxImage.Warning)
                End If

            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء تصدير ملف CSV: " & vbCrLf & ex.Message, "خطأ في التصدير", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Export to PDF using PdfSharp
        ' ===================================================
        Public Shared Sub ExportToPdf(report As AccountStatementReport, accountName As String, startDate As Date, endDate As Date)
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير إلى PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"

                ' Sanitize PDF filename
                Dim safeName = accountName
                For Each c In Path.GetInvalidFileNameChars()
                    safeName = safeName.Replace(c, "_"c)
                Next
                dlg.FileName = "كشف_حساب_" & safeName & "_" & startDate.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()

                doc.Info.Title = "كشف حساب - " & accountName
                doc.Info.Author = "Vegtablity ERP"

                Dim fontBold = New XFont("Arial", 11, XFontStyle.Bold)
                Dim fontReg = New XFont("Arial", 9, XFontStyle.Regular)
                Dim fontSmall = New XFont("Arial", 8, XFontStyle.Regular)
                Dim fontLarge = New XFont("Arial", 18, XFontStyle.Bold)

                Dim margin = 30.0
                Dim pageCount = 0

                Dim drawHeaderFunc = Function(ByRef p As PdfPage) As XGraphics
                                         Dim g = XGraphics.FromPdfPage(p)
                                         Dim currentY = margin
                                         Dim pWidth = p.Width.Point - margin * 2
                                         pageCount += 1

                                         DrawReportHeader(g, company, p, currentY, margin, pWidth, pageCount)
                                         Return g
                                     End Function

                ' Initial Page
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                page.Orientation = PdfSharp.PageOrientation.Landscape
                Dim gfx = drawHeaderFunc(page)
                Dim pageWidth = page.Width.Point - margin * 2
                Dim y = margin + 80 ' Header height + buffer

                ' Title
                gfx.DrawString(ArabicTextHelper.Fix("Account Statement: " & accountName), New XFont("Arial", 14, XFontStyle.Bold),
                               XBrushes.Black, New XRect(margin, y, pageWidth, 20), XStringFormats.TopLeft)
                y += 22

                gfx.DrawString(ArabicTextHelper.Fix("Period: " & startDate.ToString("yyyy/MM/dd") & " - " & endDate.ToString("yyyy/MM/dd")),
                               fontReg, XBrushes.DarkGray, margin, y)
                y += 16
                gfx.DrawString(ArabicTextHelper.Fix("Opening Balance: " & report.OpeningBalance.ToString("N2")),
                               fontBold, XBrushes.Black, margin, y)
                y += 20

                ' Table header
                Dim cols() As Double = {40, 85, 90, 240, 85, 85, 95}
                Dim headers() As String = {"No.", "Date", "Ref. Type", "Description", "Debit", "Credit", "Balance"}
                Dim headerBrush As New XSolidBrush(XColor.FromArgb(41, 128, 185))

                Dim x = margin
                For i = 0 To headers.Length - 1
                    gfx.DrawRectangle(headerBrush, x, y, cols(i), 18)
                    gfx.DrawString(ArabicTextHelper.Fix(headers(i)), fontBold, XBrushes.White, New XRect(x + 2, y + 2, cols(i) - 4, 16), XStringFormats.TopLeft)
                    x += cols(i)
                Next
                y += 18

                ' Table rows
                Dim altBrush As New XSolidBrush(XColor.FromArgb(248, 249, 250))
                Dim rowIndex = 0
                For Each item In report.Transactions
                    ' Check if we need a new page
                    If y > doc.Pages(0).Height.Point - margin - 60 Then
                        Dim newPage = doc.AddPage()
                        newPage.Size = PdfSharp.PageSize.A4
                        newPage.Orientation = PdfSharp.PageOrientation.Landscape
                        gfx = drawHeaderFunc(newPage)
                        y = margin + 80

                        ' Re-draw table header on new page
                        x = margin
                        For i = 0 To headers.Length - 1
                            gfx.DrawRectangle(headerBrush, x, y, cols(i), 18)
                            gfx.DrawString(ArabicTextHelper.Fix(headers(i)), fontBold, XBrushes.White, New XRect(x + 2, y + 2, cols(i) - 4, 16), XStringFormats.TopLeft)
                            x += cols(i)
                        Next
                        y += 18
                    End If

                    If rowIndex Mod 2 = 0 Then
                        gfx.DrawRectangle(altBrush, margin, y, pageWidth, 16)
                    End If

                    x = margin
                    Dim desc = If(item.Description, "")
                    Dim rowData() As String = {
                        item.EntryNo.ToString(),
                        item.EntryDate.ToString("yyyy/MM/dd"),
                        If(item.ReferenceType, ""),
                        If(desc.Length > 35, desc.Substring(0, 35) & "...", desc),
                        item.DebitAmount.ToString("N2"),
                        item.CreditAmount.ToString("N2"),
                        item.Balance.ToString("N3")
                    }

                    For i = 0 To rowData.Length - 1
                        Dim brush = If(i = 4, New XSolidBrush(XColor.FromArgb(192, 57, 43)),
                                       If(i = 5, New XSolidBrush(XColor.FromArgb(39, 174, 96)),
                                       If(i = 6, New XSolidBrush(XColor.FromArgb(41, 128, 185)), XBrushes.Black)))
                        Dim textFont = If(i = 6, New XFont("Arial", 9, XFontStyle.Bold), fontSmall)
                        gfx.DrawString(ArabicTextHelper.Fix(rowData(i)), textFont, brush, New XRect(x + 2, y + 2, cols(i) - 4, 14), XStringFormats.TopLeft)
                        x += cols(i)
                    Next

                    gfx.DrawRectangle(XPens.LightGray, margin, y, pageWidth, 16)
                    y += 16
                    rowIndex += 1
                Next

                ' Totals row
                y += 5
                If y > doc.Pages(0).Height.Point - margin - 30 Then
                    Dim newPage = doc.AddPage()
                    newPage.Size = PdfSharp.PageSize.A4
                    newPage.Orientation = PdfSharp.PageOrientation.Landscape
                    gfx = drawHeaderFunc(newPage)
                    y = margin + 80
                End If

                Dim totalBrush As New XSolidBrush(XColor.FromArgb(44, 62, 80))
                gfx.DrawRectangle(totalBrush, margin, y, pageWidth, 20)
                x = margin
                Dim totals() As String = {"", "", "", "TOTAL", report.TotalDebit.ToString("N2"), report.TotalCredit.ToString("N2"), report.EndingBalance.ToString("N3")}
                For i = 0 To totals.Length - 1
                    gfx.DrawString(ArabicTextHelper.Fix(totals(i)), fontBold, XBrushes.White, New XRect(x + 2, y + 3, cols(i) - 4, 16), XStringFormats.TopLeft)
                    x += cols(i)
                Next

                doc.Save(dlg.FileName)

                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                Else
                    MessageBox.Show("عذراً، تعذر العثور على الملف بعد الحفظ.", "خطأ", MessageBoxButton.OK, MessageBoxImage.Warning)
                End If

            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء تصدير ملف PDF: " & vbCrLf & ex.Message, "خطأ في التصدير", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Export Single Journal to PDF
        ' ===================================================
        Public Shared Sub ExportJournalToPdf(journal As JournalHeader)
            Try
                If journal Is Nothing Then Return

                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير القيد إلى PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"
                dlg.FileName = "قيد_رقم_" & journal.JournalNo & "_" & DateTime.Now.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()

                doc.Info.Title = "قيد يومية رقم - " & journal.JournalNo

                Dim fontBold = New XFont("Arial", 11, XFontStyle.Bold)
                Dim fontReg = New XFont("Arial", 9, XFontStyle.Regular)
                Dim fontLarge = New XFont("Arial", 16, XFontStyle.Bold)

                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                Dim gfx = XGraphics.FromPdfPage(page)
                Dim margin = 40.0
                Dim width = page.Width.Point - margin * 2
                Dim currentY = margin

                DrawReportHeader(gfx, company, page, currentY, margin, width, 1)

                Dim y = currentY

                ' --- Journal Title ---
                gfx.DrawLine(XPens.DarkGray, margin, y, margin + width, y)
                y += 10
                gfx.DrawString(ArabicTextHelper.Fix("سند قيد يومية رقم: " & journal.JournalNo), fontBold, XBrushes.Black,
                               New XRect(margin, y, width, 20), XStringFormats.TopCenter)
                y += 25

                ' --- Journal Info ---
                gfx.DrawString(ArabicTextHelper.Fix("التاريخ: " & journal.JDate.ToString("yyyy/MM/dd")), fontReg, XBrushes.Black, margin, y)
                y += 15
                gfx.DrawString(ArabicTextHelper.Fix("الوصف: " & journal.Description), fontReg, XBrushes.Black, margin, y)
                y += 25

                ' --- Table Header ---
                Dim cols() As Double = {150, 150, 70, 70}
                Dim headers() As String = {"الحساب", "ملاحظات", "مدين", "دائن"}
                Dim x = margin
                gfx.DrawRectangle(XBrushes.LightGray, margin, y, width, 20)

                ' Sum of columns is 440, but A4 Portrait is ~515 width at 40 margin. Let's adjust.
                cols(0) = width * 0.35 ' Account
                cols(1) = width * 0.35 ' Notes
                cols(2) = width * 0.15 ' Debit
                cols(3) = width * 0.15 ' Credit

                For i = 0 To headers.Length - 1
                    gfx.DrawString(ArabicTextHelper.Fix(headers(i)), fontBold, XBrushes.Black, New XRect(x + 2, y + 2, cols(i) - 4, 16), XStringFormats.TopLeft)
                    x += cols(i)
                Next
                y += 20

                ' --- Table Rows ---
                For Each d In journal.Details
                    x = margin
                    gfx.DrawString(ArabicTextHelper.Fix(d.AccountName), fontReg, XBrushes.Black, New XRect(x + 2, y + 2, cols(0) - 4, 16), XStringFormats.TopLeft)
                    x += cols(0)
                    gfx.DrawString(ArabicTextHelper.Fix(d.Notes), fontReg, XBrushes.Black, New XRect(x + 2, y + 2, cols(1) - 4, 16), XStringFormats.TopLeft)
                    x += cols(1)
                    gfx.DrawString(d.Debit.ToString("N3"), fontReg, XBrushes.Black, New XRect(x + 2, y + 2, cols(2) - 4, 16), XStringFormats.TopRight)
                    x += cols(2)
                    gfx.DrawString(d.Credit.ToString("N3"), fontReg, XBrushes.Black, New XRect(x + 2, y + 2, cols(3) - 4, 16), XStringFormats.TopRight)

                    y += 18
                    gfx.DrawLine(XPens.LightGray, margin, y, margin + width, y)

                    ' Simple page overflow check
                    If y > page.Height.Point - margin - 100 Then
                        page = doc.AddPage()
                        gfx = XGraphics.FromPdfPage(page)
                        y = margin
                    End If
                Next

                ' --- Totals ---
                y += 10
                gfx.DrawRectangle(XBrushes.GhostWhite, margin, y, width, 20)
                gfx.DrawString(ArabicTextHelper.Fix("الإجمالي:"), fontBold, XBrushes.Black, margin + 10, y + 4)

                Dim totalDebit = journal.Details.Sum(Function(d) d.Debit)
                Dim totalCredit = journal.Details.Sum(Function(d) d.Credit)

                gfx.DrawString(totalDebit.ToString("N3"), fontBold, XBrushes.DarkRed, New XRect(margin + width - cols(3) - cols(2), y + 4, cols(2) - 4, 16), XStringFormats.TopRight)
                gfx.DrawString(totalCredit.ToString("N3"), fontBold, XBrushes.DarkGreen, New XRect(margin + width - cols(3), y + 4, cols(3) - 4, 16), XStringFormats.TopRight)

                ' --- Signatures ---
                y += 60
                gfx.DrawString(ArabicTextHelper.Fix("المحاسب: ....................."), fontReg, XBrushes.Black, margin, y)
                gfx.DrawString(ArabicTextHelper.Fix("المدير: ....................."), fontReg, XBrushes.Black, margin + width - 150, y)

                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء طباعة القيد: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Export Trial Balance to CSV
        ' ===================================================
        Public Shared Sub ExportTrialBalanceToCsv(report As TrialBalanceReport, startDate As Date, endDate As Date, isDetailed As Boolean)
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير ميزان المراجعة إلى CSV"
                dlg.Filter = "CSV Files (*.csv)|*.csv"
                dlg.FileName = "ميزان_المراجعة_" & startDate.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Using sw As New StreamWriter(dlg.FileName, False, New UTF8Encoding(True))
                    sw.WriteLine("ميزان المراجعة")
                    sw.WriteLine("الفترة: " & startDate.ToString("yyyy/MM/dd") & " - " & endDate.ToString("yyyy/MM/dd"))
                    sw.WriteLine()

                    ' --- Table Headers ---
                    Dim headers As New List(Of String) From {"كود الحساب", "اسم الحساب", "رصيد أول"}
                    If isDetailed Then
                        headers.Add("مدين الحركة")
                        headers.Add("دائن الحركة")
                    End If
                    headers.Add("رصيد آخر")

                    sw.WriteLine(String.Join(",", headers))

                    ' --- Data Rows ---
                    For Each i In report.Items
                        Dim row As New List(Of String) From {
                            i.AccountCode,
                            """" & i.AccountName & """",
                            i.OpeningBalance.ToString("F3")
                        }
                        If isDetailed Then
                            row.Add(i.PeriodDebit.ToString("F3"))
                            row.Add(i.PeriodCredit.ToString("F3"))
                        End If
                        row.Add(i.EndingBalance.ToString("F3"))

                        sw.WriteLine(String.Join(",", row))
                    Next

                    ' --- Summary ---
                    sw.WriteLine()
                    Dim totals As New List(Of String) From {"", "الإجمالي", report.TotalOpeningBalance.ToString("F3")}
                    If isDetailed Then
                        totals.Add(report.TotalPeriodDebit.ToString("F3"))
                        totals.Add(report.TotalPeriodCredit.ToString("F3"))
                    End If
                    totals.Add(report.TotalEndingBalance.ToString("F3"))
                    sw.WriteLine(String.Join(",", totals))
                End Using

                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                End If

            Catch ex As Exception
                MessageBox.Show("Error: " & ex.Message)
            End Try
        End Sub

        ' ===================================================
        ' Export Trial Balance to PDF (Landscape)
        ' ===================================================
        Public Shared Sub ExportTrialBalanceToPdf(report As TrialBalanceReport, startDate As Date, endDate As Date, isDetailed As Boolean)
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير ميزان المراجعة إلى PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"
                dlg.FileName = "ميزان_المراجعة_" & startDate.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                page.Orientation = PdfSharp.PageOrientation.Landscape
                Dim gfx = XGraphics.FromPdfPage(page)

                Dim fontBold = New XFont("Arial", 11, XFontStyle.Bold)
                Dim fontReg = New XFont("Arial", 9, XFontStyle.Regular)
                Dim fontTitle = New XFont("Arial", 16, XFontStyle.Bold)

                Dim margin = 30.0
                Dim width = page.Width.Point - margin * 2
                Dim currentY = margin
                Dim pageCount = 1

                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()

                DrawReportHeader(gfx, company, page, currentY, margin, width, pageCount)

                Dim y = currentY

                ' --- Title ---
                gfx.DrawString(ArabicTextHelper.Fix("ميزان المراجعة"), fontTitle, XBrushes.Black, New XRect(margin, y, width, 25), XStringFormats.TopCenter)
                y += 30
                gfx.DrawString(ArabicTextHelper.Fix("الفترة: " & startDate.ToString("yyyy/MM/dd") & " - " & endDate.ToString("yyyy/MM/dd")), fontReg, XBrushes.Black, margin, y)
                y += 20

                ' --- Table Header ---
                Dim cols As New List(Of Double) From {width * 0.12, width * 0.35, width * 0.15} ' Code, Name, Opening
                If isDetailed Then
                    cols.Add(width * 0.12) ' Period Dr
                    cols.Add(width * 0.12) ' Period Cr
                End If
                cols.Add(width * 0.14) ' Ending

                Dim headers As New List(Of String) From {"كود الحساب", "اسم الحساب", "رصيد أول"}
                If isDetailed Then
                    headers.Add("مدين الحركة")
                    headers.Add("دائن الحركة")
                End If
                headers.Add("رصيد آخر")

                Dim x = margin
                gfx.DrawRectangle(XBrushes.LightGray, margin, y, width, 20)
                For idx = 0 To headers.Count - 1
                    gfx.DrawString(ArabicTextHelper.Fix(headers(idx)), fontBold, XBrushes.Black, New XRect(x + 5, y + 3, cols(idx) - 10, 16), XStringFormats.TopLeft)
                    x += cols(idx)
                Next
                y += 20

                ' --- Table Body ---
                For Each item In report.Items
                    x = margin
                    gfx.DrawString(item.AccountCode, fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(0) - 10, 16), XStringFormats.TopLeft)
                    x += cols(0)
                    gfx.DrawString(ArabicTextHelper.Fix(item.AccountName), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(1) - 10, 16), XStringFormats.TopLeft)
                    x += cols(1)
                    gfx.DrawString(FormatAmount(item.OpeningBalance), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(2) - 10, 16), XStringFormats.TopRight)
                    x += cols(2)

                    Dim curPos = 3
                    If isDetailed Then
                        gfx.DrawString(FormatAmount(item.PeriodDebit), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(curPos) - 10, 16), XStringFormats.TopRight)
                        x += cols(curPos)
                        curPos += 1
                        gfx.DrawString(FormatAmount(item.PeriodCredit), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(curPos) - 10, 16), XStringFormats.TopRight)
                        x += cols(curPos)
                        curPos += 1
                    End If

                    gfx.DrawString(FormatAmount(item.EndingBalance), fontBold, XBrushes.DarkBlue, New XRect(x + 5, y + 3, cols(headers.Count - 1) - 10, 16), XStringFormats.TopRight)

                    y += 18
                    gfx.DrawLine(XPens.LightGray, margin, y, margin + width, y)

                    ' Page overflow check
                    If y > page.Height.Point - margin - 50 Then
                        page = doc.AddPage()
                        page.Orientation = PdfSharp.PageOrientation.Landscape
                        gfx = XGraphics.FromPdfPage(page)
                        currentY = margin
                        pageCount += 1
                        DrawReportHeader(gfx, company, page, currentY, margin, width, pageCount)
                        y = currentY
                    End If
                Next

                ' --- Summary ---
                y += 10
                gfx.DrawRectangle(XBrushes.GhostWhite, margin, y, width, 22)
                x = margin + cols(0) + cols(1)
                gfx.DrawString(FormatAmount(report.TotalOpeningBalance), fontBold, XBrushes.Black, New XRect(x + 5, y + 4, cols(2) - 10, 16), XStringFormats.TopRight)
                x += cols(2)

                If isDetailed Then
                    gfx.DrawString(FormatAmount(report.TotalPeriodDebit), fontBold, XBrushes.Black, New XRect(x + 5, y + 4, cols(3) - 10, 16), XStringFormats.TopRight)
                    x += cols(3)
                    gfx.DrawString(FormatAmount(report.TotalPeriodCredit), fontBold, XBrushes.Black, New XRect(x + 5, y + 4, cols(4) - 10, 16), XStringFormats.TopRight)
                    x += cols(4)
                End If
                gfx.DrawString(FormatAmount(report.TotalEndingBalance), fontBold, XBrushes.DarkGreen, New XRect(x + 5, y + 4, cols(headers.Count - 1) - 10, 16), XStringFormats.TopRight)

                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})

            Catch ex As Exception
                MessageBox.Show("Error: " & ex.Message)
            End Try
        End Sub

        ' ===================================================
        ' Export Single Payment Voucher (طباعة سند صرف)
        ' ===================================================
        Public Shared Sub ExportPaymentVoucherToPdf(voucher As Voucher)
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "حفظ سند الصرف كـ PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"
                dlg.FileName = "سند_صرف_" & voucher.VoucherNo & "_" & DateTime.Now.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A5
                page.Orientation = PdfSharp.PageOrientation.Landscape
                Dim gfx = XGraphics.FromPdfPage(page)

                Dim margin = 20.0
                Dim width = page.Width.Point - margin * 2
                Dim currentY = margin

                ' 1. Header & Branding
                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()
                DrawReportHeader(gfx, company, page, currentY, margin, width, 1)

                Dim labelFont = New XFont("Arial", 10, XFontStyle.Bold)
                Dim valueFont = New XFont("Arial", 11, XFontStyle.Regular)

                ' 2. Voucher Title & Status
                currentY += 10
                Dim title = "سند صرف"
                gfx.DrawString(ArabicTextHelper.Fix(title), fontTitle, XBrushes.DarkRed, New XRect(margin, currentY, width, 30), XStringFormats.TopCenter)

                ' Status Badge
                Dim statusText = If(voucher.IsPosted, "(Posted)", "(Draft)")
                Dim statusBrush = If(voucher.IsPosted, XBrushes.DarkGreen, XBrushes.Gray)
                gfx.DrawString(ArabicTextHelper.Fix(statusText), labelFont, statusBrush, New XRect(margin + 5, currentY, 150, 20), XStringFormats.TopLeft)

                currentY += 45

                ' 3. Voucher Info Grid

                ' Row 1: No and Date
                gfx.DrawString(ArabicTextHelper.Fix("رقم السند:"), labelFont, XBrushes.Black, New XRect(width - margin - 40, currentY, 50, 20), XStringFormats.TopRight)
                gfx.DrawString(voucher.VoucherNo.ToString(), valueFont, XBrushes.Black, New XRect(width - margin - 150, currentY, 100, 20), XStringFormats.TopRight)

                gfx.DrawString(ArabicTextHelper.Fix("التاريخ:"), labelFont, XBrushes.Black, New XRect(margin, currentY, 50, 20), XStringFormats.TopLeft)
                gfx.DrawString(voucher.VoucherDate.ToString("yyyy/MM/dd"), valueFont, XBrushes.Black, New XRect(margin + 60, currentY, 100, 20), XStringFormats.TopLeft)

                currentY += 30

                ' Row 2: Pay to
                Dim payToLabel = If(Not String.IsNullOrEmpty(voucher.PartnerName), "يصرف للمكرم:", "يصرف لحساب:")
                Dim payToValue = If(Not String.IsNullOrEmpty(voucher.PartnerName), voucher.PartnerName, voucher.AccountName)

                gfx.DrawString(ArabicTextHelper.Fix(payToLabel), labelFont, XBrushes.Black, New XRect(width - margin - 70, currentY, 80, 20), XStringFormats.TopRight)
                gfx.DrawRectangle(XPens.LightGray, margin, currentY - 2, width - 85, 24)
                gfx.DrawString(ArabicTextHelper.Fix(payToValue), valueFont, XBrushes.Black, New XRect(margin + 5, currentY + 2, width - 95, 20), XStringFormats.TopRight)

                currentY += 35

                ' Row 3: Amount
                gfx.DrawString(ArabicTextHelper.Fix("مبلغ وقدره:"), labelFont, XBrushes.Black, New XRect(width - margin - 70, currentY, 80, 20), XStringFormats.TopRight)

                ' Amount Box
                Dim amountRect As New XRect(width - margin - 190, currentY - 5, 110, 30)
                gfx.DrawRectangle(XBrushes.WhiteSmoke, amountRect)
                gfx.DrawRectangle(XPens.Black, amountRect)
                gfx.DrawString(voucher.Amount.ToString("N3"), fontBold, XBrushes.Black, New XRect(width - margin - 185, currentY, 100, 20), XStringFormats.Center)

                ' Amount in Words (Tafqeet) - Centered and Spaced Down
                Dim tafqeet = CurrencyToLetters.Convert(voucher.Amount, "دينار كويتي", "فلس", 3)
                gfx.DrawString(ArabicTextHelper.Fix(tafqeet), fontReg, XBrushes.Black, New XRect(margin, currentY + 12, width, 25), XStringFormats.TopCenter)

                currentY += 50

                ' Row 4: Description
                gfx.DrawString(ArabicTextHelper.Fix("وذلك عن:"), labelFont, XBrushes.Black, New XRect(width - margin - 70, currentY, 80, 20), XStringFormats.TopRight)
                gfx.DrawRectangle(XPens.LightGray, margin, currentY - 2, width - 85, 40)
                gfx.DrawString(ArabicTextHelper.Fix(voucher.Description), fontReg, XBrushes.Black, New XRect(margin + 5, currentY + 2, width - 95, 35), XStringFormats.TopRight)

                currentY += 60

                ' 4. Signatures
                Dim sigY = currentY + 20
                gfx.DrawLine(XPens.Black, margin + 20, sigY, margin + 120, sigY)
                gfx.DrawString(ArabicTextHelper.Fix("المحاسب"), labelFont, XBrushes.Black, New XRect(margin + 20, sigY + 5, 100, 20), XStringFormats.TopCenter)

                gfx.DrawLine(XPens.Black, width - 100 + margin, sigY, width + margin, sigY)
                gfx.DrawString(ArabicTextHelper.Fix("المستلم"), labelFont, XBrushes.Black, New XRect(width - 100 + margin, sigY + 5, 100, 20), XStringFormats.TopCenter)

                ' 5. Save and Close
                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء طباعة السند: " & ex.Message)
            End Try
        End Sub

        ' ===================================================
        ' Export Single Receipt Voucher (طباعة سند قبض)
        ' ===================================================
        Public Shared Sub ExportReceiptVoucherToPdf(voucher As Voucher)
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "حفظ سند القبض كـ PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"
                dlg.FileName = "سند_قبض_" & voucher.VoucherNo & "_" & DateTime.Now.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A5
                page.Orientation = PdfSharp.PageOrientation.Landscape
                Dim gfx = XGraphics.FromPdfPage(page)

                Dim margin = 20.0
                Dim width = page.Width.Point - margin * 2
                Dim currentY = margin

                ' 1. Header & Branding
                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()
                DrawReportHeader(gfx, company, page, currentY, margin, width, 1)

                Dim labelFont = New XFont("Arial", 10, XFontStyle.Bold)
                Dim valueFont = New XFont("Arial", 11, XFontStyle.Regular)

                ' 2. Voucher Title & Status
                currentY += 10
                Dim title = "سند قبض"
                gfx.DrawString(ArabicTextHelper.Fix(title), fontTitle, XBrushes.DarkGreen, New XRect(margin, currentY, width, 30), XStringFormats.TopCenter)

                ' Status Badge
                Dim statusText = If(voucher.IsPosted, "(Posted)", "(Draft)")
                Dim statusBrush = If(voucher.IsPosted, XBrushes.DarkGreen, XBrushes.Gray)
                gfx.DrawString(ArabicTextHelper.Fix(statusText), labelFont, statusBrush, New XRect(margin + 5, currentY, 150, 20), XStringFormats.TopLeft)

                currentY += 45

                ' 3. Voucher Info Grid

                ' Row 1: No and Date
                gfx.DrawString(ArabicTextHelper.Fix("رقم السند:"), labelFont, XBrushes.Black, New XRect(width - margin - 40, currentY, 50, 20), XStringFormats.TopRight)
                gfx.DrawString(voucher.VoucherNo.ToString(), valueFont, XBrushes.Black, New XRect(width - margin - 150, currentY, 100, 20), XStringFormats.TopRight)

                gfx.DrawString(ArabicTextHelper.Fix("التاريخ:"), labelFont, XBrushes.Black, New XRect(margin, currentY, 50, 20), XStringFormats.TopLeft)
                gfx.DrawString(voucher.VoucherDate.ToString("yyyy/MM/dd"), valueFont, XBrushes.Black, New XRect(margin + 60, currentY, 100, 20), XStringFormats.TopLeft)

                currentY += 30

                ' Row 2: Received from
                Dim fromLabel = If(Not String.IsNullOrEmpty(voucher.PartnerName), "استلمنا من المكرم:", "استحقاق لحساب:")
                Dim fromValue = If(Not String.IsNullOrEmpty(voucher.PartnerName), voucher.PartnerName, voucher.AccountName)

                gfx.DrawString(ArabicTextHelper.Fix(fromLabel), labelFont, XBrushes.Black, New XRect(width - margin - 100, currentY, 110, 20), XStringFormats.TopRight)
                gfx.DrawRectangle(XPens.LightGray, margin, currentY - 2, width - 115, 24)
                gfx.DrawString(ArabicTextHelper.Fix(fromValue), valueFont, XBrushes.Black, New XRect(margin + 5, currentY + 2, width - 125, 20), XStringFormats.TopRight)

                currentY += 35

                ' Row 3: Amount
                gfx.DrawString(ArabicTextHelper.Fix("مبلغ وقدره:"), labelFont, XBrushes.Black, New XRect(width - margin - 70, currentY, 80, 20), XStringFormats.TopRight)

                ' Amount Box
                Dim amountRect As New XRect(width - margin - 190, currentY - 5, 110, 30)
                gfx.DrawRectangle(XBrushes.WhiteSmoke, amountRect)
                gfx.DrawRectangle(XPens.Black, amountRect)
                gfx.DrawString(voucher.Amount.ToString("N3"), fontBold, XBrushes.Black, New XRect(width - margin - 185, currentY, 100, 20), XStringFormats.Center)

                ' Amount in Words (Tafqeet) - Centered and Spaced Down
                Dim tafqeet = CurrencyToLetters.Convert(voucher.Amount, "دينار كويتي", "فلس", 3)
                gfx.DrawString(ArabicTextHelper.Fix(tafqeet), fontReg, XBrushes.Black, New XRect(margin, currentY + 12, width, 25), XStringFormats.TopCenter)

                currentY += 50

                ' Row 4: Description
                gfx.DrawString(ArabicTextHelper.Fix("وذلك عن:"), labelFont, XBrushes.Black, New XRect(width - margin - 70, currentY, 80, 20), XStringFormats.TopRight)
                gfx.DrawRectangle(XPens.LightGray, margin, currentY - 2, width - 85, 40)
                gfx.DrawString(ArabicTextHelper.Fix(voucher.Description), fontReg, XBrushes.Black, New XRect(margin + 5, currentY + 2, width - 95, 35), XStringFormats.TopRight)

                currentY += 60

                ' 4. Signatures
                Dim sigY = currentY + 20
                gfx.DrawLine(XPens.Black, margin + 20, sigY, margin + 120, sigY)
                gfx.DrawString(ArabicTextHelper.Fix("المحاسب"), labelFont, XBrushes.Black, New XRect(margin + 20, sigY + 5, 100, 20), XStringFormats.TopCenter)

                gfx.DrawLine(XPens.Black, width - 100 + margin, sigY, width + margin, sigY)
                gfx.DrawString(ArabicTextHelper.Fix("أمين الصندوق"), labelFont, XBrushes.Black, New XRect(width - 100 + margin, sigY + 5, 100, 20), XStringFormats.TopCenter)

                ' 5. Save and Close
                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء طباعة السند: " & ex.Message)
            End Try
        End Sub

        ' ===================================================
        ' Financial Reports PDF Export
        ' ===================================================

        Public Shared Sub ExportProfitLossToPdf(report As FinancialReport, startDate As Date, endDate As Date)
            Try
                Dim dlg As New SaveFileDialog() With {
                    .Filter = "PDF Files (*.pdf)|*.pdf",
                    .FileName = "Profit_Loss_Report_" & DateTime.Now.ToString("yyyyMMdd_HHmm") & ".pdf"
                }

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                Dim gfx = XGraphics.FromPdfPage(page)
                Dim margin As Double = 40
                Dim width = page.Width.Point - (2 * margin)
                Dim currentY As Double = 20

                Dim service As New Services.SettingsService()
                Dim company = service.GetCompanyInfo()

                DrawReportHeader(gfx, company, page, currentY, margin, width, 1)

                ' Title
                gfx.DrawString(ArabicTextHelper.Fix(report.Title), fontTitle, XBrushes.DarkRed, New XRect(margin, currentY, width, 30), XStringFormats.TopCenter)
                currentY += 35
                gfx.DrawString(ArabicTextHelper.Fix("الفترة: " & startDate.ToString("yyyy/MM/dd") & " - " & endDate.ToString("yyyy/MM/dd")), fontReg, XBrushes.Gray, New XRect(margin, currentY, width, 20), XStringFormats.TopCenter)
                currentY += 35

                ' Revenues
                DrawFinancialSection(gfx, "الإيرادات", report.Items.Where(Function(i) i.AccountType = "Revenue").ToList(), currentY, margin, width)

                ' Expenses
                currentY += 20
                DrawFinancialSection(gfx, "المصروفات", report.Items.Where(Function(i) i.AccountType = "Expenses").ToList(), currentY, margin, width)

                ' Net Result
                currentY += 30
                gfx.DrawRectangle(XBrushes.WhiteSmoke, margin, currentY, width, 35)
                gfx.DrawRectangle(XPens.DarkSlateGray, margin, currentY, width, 35)

                Dim netLabel As String = If(report.TotalBalance < 0, "صافي الربح:", "صافي الخسارة:")
                gfx.DrawString(ArabicTextHelper.Fix(netLabel), fontLarge, XBrushes.Black, New XRect(margin + 10, currentY + 7, width, 25), XStringFormats.TopLeft)
                gfx.DrawString(FormatAmount(Math.Abs(report.TotalBalance)), fontLarge, XBrushes.DarkGreen, New XRect(margin, currentY + 7, width - 10, 25), XStringFormats.TopRight)

                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير PDF: " & ex.Message)
            End Try
        End Sub

        Public Shared Sub ExportBalanceSheetToPdf(report As FinancialReport, asOfDate As Date)
            Try
                Dim dlg As New SaveFileDialog() With {
                    .Filter = "PDF Files (*.pdf)|*.pdf",
                    .FileName = "Balance_Sheet_" & DateTime.Now.ToString("yyyyMMdd_HHmm") & ".pdf"
                }

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                Dim gfx = XGraphics.FromPdfPage(page)
                Dim margin As Double = 40
                Dim width = page.Width.Point - (2 * margin)
                Dim currentY As Double = 20

                Dim service As New Services.SettingsService()
                Dim company = service.GetCompanyInfo()

                DrawReportHeader(gfx, company, page, currentY, margin, width, 1)

                ' Title
                gfx.DrawString(ArabicTextHelper.Fix(report.Title), fontTitle, XBrushes.DarkBlue, New XRect(margin, currentY, width, 30), XStringFormats.TopCenter)
                currentY += 35
                gfx.DrawString(ArabicTextHelper.Fix("كما في تاريخ: " & asOfDate.ToString("yyyy/MM/dd")), fontReg, XBrushes.Gray, New XRect(margin, currentY, width, 20), XStringFormats.TopCenter)
                currentY += 35

                ' Assets
                DrawFinancialSection(gfx, "الأصول", report.Items.Where(Function(i) i.AccountType = "Assets").ToList(), currentY, margin, width)

                ' Liabilities
                currentY += 20
                DrawFinancialSection(gfx, "الالتزامات", report.Items.Where(Function(i) i.AccountType = "Liabilities").ToList(), currentY, margin, width)

                ' Equity
                currentY += 20
                DrawFinancialSection(gfx, "حقوق الملكية", report.Items.Where(Function(i) i.AccountType = "Equity").ToList(), currentY, margin, width)

                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير PDF: " & ex.Message)
            End Try
        End Sub

        Private Shared Sub DrawFinancialSection(gfx As XGraphics, title As String, items As List(Of FinancialReportItem), ByRef currentY As Double, margin As Double, width As Double)
            ' Section Header
            gfx.DrawRectangle(XBrushes.AntiqueWhite, margin, currentY, width, 25)
            gfx.DrawString(ArabicTextHelper.Fix(title), headerFont, XBrushes.Black, New XRect(margin + 5, currentY + 5, width, 20), XStringFormats.TopLeft)
            currentY += 25

            ' Table Headers
            gfx.DrawRectangle(XBrushes.LightGray, margin, currentY, 100, 20)
            gfx.DrawString(ArabicTextHelper.Fix("الكود"), fontBold, XBrushes.Black, New XRect(margin, currentY + 3, 100, 20), XStringFormats.TopCenter)

            gfx.DrawRectangle(XBrushes.LightGray, margin + 100, currentY, width - 220, 20)
            gfx.DrawString(ArabicTextHelper.Fix("اسم الحساب"), fontBold, XBrushes.Black, New XRect(margin + 105, currentY + 3, width - 230, 20), XStringFormats.TopLeft)

            gfx.DrawRectangle(XBrushes.LightGray, margin + width - 120, currentY, 120, 20)
            gfx.DrawString(ArabicTextHelper.Fix("المبلغ"), fontBold, XBrushes.Black, New XRect(margin + width - 115, currentY + 3, 110, 20), XStringFormats.TopRight)
            currentY += 20

            ' Items
            Dim total As Decimal = 0
            For Each itm In items
                gfx.DrawString(itm.AccountCode, fontReg, XBrushes.Black, New XRect(margin, currentY + 3, 100, 20), XStringFormats.TopCenter)
                gfx.DrawString(ArabicTextHelper.Fix(itm.AccountName), fontReg, XBrushes.Black, New XRect(margin + 105, currentY + 3, width - 230, 20), XStringFormats.TopLeft)
                gfx.DrawString(FormatAmount(itm.Balance), fontReg, XBrushes.Black, New XRect(margin + width - 115, currentY + 3, 110, 20), XStringFormats.TopRight)

                gfx.DrawLine(XPens.LightGray, margin, currentY + 20, margin + width, currentY + 20)
                currentY += 20
                total += itm.Balance
            Next

            ' Section Total
            gfx.DrawString(ArabicTextHelper.Fix("إجمالي " & title), fontBold, XBrushes.Black, New XRect(margin + 105, currentY + 3, width - 230, 20), XStringFormats.TopLeft)
            gfx.DrawString(FormatAmount(total), fontBold, XBrushes.Black, New XRect(margin + width - 115, currentY + 3, 110, 20), XStringFormats.TopRight)
            currentY += 25
        End Sub

        Public Shared Sub ExportFinancialToCsv(report As FinancialReport)
            Try
                Dim dlg As New SaveFileDialog() With {.Filter = "CSV Files (*.csv)|*.csv", .FileName = report.Title & ".csv"}
                If dlg.ShowDialog() <> True Then Return

                Using sw As New StreamWriter(dlg.FileName, False, System.Text.Encoding.UTF8)
                    ' Header
                    sw.WriteLine(report.Title)
                    If report.StartDate.HasValue Then
                        sw.WriteLine("الفترة: " & report.StartDate.Value.ToString("yyyy/MM/dd") & " - " & report.EndDate.ToString("yyyy/MM/dd"))
                    Else
                        sw.WriteLine("تاريخ: " & report.EndDate.ToString("yyyy/MM/dd"))
                    End If
                    sw.WriteLine()

                    ' Table
                    sw.WriteLine("الكود,اسم الحساب,المبلغ,النوع")
                    For Each itm In report.Items
                        sw.WriteLine(String.Format("{0},{1},{2},{3}",
                            itm.AccountCode,
                            itm.AccountName,
                            itm.Balance.ToString("F3"),
                            itm.AccountType))
                    Next

                    sw.WriteLine()
                    sw.WriteLine("الإجمالي:," & report.TotalBalance.ToString("F3"))
                End Using
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير CSV: " & ex.Message)
            End Try
        End Sub

        ' ===================================================
        ' PDF Branding Helper
        ' ===================================================
        Private Shared Sub DrawReportHeader(gfx As XGraphics, company As CompanyInfo, page As PdfPage, ByRef currentY As Double, margin As Double, pWidth As Double, pageIndex As Integer)
            If company IsNot Nothing Then
                ' 1. Draw Logo
                If company.Logo IsNot Nothing AndAlso company.Logo.Length > 0 Then
                    Try
                        Using ms As New MemoryStream(company.Logo)
                            Dim img = XImage.FromStream(ms)
                            gfx.DrawImage(img, margin, currentY, 60, 60)
                        End Using
                    Catch
                    End Try
                End If

                ' 2. Company Info (Left Aligned)
                Dim textX = margin + 70
                gfx.DrawString(ArabicTextHelper.Fix(company.CompanyName), fontLarge, XBrushes.Black, New XRect(textX, currentY, pWidth - 70, 25), XStringFormats.TopLeft)

                Dim subTextY = currentY + 25
                If Not String.IsNullOrEmpty(company.Address) Then
                    gfx.DrawString(ArabicTextHelper.Fix(company.Address), fontReg, XBrushes.Gray, New XRect(textX, subTextY, pWidth - 70, 15), XStringFormats.TopLeft)
                    subTextY += 15
                End If

                Dim contactInfo = ""
                If Not String.IsNullOrEmpty(company.Phone) Then contactInfo &= "Tel: " & company.Phone & "  "
                If Not String.IsNullOrEmpty(company.Email) Then contactInfo &= "Email: " & company.Email

                If Not String.IsNullOrEmpty(contactInfo) Then
                    gfx.DrawString(ArabicTextHelper.Fix(contactInfo), fontSmall, XBrushes.Gray, New XRect(textX, subTextY, pWidth - 70, 15), XStringFormats.TopLeft)
                End If
            End If

            ' 3. Page Number (Bottom Right of Header)
            gfx.DrawString(ArabicTextHelper.Fix("صفحة: " & pageIndex), fontReg, XBrushes.Black, New XRect(margin, currentY + 45, pWidth, 15), XStringFormats.TopRight)

            ' 4. Separator Line
            currentY += 65
            gfx.DrawLine(New XPen(XColors.DarkGray, 1.5), margin, currentY, margin + pWidth, currentY)
            currentY += 10
        End Sub

        ' ===================================================
        ' Export Product Movements to CSV
        ' ===================================================
        Public Shared Sub ExportProductMovementsToCsv(movements As List(Of ProductMovement), productName As String)
            Try
                If movements Is Nothing OrElse movements.Count = 0 Then
                    MessageBox.Show("لا توجد حركات للتصدير", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Information)
                    Return
                End If

                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير حركات الصنف إلى CSV"
                dlg.Filter = "CSV Files (*.csv)|*.csv"

                Dim safeName = productName
                For Each c In Path.GetInvalidFileNameChars()
                    safeName = safeName.Replace(c, "_"c)
                Next
                dlg.FileName = "حركات_الصنف_" & safeName & "_" & DateTime.Now.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Using sw As New StreamWriter(dlg.FileName, False, New UTF8Encoding(True))
                    sw.WriteLine("تقرير حركات الصنف: " & productName)
                    sw.WriteLine("تاريخ الطباعة: " & DateTime.Now.ToString("yyyy/MM/dd HH:mm"))
                    sw.WriteLine()

                    ' --- Table Headers ---
                    Dim headers = {"رقم الفاتورة", "التاريخ", "النوع", "الاتجاه", "الكمية", "السعر", "الإجمالي", "العميل/المورد"}
                    sw.WriteLine(String.Join(",", headers))

                    ' --- Data Rows ---
                    For Each item In movements
                        Dim row = {
                            item.InvID.ToString(),
                            item.InvDate.ToString("yyyy/MM/dd"),
                            """" & If(item.InvTypeName, "").Replace("""", """""") & """",
                            item.MovementDirection,
                            item.Quantity.ToString("F2"),
                            item.UnitPrice.ToString("F3"),
                            item.TotalPrice.ToString("F3"),
                            """" & If(item.PartnerName, "").Replace("""", """""") & """"
                        }
                        sw.WriteLine(String.Join(",", row))
                    Next
                End Using

                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                End If

            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء التصدير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Export Product Movements to PDF
        ' ===================================================
        Public Shared Sub ExportProductMovementsToPdf(movements As List(Of ProductMovement), productName As String, Optional summary As ProductCardSummary = Nothing, Optional warehouses As List(Of WarehouseStock) = Nothing)
            Try
                If movements Is Nothing OrElse movements.Count = 0 Then
                    MessageBox.Show("لا توجد حركات لطباعتها", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Information)
                    Return
                End If

                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير حركات الصنف إلى PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"

                Dim safeName = productName
                For Each c In Path.GetInvalidFileNameChars()
                    safeName = safeName.Replace(c, "_"c)
                Next
                dlg.FileName = "حركات_الصنف_" & safeName & "_" & DateTime.Now.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()

                doc.Info.Title = "حركات الصنف - " & productName
                
                Dim pageCount = 0
                Dim margin = 30.0

                Dim drawHeaderFunc = Function(ByRef p As PdfPage) As XGraphics
                                         Dim g = XGraphics.FromPdfPage(p)
                                         Dim currentY = margin
                                         Dim pWidth = p.Width.Point - margin * 2
                                         pageCount += 1
                                         DrawReportHeader(g, company, p, currentY, margin, pWidth, pageCount)
                                         Return g
                                     End Function

                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                page.Orientation = PdfSharp.PageOrientation.Portrait
                Dim gfx = drawHeaderFunc(page)
                
                Dim pageWidth = page.Width.Point - margin * 2
                Dim y = margin + 80

                ' Title
                gfx.DrawString(ArabicTextHelper.Fix("تقرير حركات الصنف: " & productName), New XFont("Arial", 16, XFontStyle.Bold),
                               XBrushes.Black, New XRect(margin, y, pageWidth, 25), XStringFormats.TopCenter)
                y += 35

                ' --- Product Summary Section ---
                If summary IsNot Nothing Then
                    Dim summaryFont = New XFont("Arial", 10, XFontStyle.Bold)
                    Dim valueFont = New XFont("Arial", 10, XFontStyle.Regular)
                    
                    ' Row 1: Barcode & Avg Cost
                    gfx.DrawString(ArabicTextHelper.Fix("الباركود:   " & If(summary.Barcode, "-")), summaryFont, XBrushes.DarkSlateGray, margin, y)
                    gfx.DrawString(ArabicTextHelper.Fix("متوسط التكلفة: " & summary.AvgCost.ToString("N3")), summaryFont, XBrushes.DarkSlateGray, margin + 250, y)
                    gfx.DrawString(ArabicTextHelper.Fix("إجمالي الرصيد: " & summary.Balance.ToString("N2")), summaryFont, XBrushes.DarkBlue, margin + 400, y)
                    y += 20
                    
                    ' Row 2: In/Out Totals
                    gfx.DrawString(ArabicTextHelper.Fix("إجمالي الإيرادات (وارد): " & summary.TotalInQty.ToString("N2") & " / " & summary.TotalInValue.ToString("N3")), summaryFont, XBrushes.DarkGreen, margin, y)
                    gfx.DrawString(ArabicTextHelper.Fix("إجمالي الصادرات (صادر): " & summary.TotalOutQty.ToString("N2") & " / " & summary.TotalOutValue.ToString("N3")), summaryFont, XBrushes.DarkRed, margin + 250, y)
                    y += 25
                End If

                ' --- Warehouse Stocks Section ---
                If warehouses IsNot Nothing AndAlso warehouses.Count > 0 Then
                    Dim whFont = New XFont("Arial", 9, XFontStyle.Bold)
                    gfx.DrawString(ArabicTextHelper.Fix("رصيد المستودعات:"), whFont, XBrushes.Black, margin, y)
                    y += 15
                    
                    Dim whX = margin
                    For Each wh In warehouses
                        Dim whText = wh.WarehouseName & ": " & wh.CurrentQty.ToString("N2")
                        gfx.DrawString(ArabicTextHelper.Fix(whText), New XFont("Arial", 9, XFontStyle.Regular), XBrushes.DarkSlateGray, whX, y)
                        whX += 130
                        If whX > pageWidth - 100 Then
                            whX = margin
                            y += 15
                        End If
                    Next
                    y += 25
                Else 
                    y += 10
                End If

                ' Table header
                Dim cols() As Double = {50, 70, 70, 50, 60, 60, 150}
                Dim headers() As String = {"الفاتورة", "التاريخ", "النوع", "الاتجاه", "الكمية", "الإجمالي", "الجهة"}
                Dim headerBrush As New XSolidBrush(XColor.FromArgb(41, 128, 185))

                Dim x = margin
                For i = 0 To headers.Length - 1
                    gfx.DrawRectangle(headerBrush, x, y, cols(i), 18)
                    gfx.DrawString(ArabicTextHelper.Fix(headers(i)), fontBold, XBrushes.White, New XRect(x + 2, y + 2, cols(i) - 4, 16), XStringFormats.TopLeft)
                    x += cols(i)
                Next
                y += 18

                ' Table rows
                Dim altBrush As New XSolidBrush(XColor.FromArgb(248, 249, 250))
                Dim rowIndex = 0
                For Each item In movements
                    If y > page.Height.Point - margin - 40 Then
                        page = doc.AddPage()
                        page.Size = PdfSharp.PageSize.A4
                        page.Orientation = PdfSharp.PageOrientation.Portrait
                        gfx = drawHeaderFunc(page)
                        y = margin + 80

                        x = margin
                        For i = 0 To headers.Length - 1
                            gfx.DrawRectangle(headerBrush, x, y, cols(i), 18)
                            gfx.DrawString(ArabicTextHelper.Fix(headers(i)), fontBold, XBrushes.White, New XRect(x + 2, y + 2, cols(i) - 4, 16), XStringFormats.TopLeft)
                            x += cols(i)
                        Next
                        y += 18
                    End If

                    If rowIndex Mod 2 = 0 Then
                        gfx.DrawRectangle(altBrush, margin, y, pageWidth, 16)
                    End If

                    x = margin
                    Dim partner = If(item.PartnerName, "")
                    Dim rowData() As String = {
                        item.InvID.ToString(),
                        item.InvDate.ToString("yyyy/MM/dd"),
                        If(item.InvTypeName, ""),
                        item.MovementDirection,
                        item.Quantity.ToString("F2"),
                        item.TotalPrice.ToString("N3"),
                        If(partner.Length > 25, partner.Substring(0, 25) & "...", partner)
                    }

                    For i = 0 To rowData.Length - 1
                        Dim brush = If(i = 3 AndAlso rowData(i) = "IN", New XSolidBrush(XColor.FromArgb(39, 174, 96)),
                                    If(i = 3 AndAlso rowData(i) = "OUT", New XSolidBrush(XColor.FromArgb(192, 57, 43)), XBrushes.Black))
                        
                        gfx.DrawString(ArabicTextHelper.Fix(rowData(i)), fontSmall, brush, New XRect(x + 2, y + 2, cols(i) - 4, 14), XStringFormats.TopLeft)
                        x += cols(i)
                    Next

                    gfx.DrawRectangle(XPens.LightGray, margin, y, pageWidth, 16)
                    y += 16
                    rowIndex += 1
                Next

                doc.Save(dlg.FileName)
                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                End If

            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء التصدير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Export Quote to CSV
        ' ===================================================
        Public Shared Sub ExportQuoteToCsv(quote As QuoteHeader, customerName As String)
            Try
                If quote Is Nothing OrElse quote.Details Is Nothing OrElse quote.Details.Count = 0 Then
                    MessageBox.Show("لا يوجد بيانات لتصديرها.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If

                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير عرض الأسعار - CSV"
                dlg.Filter = "CSV Files (*.csv)|*.csv"
                Dim safeName = customerName
                For Each c In Path.GetInvalidFileNameChars()
                    safeName = safeName.Replace(c, "_"c)
                Next
                dlg.FileName = "عرض_اسعار_" & safeName & "_" & quote.QuoteDate.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Using sw As New StreamWriter(dlg.FileName, False, New UTF8Encoding(True))
                    ' Header
                    sw.WriteLine("عرض أسعار")
                    sw.WriteLine("العميل:," & customerName)
                    sw.WriteLine("تاريخ العرض:," & quote.QuoteDate.ToString("yyyy/MM/dd"))
                    Dim expiry As String = If(quote.ExpiryDate.HasValue, quote.ExpiryDate.Value.ToString("yyyy/MM/dd"), "غير محدد")
                    sw.WriteLine("صالح حتى:," & expiry)
                    sw.WriteLine("الحالة:," & If(quote.IsActive, "فعال", "غير فعال"))
                    If Not String.IsNullOrWhiteSpace(quote.Notes) Then
                        sw.WriteLine("ملاحظات:,""" & quote.Notes.Replace("""", """""") & """")
                    End If
                    sw.WriteLine()
                    sw.WriteLine("م,كود الصنف,اسم الصنف,الوحدة,سعر العرض")

                    For i As Integer = 0 To quote.Details.Count - 1
                        Dim d = quote.Details(i)
                        Dim name As String = """" & If(d.ProductName, "").Replace("""", """""") & """"
                        sw.WriteLine($"{i + 1},{If(d.Barcode, "")},{name},{If(d.UnitName, "")},{d.QuotedPrice:N3}")
                    Next
                End Using

                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                End If

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء التصدير: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Export Quote to PDF (PdfSharp)
        ' ===================================================
        Public Shared Sub ExportQuoteToPdf(quote As QuoteHeader, customerName As String)
            Try
                If quote Is Nothing OrElse quote.Details Is Nothing OrElse quote.Details.Count = 0 Then
                    MessageBox.Show("لا يوجد بيانات لتصديرها.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                    Return
                End If

                Dim dlg As New SaveFileDialog()
                dlg.Title = "تصدير عرض الأسعار - PDF"
                dlg.Filter = "PDF Files (*.pdf)|*.pdf"
                Dim safeName = customerName
                For Each c In Path.GetInvalidFileNameChars()
                    safeName = safeName.Replace(c, "_"c)
                Next
                dlg.FileName = "عرض_اسعار_" & safeName & "_" & quote.QuoteDate.ToString("yyyyMMdd")

                If dlg.ShowDialog() <> True Then Return

                Dim doc As New PdfDocument()
                doc.Info.Title = "عرض أسعار - " & customerName
                doc.Info.Author = "Vegtablity ERP"

                Dim settingsSvc As New SettingsService()
                Dim company = settingsSvc.GetCompanyInfo()

                Dim margin As Double = 35
                Dim pageCount As Integer = 0

                ' ── Initial page ──
                Dim page = doc.AddPage()
                page.Size = PdfSharp.PageSize.A4
                Dim gfx = XGraphics.FromPdfPage(page)
                Dim pageWidth = page.Width.Point - margin * 2
                Dim currentY As Double = margin
                pageCount += 1
                DrawReportHeader(gfx, company, page, currentY, margin, pageWidth, pageCount)
                Dim y As Double = currentY

                ' ── Quote title ──
                Dim titleFont = New XFont("Arial", 16, XFontStyle.Bold)
                gfx.DrawString(ArabicTextHelper.Fix("عرض أسعار"), titleFont, XBrushes.Black,
                               New XRect(margin, y, pageWidth, 25), XStringFormats.TopCenter)
                y += 30

                ' ── Info card (background box) ──
                Dim infoH As Double = If(String.IsNullOrWhiteSpace(quote.Notes), 42, 56)
                gfx.DrawRectangle(New XSolidBrush(XColor.FromArgb(241, 245, 249)), margin, y, pageWidth, infoH)
                gfx.DrawRectangle(XPens.LightGray, margin, y, pageWidth, infoH)

                Dim lbf = New XFont("Arial", 9, XFontStyle.Bold)
                Dim lvf = New XFont("Arial", 9, XFontStyle.Regular)
                Dim col1 As Double = margin + 5
                Dim col2 As Double = margin + pageWidth / 2 + 5

                ' Row 1
                gfx.DrawString(ArabicTextHelper.Fix("العميل:"), lbf, XBrushes.DarkGray, col1, y + 8)
                gfx.DrawString(ArabicTextHelper.Fix(customerName), New XFont("Arial", 9, XFontStyle.Bold), XBrushes.Black, col1 + 35, y + 8)

                gfx.DrawString(ArabicTextHelper.Fix("تاريخ العرض:"), lbf, XBrushes.DarkGray, col2, y + 8)
                gfx.DrawString(quote.QuoteDate.ToString("dd/MM/yyyy"), lvf, XBrushes.Black, col2 + 55, y + 8)

                ' Row 2
                Dim expiry As String = If(quote.ExpiryDate.HasValue, quote.ExpiryDate.Value.ToString("dd/MM/yyyy"), "غير محدد")
                gfx.DrawString(ArabicTextHelper.Fix("صالح حتى:"), lbf, XBrushes.DarkGray, col1, y + 22)
                gfx.DrawString(expiry, lvf, XBrushes.Black, col1 + 35, y + 22)

                gfx.DrawString(ArabicTextHelper.Fix("الحالة:"), lbf, XBrushes.DarkGray, col2, y + 22)
                Dim statusBrush = If(quote.IsActive, New XSolidBrush(XColor.FromArgb(22, 163, 74)), XBrushes.Gray)
                gfx.DrawString(ArabicTextHelper.Fix(If(quote.IsActive, "فعال", "غير فعال")), New XFont("Arial", 9, XFontStyle.Bold), statusBrush, col2 + 35, y + 22)

                ' Row 3 - notes
                If Not String.IsNullOrWhiteSpace(quote.Notes) Then
                    gfx.DrawString(ArabicTextHelper.Fix("ملاحظات:"), lbf, XBrushes.DarkGray, col1, y + 36)
                    gfx.DrawString(ArabicTextHelper.Fix(quote.Notes), lvf, XBrushes.Black, col1 + 35, y + 36)
                End If
                y += infoH + 10

                ' ── Table header ──
                Dim colW() As Double = {pageWidth * 0.05, pageWidth * 0.18, pageWidth * 0.45, pageWidth * 0.15, pageWidth * 0.17}
                Dim colHdr() As String = {"م", "كود الصنف", "اسم الصنف", "الوحدة", "سعر العرض"}
                Dim rowH As Double = 16
                Dim headerBrush As New XSolidBrush(XColor.FromArgb(79, 70, 229))

                Dim hx As Double = margin
                gfx.DrawRectangle(headerBrush, margin, y, pageWidth, rowH)
                For c = 0 To colHdr.Length - 1
                    gfx.DrawString(ArabicTextHelper.Fix(colHdr(c)), lbf, XBrushes.White,
                                   New XRect(hx + 2, y + 2, colW(c) - 4, rowH - 4), XStringFormats.TopCenter)
                    hx += colW(c)
                Next
                y += rowH

                ' ── Table rows ──
                Dim altBrush As New XSolidBrush(XColor.FromArgb(248, 250, 252))
                For i = 0 To quote.Details.Count - 1
                    ' New page if needed
                    If y > page.Height.Point - margin - 30 Then
                        page = doc.AddPage()
                        page.Size = PdfSharp.PageSize.A4
                        gfx = XGraphics.FromPdfPage(page)
                        currentY = margin
                        pageCount += 1
                        DrawReportHeader(gfx, company, page, currentY, margin, pageWidth, pageCount)
                        y = currentY
                        ' Redraw header
                        hx = margin
                        gfx.DrawRectangle(headerBrush, margin, y, pageWidth, rowH)
                        For c = 0 To colHdr.Length - 1
                            gfx.DrawString(ArabicTextHelper.Fix(colHdr(c)), lbf, XBrushes.White,
                                           New XRect(hx + 2, y + 2, colW(c) - 4, rowH - 4), XStringFormats.TopCenter)
                            hx += colW(c)
                        Next
                        y += rowH
                    End If

                    Dim d = quote.Details(i)
                    If i Mod 2 = 1 Then gfx.DrawRectangle(altBrush, margin, y, pageWidth, rowH)
                    gfx.DrawLine(XPens.LightGray, margin, y + rowH, margin + pageWidth, y + rowH)

                    Dim cells() As String = {
                        (i + 1).ToString(),
                        If(d.Barcode, ""),
                        If(d.ProductName, ""),
                        If(d.UnitName, ""),
                        d.QuotedPrice.ToString("N3")
                    }
                    Dim cx As Double = margin
                    For c = 0 To cells.Length - 1
                        gfx.DrawString(ArabicTextHelper.Fix(cells(c)), lvf, XBrushes.Black,
                                       New XRect(cx + 2, y + 2, colW(c) - 4, rowH - 4), XStringFormats.TopCenter)
                        cx += colW(c)
                    Next
                    y += rowH
                Next

                ' ── Footer: total count ──
                y += 8
                gfx.DrawString(ArabicTextHelper.Fix($"إجمالي الأصناف: {quote.Details.Count} صنف"),
                               lbf, XBrushes.Black, New XRect(margin, y, pageWidth, 16), XStringFormats.TopLeft)
                gfx.DrawString($"صفحة {pageCount}",
                               lvf, XBrushes.DarkGray, New XRect(margin, y, pageWidth, 16), XStringFormats.TopRight)

                doc.Save(dlg.FileName)
                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                End If

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تصدير PDF: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Generate Empty Excel Template for Quote Import
        ' Uses DocumentFormat.OpenXml (no extra DLL deps)
        ' ===================================================
        Public Shared Sub ExportQuoteTemplate()
            Try
                Dim dlg As New SaveFileDialog()
                dlg.Title = "حفظ قالب Excel"
                dlg.Filter = "Excel Files (*.xlsx)|*.xlsx"
                dlg.FileName = "قالب_استيراد_عرض_اسعار"

                If dlg.ShowDialog() <> True Then Return

                ' Build a minimal valid xlsx using Open XML SDK
                Using doc = DocumentFormat.OpenXml.Packaging.SpreadsheetDocument.Create(
                            dlg.FileName, DocumentFormat.OpenXml.SpreadsheetDocumentType.Workbook)

                    Dim wbPart = doc.AddWorkbookPart()
                    wbPart.Workbook = New DocumentFormat.OpenXml.Spreadsheet.Workbook()

                    Dim wsPart = wbPart.AddNewPart(Of DocumentFormat.OpenXml.Packaging.WorksheetPart)()
                    Dim sheetData As New DocumentFormat.OpenXml.Spreadsheet.SheetData()
                    wsPart.Worksheet = New DocumentFormat.OpenXml.Spreadsheet.Worksheet(sheetData)

                    Dim sheets = wbPart.Workbook.AppendChild(New DocumentFormat.OpenXml.Spreadsheet.Sheets())
                    sheets.AppendChild(New DocumentFormat.OpenXml.Spreadsheet.Sheet() With {
                        .Id = wbPart.GetIdOfPart(wsPart),
                        .SheetId = 1,
                        .Name = "عرض الأسعار"
                    })

                    ' Helper to create a text cell
                    Dim makeCell As Func(Of String, String, DocumentFormat.OpenXml.Spreadsheet.Cell) =
                        Function(cellRef As String, value As String)
                            Dim c As New DocumentFormat.OpenXml.Spreadsheet.Cell()
                            c.CellReference = cellRef
                            c.DataType = DocumentFormat.OpenXml.Spreadsheet.CellValues.InlineString
                            c.InlineString = New DocumentFormat.OpenXml.Spreadsheet.InlineString(
                                New DocumentFormat.OpenXml.Spreadsheet.Text(value))
                            Return c
                        End Function

                    ' Row 1 — headers
                    Dim row1 As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 1}
                    row1.AppendChild(makeCell("A1", "كود الصنف (Barcode)"))
                    row1.AppendChild(makeCell("B1", "اسم الصنف"))
                    row1.AppendChild(makeCell("C1", "سعر العرض"))
                    sheetData.AppendChild(row1)

                    ' Row 2 — sample
                    Dim row2 As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 2}
                    row2.AppendChild(makeCell("A2", "12345"))
                    row2.AppendChild(makeCell("B2", "توماتة"))
                    row2.AppendChild(makeCell("C2", "0.500"))
                    sheetData.AppendChild(row2)

                    ' Row 3 — sample
                    Dim row3 As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 3}
                    row3.AppendChild(makeCell("A3", "22222"))
                    row3.AppendChild(makeCell("B3", "خيار"))
                    row3.AppendChild(makeCell("C3", "0.350"))
                    sheetData.AppendChild(row3)

                    ' Row 5 — note
                    Dim row5 As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 5}
                    row5.AppendChild(makeCell("A5", "ملاحظة: عمود 'كود الصنف' إلزامي. 'سعر العرض' اختياري — إذا تُرك فارغاً يُستخدم السعر الافتراضي للصنف."))
                    sheetData.AppendChild(row5)

                    wbPart.Workbook.Save()
                End Using

                If File.Exists(dlg.FileName) Then
                    Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                End If

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء إنشاء القالب: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ===================================================
        ' Import Quote Details from Excel (Open XML SDK)
        ' Returns list of QuoteDetail rows (unmatched flagged)
        ' ===================================================
        Public Shared Function ImportQuoteFromExcel(products As IList(Of Product)) As List(Of QuoteDetail)
            Dim result As New List(Of QuoteDetail)

            Try
                Dim dlg As New OpenFileDialog()
                dlg.Title = "استيراد عرض أسعار من Excel"
                dlg.Filter = "Excel Files (*.xlsx)|*.xlsx"

                If dlg.ShowDialog() <> True Then Return Nothing

                Using doc = DocumentFormat.OpenXml.Packaging.SpreadsheetDocument.Open(dlg.FileName, False)
                    Dim wbPart = doc.WorkbookPart
                    If wbPart Is Nothing Then Return Nothing

                    ' Get first sheet
                    Dim sheet = wbPart.Workbook.Descendants(Of DocumentFormat.OpenXml.Spreadsheet.Sheet).FirstOrDefault()
                    If sheet Is Nothing Then Return Nothing

                    Dim wsPart = TryCast(wbPart.GetPartById(sheet.Id), DocumentFormat.OpenXml.Packaging.WorksheetPart)
                    If wsPart Is Nothing Then Return Nothing

                    ' Shared strings table for string cells
                    Dim sstPart = wbPart.SharedStringTablePart
                    Dim sharedStrings As New List(Of String)
                    If sstPart IsNot Nothing Then
                        For Each item In sstPart.SharedStringTable.Elements(Of DocumentFormat.OpenXml.Spreadsheet.SharedStringItem)()
                            sharedStrings.Add(item.InnerText)
                        Next
                    End If

                    ' Helper to get cell text value
                    Dim getCellValue As Func(Of DocumentFormat.OpenXml.Spreadsheet.Cell, String) =
                        Function(c As DocumentFormat.OpenXml.Spreadsheet.Cell) As String
                            If c Is Nothing OrElse c.CellValue Is Nothing Then Return ""
                            Dim raw = c.CellValue.InnerText.Trim()
                            If c.DataType IsNot Nothing AndAlso c.DataType.Value = DocumentFormat.OpenXml.Spreadsheet.CellValues.SharedString Then
                                Dim idx As Integer
                                If Integer.TryParse(raw, idx) AndAlso idx < sharedStrings.Count Then
                                    Return sharedStrings(idx)
                                End If
                            ElseIf c.DataType IsNot Nothing AndAlso c.DataType.Value = DocumentFormat.OpenXml.Spreadsheet.CellValues.InlineString Then
                                Return If(c.InlineString?.InnerText, raw)
                            End If
                            Return raw
                        End Function

                    ' Read all rows — skip row 1 (header)
                    Dim rows = wsPart.Worksheet.Descendants(Of DocumentFormat.OpenXml.Spreadsheet.Row)().
                                      Where(Function(r) r.RowIndex.HasValue AndAlso r.RowIndex.Value > CUInt(1)).ToList()

                    If rows.Count = 0 Then
                        MessageBox.Show("الملف لا يحتوي على بيانات بعد السطر الأول.", "تنبيه", MessageBoxButton.OK, MessageBoxImage.Warning)
                        Return Nothing
                    End If

                    Dim addedBarcodes As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

                    For Each row In rows
                        ' Get cells by column letter
                        Dim cells = row.Elements(Of DocumentFormat.OpenXml.Spreadsheet.Cell)().ToList()

                        Dim getCol As Func(Of String, String) =
                            Function(col As String) As String
                                Dim c = cells.FirstOrDefault(Function(x) x.CellReference.HasValue AndAlso
                                                              x.CellReference.Value.StartsWith(col, StringComparison.OrdinalIgnoreCase))
                                Return getCellValue(c)
                            End Function

                        Dim barcodeVal = getCol("A").Trim()
                        Dim nameVal = getCol("B").Trim()
                        Dim priceVal = getCol("C").Trim()

                        If String.IsNullOrEmpty(barcodeVal) AndAlso String.IsNullOrEmpty(nameVal) Then Continue For

                        Dim quotedPrice As Decimal = 0
                        Decimal.TryParse(priceVal.Replace(",", "."), Globalization.NumberStyles.Any,
                                         Globalization.CultureInfo.InvariantCulture, quotedPrice)

                        ' ── Match product ──
                        Dim matchedProduct As Product = Nothing

                        If Not String.IsNullOrEmpty(barcodeVal) Then
                            matchedProduct = products.FirstOrDefault(
                                Function(p) p.Barcode IsNot Nothing AndAlso
                                            p.Barcode.Trim().Equals(barcodeVal, StringComparison.OrdinalIgnoreCase))
                        End If

                        If matchedProduct Is Nothing AndAlso Not String.IsNullOrEmpty(nameVal) Then
                            matchedProduct = products.FirstOrDefault(
                                Function(p) p.SearchText IsNot Nothing AndAlso
                                            p.SearchText.ToLower().Contains(nameVal.ToLower()))
                        End If

                        ' ── Duplicate guard ──
                        If matchedProduct IsNot Nothing Then
                            Dim key = matchedProduct.ProductID.ToString()
                            If addedBarcodes.Contains(key) Then Continue For
                            addedBarcodes.Add(key)
                        End If

                        ' ── Build row ──
                        If matchedProduct IsNot Nothing Then
                            result.Add(New QuoteDetail() With {
                                .ProductID = matchedProduct.ProductID,
                                .Barcode = matchedProduct.Barcode,
                                .ProductName = matchedProduct.ProductName,
                                .UnitName = matchedProduct.UnitName,
                                .QuotedPrice = If(quotedPrice > 0, quotedPrice, matchedProduct.SalePrice),
                                .IsUnmatched = False
                            })
                        Else
                            result.Add(New QuoteDetail() With {
                                .ProductID = 0,
                                .Barcode = barcodeVal,
                                .ProductName = If(Not String.IsNullOrEmpty(nameVal), nameVal, $"[غير معروف: {barcodeVal}]"),
                                .UnitName = "",
                                .QuotedPrice = quotedPrice,
                                .IsUnmatched = True
                            })
                        End If
                    Next
                End Using

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الاستيراد: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                Return Nothing
            End Try

            Return result
        End Function

    End Class
End Namespace
