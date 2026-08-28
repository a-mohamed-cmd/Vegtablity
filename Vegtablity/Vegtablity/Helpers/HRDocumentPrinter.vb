Imports System
Imports System.Collections.Generic
Imports System.Drawing
Imports System.Drawing.Printing
Imports System.Linq
Imports System.Windows
Imports Vegtablity.Models
Imports Vegtablity.Models.HR

Namespace Helpers
    Public Class HRDocumentPrinter
        Private _companyInfo As CompanyInfo
        Private _printFontSmall As Font
        Private _printFontNormal As Font
        Private _printFontBold As Font
        Private _printFontHeader As Font
        Private _printFontTitle As Font

        Private _docType As String ' "Commencement", "Leave", "Settlement", "Payslip", "BatchReport"
        Private _emp As Employee
        Private _leave As EmployeeLeave
        Private _settlement As EndOfServiceSettlement
        Private _payrollDetail As PayrollDetail
        Private _payrollBatch As PayrollBatch
        Private _payrollDetailsList As List(Of PayrollDetail)
        Private _extraNotes As String

        Public Sub New()
            Try
                Dim svc As New Services.SettingsService()
                _companyInfo = svc.GetCompanyInfo()
            Catch
                _companyInfo = Nothing
            End Try

            _printFontSmall = New Font("Arial", 8.5F, System.Drawing.FontStyle.Regular)
            _printFontNormal = New Font("Arial", 10.0F, System.Drawing.FontStyle.Regular)
            _printFontBold = New Font("Arial", 10.0F, System.Drawing.FontStyle.Bold)
            _printFontHeader = New Font("Arial", 12.0F, System.Drawing.FontStyle.Bold)
            _printFontTitle = New Font("Arial", 15.0F, System.Drawing.FontStyle.Bold)
        End Sub

        Public Sub PrintJobCommencement(emp As Employee, leave As EmployeeLeave, Optional notes As String = Nothing)
            _docType = "Commencement"
            _emp = emp
            _leave = leave
            _extraNotes = notes
            ExecutePrint("طباعة نموذج مباشرة عمل")
        End Sub

        Public Sub PrintLeaveApplication(emp As Employee, leave As EmployeeLeave, Optional remainingBalance As Decimal = 0)
            _docType = "Leave"
            _emp = emp
            _leave = leave
            _extraNotes = remainingBalance.ToString("0.0")
            ExecutePrint("طباعة نموذج طلب إجازة")
        End Sub

        Public Sub PrintEndOfServiceSettlement(emp As Employee, settlement As EndOfServiceSettlement)
            _docType = "Settlement"
            _emp = emp
            _settlement = settlement
            ExecutePrint("طباعة نموذج تصفية نهاية الخدمة")
        End Sub

        Public Sub PrintSalaryPayslip(emp As Employee, detail As PayrollDetail, batch As PayrollBatch)
            _docType = "Payslip"
            _emp = emp
            _payrollDetail = detail
            _payrollBatch = batch
            ExecutePrint("طباعة قسيمة الراتب")
        End Sub

        Public Sub PrintPayrollBatchReport(batch As PayrollBatch, details As IEnumerable(Of PayrollDetail))
            _docType = "BatchReport"
            _payrollBatch = batch
            _payrollDetailsList = If(details IsNot Nothing, details.ToList(), New List(Of PayrollDetail)())
            ExecutePrint($"مسير رواتب شهر {batch?.Month:D2} / {batch?.Year}", landscape:=True)
        End Sub

        Private Sub ExecutePrint(docTitle As String, Optional landscape As Boolean = False)
            Try
                Dim svc As New Services.SettingsService()
                _companyInfo = svc.GetCompanyInfo()
            Catch
            End Try

            Dim pd As New PrintDocument()
            pd.DocumentName = docTitle
            pd.DefaultPageSettings.PaperSize = New PaperSize("A4", 827, 1169) ' Standard A4
            pd.DefaultPageSettings.Landscape = landscape
            pd.DefaultPageSettings.Margins = New Margins(25, 25, 25, 25)

            AddHandler pd.PrintPage, AddressOf OnPrintPage

            Dim dlg As New System.Windows.Forms.PrintDialog()
            dlg.Document = pd
            dlg.UseEXDialog = True

            If dlg.ShowDialog() = System.Windows.Forms.DialogResult.OK Then
                pd.Print()
            End If
        End Sub

        Private Sub OnPrintPage(sender As Object, e As PrintPageEventArgs)
            Dim g = e.Graphics
            g.SmoothingMode = Drawing2D.SmoothingMode.AntiAlias
            g.TextRenderingHint = Drawing.Text.TextRenderingHint.ClearTypeGridFit

            Dim rtl As New StringFormat(StringFormatFlags.DirectionRightToLeft)
            rtl.Alignment = StringAlignment.Near
            rtl.LineAlignment = StringAlignment.Center

            Dim centerFmt As New StringFormat(StringFormatFlags.DirectionRightToLeft)
            centerFmt.Alignment = StringAlignment.Center
            centerFmt.LineAlignment = StringAlignment.Center

            Dim marginX = e.MarginBounds.Left
            Dim width = e.MarginBounds.Width
            Dim rightX = e.MarginBounds.Right
            Dim curY = e.MarginBounds.Top

            ' ─────────────────────────────────────────────
            ' 1. ترويسة الشركة الكاملة (Company Header with Logo & Details)
            ' ─────────────────────────────────────────────
            Dim headerTop = e.MarginBounds.Top
            Dim logoWidth As Single = 100.0F
            Dim logoHeight As Single = 65.0F
            Dim hasLogo As Boolean = (_companyInfo IsNot Nothing AndAlso _companyInfo.Logo IsNot Nothing AndAlso _companyInfo.Logo.Length > 0)

            ' أ) رسم شعار الشركة من الجهة اليسرى
            If hasLogo Then
                Try
                    Using ms As New System.IO.MemoryStream(_companyInfo.Logo)
                        Using originalImg As Image = Image.FromStream(ms)
                            Dim scaleRatio = Math.Min(logoWidth / originalImg.Width, logoHeight / originalImg.Height)
                            Dim drawW = originalImg.Width * scaleRatio
                            Dim drawH = originalImg.Height * scaleRatio
                            Dim drawX = marginX + (logoWidth - drawW) / 2.0F
                            Dim drawY = headerTop + (logoHeight - drawH) / 2.0F

                            g.InterpolationMode = Drawing2D.InterpolationMode.HighQualityBicubic
                            g.DrawImage(originalImg, drawX, drawY, drawW, drawH)
                        End Using
                    End Using
                Catch
                End Try
            End If

            ' ب) بيانات الشركة من الجهة اليمنى
            Dim compTextRightX As Single = rightX
            Dim compTextWidth As Single = width - If(hasLogo, (logoWidth + 25.0F), 0.0F)
            Dim compName = If(Not String.IsNullOrWhiteSpace(_companyInfo?.CompanyName), _companyInfo.CompanyName, "مؤسسة تجارية")

            g.DrawString(compName, _printFontTitle, Brushes.MidnightBlue, New RectangleF(compTextRightX - compTextWidth, headerTop, compTextWidth, 26), rtl)

            Dim deptSubText = "إدارة الموارد البشرية والشؤون الإدارية والمالية"
            g.DrawString(deptSubText, _printFontBold, Brushes.DimGray, New RectangleF(compTextRightX - compTextWidth, headerTop + 26, compTextWidth, 18), rtl)

            ' سطر العنوان والاتصال
            Dim contactLine As String = ""
            If _companyInfo IsNot Nothing Then
                If Not String.IsNullOrWhiteSpace(_companyInfo.Address) Then
                    contactLine &= "العنوان: " & _companyInfo.Address.Trim()
                End If
                If Not String.IsNullOrWhiteSpace(_companyInfo.Phone) Then
                    If contactLine.Length > 0 Then contactLine &= "  |  "
                    contactLine &= "هاتف: " & _companyInfo.Phone.Trim()
                End If
                If Not String.IsNullOrWhiteSpace(_companyInfo.Email) Then
                    If contactLine.Length > 0 Then contactLine &= "  |  "
                    contactLine &= "البريد: " & _companyInfo.Email.Trim()
                End If
            End If

            If contactLine.Length > 0 Then
                g.DrawString(contactLine, _printFontSmall, Brushes.DarkSlateGray, New RectangleF(compTextRightX - compTextWidth, headerTop + 45, compTextWidth, 16), rtl)
            End If

            ' تاريخ الطباعة في أقصى اليسار تحت الشعار أو مكانه
            Dim printDateText = $"تاريخ الطباعة: {DateTime.Now:yyyy-MM-dd HH:mm}"
            Dim ltrSmall As New StringFormat() With {.Alignment = StringAlignment.Near, .LineAlignment = StringAlignment.Center}
            Dim printDateY = If(hasLogo, headerTop + logoHeight + 2, headerTop + 45)
            g.DrawString(printDateText, _printFontSmall, Brushes.Gray, New RectangleF(marginX, printDateY, 200, 15), ltrSmall)

            ' خط فاصل جمالي مزدوج تحت الترويسة
            curY = Math.Max(headerTop + logoHeight + 18, headerTop + 68)
            Using p1 As New Pen(Color.FromArgb(79, 70, 229), 1.5F), p2 As New Pen(Color.FromArgb(226, 232, 240), 1.0F)
                g.DrawLine(p1, marginX, curY, rightX, curY)
                g.DrawLine(p2, marginX, curY + 2.5F, rightX, curY + 2.5F)
            End Using

            curY += 12

            ' ─────────────────────────────────────────────
            ' 2. عنوان المستند (Document Title Box)
            ' ─────────────────────────────────────────────
            Dim titleRect As New RectangleF(marginX + 30, curY, width - 60, 32)
            g.FillRectangle(New SolidBrush(Color.FromArgb(245, 247, 250)), titleRect)
            g.DrawRectangle(New Pen(Color.FromArgb(200, 210, 220), 1.5F), Rectangle.Round(titleRect))

            Dim docTitleText = ""
            Select Case _docType
                Case "Commencement" : docTitleText = "نموذج مباشرة عمل (تعيين / عودة من إجازة)"
                Case "Leave" : docTitleText = "نموذج طلب وموافقة إجازة رسمية"
                Case "Settlement" : docTitleText = "تصفية مستحقات ونهاية خدمة وإبراء ذمة"
                Case "Payslip" : docTitleText = $"قسيمة راتب شهر {_payrollBatch?.Month:D2} / {_payrollBatch?.Year}"
                Case "BatchReport" : docTitleText = $"كشف مسير الرواتب والأجور لشهر {_payrollBatch?.Month:D2} / {_payrollBatch?.Year} (الحالة: {If(_payrollBatch?.Status = "Approved", "معتمد", "مسودة")})"
            End Select

            g.DrawString(docTitleText, _printFontHeader, Brushes.DarkBlue, titleRect, centerFmt)
            curY = titleRect.Bottom + 18


            If _docType <> "BatchReport" Then
                ' Employee Section Box
                DrawSectionHeader(g, "1. البيانات الأساسية للموظف", rightX, curY, width, rtl)
                curY += 28

                Dim empCode = If(_emp?.EmployeeCode, "-")
                Dim empName = If(_emp?.FullName, "-")
                Dim jobTitle = If(_emp?.JobTitle, "-")
                Dim dept = If(_emp?.Department, "-")
                Dim civilID = If(_emp?.CivilID, "-")
                Dim hireDate = If(_emp?.HireDate.ToString("yyyy-MM-dd"), "-")

                DrawDataRow(g, "اسم الموظف:", empName, "الرقم الوظيفي:", empCode, marginX, rightX, curY, width, rtl)
                curY += 24
                DrawDataRow(g, "المسمى الوظيفي:", jobTitle, "القسم / الإدارة:", dept, marginX, rightX, curY, width, rtl)
                curY += 24
                DrawDataRow(g, "الرقم المدني/الوطني:", civilID, "تاريخ التعيين:", hireDate, marginX, rightX, curY, width, rtl)
                curY += 35
            End If

            ' Specific Content per Type
            Select Case _docType
                Case "Commencement"
                    DrawSectionHeader(g, "2. تفاصيل مباشرة العمل", rightX, curY, width, rtl)
                    curY += 28
                    Dim resDate = If(_leave?.ResumptionDate?.ToString("yyyy-MM-dd"), DateTime.Today.ToString("yyyy-MM-dd"))
                    Dim expDate = If(_leave?.ExpectedReturnDate.ToString("yyyy-MM-dd"), "-")
                    Dim delay = If(_leave IsNot Nothing, _leave.DelayDays.ToString() & " يوم", "0 يوم")

                    DrawDataRow(g, "تاريخ المباشرة الفعلي:", resDate, "العودة المقررة أصلاً:", expDate, marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "أيام التأخير المسجلة:", delay, "نوع المباشرة:", "عودة من إجازة", marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "ملاحظات المباشرة:", If(_leave?.ResumptionNotes, If(_extraNotes, "باشر الموظف عمله بانتظام")), "", "", marginX, rightX, curY, width, rtl)
                    curY += 40

                Case "Leave"
                    DrawSectionHeader(g, "2. تفاصيل الإجازة والرصيد", rightX, curY, width, rtl)
                    curY += 28
                    Dim lType = If(_leave?.LeaveTypeName, "إجازة سنوية")
                    Dim sDate = If(_leave?.StartDate.ToString("yyyy-MM-dd"), "-")
                    Dim eDate = If(_leave?.EndDate.ToString("yyyy-MM-dd"), "-")
                    Dim days = If(_leave?.DaysCount.ToString(), "-") & " يوماً"

                    DrawDataRow(g, "نوع الإجازة:", lType, "المدة المطلوبة:", days, marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "تاريخ بدء الإجازة:", sDate, "تاريخ الانتهاء:", eDate, marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "الرصيد المتبقي:", _extraNotes & " يوم", "سبب الإجازة:", If(_leave?.Reason, "إجازة سنوية اعتيادية"), marginX, rightX, curY, width, rtl)
                    curY += 40

                Case "Settlement"
                    DrawSectionHeader(g, "2. التفصيل المالي ومكافأة نهاية الخدمة", rightX, curY, width, rtl)
                    curY += 28
                    Dim dur = If(_settlement?.DurationDescription, "-")
                    Dim reason = If(_settlement?.DepartureReason, "إنهاء خدمة")
                    Dim lastSal = If(_settlement IsNot Nothing, (_settlement.LastBasicSalary + _settlement.LastAllowances).ToString("N3"), "0.000")
                    Dim indemnity = If(_settlement IsNot Nothing, _settlement.IndemnityAmount.ToString("N3"), "0.000")
                    Dim leaveComp = If(_settlement IsNot Nothing, _settlement.UnpaidLeaveCompensation.ToString("N3"), "0.000")
                    Dim deductions = If(_settlement IsNot Nothing, _settlement.DeductionsLoans.ToString("N3"), "0.000")
                    Dim netPayout = If(_settlement IsNot Nothing, _settlement.NetSettlementAmount.ToString("N3"), "0.000")

                    DrawDataRow(g, "مدة الخدمة:", dur, "سبب ترك العمل:", reason, marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "الراتب الشامل الأخير:", lastSal, "مكافأة نهاية الخدمة:", indemnity, marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "تعويض رصيد الإجازات:", leaveComp, "الخصومات والسلف:", deductions, marginX, rightX, curY, width, rtl)
                    curY += 28

                    Dim netBox As New RectangleF(marginX + 50, curY, width - 100, 32)
                    g.FillRectangle(New SolidBrush(Color.FromArgb(235, 250, 240)), netBox)
                    g.DrawRectangle(Pens.MediumSeaGreen, Rectangle.Round(netBox))
                    g.DrawString($"صافي المستحقات النهائي للصرف: {netPayout}", _printFontBold, Brushes.DarkGreen, netBox, centerFmt)
                    curY += 45

                Case "Payslip"
                    DrawSectionHeader(g, "2. مفردات الراتب والبدلات والاستقطاعات", rightX, curY, width, rtl)
                    curY += 28
                    Dim basic = If(_payrollDetail IsNot Nothing, _payrollDetail.BasicSalary.ToString("N3"), "0.000")
                    Dim allowances = If(_payrollDetail IsNot Nothing, _payrollDetail.TotalAllowances.ToString("N3"), "0.000")
                    Dim overtime = If(_payrollDetail IsNot Nothing, _payrollDetail.OvertimeAmount.ToString("N3"), "0.000")
                    Dim deductions = If(_payrollDetail IsNot Nothing, _payrollDetail.TotalDeductions.ToString("N3"), "0.000")
                    Dim net = If(_payrollDetail IsNot Nothing, _payrollDetail.NetSalary.ToString("N3"), "0.000")

                    DrawDataRow(g, "الراتب الأساسي:", basic, "إجمالي البدلات:", allowances, marginX, rightX, curY, width, rtl)
                    curY += 24
                    DrawDataRow(g, "ساعات/قيمة الإضافي:", overtime, "إجمالي الاستقطاعات:", deductions, marginX, rightX, curY, width, rtl)
                    curY += 28

                    Dim netBox As New RectangleF(marginX + 50, curY, width - 100, 32)
                    g.FillRectangle(New SolidBrush(Color.FromArgb(235, 250, 240)), netBox)
                    g.DrawRectangle(Pens.MediumSeaGreen, Rectangle.Round(netBox))
                    g.DrawString($"صافي الراتب المستلم: {net}", _printFontBold, Brushes.DarkGreen, netBox, centerFmt)
                    curY += 45

                Case "BatchReport"
                    ' Summary Totals Card in Print Header
                    Dim sumRect As New RectangleF(marginX, curY, width, 24)
                    g.FillRectangle(New SolidBrush(Color.FromArgb(248, 250, 252)), sumRect)
                    g.DrawRectangle(Pens.LightGray, Rectangle.Round(sumRect))
                    Dim sumText = $"عدد الموظفين: {_payrollDetailsList.Count}  |  إجمالي الأساسي: {_payrollBatch?.TotalBasic:N3}  |  إجمالي البدلات: {_payrollBatch?.TotalAllowances:N3}  |  إجمالي الإضافي: {_payrollBatch?.TotalOvertime:N3}  |  إجمالي الخصومات: {_payrollBatch?.TotalDeductions:N3}  |  الصافي الإجمالي: {_payrollBatch?.TotalNetSalary:N3}"
                    g.DrawString(sumText, _printFontBold, Brushes.DarkSlateGray, sumRect, centerFmt)
                    curY += 30

                    ' Columns widths
                    Dim colCodeW As Single = 75
                    Dim colNameW As Single = 170
                    Dim colDeptW As Single = 120
                    Dim colBasicW As Single = 85
                    Dim colAllowW As Single = 80
                    Dim colOverW As Single = 80
                    Dim colDeductW As Single = 85
                    Dim colAdvW As Single = 80
                    Dim colNetW As Single = 100
                    Dim colStatusW As Single = width - (colCodeW + colNameW + colDeptW + colBasicW + colAllowW + colOverW + colDeductW + colAdvW + colNetW)

                    Dim tblHeaderRect As New RectangleF(marginX, curY, width, 26)
                    g.FillRectangle(New SolidBrush(Color.FromArgb(238, 242, 255)), tblHeaderRect)
                    g.DrawRectangle(Pens.SlateGray, Rectangle.Round(tblHeaderRect))

                    Dim curColX As Single = rightX
                    Dim drawColHeader = Sub(title As String, w As Single)
                                            curColX -= w
                                            g.DrawString(title, _printFontBold, Brushes.MidnightBlue, New RectangleF(curColX, curY, w, 26), centerFmt)
                                            g.DrawLine(Pens.LightGray, curColX, curY, curColX, curY + 26)
                                        End Sub

                    drawColHeader("الكود", colCodeW)
                    drawColHeader("اسم الموظف", colNameW)
                    drawColHeader("القسم", colDeptW)
                    drawColHeader("الأساسي", colBasicW)
                    drawColHeader("البدلات", colAllowW)
                    drawColHeader("إضافي", colOverW)
                    drawColHeader("خصومات", colDeductW)
                    drawColHeader("سلف", colAdvW)
                    drawColHeader("صافي الراتب", colNetW)
                    drawColHeader("الحالة", colStatusW)

                    curY += 26

                    ' Data Rows
                    Dim rowIdx As Integer = 0
                    For Each row In _payrollDetailsList
                        Dim rowRect As New RectangleF(marginX, curY, width, 22)
                        If rowIdx Mod 2 = 1 Then
                            g.FillRectangle(New SolidBrush(Color.FromArgb(248, 250, 252)), rowRect)
                        End If
                        g.DrawRectangle(Pens.LightGray, Rectangle.Round(rowRect))

                        curColX = rightX
                        Dim drawCell = Sub(text As String, w As Single, isBold As Boolean, fontBrush As Brush)
                                           curColX -= w
                                           Dim f = If(isBold, _printFontBold, _printFontSmall)
                                           g.DrawString(text, f, fontBrush, New RectangleF(curColX, curY, w, 22), centerFmt)
                                           g.DrawLine(Pens.LightGray, curColX, curY, curColX, curY + 22)
                                       End Sub

                        drawCell(row.EmployeeCode, colCodeW, True, Brushes.Black)
                        drawCell(row.EmployeeName, colNameW, False, Brushes.Black)
                        drawCell(row.Department, colDeptW, False, Brushes.DimGray)
                        drawCell(row.BasicSalary.ToString("N3"), colBasicW, False, Brushes.Black)
                        drawCell(row.TotalAllowances.ToString("N3"), colAllowW, False, Brushes.DarkGreen)
                        drawCell(row.OvertimeAmount.ToString("N3"), colOverW, False, Brushes.DarkBlue)
                        drawCell(row.DeductionAmount.ToString("N3"), colDeductW, False, Brushes.DarkRed)
                        drawCell(row.AdvancesDeductions.ToString("N3"), colAdvW, False, Brushes.Purple)
                        drawCell(row.NetSalary.ToString("N3"), colNetW, True, Brushes.DarkGreen)
                        drawCell(If(row.PaymentStatus = "Paid", "مدفوع", "غير مدفوع"), colStatusW, False, If(row.PaymentStatus = "Paid", Brushes.Green, Brushes.Red))

                        curY += 22
                        rowIdx += 1
                    Next

                    ' Totals Bottom Row
                    Dim totRect As New RectangleF(marginX, curY, width, 26)
                    g.FillRectangle(New SolidBrush(Color.FromArgb(236, 253, 245)), totRect)
                    g.DrawRectangle(Pens.MediumSeaGreen, Rectangle.Round(totRect))

                    curColX = rightX
                    Dim drawTotCell = Sub(text As String, w As Single, isBold As Boolean, fontBrush As Brush)
                                          curColX -= w
                                          Dim f = If(isBold, _printFontBold, _printFontSmall)
                                          g.DrawString(text, f, fontBrush, New RectangleF(curColX, curY, w, 26), centerFmt)
                                          g.DrawLine(Pens.MediumSeaGreen, curColX, curY, curColX, curY + 26)
                                      End Sub

                    drawTotCell("الإجمالي", colCodeW + colNameW + colDeptW, True, Brushes.DarkSlateGray)
                    drawTotCell(_payrollBatch?.TotalBasic.ToString("N3"), colBasicW, True, Brushes.Black)
                    drawTotCell(_payrollBatch?.TotalAllowances.ToString("N3"), colAllowW, True, Brushes.DarkGreen)
                    drawTotCell(_payrollBatch?.TotalOvertime.ToString("N3"), colOverW, True, Brushes.DarkBlue)
                    drawTotCell(_payrollBatch?.TotalDeductions.ToString("N3"), colDeductW, True, Brushes.DarkRed)
                    drawTotCell(_payrollDetailsList.Sum(Function(d) d.AdvancesDeductions).ToString("N3"), colAdvW, True, Brushes.Purple)
                    drawTotCell(_payrollBatch?.TotalNetSalary.ToString("N3"), colNetW, True, Brushes.DarkGreen)
                    drawTotCell("-", colStatusW, False, Brushes.Gray)

                    curY += 35
            End Select

            ' Signatures Footer
            curY = Math.Max(curY + 30, e.MarginBounds.Bottom - 85)
            g.DrawLine(New Pen(Color.LightGray, 1) With {.DashStyle = Drawing2D.DashStyle.Dash}, marginX, curY, rightX, curY)
            curY += 15

            Dim colSignW = width / 3.0F
            g.DrawString("المحاسب / إعداد", _printFontBold, Brushes.Black, New RectangleF(rightX - colSignW, curY, colSignW, 20), centerFmt)
            g.DrawString("الموارد البشرية / تدقيق", _printFontBold, Brushes.Black, New RectangleF(rightX - 2 * colSignW, curY, colSignW, 20), centerFmt)
            g.DrawString("المدير المالي / اعتماد", _printFontBold, Brushes.Black, New RectangleF(marginX, curY, colSignW, 20), centerFmt)

            g.DrawLine(Pens.Gray, rightX - colSignW + 30, curY + 45, rightX - 30, curY + 45)
            g.DrawLine(Pens.Gray, rightX - 2 * colSignW + 30, curY + 45, rightX - colSignW - 30, curY + 45)
            g.DrawLine(Pens.Gray, marginX + 30, curY + 45, marginX + colSignW - 30, curY + 45)

            e.HasMorePages = False
        End Sub

        Private Sub DrawSectionHeader(g As Graphics, title As String, rightX As Single, curY As Single, width As Single, rtl As StringFormat)
            Dim rect As New RectangleF(rightX - width, curY, width, 22)
            g.FillRectangle(New SolidBrush(Color.FromArgb(240, 244, 248)), rect)
            g.FillRectangle(New SolidBrush(Color.FromArgb(79, 70, 229)), rightX - 5, curY, 5, 22)
            g.DrawString(title, _printFontBold, Brushes.DarkSlateGray, New RectangleF(rightX - width + 10, curY + 1, width - 20, 20), rtl)
        End Sub

        Private Sub DrawDataRow(g As Graphics, lbl1 As String, val1 As String, lbl2 As String, val2 As String, marginX As Single, rightX As Single, curY As Single, width As Single, rtl As StringFormat)
            Dim colW = width / 2.0F
            ' Col 1
            g.DrawString(lbl1, _printFontNormal, Brushes.Gray, New RectangleF(rightX - 120, curY, 120, 20), rtl)
            g.DrawString(val1, _printFontBold, Brushes.Black, New RectangleF(rightX - colW, curY, colW - 120, 20), rtl)
            ' Col 2
            If Not String.IsNullOrEmpty(lbl2) Then
                g.DrawString(lbl2, _printFontNormal, Brushes.Gray, New RectangleF(rightX - colW - 120, curY, 120, 20), rtl)
                g.DrawString(val2, _printFontBold, Brushes.Black, New RectangleF(marginX, curY, colW - 120, 20), rtl)
            End If
        End Sub
    End Class
End Namespace
