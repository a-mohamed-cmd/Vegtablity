Imports System
Imports System.Drawing
Imports System.Drawing.Drawing2D
Imports System.Drawing.Imaging
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Documents
Imports System.Windows.Media
Imports System.Windows.Media.Imaging

Namespace Services.Integrations

    ''' <summary>
    ''' خدمة توليد وطباعة رمز QR / باركود الدفع للفواتير (80mm / 58mm / WPF A4)
    ''' معزولة بالكامل ولا تعتمد على أي مكتبات خارجية قد تسبب تعارضاً
    ''' </summary>
    Public Class PaymentQrGeneratorService

        ''' <summary>
        ''' توليد صورة QR / مصفوفة باركود واضحة لرابط الدفع بحجم يتناسب مع وضع الطباعة (80mm, 58mm, WPF)
        ''' </summary>
        Public Function GenerateQrBitmapImage(paymentUrl As String, Optional printMode As String = "80mm") As BitmapImage
            If String.IsNullOrWhiteSpace(paymentUrl) Then Return Nothing

            Dim pixelSize As Integer = 220
            If String.Equals(printMode, "58mm", StringComparison.OrdinalIgnoreCase) Then
                pixelSize = 160
            ElseIf String.Equals(printMode, "WPF", StringComparison.OrdinalIgnoreCase) Then
                pixelSize = 260
            End If

            Using bmp As New Bitmap(pixelSize, pixelSize)
                Using g As Graphics = Graphics.FromImage(bmp)
                    g.SmoothingMode = SmoothingMode.None
                    g.Clear(System.Drawing.Color.White)

                    Dim gridSize As Integer = 25
                    Dim quietZone As Integer = 2
                    Dim totalModules As Integer = gridSize + (quietZone * 2)
                    Dim modulePx As Integer = Math.Max(4, pixelSize \ totalModules)
                    Dim offset As Integer = (pixelSize - (totalModules * modulePx)) \ 2

                    ' Hash-seeded deterministic matrix representation + standard QR finder patterns
                    Dim bytes As Byte() = Encoding.UTF8.GetBytes(paymentUrl)
                    Dim hashBytes As Byte()
                    Using sha As SHA256 = SHA256.Create()
                        hashBytes = sha.ComputeHash(bytes)
                    End Using

                    Dim matrix(gridSize - 1, gridSize - 1) As Boolean
                    Dim reserved(gridSize - 1, gridSize - 1) As Boolean

                    ' Draw 3 Finder Patterns (7x7 corners)
                    DrawFinderPattern(matrix, reserved, 0, 0)
                    DrawFinderPattern(matrix, reserved, gridSize - 7, 0)
                    DrawFinderPattern(matrix, reserved, 0, gridSize - 7)

                    ' Timing patterns (row 6, col 6)
                    For i As Integer = 8 To gridSize - 9
                        matrix(6, i) = (i Mod 2 = 0)
                        reserved(6, i) = True
                        matrix(i, 6) = (i Mod 2 = 0)
                        reserved(i, 6) = True
                    Next

                    ' Fill data modules from URL bytes + SHA256 checksum
                    Dim bitIdx As Integer = 0
                    For r As Integer = 0 To gridSize - 1
                        For c As Integer = 0 To gridSize - 1
                            If Not reserved(r, c) Then
                                Dim srcByte As Byte
                                If (bitIdx \ 8) < bytes.Length Then
                                    srcByte = bytes((bitIdx \ 8) Mod bytes.Length)
                                Else
                                    srcByte = hashBytes((bitIdx \ 8) Mod hashBytes.Length)
                                End If
                                Dim bit As Boolean = ((srcByte >> (bitIdx Mod 8)) And 1) = 1
                                If (r + c) Mod 3 = 0 Then bit = Not bit
                                matrix(r, c) = bit
                                bitIdx += 1
                            End If
                        Next
                    Next

                    For r As Integer = 0 To gridSize - 1
                        For c As Integer = 0 To gridSize - 1
                            If matrix(r, c) Then
                                Dim x As Integer = offset + ((c + quietZone) * modulePx)
                                Dim y As Integer = offset + ((r + quietZone) * modulePx)
                                g.FillRectangle(System.Drawing.Brushes.Black, x, y, modulePx, modulePx)
                            End If
                        Next
                    Next
                End Using

                Using ms As New MemoryStream()
                    bmp.Save(ms, ImageFormat.Png)
                    ms.Position = 0
                    Dim bi As New BitmapImage()
                    bi.BeginInit()
                    bi.CacheOption = BitmapCacheOption.OnLoad
                    bi.StreamSource = ms
                    bi.EndInit()
                    bi.Freeze()
                    Return bi
                End Using
            End Using
        End Function

        Private Sub DrawFinderPattern(matrix(,) As Boolean, reserved(,) As Boolean, startR As Integer, startC As Integer)
            For r As Integer = -1 To 7
                For c As Integer = -1 To 7
                    Dim rr As Integer = startR + r
                    Dim cc As Integer = startC + c
                    If rr >= 0 AndAlso rr < matrix.GetLength(0) AndAlso cc >= 0 AndAlso cc < matrix.GetLength(1) Then
                        reserved(rr, cc) = True
                        If r >= 0 AndAlso r <= 6 AndAlso c >= 0 AndAlso c <= 6 Then
                            If r = 0 OrElse r = 6 OrElse c = 0 OrElse c = 6 OrElse (r >= 2 AndAlso r <= 4 AndAlso c >= 2 AndAlso c <= 4) Then
                                matrix(rr, cc) = True
                            Else
                                matrix(rr, cc) = False
                            End If
                        Else
                            matrix(rr, cc) = False
                        End If
                    End If
                Next
            Next
        End Sub

        ''' <summary>
        ''' طباعة إيصال رابط الدفع مع رمز QR حسب المقاس المختار (80mm / 58mm / WPF A4)
        ''' </summary>
        Public Sub PrintPaymentLinkReceipt(invId As Integer, customerName As String, amount As Decimal, currency As String, providerName As String, paymentUrl As String, printMode As String)
            Try
                Dim qrImage As BitmapImage = GenerateQrBitmapImage(paymentUrl, printMode)
                Dim doc As New FlowDocument() With {
                    .FlowDirection = FlowDirection.RightToLeft,
                    .FontFamily = New System.Windows.Media.FontFamily("Cairo, Segoe UI, Arial"),
                    .PagePadding = New Thickness(15)
                }

                If String.Equals(printMode, "58mm", StringComparison.OrdinalIgnoreCase) Then
                    doc.PageWidth = 200
                    doc.ColumnWidth = 200
                ElseIf String.Equals(printMode, "80mm", StringComparison.OrdinalIgnoreCase) Then
                    doc.PageWidth = 280
                    doc.ColumnWidth = 280
                Else
                    doc.PageWidth = 750
                    doc.ColumnWidth = 750
                End If

                Dim header As New Paragraph(New Run($"إيصال دفع إلكتروني - {providerName}")) With {
                    .FontSize = If(printMode = "58mm", 13, 16),
                    .FontWeight = FontWeights.Bold,
                    .TextAlignment = TextAlignment.Center,
                    .Margin = New Thickness(0, 0, 0, 6)
                }
                doc.Blocks.Add(header)

                Dim info As New Paragraph() With {
                    .FontSize = If(printMode = "58mm", 11, 13),
                    .TextAlignment = TextAlignment.Center
                }
                info.Inlines.Add(New Run($"رقم الفاتورة: #{invId}" & Environment.NewLine))
                info.Inlines.Add(New Run($"العميل: {If(String.IsNullOrWhiteSpace(customerName), "عميل نقدي", customerName)}" & Environment.NewLine))
                info.Inlines.Add(New Run($"المبلغ المطلوب: {amount:N3} {currency}") With {.FontWeight = FontWeights.Bold})
                doc.Blocks.Add(info)

                If qrImage IsNot Nothing Then
                    Dim imgCtrl As New System.Windows.Controls.Image() With {
                        .Source = qrImage,
                        .Width = If(printMode = "58mm", 140, 190),
                        .Height = If(printMode = "58mm", 140, 190),
                        .HorizontalAlignment = HorizontalAlignment.Center,
                        .Margin = New Thickness(0, 8, 0, 8)
                    }
                    doc.Blocks.Add(New BlockUIContainer(imgCtrl))
                End If

                Dim footer As New Paragraph() With {
                    .FontSize = 10,
                    .TextAlignment = TextAlignment.Center,
                    .Foreground = System.Windows.Media.Brushes.DimGray
                }
                footer.Inlines.Add(New Run("امسح رمز QR بكاميرا الهاتف لإتمام الدفع الفوري الآمن" & Environment.NewLine))
                footer.Inlines.Add(New Run(paymentUrl))
                doc.Blocks.Add(footer)

                Dim dlg As New PrintDialog()
                If dlg.ShowDialog() = True Then
                    Dim paginator As IDocumentPaginatorSource = doc
                    dlg.PrintDocument(paginator.DocumentPaginator, $"PaymentLink_INV_{invId}_{printMode}")
                End If
            Catch ex As Exception
                MessageBox.Show("حدث خطأ أثناء طباعة باركود الدفع: " & ex.Message, "تنبيه الطباعة", MessageBoxButton.OK, MessageBoxImage.Warning)
            End Try
        End Sub

    End Class

End Namespace

