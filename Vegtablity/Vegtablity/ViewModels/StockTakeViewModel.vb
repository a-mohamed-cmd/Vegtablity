Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class StockTakeViewModel
        Inherits BaseViewModel

        ' Events
        Public Event RequestSnackbar(message As String)

        Private ReadOnly _stockTakeService As New StockTakeService()
        Private ReadOnly _productService As New ProductService()
        Private ReadOnly _inventoryService As New InventoryService()
        Private ReadOnly _warehouseService As New WarehouseService()

        ' Products for Autocomplete
        Public Property AvailableProducts As New ObservableCollection(Of Product)()

        ' Warehouses
        Private _warehouses As ObservableCollection(Of Warehouse)
        Public Property Warehouses As ObservableCollection(Of Warehouse)
            Get
                Return _warehouses
            End Get
            Set(value As ObservableCollection(Of Warehouse))
                SetProperty(_warehouses, value)
            End Set
        End Property

        ' History
        Private _stockTakeHistory As ObservableCollection(Of StockTakeHeader)
        Public Property StockTakeHistory As ObservableCollection(Of StockTakeHeader)
            Get
                Return _stockTakeHistory
            End Get
            Set(value As ObservableCollection(Of StockTakeHeader))
                SetProperty(_stockTakeHistory, value)
            End Set
        End Property

        Private _selectedStockTake As StockTakeHeader
        Public Property SelectedStockTake As StockTakeHeader
            Get
                Return _selectedStockTake
            End Get
            Set(value As StockTakeHeader)
                _selectedStockTake = value
                OnPropertyChanged(NameOf(SelectedStockTake))
                If value IsNot Nothing Then
                    IsEditing = False
                    CurrentStockTake = Nothing
                    LoadStockTakeDetails(value.StockTakeID)
                End If
                CommandManager.InvalidateRequerySuggested()
            End Set
        End Property

        ' يُستدعى من Code-Behind لإعادة تحميل نفس السجل عند النقر عليه مرتين
        Public Sub ForceLoadDetails(header As StockTakeHeader)
            If header IsNot Nothing Then
                IsEditing = False
                CurrentStockTake = Nothing
                LoadStockTakeDetails(header.StockTakeID)
                CommandManager.InvalidateRequerySuggested()
            End If
        End Sub

        ' Current Stock Take
        Private _currentStockTake As StockTakeHeader
        Public Property CurrentStockTake As StockTakeHeader
            Get
                Return _currentStockTake
            End Get
            Set(value As StockTakeHeader)
                SetProperty(_currentStockTake, value)
            End Set
        End Property

        Private _isEditing As Boolean
        Public Property IsEditing As Boolean
            Get
                Return _isEditing
            End Get
            Set(value As Boolean)
                SetProperty(_isEditing, value)
            End Set
        End Property

        ' تحكم في تفعيل ComboBox المستودع
        Private _isWarehouseEnabled As Boolean = True
        Public Property IsWarehouseEnabled As Boolean
            Get
                Return _isWarehouseEnabled
            End Get
            Set(value As Boolean)
                SetProperty(_isWarehouseEnabled, value)
            End Set
        End Property

        ' Pagination
        Private _currentPage As Integer = 1
        Private Const PageSize As Integer = 20
        Private _totalRecords As Integer

        ' Commands
        Public Property AddNewCommand As ICommand
        Public Property SaveCommand As ICommand
        Public Property EditCommand As ICommand
        Public Property ApproveCommand As ICommand
        Public Property RefreshCommand As ICommand
        Public Property FetchSystemQuantityCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand
        Public Property ImportExcelCommand As ICommand
        Public Property PrintCommand As ICommand

        Public Sub New()
            AddNewCommand = New RelayCommand(AddressOf AddNew)
            SaveCommand = New RelayCommand(AddressOf Save, AddressOf CanSave)
            EditCommand = New RelayCommand(AddressOf EditDraft, AddressOf CanEditDraft)
            ApproveCommand = New RelayCommand(AddressOf Approve, AddressOf CanApprove)
            RefreshCommand = New RelayCommand(AddressOf LoadHistory)
            FetchSystemQuantityCommand = New RelayCommand(AddressOf FetchSystemQuantity)
            DownloadTemplateCommand = New RelayCommand(AddressOf DownloadTemplate)
            ImportExcelCommand = New RelayCommand(AddressOf ImportFromExcel, AddressOf CanImport)
            PrintCommand = New RelayCommand(AddressOf PrintStockTake, AddressOf CanPrintStockTake)
            
            LoadProducts()
            LoadWarehouses()
            LoadHistory()
        End Sub

        Private Sub LoadProducts()
            Try
                Dim prods = _productService.GetAllProducts()
                AvailableProducts = New ObservableCollection(Of Product)(prods)
            Catch ex As Exception
                ' Log error
            End Try
        End Sub

        Private Sub LoadWarehouses()
            Try
                Dim list = _warehouseService.GetAllWarehouses()
                Warehouses = New ObservableCollection(Of Warehouse)(list)
            Catch ex As Exception
                ' Log error
            End Try
        End Sub

        Private Sub LoadHistory()
            Try
                Dim result = _stockTakeService.GetStockTakeHistory(_currentPage, PageSize)
                ' نُحدِّث الكوليكشن بدون إعادة إنشائها لتجنب فقدان الـ Selection
                If StockTakeHistory Is Nothing Then
                    StockTakeHistory = New ObservableCollection(Of StockTakeHeader)(result.Data)
                Else
                    StockTakeHistory.Clear()
                    For Each item In result.Data
                        StockTakeHistory.Add(item)
                    Next
                End If
                _totalRecords = result.TotalCount
            Catch ex As Exception
                MessageBox.Show("خطأ في تحميل سجل الجرد: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub LoadStockTakeDetails(id As Integer)
            Try
                Dim details = _stockTakeService.GetStockTakeDetails(id)
                SelectedStockTake.Details = New ObservableCollection(Of StockTakeDetails)(details)
            Catch ex As Exception
                ' Log
            End Try
        End Sub

        Private Sub AddNew()
            Dim defaultWarehouseId = If(Warehouses IsNot Nothing AndAlso Warehouses.Any(), Warehouses.First().WarehouseID, 1)

            CurrentStockTake = New StockTakeHeader() With {
                .StockTakeDate = DateTime.Now,
                .UserID = Services.Session.CurrentUser.UserID,
                .WarehouseID = defaultWarehouseId,
                .Status = "Pending",
                .Details = New ObservableCollection(Of StockTakeDetails)()
            }
            ' فعّل اختيار المستودع عند إنشاء ورقة جديدة
            IsWarehouseEnabled = True
            IsEditing = True
        End Sub

        Private Function CanEditDraft() As Boolean
            Return SelectedStockTake IsNot Nothing AndAlso SelectedStockTake.Status = "Pending" AndAlso Not IsEditing
        End Function

        Private Sub EditDraft()
            If SelectedStockTake IsNot Nothing Then
                CurrentStockTake = SelectedStockTake
                For Each d In CurrentStockTake.Details
                    AttachDetailHandler(d)
                Next
                ' فعّل اختيار المستودع عند فتح التعديل
                IsWarehouseEnabled = True
                IsEditing = True
            End If
        End Sub

        Public Sub AttachDetailHandler(detail As StockTakeDetails)
            AddHandler detail.PropertyChanged, AddressOf OnDetailPropertyChanged
        End Sub

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            Dim detail = TryCast(sender, StockTakeDetails)
            If detail Is Nothing Then Return

            If e.PropertyName = NameOf(StockTakeDetails.ProductID) Then
                Dim prod = AvailableProducts.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                If prod IsNot Nothing Then
                    detail.ProductCode = If(Not String.IsNullOrEmpty(prod.Barcode), prod.Barcode, prod.ProductID.ToString())
                    detail.ProductName = prod.ProductName
                    ' Automatically fetch quantity from system when product selected
                    FetchSystemQuantity(detail)
                End If
            ElseIf e.PropertyName = NameOf(StockTakeDetails.ProductCode) Then
                ' User typed code manually
                If Not String.IsNullOrEmpty(detail.ProductCode) Then
                    Dim prod = AvailableProducts.FirstOrDefault(Function(p) p.Barcode = detail.ProductCode OrElse p.ProductID.ToString() = detail.ProductCode)
                    If prod IsNot Nothing AndAlso prod.ProductID <> detail.ProductID Then
                        detail.ProductID = prod.ProductID
                        detail.ProductName = prod.ProductName
                        FetchSystemQuantity(detail)
                    End If
                End If
            End If

            ' If differences are changed, recalculate total
            If e.PropertyName = NameOf(StockTakeDetails.DifferenceValue) Then
                If CurrentStockTake IsNot Nothing AndAlso CurrentStockTake.Details IsNot Nothing Then
                    CurrentStockTake.TotalDifferenceValue = CurrentStockTake.Details.Sum(Function(d) d.DifferenceValue)
                End If
            End If
        End Sub

        Private Sub FetchSystemQuantity(param As Object)
            Dim detail = TryCast(param, StockTakeDetails)
            If detail IsNot Nothing AndAlso detail.ProductID > 0 AndAlso CurrentStockTake IsNot Nothing Then
                Try
                    detail.SystemQuantity = _inventoryService.GetStockByProduct(detail.ProductID, CurrentStockTake.WarehouseID)
                    detail.CostPrice = _inventoryService.GetAvgCostByProduct(detail.ProductID, CurrentStockTake.WarehouseID)
                Catch ex As Exception
                    ' Log error
                End Try
            End If
        End Sub

        Private Function CanSave() As Boolean
            Return IsEditing AndAlso CurrentStockTake IsNot Nothing AndAlso CurrentStockTake.Details.Count > 0 AndAlso CurrentStockTake.Status = "Pending"
        End Function

        Private Sub Save()
            Try
                CurrentStockTake.TotalDifferenceValue = CurrentStockTake.Details.Sum(Function(d) d.DifferenceValue)
                Dim newId = _stockTakeService.SaveStockTake(CurrentStockTake, CurrentStockTake.Details.ToList())
                RaiseEvent RequestSnackbar("✅ تم حفظ مسودة الجرد بنجاح")
                IsEditing = False
                LoadHistory()
            Catch ex As Exception
                MessageBox.Show(ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanApprove() As Boolean
            Return SelectedStockTake IsNot Nothing AndAlso SelectedStockTake.Status = "Pending"
        End Function

        Private Sub Approve()
            If MessageBox.Show("هل أنت متأكد من اعتماد الجرد وتعديل الكميات في النظام لتطابق الكميات الفعلية؟ لا يمكن التراجع عن هذه العملية.", "تأكيد الاعتماد", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _stockTakeService.ApproveStockTake(SelectedStockTake.StockTakeID, Services.Session.CurrentUser.UserID)
                    RaiseEvent RequestSnackbar("✅ تم اعتماد الجرد وتعديل الكميات بنجاح")
                    LoadHistory()
                Catch ex As Exception
                    MessageBox.Show(ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        ' ─────────────────────────────────────────────
        ' استيراد وتنزيل قالب Excel
        ' ─────────────────────────────────────────────
        Private Function CanImport() As Boolean
            Return IsEditing AndAlso CurrentStockTake IsNot Nothing AndAlso CurrentStockTake.Status = "Pending"
        End Function

        Private Sub DownloadTemplate()
            Try
                Dim dlg As New Microsoft.Win32.SaveFileDialog() With {
                    .Title           = "حفظ قالب استيراد الجرد",
                    .FileName        = "قالب_استيراد_الجرد.xlsx",
                    .Filter          = "Excel Files (*.xlsx)|*.xlsx",
                    .DefaultExt      = "xlsx",
                    .OverwritePrompt = True
                }
                If dlg.ShowDialog() <> True Then Return

                Using ms As New System.IO.MemoryStream()
                    Using doc = DocumentFormat.OpenXml.Packaging.SpreadsheetDocument.Create(
                                    ms, DocumentFormat.OpenXml.SpreadsheetDocumentType.Workbook)

                        Dim wbPart = doc.AddWorkbookPart()
                        wbPart.Workbook = New DocumentFormat.OpenXml.Spreadsheet.Workbook()

                        Dim wsPart = wbPart.AddNewPart(Of DocumentFormat.OpenXml.Packaging.WorksheetPart)()
                        Dim sheetData As New DocumentFormat.OpenXml.Spreadsheet.SheetData()
                        wsPart.Worksheet = New DocumentFormat.OpenXml.Spreadsheet.Worksheet(sheetData)

                        Dim sheets As New DocumentFormat.OpenXml.Spreadsheet.Sheets()
                        wbPart.Workbook.AppendChild(sheets)
                        Dim sh As New DocumentFormat.OpenXml.Spreadsheet.Sheet() With {
                            .Id      = wbPart.GetIdOfPart(wsPart),
                            .SheetId = 1,
                            .Name    = "الجرد"
                        }
                        sheets.AppendChild(sh)

                        ' Header
                        Dim headerRow As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 1}
                        Dim hdrLabels = {"كود الصنف / الباركود (*)", "الكمية الفعلية (*)", "اسم الصنف (للمرجع)"}
                        Dim hdrCols   = {"A", "B", "C"}
                        For i = 0 To hdrLabels.Length - 1
                            headerRow.AppendChild(MakeTextCell(hdrCols(i) & "1", hdrLabels(i)))
                        Next
                        sheetData.AppendChild(headerRow)

                        ' Rows 2-33: Empty data rows
                        For r = 2 To 33
                            Dim dr As New DocumentFormat.OpenXml.Spreadsheet.Row() With {
                                .RowIndex = CUInt(r)
                            }
                            dr.AppendChild(MakeTextCell("A" & r, ""))
                            dr.AppendChild(MakeNumberCell("B" & r, ""))
                            sheetData.AppendChild(dr)
                        Next

                        ' Instructions
                        Dim instrHdr As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 35}
                        instrHdr.AppendChild(MakeTextCell("A35", "تعليمات الاستيراد:"))
                        sheetData.AppendChild(instrHdr)

                        Dim notes() As String = {
                            "1. العمود A (إلزامي): كود الصنف أو الباركود.",
                            "2. العمود B (إلزامي): الكمية الفعلية الموجودة في المستودع.",
                            "3. العمود C (اختياري): اسم الصنف للمرجع فقط."
                        }
                        For n = 0 To notes.Length - 1
                            Dim nr As New DocumentFormat.OpenXml.Spreadsheet.Row() With {
                                .RowIndex = CUInt(36 + n)
                            }
                            nr.AppendChild(MakeTextCell("A" & (36 + n), notes(n)))
                            sheetData.AppendChild(nr)
                        Next

                        wbPart.Workbook.Save()
                    End Using

                    System.IO.File.WriteAllBytes(dlg.FileName, ms.ToArray())
                End Using

                Process.Start(New System.Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                RaiseEvent RequestSnackbar("✅ تم إنشاء القالب — افتحه وأدخل البيانات ثم استورد")

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء إنشاء القالب: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ─────────────────────────────────────────────
        ' طباعة سند الجرد (PDF)
        ' ─────────────────────────────────────────────
        Private Function CanPrintStockTake() As Boolean
            Return SelectedStockTake IsNot Nothing AndAlso SelectedStockTake.StockTakeID > 0
        End Function

        Private Sub PrintStockTake()
            Try
                If SelectedStockTake Is Nothing OrElse SelectedStockTake.StockTakeID = 0 Then
                    RaiseEvent RequestSnackbar("⚠️ اختر مستند جرد محفوظ من القائمة أولاً")
                    Return
                End If

                ' Ensure details are loaded for printing
                If SelectedStockTake.Details Is Nothing OrElse SelectedStockTake.Details.Count = 0 Then
                    Dim details = _stockTakeService.GetStockTakeDetails(SelectedStockTake.StockTakeID)
                    SelectedStockTake.Details = New ObservableCollection(Of StockTakeDetails)(details)
                End If

                ' Attach warehouse name for print
                If Warehouses IsNot Nothing Then
                    Dim wh = Warehouses.FirstOrDefault(Function(w) w.WarehouseID = SelectedStockTake.WarehouseID)
                    If wh IsNot Nothing Then SelectedStockTake.WarehouseName = wh.WarehouseName
                End If

                Helpers.ReportExporter.ExportStockTakeVoucherToPdf(SelectedStockTake)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء طباعة سند الجرد: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ImportFromExcel()
            Try
                Dim dlg As New Microsoft.Win32.OpenFileDialog() With {
                    .Title  = "استيراد الجرد من Excel",
                    .Filter = "Excel Files (*.xlsx)|*.xlsx",
                    .CheckFileExists = True
                }
                If dlg.ShowDialog() <> True Then Return

                If CurrentStockTake.Details Is Nothing Then
                    CurrentStockTake.Details = New System.Collections.ObjectModel.ObservableCollection(Of StockTakeDetails)()
                End If

                Dim matchedCount As Integer = 0
                Dim unmatchedList As New System.Text.StringBuilder()

                Using doc As DocumentFormat.OpenXml.Packaging.SpreadsheetDocument =
                          DocumentFormat.OpenXml.Packaging.SpreadsheetDocument.Open(dlg.FileName, False)

                    Dim wbPart  = doc.WorkbookPart
                    Dim sheet   = wbPart.Workbook.Sheets.Elements(Of DocumentFormat.OpenXml.Spreadsheet.Sheet)().FirstOrDefault()
                    If sheet Is Nothing Then
                        RaiseEvent RequestSnackbar("⚠️ الملف فارغ أو لا يحتوي على بيانات")
                        Return
                    End If

                    Dim wsPart = CType(wbPart.GetPartById(sheet.Id), DocumentFormat.OpenXml.Packaging.WorksheetPart)
                    Dim allRows = wsPart.Worksheet.Descendants(Of DocumentFormat.OpenXml.Spreadsheet.Row)().ToList()
                    Dim sst As DocumentFormat.OpenXml.Packaging.SharedStringTablePart = wbPart.SharedStringTablePart

                    If allRows.Count = 0 Then
                        RaiseEvent RequestSnackbar("⚠️ الملف فارغ أو لا يحتوي على بيانات")
                        Return
                    End If

                    Dim dataStartIndex As Integer = 1
                    For idx = 0 To Math.Min(9, allRows.Count - 1)
                        Dim scanCells = allRows(idx).Elements(Of DocumentFormat.OpenXml.Spreadsheet.Cell)().ToList()
                        Dim scanVal = GetCellStringValue(scanCells, "A", sst).Trim()
                        If scanVal.Contains("كود") OrElse scanVal.ToLower().Contains("code") OrElse scanVal.ToLower().Contains("barcode") Then
                            dataStartIndex = idx + 1
                            Exit For
                        End If
                    Next

                    For rowIdx = dataStartIndex To allRows.Count - 1
                        Dim cells = allRows(rowIdx).Elements(Of DocumentFormat.OpenXml.Spreadsheet.Cell)().ToList()
                        If cells.Count = 0 Then Continue For

                        Dim codeVal = GetCellStringValue(cells, "A", sst).Trim()
                        Dim qtyStr  = GetCellStringValue(cells, "B", sst).Trim()
                        If String.IsNullOrEmpty(codeVal) Then Continue For

                        Dim qty As Decimal = 0
                        Decimal.TryParse(qtyStr, System.Globalization.NumberStyles.Any,
                                         System.Globalization.CultureInfo.InvariantCulture, qty)

                        Dim prod = AvailableProducts.FirstOrDefault(
                            Function(p) (Not String.IsNullOrEmpty(p.Barcode) AndAlso p.Barcode = codeVal) OrElse
                                        p.ProductID.ToString() = codeVal OrElse
                                        (Not String.IsNullOrEmpty(p.ProductName) AndAlso
                                         p.ProductName.ToLower() = codeVal.ToLower()))

                        If prod IsNot Nothing Then
                            Dim newDetail As New StockTakeDetails() With {
                                .ProductID   = prod.ProductID,
                                .ProductCode = If(Not String.IsNullOrEmpty(prod.Barcode), prod.Barcode, prod.ProductID.ToString()),
                                .ProductName = prod.ProductName,
                                .ActualQuantity = qty
                            }
                            Try
                                Dim avgCost = _inventoryService.GetAvgCostByProduct(prod.ProductID, CurrentStockTake.WarehouseID)
                                newDetail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                            Catch
                                newDetail.CostPrice = prod.PurchasePrice
                            End Try
                            Try
                                newDetail.SystemQuantity = _inventoryService.GetStockByProduct(prod.ProductID, CurrentStockTake.WarehouseID)
                            Catch
                                newDetail.SystemQuantity = 0
                            End Try
                            
                            AttachDetailHandler(newDetail)
                            CurrentStockTake.Details.Add(newDetail)
                            matchedCount += 1
                        Else
                            unmatchedList.AppendLine($"  • {codeVal}")
                        End If
                    Next
                End Using

                CurrentStockTake.TotalDifferenceValue = CurrentStockTake.Details.Sum(Function(d) d.DifferenceValue)

                Dim msg = $"✅ تم استيراد {matchedCount} صنف بنجاح."
                If unmatchedList.Length > 0 Then
                    msg &= $"{vbCrLf}⚠️ الأصناف التالية لم تُعثر عليها:{vbCrLf}{unmatchedList}"
                    MessageBox.Show(msg, "نتيجة الاستيراد", MessageBoxButton.OK, MessageBoxImage.Warning)
                Else
                    RaiseEvent RequestSnackbar(msg)
                End If

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الاستيراد من Excel: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ── OpenXml Helpers ──────────────────
        Private Function GetCellStringValue(cells As List(Of DocumentFormat.OpenXml.Spreadsheet.Cell), colRef As String, sst As DocumentFormat.OpenXml.Packaging.SharedStringTablePart) As String
            Dim cell = cells.FirstOrDefault(Function(c) c.CellReference IsNot Nothing AndAlso c.CellReference.Value.StartsWith(colRef))
            If cell Is Nothing OrElse cell.CellValue Is Nothing Then Return ""

            Dim val = cell.CellValue.Text
            If cell.DataType IsNot Nothing AndAlso cell.DataType.Value = DocumentFormat.OpenXml.Spreadsheet.CellValues.SharedString Then
                If sst IsNot Nothing Then
                    Return sst.SharedStringTable.ElementAt(Integer.Parse(val)).InnerText
                End If
            End If
            Return val
        End Function

        Private Function MakeTextCell(cellRef As String, text As String) As DocumentFormat.OpenXml.Spreadsheet.Cell
            Return New DocumentFormat.OpenXml.Spreadsheet.Cell() With {
                .CellReference = cellRef,
                .DataType      = DocumentFormat.OpenXml.Spreadsheet.CellValues.String,
                .CellValue     = New DocumentFormat.OpenXml.Spreadsheet.CellValue(text)
            }
        End Function

        Private Function MakeNumberCell(cellRef As String, text As String) As DocumentFormat.OpenXml.Spreadsheet.Cell
            Return New DocumentFormat.OpenXml.Spreadsheet.Cell() With {
                .CellReference = cellRef,
                .DataType      = DocumentFormat.OpenXml.Spreadsheet.CellValues.Number,
                .CellValue     = New DocumentFormat.OpenXml.Spreadsheet.CellValue(text)
            }
        End Function

    End Class
End Namespace
