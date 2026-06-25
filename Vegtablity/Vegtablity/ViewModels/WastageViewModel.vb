Imports System.Collections.ObjectModel
Imports System.ComponentModel
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class WastageViewModel
        Inherits BaseViewModel

        Private ReadOnly _wastageService As New WastageService()
        Private ReadOnly _productService As New ProductService()
        Private ReadOnly _inventoryService As New InventoryService()
        Private ReadOnly _warehouseService As New WarehouseService()
        Private ReadOnly _permissionService As New PermissionService()

        Public Event RequestSnackbar As Action(Of String)
        
        Public Property Warehouses As New ObservableCollection(Of Warehouse)()
        
        ' Products for Autocomplete
        Public Property AvailableProducts As New ObservableCollection(Of Product)()

        ' History
        Private _wastageHistory As ObservableCollection(Of WastageHeader)
        Public Property WastageHistory As ObservableCollection(Of WastageHeader)
            Get
                Return _wastageHistory
            End Get
            Set(value As ObservableCollection(Of WastageHeader))
                SetProperty(_wastageHistory, value)
            End Set
        End Property

        Private _selectedWastage As WastageHeader
        Public Property SelectedWastage As WastageHeader
            Get
                Return _selectedWastage
            End Get
            Set(value As WastageHeader)
                SetProperty(_selectedWastage, value)
                If value IsNot Nothing Then
                    LoadWastageDetails(value)
                End If
            End Set
        End Property

        ' Current Wastage
        Private _currentWastage As WastageHeader
        Public Property CurrentWastage As WastageHeader
            Get
                Return _currentWastage
            End Get
            Set(value As WastageHeader)
                SetProperty(_currentWastage, value)
            End Set
        End Property

        Private Sub CurrentWastage_PropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If e.PropertyName = "WarehouseID" AndAlso CurrentWastage IsNot Nothing AndAlso CurrentWastage.Details IsNot Nothing Then
                ' Re-evaluate available stock when warehouse changes
                For Each detail In CurrentWastage.Details
                    If detail.ProductID > 0 Then
                        detail.AvailableQuantity = _inventoryService.GetStockByProduct(detail.ProductID, CurrentWastage.WarehouseID)
                    End If
                Next
            End If
        End Sub

        Private _isEditing As Boolean
        Public Property IsEditing As Boolean
            Get
                Return _isEditing
            End Get
            Set(value As Boolean)
                SetProperty(_isEditing, value)
            End Set
        End Property

        Private _isNewEntry As Boolean
        Public Property IsNewEntry As Boolean
            Get
                Return _isNewEntry
            End Get
            Set(value As Boolean)
                SetProperty(_isNewEntry, value)
            End Set
        End Property

        ' صلاحية إلغاء الترحيل (مربوطة بـ CanDelete في الـ RolePermissions)
        Private _canUnpostAllowed As Boolean = False
        Public Property CanUnpostAllowed As Boolean
            Get
                Return _canUnpostAllowed
            End Get
            Set(value As Boolean)
                SetProperty(_canUnpostAllowed, value)
            End Set
        End Property

        ' Pagination
        Private _currentPage As Integer = 1
        Private Const PageSize As Integer = 20
        Private _totalRecords As Integer

        ' Commands
        Public Property AddNewCommand As ICommand
        Public Property AddItemCommand As ICommand
        Public Property SaveCommand As ICommand
        Public Property PostCommand As ICommand
        Public Property UnpostCommand As ICommand
        Public Property RefreshCommand As ICommand
        Public Property RemoveItemCommand As ICommand
        Public Property PrintCommand As ICommand
        Public Property ImportFromExcelCommand As ICommand
        Public Property DownloadTemplateCommand As ICommand

        Public Sub New()
            AddNewCommand = New RelayCommand(AddressOf AddNew)
            AddItemCommand = New RelayCommand(AddressOf AddItem)
            SaveCommand = New RelayCommand(AddressOf Save, AddressOf CanSave)
            PostCommand = New RelayCommand(AddressOf Post, AddressOf CanPost)
            UnpostCommand = New RelayCommand(AddressOf Unpost, AddressOf CanUnpost)
            RefreshCommand = New RelayCommand(AddressOf LoadHistory)
            RemoveItemCommand = New RelayCommand(AddressOf RemoveItem)
            PrintCommand = New RelayCommand(AddressOf PrintWastage, AddressOf CanPrint)
            ImportFromExcelCommand = New RelayCommand(AddressOf ImportFromExcel, AddressOf CanImport)
            DownloadTemplateCommand = New RelayCommand(AddressOf DownloadTemplate, AddressOf CanImport)
            
            LoadWarehouses()
            LoadProducts()
            LoadHistory()
            LoadPermissions()
        End Sub

        Private Sub LoadPermissions()
            Try
                If Services.Session.CurrentUser Is Nothing Then Return
                Dim perm = _permissionService.GetPermissionsForForm(Services.Session.CurrentUser.RoleID, "Wastage")
                CanUnpostAllowed = perm.CanDelete
            Catch
                CanUnpostAllowed = False
            End Try
        End Sub

        Private Sub LoadWarehouses()
            Try
                Dim list = _warehouseService.GetAllWarehouses()
                Warehouses.Clear()
                For Each w In list
                    Warehouses.Add(w)
                Next
            Catch ex As Exception
                ' Handle error silently or log
            End Try
        End Sub

        Private Sub LoadProducts()
            Try
                Dim prods = _productService.GetAllProducts()
                AvailableProducts = New ObservableCollection(Of Product)(prods)
            Catch ex As Exception
                ' Log error
            End Try
        End Sub

        Private Sub LoadHistory()
            Try
                Dim result = _wastageService.GetWastageHistory(_currentPage, PageSize)
                WastageHistory = New ObservableCollection(Of WastageHeader)(result.Data)
                _totalRecords = result.TotalCount
            Catch ex As Exception
                MessageBox.Show("خطأ في تحميل سجل التوالف: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub LoadWastageDetails(header As WastageHeader)
            Try
                Dim details = _wastageService.GetWastageDetails(header.WastageID)
                header.Details = New ObservableCollection(Of WastageDetails)(details)
                AddHandler header.Details.CollectionChanged, AddressOf OnDetailsCollectionChanged
                For Each d In header.Details
                    AttachDetailHandler(d)
                Next
                ' Load into CurrentWastage for unified editing form
                CurrentWastage = header
                AddHandler CurrentWastage.PropertyChanged, AddressOf CurrentWastage_PropertyChanged
                IsNewEntry = False
                IsEditing = True
            Catch ex As Exception
                ' Log
            End Try
        End Sub

        Private Sub AddNew()
            Dim newWastage = New WastageHeader() With {
                .UserID = If(Services.Session.CurrentUser IsNot Nothing, Services.Session.CurrentUser.UserID, 0),
                .WastageDate = DateTime.Now,
                .WarehouseID = If(Warehouses.Any(), Warehouses.First().WarehouseID, 1)
            }
            CurrentWastage = newWastage
            AddHandler CurrentWastage.PropertyChanged, AddressOf CurrentWastage_PropertyChanged
            CurrentWastage.Details = New ObservableCollection(Of WastageDetails)()
            AddHandler CurrentWastage.Details.CollectionChanged, AddressOf OnDetailsCollectionChanged
            IsNewEntry = True
            IsEditing = True
            AddItem()
        End Sub

        Public Sub AddItem()
            If CurrentWastage Is Nothing OrElse CurrentWastage.Details Is Nothing Then Return
            Dim newDetail As New WastageDetails()
            AttachDetailHandler(newDetail)
            CurrentWastage.Details.Add(newDetail)
        End Sub

        Public Sub AttachDetailHandler(item As WastageDetails)
            If item IsNot Nothing Then
                RemoveHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                AddHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
            End If
        End Sub

        Private Sub OnDetailsCollectionChanged(sender As Object, e As Specialized.NotifyCollectionChangedEventArgs)
            If e.NewItems IsNot Nothing Then
                For Each item As WastageDetails In e.NewItems
                    AttachDetailHandler(item)
                Next
            End If
            If e.OldItems IsNot Nothing Then
                For Each item As WastageDetails In e.OldItems
                    RemoveHandler item.PropertyChanged, AddressOf OnDetailPropertyChanged
                Next
            End If
        End Sub

        Private _isUpdatingDetail As Boolean = False

        Private Sub OnDetailPropertyChanged(sender As Object, e As PropertyChangedEventArgs)
            If _isUpdatingDetail Then Return

            Dim detail = DirectCast(sender, WastageDetails)
            
            If e.PropertyName = "ProductCode" AndAlso Not String.IsNullOrEmpty(detail.ProductCode) Then
                _isUpdatingDetail = True
                Try
                    Dim prod = AvailableProducts.FirstOrDefault(Function(p) (Not String.IsNullOrEmpty(p.Barcode) AndAlso p.Barcode = detail.ProductCode) OrElse p.ProductID.ToString() = detail.ProductCode)
                    If prod IsNot Nothing Then
                        detail.ProductID = prod.ProductID
                        detail.ProductName = prod.ProductName
                        If detail.Quantity = 0 Then detail.Quantity = 1
                        
                        ' Use InventoryService to get Cost and Stock based on selected Warehouse
                        Try
                            Dim avgCost = _inventoryService.GetAvgCostByProduct(detail.ProductID, CurrentWastage.WarehouseID)
                            detail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                        Catch ex As Exception
                            detail.CostPrice = prod.PurchasePrice
                        End Try
                        
                        Try
                            detail.AvailableQuantity = _inventoryService.GetStockByProduct(detail.ProductID, CurrentWastage.WarehouseID)
                        Catch ex As Exception
                            detail.AvailableQuantity = 0
                        End Try
                    End If
                Catch ex As Exception
                    MessageBox.Show("خطأ أثناء جلب بيانات الصنف: " & ex.Message)
                End Try
                _isUpdatingDetail = False
            ElseIf e.PropertyName = "ProductID" AndAlso detail.ProductID > 0 Then
                _isUpdatingDetail = True
                Try
                    Dim prod = AvailableProducts.FirstOrDefault(Function(p) p.ProductID = detail.ProductID)
                    If prod IsNot Nothing Then
                        detail.ProductCode = If(Not String.IsNullOrEmpty(prod.Barcode), prod.Barcode, prod.ProductID.ToString())
                        detail.ProductName = prod.ProductName
                        If detail.Quantity = 0 Then detail.Quantity = 1
                        
                        Try
                            Dim avgCost = _inventoryService.GetAvgCostByProduct(detail.ProductID, CurrentWastage.WarehouseID)
                            detail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                        Catch ex As Exception
                            detail.CostPrice = prod.PurchasePrice
                        End Try
                        
                        Try
                            detail.AvailableQuantity = _inventoryService.GetStockByProduct(detail.ProductID, CurrentWastage.WarehouseID)
                        Catch ex As Exception
                            detail.AvailableQuantity = 0
                        End Try
                    End If
                Catch ex As Exception
                    MessageBox.Show("خطأ أثناء جلب بيانات الصنف: " & ex.Message)
                End Try
                _isUpdatingDetail = False
            ElseIf e.PropertyName = "Quantity" Then
                If detail.Quantity > detail.AvailableQuantity Then
                    RaiseEvent RequestSnackbar($"⚠️ تنبيه: الكمية المدخلة ({detail.Quantity}) تتجاوز الرصيد المتاح ({detail.AvailableQuantity}) للصنف: {detail.ProductName}")
                End If
            End If
        End Sub

        Private Sub RemoveItem(parameter As Object)
            Dim item = TryCast(parameter, WastageDetails)
            If item IsNot Nothing AndAlso CurrentWastage IsNot Nothing AndAlso CurrentWastage.Details IsNot Nothing Then
                CurrentWastage.Details.Remove(item)
                CurrentWastage.TotalValue = CurrentWastage.Details.Sum(Function(d) d.TotalCost)
            End If
        End Sub

        Private Function CanSave() As Boolean
            Return IsEditing AndAlso CurrentWastage IsNot Nothing AndAlso
                   CurrentWastage.Details IsNot Nothing AndAlso
                   CurrentWastage.Details.Count > 0 AndAlso Not CurrentWastage.IsPosted
        End Function

        Private Sub Save()
            Try
                ' حذف الصفوف الفارغة (لا كود ولا اسم صنف) قبل الحفظ
                If CurrentWastage.Details IsNot Nothing Then
                    Dim emptyRows = CurrentWastage.Details.Where(
                        Function(d) d.ProductID = 0 AndAlso
                                    String.IsNullOrWhiteSpace(d.ProductCode) AndAlso
                                    String.IsNullOrWhiteSpace(d.ProductName)).ToList()
                    For Each row In emptyRows
                        CurrentWastage.Details.Remove(row)
                    Next
                End If

                CurrentWastage.TotalValue = CurrentWastage.Details.Sum(Function(d) d.TotalCost)
                Dim newId = _wastageService.SaveWastage(CurrentWastage, CurrentWastage.Details.ToList())
                MessageBox.Show("تم حفظ سجل الهالك بنجاح", "نجاح", MessageBoxButton.OK, MessageBoxImage.Information)
                IsEditing = False
                LoadHistory()
            Catch ex As Exception
                MessageBox.Show(ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Function CanPost() As Boolean
            Return CurrentWastage IsNot Nothing AndAlso Not CurrentWastage.IsPosted AndAlso CurrentWastage.WastageID > 0
        End Function

        Private Sub Post()
            If MessageBox.Show("هل أنت متأكد من اعتماد هذا الهالك وخصم الكميات من المخزون؟ لا يمكن التراجع عن هذه العملية.",
                               "تأكيد", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _wastageService.PostWastage(CurrentWastage.WastageID)
                    CurrentWastage.IsPosted = True
                    MessageBox.Show("تم الاعتماد وخصم الكميات بنجاح", "نجاح", MessageBoxButton.OK, MessageBoxImage.Information)
                    LoadHistory()
                Catch ex As Exception
                    MessageBox.Show(ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub
        Private Function CanUnpost() As Boolean
            Return CanUnpostAllowed AndAlso
                   CurrentWastage IsNot Nothing AndAlso
                   CurrentWastage.IsPosted AndAlso
                   CurrentWastage.WastageID > 0
        End Function

        Private Sub Unpost()
            If MessageBox.Show("هل أنت متأكد من إلغاء ترحيل هذا الهالك؟ سيتم إعادة الكميات للمخزون وحذف القيد المحاسبي.",
                               "تأكيد إلغاء الترحيل", MessageBoxButton.YesNo, MessageBoxImage.Warning) = MessageBoxResult.Yes Then
                Try
                    _wastageService.UnpostWastage(CurrentWastage.WastageID)
                    CurrentWastage.IsPosted = False
                    RaiseEvent RequestSnackbar("✅ تم إلغاء الترحيل — الرصيد أُعيد وحُذف القيد")
                    LoadHistory()
                Catch ex As Exception
                    MessageBox.Show(ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
                End Try
            End If
        End Sub

        ' ─────────────────────────────────────────────
        ' طباعة مستند الهالك (PDF)
        ' ─────────────────────────────────────────────
        Private Function CanPrint() As Boolean
            Return CurrentWastage IsNot Nothing AndAlso CurrentWastage.WastageID > 0
        End Function

        Private Sub PrintWastage()
            Try
                If CurrentWastage Is Nothing OrElse CurrentWastage.WastageID = 0 Then
                    RaiseEvent RequestSnackbar("⚠️ احفظ المستند أولاً قبل الطباعة")
                    Return
                End If
                ' Ensure details are loaded for printing
                If CurrentWastage.Details Is Nothing OrElse CurrentWastage.Details.Count = 0 Then
                    Dim details = _wastageService.GetWastageDetails(CurrentWastage.WastageID)
                    CurrentWastage.Details = New System.Collections.ObjectModel.ObservableCollection(Of WastageDetails)(details)
                End If
                ' Attach warehouse name for print
                Dim wh = Warehouses.FirstOrDefault(Function(w) w.WarehouseID = CurrentWastage.WarehouseID)
                If wh IsNot Nothing Then CurrentWastage.WarehouseName = wh.WarehouseName

                Helpers.ReportExporter.ExportWastageVoucherToPdf(CurrentWastage)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الطباعة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ─────────────────────────────────────────────
        ' استيراد من Excel
        ' ─────────────────────────────────────────────
        Private Function CanImport() As Boolean
            Return IsEditing AndAlso CurrentWastage IsNot Nothing AndAlso Not CurrentWastage.IsPosted
        End Function

        Private Sub ImportFromExcel()
            Try
                Dim dlg As New Microsoft.Win32.OpenFileDialog() With {
                    .Title  = "استيراد أصناف الهالك من Excel",
                    .Filter = "Excel Files (*.xlsx)|*.xlsx",
                    .CheckFileExists = True
                }
                If dlg.ShowDialog() <> True Then Return

                If CurrentWastage.Details Is Nothing Then
                    CurrentWastage.Details = New System.Collections.ObjectModel.ObservableCollection(Of WastageDetails)()
                End If

                Dim matchedCount As Integer = 0
                Dim unmatchedList As New System.Text.StringBuilder()

                ' ── Read using DocumentFormat.OpenXml (same as ExcelImporter pattern) ──
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

                    ' Smart header detection: find the row containing "كود" in column A
                    Dim dataStartIndex As Integer = 1  ' default: skip row 1 (header)
                    For idx = 0 To Math.Min(9, allRows.Count - 1)
                        Dim scanCells = allRows(idx).Elements(Of DocumentFormat.OpenXml.Spreadsheet.Cell)().ToList()
                        Dim scanVal = GetCellStringValue(scanCells, "A", sst).Trim()
                        If scanVal.Contains("كود") OrElse scanVal.ToLower().Contains("code") OrElse scanVal.ToLower().Contains("barcode") Then
                            dataStartIndex = idx + 1  ' start from next row
                            Exit For
                        End If
                    Next

                    For rowIdx = dataStartIndex To allRows.Count - 1
                        Dim cells = allRows(rowIdx).Elements(Of DocumentFormat.OpenXml.Spreadsheet.Cell)().ToList()
                        If cells.Count = 0 Then Continue For

                        Dim codeVal = GetCellStringValue(cells, "A", sst).Trim()
                        Dim qtyStr  = GetCellStringValue(cells, "B", sst).Trim()
                        If String.IsNullOrEmpty(codeVal) Then Continue For

                        Dim qty As Decimal = 1
                        Decimal.TryParse(qtyStr, System.Globalization.NumberStyles.Any,
                                         System.Globalization.CultureInfo.InvariantCulture, qty)
                        If qty <= 0 Then qty = 1

                        ' Match by Barcode, ProductID, or ProductName
                        Dim prod = AvailableProducts.FirstOrDefault(
                            Function(p) (Not String.IsNullOrEmpty(p.Barcode) AndAlso p.Barcode = codeVal) OrElse
                                        p.ProductID.ToString() = codeVal OrElse
                                        (Not String.IsNullOrEmpty(p.ProductName) AndAlso
                                         p.ProductName.ToLower() = codeVal.ToLower()))

                        If prod IsNot Nothing Then
                            Dim newDetail As New WastageDetails() With {
                                .ProductID   = prod.ProductID,
                                .ProductCode = If(Not String.IsNullOrEmpty(prod.Barcode), prod.Barcode, prod.ProductID.ToString()),
                                .ProductName = prod.ProductName,
                                .Quantity    = qty
                            }
                            Try
                                Dim avgCost = _inventoryService.GetAvgCostByProduct(prod.ProductID, CurrentWastage.WarehouseID)
                                newDetail.CostPrice = If(avgCost > 0, avgCost, prod.PurchasePrice)
                            Catch
                                newDetail.CostPrice = prod.PurchasePrice
                            End Try
                            Try
                                newDetail.AvailableQuantity = _inventoryService.GetStockByProduct(prod.ProductID, CurrentWastage.WarehouseID)
                            Catch
                                newDetail.AvailableQuantity = 0
                            End Try
                            AttachDetailHandler(newDetail)
                            CurrentWastage.Details.Add(newDetail)
                            matchedCount += 1
                        Else
                            unmatchedList.AppendLine($"  • {codeVal}")
                        End If
                    Next
                End Using

                CurrentWastage.TotalValue = CurrentWastage.Details.Sum(Function(d) d.TotalCost)

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

        ' ─────────────────────────────────────────────
        ' تنزيل قالب Excel للاستيراد
        ' ─────────────────────────────────────────────
        Private Sub DownloadTemplate()
            Try
                Dim dlg As New Microsoft.Win32.SaveFileDialog() With {
                    .Title           = "حفظ قالب استيراد الهالك",
                    .FileName        = "قالب_استيراد_الهالك.xlsx",
                    .Filter          = "Excel Files (*.xlsx)|*.xlsx",
                    .DefaultExt      = "xlsx",
                    .OverwritePrompt = True
                }
                If dlg.ShowDialog() <> True Then Return

                Using ms As New System.IO.MemoryStream()
                    Using doc = DocumentFormat.OpenXml.Packaging.SpreadsheetDocument.Create(
                                    ms, DocumentFormat.OpenXml.SpreadsheetDocumentType.Workbook)

                        ' ── Workbook
                        Dim wbPart = doc.AddWorkbookPart()
                        wbPart.Workbook = New DocumentFormat.OpenXml.Spreadsheet.Workbook()

                        ' ── Worksheet
                        Dim wsPart = wbPart.AddNewPart(Of DocumentFormat.OpenXml.Packaging.WorksheetPart)()
                        Dim sheetData As New DocumentFormat.OpenXml.Spreadsheet.SheetData()
                        wsPart.Worksheet = New DocumentFormat.OpenXml.Spreadsheet.Worksheet(sheetData)

                        ' ── Sheets registry
                        Dim sheets As New DocumentFormat.OpenXml.Spreadsheet.Sheets()
                        wbPart.Workbook.AppendChild(sheets)
                        Dim sh As New DocumentFormat.OpenXml.Spreadsheet.Sheet() With {
                            .Id      = wbPart.GetIdOfPart(wsPart),
                            .SheetId = 1,
                            .Name    = "الهالك"
                        }
                        sheets.AppendChild(sh)

                        ' ── Row 1: Header
                        Dim headerRow As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 1}
                        Dim hdrLabels = {"كود الصنف / الباركود (*)", "الكمية (*)", "اسم الصنف (للمرجع)", "ملاحظات"}
                        Dim hdrCols   = {"A", "B", "C", "D"}
                        For i = 0 To hdrLabels.Length - 1
                            headerRow.AppendChild(MakeTextCell(hdrCols(i) & "1", hdrLabels(i)))
                        Next
                        sheetData.AppendChild(headerRow)

                        ' ── Row 2: Sample 1
                        Dim row2 As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 2}
                        row2.AppendChild(MakeTextCell("A2",   "1001"))
                        row2.AppendChild(MakeNumberCell("B2", "5"))
                        row2.AppendChild(MakeTextCell("C2",   "مثال - تفاح أحمر"))
                        row2.AppendChild(MakeTextCell("D2",   "صنف تالف"))
                        sheetData.AppendChild(row2)

                        ' ── Row 3: Sample 2
                        Dim row3 As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 3}
                        row3.AppendChild(MakeTextCell("A3",   "BARCODE123"))
                        row3.AppendChild(MakeNumberCell("B3", "2.5"))
                        row3.AppendChild(MakeTextCell("C3",   "مثال - عصير برتقال"))
                        row3.AppendChild(MakeTextCell("D3",   "تلف بسبب التخزين"))
                        sheetData.AppendChild(row3)

                        ' ── Rows 4-33: Empty data rows
                        For r = 4 To 33
                            Dim dr As New DocumentFormat.OpenXml.Spreadsheet.Row() With {
                                .RowIndex = CUInt(r)
                            }
                            dr.AppendChild(MakeTextCell("A" & r, ""))
                            dr.AppendChild(MakeNumberCell("B" & r, ""))
                            sheetData.AppendChild(dr)
                        Next

                        ' ── Row 35: Instructions header
                        Dim instrHdr As New DocumentFormat.OpenXml.Spreadsheet.Row() With {.RowIndex = 35}
                        instrHdr.AppendChild(MakeTextCell("A35", "تعليمات الاستيراد:"))
                        sheetData.AppendChild(instrHdr)

                        ' ── Rows 36-41: Instruction lines
                        Dim notes() As String = {
                            "1. العمود A (إلزامي): كود الصنف أو الباركود أو رقم ID الصنف في النظام.",
                            "2. العمود B (إلزامي): الكمية التالفة — يمكن استخدام الكسور مثل: 2.500",
                            "3. العمود C (اختياري): اسم الصنف للمرجع فقط — لن يُستخدم في الاستيراد.",
                            "4. العمود D (اختياري): ملاحظات — لن تُستخدم في الاستيراد.",
                            "5. ابدأ الإدخال من الصف 4 — الصفوف 2-3 هي بيانات تجريبية يمكن حذفها.",
                            "6. الأصناف التي لا يجد النظام لها تطابق سيُبلَّغ عنها بعد الاستيراد."
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

                ' Open the saved file
                Process.Start(New System.Diagnostics.ProcessStartInfo(dlg.FileName) With {.UseShellExecute = True})
                RaiseEvent RequestSnackbar("✅ تم إنشاء القالب — افتحه وأدخل البيانات ثم استورد")

            Catch ex As Exception
                MessageBox.Show("خطأ أثناء إنشاء القالب: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        ' ── OpenXml helpers (match ExcelImporter pattern) ──────────────────

        ''' <summary>Gets the display string of a cell, resolving SharedString if needed.</summary>
        Private Shared Function GetCellStringValue(
                cells As System.Collections.Generic.List(Of DocumentFormat.OpenXml.Spreadsheet.Cell),
                colLetter As String,
                sst As DocumentFormat.OpenXml.Packaging.SharedStringTablePart) As String

            Dim cell = cells.FirstOrDefault(
                Function(c) c.CellReference IsNot Nothing AndAlso
                            c.CellReference.Value IsNot Nothing AndAlso
                            c.CellReference.Value.StartsWith(colLetter, StringComparison.OrdinalIgnoreCase))

            If cell Is Nothing OrElse cell.CellValue Is Nothing Then Return ""

            Dim val = cell.CellValue.Text
            If cell.DataType IsNot Nothing AndAlso
               cell.DataType.Value = DocumentFormat.OpenXml.Spreadsheet.CellValues.SharedString AndAlso
               sst IsNot Nothing Then
                Dim idx As Integer
                If Integer.TryParse(val, idx) Then
                    val = sst.SharedStringTable.Elements(Of DocumentFormat.OpenXml.Spreadsheet.SharedStringItem)().
                              ElementAtOrDefault(idx)?.InnerText
                End If
            End If
            Return If(val, "")
        End Function

        Private Shared Function MakeTextCell(ref As String, text As String) As DocumentFormat.OpenXml.Spreadsheet.Cell
            Return New DocumentFormat.OpenXml.Spreadsheet.Cell() With {
                .CellReference = ref,
                .DataType      = DocumentFormat.OpenXml.Spreadsheet.CellValues.InlineString,
                .InlineString  = New DocumentFormat.OpenXml.Spreadsheet.InlineString(
                                     New DocumentFormat.OpenXml.Spreadsheet.Text(text))
            }
        End Function

        Private Shared Function MakeNumberCell(ref As String, number As String) As DocumentFormat.OpenXml.Spreadsheet.Cell
            Return New DocumentFormat.OpenXml.Spreadsheet.Cell() With {
                .CellReference = ref,
                .CellValue     = New DocumentFormat.OpenXml.Spreadsheet.CellValue(number)
            }
        End Function

    End Class
End Namespace

