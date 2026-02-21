Imports System.IO
Imports System.Text
Imports PdfSharp.Pdf
Imports PdfSharp.Drawing
Imports Microsoft.Win32
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace Helpers
    Public Class ReportExporter

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
                Dim pageIndex = 0

                Dim addNewPageWithHeader = Function() As XGraphics
                                               Dim p = doc.AddPage()
                                               p.Size = PdfSharp.PageSize.A4
                                               p.Orientation = PdfSharp.PageOrientation.Landscape
                                               Dim g = XGraphics.FromPdfPage(p)
                                               Dim currentY = margin
                                               Dim pWidth = p.Width.Point - margin * 2

                                               ' --- Header Branding ---
                                               If company IsNot Nothing Then
                                                   ' Logo
                                                   If company.Logo IsNot Nothing AndAlso company.Logo.Length > 0 Then
                                                       Try
                                                           Using ms As New MemoryStream(company.Logo)
                                                               Dim img = XImage.FromStream(ms)
                                                               g.DrawImage(img, margin, currentY, 60, 60)
                                                           End Using
                                                       Catch ex As Exception
                                                       End Try
                                                   End If

                                                   ' Company Name
                                                   g.DrawString(ArabicTextHelper.Fix(company.CompanyName), fontLarge, XBrushes.Black,
                                       New XRect(margin + 70, currentY, pWidth - 70, 25), XStringFormats.TopLeft)

                                                   g.DrawString(ArabicTextHelper.Fix(If(company.Email, "")), fontSmall,
                                        XBrushes.Gray, New XRect(margin + 70, currentY + 25, pWidth - 70, 15), XStringFormats.TopLeft)
                                                   g.DrawString(ArabicTextHelper.Fix(If(company.Phone, "")), fontSmall,
                                        XBrushes.Gray, New XRect(margin + 70, currentY + 40, pWidth - 70, 15), XStringFormats.TopLeft)

                                                   currentY += 75
                                               End If

                                               ' Page Number
                                               pageIndex += 1
                                               g.DrawString(ArabicTextHelper.Fix("Page: " & pageIndex), fontSmall, XBrushes.Gray,
                                 New XRect(margin, p.Height.Point - margin + 5, pWidth, 15), XStringFormats.TopRight)

                                               Return g
                                           End Function

                ' Initial Page
                Dim gfx = addNewPageWithHeader()
                Dim pageWidth = doc.Pages(0).Width.Point - margin * 2
                Dim y = margin + (If(company IsNot Nothing, 75, 0))

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
                        gfx = addNewPageWithHeader()
                        y = margin + (If(company IsNot Nothing, 75, 0))

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
                    gfx = addNewPageWithHeader()
                    y = margin + (If(company IsNot Nothing, 75, 0))
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

    End Class
End Namespace
