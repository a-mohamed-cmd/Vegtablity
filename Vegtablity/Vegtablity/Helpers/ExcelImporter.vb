Imports System.IO
Imports System.Linq
Imports DocumentFormat.OpenXml.Packaging
Imports DocumentFormat.OpenXml.Spreadsheet
Imports Vegtablity.Models
Imports Microsoft.Win32

Namespace Helpers

    Public Class ImportedRow
        Public Property Barcode     As String
        Public Property ProductName As String
        Public Property Quantity    As Decimal
        Public Property UnitPrice   As Decimal
    End Class

    ''' <summary>
    ''' Imports invoice details from an Excel (.xlsx) file using DocumentFormat.OpenXml.
    ''' </summary>
    Public Class ExcelImporter

        ''' <summary>
        ''' Opens a file dialog, reads the xlsx, and returns all data rows.
        ''' </summary>
        Public Shared Function ReadExcelRows() As List(Of ImportedRow)
            Dim result As New List(Of ImportedRow)()

            Dim dlg As New OpenFileDialog() With {
                .Title  = "اختر ملف Excel للاستيراد",
                .Filter = "Excel Files (*.xlsx)|*.xlsx",
                .CheckFileExists = True
            }
            If dlg.ShowDialog() <> True Then Return result

            Using doc As SpreadsheetDocument = SpreadsheetDocument.Open(dlg.FileName, False)
                Dim wbPart  = doc.WorkbookPart
                Dim sheet   = wbPart.Workbook.Sheets.Elements(Of Sheet)().FirstOrDefault()
                If sheet Is Nothing Then Return result

                Dim wsPart = CType(wbPart.GetPartById(sheet.Id), WorksheetPart)
                Dim rows   = wsPart.Worksheet.Descendants(Of Row)().ToList()

                Dim sst As SharedStringTablePart = wbPart.SharedStringTablePart

                For Each row As Row In rows.Skip(1) ' Skip headers
                    Dim cells = row.Elements(Of Cell)().ToList()
                    If cells.Count = 0 Then Continue For

                    Dim barcodeVal = GetCellValue(cells, "A", sst).Trim()
                    Dim nameVal    = GetCellValue(cells, "B", sst).Trim()
                    Dim qtyStr     = GetCellValue(cells, "C", sst).Trim()
                    Dim priceStr   = GetCellValue(cells, "D", sst).Trim()

                    If String.IsNullOrWhiteSpace(barcodeVal) AndAlso String.IsNullOrWhiteSpace(nameVal) Then Continue For

                    Dim qty   As Decimal = 1
                    Dim price As Decimal = 0
                    Decimal.TryParse(qtyStr,   Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, qty)
                    Decimal.TryParse(priceStr, Globalization.NumberStyles.Any, Globalization.CultureInfo.InvariantCulture, price)

                    result.Add(New ImportedRow() With {
                        .Barcode     = barcodeVal,
                        .ProductName = nameVal,
                        .Quantity    = qty,
                        .UnitPrice   = price
                    })
                Next
            End Using

            Return result
        End Function

        ''' <summary>
        ''' Downloads a blank invoice template xlsx to a user-chosen path.
        ''' </summary>
        Public Shared Sub DownloadTemplate()
            Dim dlg As New SaveFileDialog() With {
                .Title           = "حفظ قالب Excel",
                .FileName        = "invoice_template.xlsx",
                .Filter          = "Excel Files (*.xlsx)|*.xlsx",
                .DefaultExt      = "xlsx",
                .OverwritePrompt = True
            }
            If dlg.ShowDialog() <> True Then Return

            Using ms As New MemoryStream()
                Using doc = SpreadsheetDocument.Create(ms, DocumentFormat.OpenXml.SpreadsheetDocumentType.Workbook)
                    Dim wbPart = doc.AddWorkbookPart()
                    wbPart.Workbook = New Workbook()

                    Dim wsPart = wbPart.AddNewPart(Of WorksheetPart)()
                    Dim sheetData As New SheetData()
                    wsPart.Worksheet = New Worksheet(sheetData)

                    Dim sheets As New Sheets()
                    wbPart.Workbook.AppendChild(sheets)
                    Dim s As New Sheet() With {
                        .Id      = wbPart.GetIdOfPart(wsPart),
                        .SheetId = 1,
                        .Name    = "فاتورة"
                    }
                    sheets.AppendChild(s)

                    Dim headerRow As New Row() With {.RowIndex = 1}
                    Dim headers = {"الباركود", "اسم الصنف", "الكمية", "سعر الوحدة"}
                    Dim cols = {"A", "B", "C", "D"}
                    For i = 0 To headers.Length - 1
                        headerRow.AppendChild(MakeTextCell(cols(i) & "1", headers(i)))
                    Next
                    sheetData.AppendChild(headerRow)

                    Dim dataRow As New Row() With {.RowIndex = 2}
                    dataRow.AppendChild(MakeTextCell("A2", "6001234"))
                    dataRow.AppendChild(MakeTextCell("B2", "مثال — طماطم"))
                    dataRow.AppendChild(MakeNumberCell("C2", "10"))
                    dataRow.AppendChild(MakeNumberCell("D2", "5.5"))
                    sheetData.AppendChild(dataRow)

                    wbPart.Workbook.Save()
                End Using

                File.WriteAllBytes(dlg.FileName, ms.ToArray())
            End Using

            System.Windows.MessageBox.Show(
                $"تم حفظ القالب بنجاح:{vbCrLf}{dlg.FileName}",
                "تنزيل القالب",
                System.Windows.MessageBoxButton.OK,
                System.Windows.MessageBoxImage.Information)
        End Sub

        ' ── Helpers ──────────────────────────────────────────────

        Private Shared Function GetCellValue(cells As List(Of Cell), colLetter As String, sst As SharedStringTablePart) As String
            Dim cell = cells.FirstOrDefault(Function(c) c.CellReference IsNot Nothing AndAlso c.CellReference.Value IsNot Nothing AndAlso c.CellReference.Value.StartsWith(colLetter, StringComparison.OrdinalIgnoreCase))
            If cell Is Nothing OrElse cell.CellValue Is Nothing Then Return ""

            Dim val = cell.CellValue.Text
            If cell.DataType IsNot Nothing AndAlso cell.DataType.Value = CellValues.SharedString AndAlso sst IsNot Nothing Then
                Dim idx As Integer
                If Integer.TryParse(val, idx) Then
                    val = sst.SharedStringTable.Elements(Of SharedStringItem)().ElementAtOrDefault(idx)?.InnerText
                End If
            End If
            Return If(val, "")
        End Function

        Private Shared Function MakeTextCell(ref As String, text As String) As Cell
            Return New Cell() With {
                .CellReference = ref,
                .DataType      = CellValues.InlineString,
                .InlineString  = New InlineString(New Text(text))
            }
        End Function

        Private Shared Function MakeNumberCell(ref As String, number As String) As Cell
            Return New Cell() With {
                .CellReference = ref,
                .CellValue     = New CellValue(number)
            }
        End Function

    End Class
End Namespace
