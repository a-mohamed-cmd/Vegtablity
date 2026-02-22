Imports System.IO
Imports System.Text
Imports PdfSharp.Pdf
Imports PdfSharp.Drawing
Imports Microsoft.Win32
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace Helpers
    Public Class ReportExporter
        Private Shared ReadOnly fontBold As New XFont("Arial", 11, XFontStyle.Bold)
        Private Shared ReadOnly fontReg As New XFont("Arial", 9, XFontStyle.Regular)
        Private Shared ReadOnly fontSmall As New XFont("Arial", 8, XFontStyle.Regular)
        Private Shared ReadOnly fontLarge As New XFont("Arial", 18, XFontStyle.Bold)
        Private Shared ReadOnly fontTitle As New XFont("Arial", 16, XFontStyle.Bold)

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
                    sw.WriteLine("الرصيد الافتتاحي: " & report.OpeningBalance.ToString("F2"))
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
                            item.DebitAmount.ToString("F2"),
                            item.CreditAmount.ToString("F2"),
                            item.Balance.ToString("F2")
                        }
                        sw.WriteLine(String.Join(",", row))
                    Next

                    ' --- Totals ---
                    sw.WriteLine()
                    Dim totals = {"", "", "", "الإجمالي", report.TotalDebit.ToString("F2"), report.TotalCredit.ToString("F2"), report.EndingBalance.ToString("F2")}
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
                        item.Balance.ToString("N2")
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
                Dim totals() As String = {"", "", "", "TOTAL", report.TotalDebit.ToString("N2"), report.TotalCredit.ToString("N2"), report.EndingBalance.ToString("N2")}
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
                    gfx.DrawString(d.Debit.ToString("N2"), fontReg, XBrushes.Black, New XRect(x + 2, y + 2, cols(2) - 4, 16), XStringFormats.TopRight)
                    x += cols(2)
                    gfx.DrawString(d.Credit.ToString("N2"), fontReg, XBrushes.Black, New XRect(x + 2, y + 2, cols(3) - 4, 16), XStringFormats.TopRight)

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

                gfx.DrawString(totalDebit.ToString("N2"), fontBold, XBrushes.DarkRed, New XRect(margin + width - cols(3) - cols(2), y + 4, cols(2) - 4, 16), XStringFormats.TopRight)
                gfx.DrawString(totalCredit.ToString("N2"), fontBold, XBrushes.DarkGreen, New XRect(margin + width - cols(3), y + 4, cols(3) - 4, 16), XStringFormats.TopRight)

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
                            i.OpeningBalance.ToString("F2")
                        }
                        If isDetailed Then
                            row.Add(i.PeriodDebit.ToString("F2"))
                            row.Add(i.PeriodCredit.ToString("F2"))
                        End If
                        row.Add(i.EndingBalance.ToString("F2"))

                        sw.WriteLine(String.Join(",", row))
                    Next

                    ' --- Summary ---
                    sw.WriteLine()
                    Dim totals As New List(Of String) From {"", "الإجمالي", report.TotalOpeningBalance.ToString("F2")}
                    If isDetailed Then
                        totals.Add(report.TotalPeriodDebit.ToString("F2"))
                        totals.Add(report.TotalPeriodCredit.ToString("F2"))
                    End If
                    totals.Add(report.TotalEndingBalance.ToString("F2"))
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
                    gfx.DrawString(item.OpeningBalance.ToString("N2"), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(2) - 10, 16), XStringFormats.TopRight)
                    x += cols(2)

                    Dim curPos = 3
                    If isDetailed Then
                        gfx.DrawString(item.PeriodDebit.ToString("N2"), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(curPos) - 10, 16), XStringFormats.TopRight)
                        x += cols(curPos)
                        curPos += 1
                        gfx.DrawString(item.PeriodCredit.ToString("N2"), fontReg, XBrushes.Black, New XRect(x + 5, y + 3, cols(curPos) - 10, 16), XStringFormats.TopRight)
                        x += cols(curPos)
                        curPos += 1
                    End If

                    gfx.DrawString(item.EndingBalance.ToString("N2"), fontBold, XBrushes.DarkBlue, New XRect(x + 5, y + 3, cols(headers.Count - 1) - 10, 16), XStringFormats.TopRight)

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
                gfx.DrawString(report.TotalOpeningBalance.ToString("N2"), fontBold, XBrushes.Black, New XRect(x + 5, y + 4, cols(2) - 10, 16), XStringFormats.TopRight)
                x += cols(2)

                If isDetailed Then
                    gfx.DrawString(report.TotalPeriodDebit.ToString("N2"), fontBold, XBrushes.Black, New XRect(x + 5, y + 4, cols(3) - 10, 16), XStringFormats.TopRight)
                    x += cols(3)
                    gfx.DrawString(report.TotalPeriodCredit.ToString("N2"), fontBold, XBrushes.Black, New XRect(x + 5, y + 4, cols(4) - 10, 16), XStringFormats.TopRight)
                    x += cols(4)
                End If
                gfx.DrawString(report.TotalEndingBalance.ToString("N2"), fontBold, XBrushes.DarkGreen, New XRect(x + 5, y + 4, cols(headers.Count - 1) - 10, 16), XStringFormats.TopRight)

                doc.Save(dlg.FileName)
                Process.Start(New Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})

            Catch ex As Exception
                MessageBox.Show("Error: " & ex.Message)
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

    End Class
End Namespace
