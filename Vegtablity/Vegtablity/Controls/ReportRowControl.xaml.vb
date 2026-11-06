Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports Vegtablity.Models

Namespace Controls
    Public Class ReportRowControl
        Inherits UserControl

        Private Shared ReadOnly BrushWhite As SolidColorBrush = CreateFrozenBrush("#FFFFFF")
        Private Shared ReadOnly BrushEven As SolidColorBrush = CreateFrozenBrush("#F8FAFC")
        Private Shared ReadOnly BrushHover As SolidColorBrush = CreateFrozenBrush("#EFF6FF")
        Private Shared ReadOnly BrushBorderNormal As SolidColorBrush = CreateFrozenBrush("#F1F5F9")
        Private Shared ReadOnly BrushBorderHover As SolidColorBrush = CreateFrozenBrush("#BFDBFE")
        Private Shared ReadOnly BrushSeqBg As SolidColorBrush = CreateFrozenBrush("#F1F5F9")
        Private Shared ReadOnly BrushSeqFg As SolidColorBrush = CreateFrozenBrush("#64748B")
        Private Shared ReadOnly BrushSubText As SolidColorBrush = CreateFrozenBrush("#64748B")

        Private Shared Function CreateFrozenBrush(hex As String) As SolidColorBrush
            Try
                Dim c As Color = CType(ColorConverter.ConvertFromString(hex), Color)
                Dim b As New SolidColorBrush(c)
                b.Freeze()
                Return b
            Catch
                Return Brushes.Transparent
            End Try
        End Function

        Public Sub New()
            InitializeComponent()
            AddHandler DataContextChanged, AddressOf OnDataContextChangedHandler
        End Sub

        Private Sub OnDataContextChangedHandler(sender As Object, e As DependencyPropertyChangedEventArgs)
            RenderRow(TryCast(e.NewValue, ReportRowItem))
        End Sub

        Private Sub RenderRow(row As ReportRowItem)
            CellsGrid.Children.Clear()
            CellsGrid.ColumnDefinitions.Clear()

            If row Is Nothing Then Return

            RowContainer.Background = If(row.IsEvenRow, BrushEven, BrushWhite)
            RowContainer.BorderBrush = BrushBorderNormal

            ' Column 0: Row sequence number (#)
            CellsGrid.ColumnDefinitions.Add(New ColumnDefinition() With {.Width = New GridLength(48, GridUnitType.Pixel)})

            Dim seqBadge As New Border() With {
                .Background = BrushSeqBg,
                .CornerRadius = New CornerRadius(6),
                .Padding = New Thickness(6, 2, 6, 2),
                .HorizontalAlignment = HorizontalAlignment.Center,
                .VerticalAlignment = VerticalAlignment.Center
            }
            Dim seqText As New TextBlock() With {
                .Text = row.RowNumber.ToString(),
                .FontSize = 11.5,
                .FontWeight = FontWeights.Bold,
                .Foreground = BrushSeqFg,
                .HorizontalAlignment = HorizontalAlignment.Center
            }
            seqBadge.Child = seqText
            Grid.SetColumn(seqBadge, 0)
            CellsGrid.Children.Add(seqBadge)

            If row.Cells Is Nothing Then Return

            For i As Integer = 0 To row.Cells.Count - 1
                Dim cell = row.Cells(i)
                Dim colIdx As Integer = i + 1
                Dim weight As Double = If(cell.WidthWeight > 0, cell.WidthWeight, 1.0)
                CellsGrid.ColumnDefinitions.Add(New ColumnDefinition() With {.Width = New GridLength(weight, GridUnitType.Star)})

                Dim fgBrush As SolidColorBrush = CreateFrozenBrush(If(String.IsNullOrEmpty(cell.ForegroundColor), "#1E293B", cell.ForegroundColor))

                If cell.IsBadge Then
                    Dim badgeBg As SolidColorBrush = CreateFrozenBrush(If(String.IsNullOrEmpty(cell.BadgeBgColor), "#F1F5F9", cell.BadgeBgColor))
                    Dim badgeBorder As SolidColorBrush = CreateFrozenBrush(If(String.IsNullOrEmpty(cell.BadgeBorderColor), "#E2E8F0", cell.BadgeBorderColor))

                    Dim pill As New Border() With {
                        .Background = badgeBg,
                        .BorderBrush = badgeBorder,
                        .BorderThickness = New Thickness(1),
                        .CornerRadius = New CornerRadius(6),
                        .Padding = New Thickness(8, 3, 8, 3),
                        .Margin = New Thickness(4, 0, 4, 0),
                        .HorizontalAlignment = GetHorizontalAlign(cell.HorizontalAlign),
                        .VerticalAlignment = VerticalAlignment.Center,
                        .ToolTip = cell.Text
                    }

                    Dim tb As New TextBlock() With {
                        .Text = cell.Text,
                        .Foreground = fgBrush,
                        .FontSize = 12,
                        .FontWeight = FontWeights.Bold,
                        .TextTrimming = TextTrimming.CharacterEllipsis
                    }
                    pill.Child = tb
                    Grid.SetColumn(pill, colIdx)
                    CellsGrid.Children.Add(pill)
                Else
                    Dim stack As New StackPanel() With {
                        .Orientation = Orientation.Vertical,
                        .VerticalAlignment = VerticalAlignment.Center,
                        .Margin = New Thickness(6, 0, 6, 0),
                        .ToolTip = If(String.IsNullOrEmpty(cell.SubText), cell.Text, cell.Text & " - " & cell.SubText)
                    }

                    Dim tbMain As New TextBlock() With {
                        .Text = cell.Text,
                        .Foreground = fgBrush,
                        .FontSize = 12.5,
                        .FontWeight = If(cell.IsBold, FontWeights.Bold, FontWeights.SemiBold),
                        .TextTrimming = TextTrimming.CharacterEllipsis,
                        .HorizontalAlignment = GetHorizontalAlign(cell.HorizontalAlign)
                    }
                    stack.Children.Add(tbMain)

                    If Not String.IsNullOrEmpty(cell.SubText) Then
                        Dim tbSub As New TextBlock() With {
                            .Text = cell.SubText,
                            .Foreground = BrushSubText,
                            .FontSize = 10.5,
                            .FontWeight = FontWeights.Medium,
                            .TextTrimming = TextTrimming.CharacterEllipsis,
                            .HorizontalAlignment = GetHorizontalAlign(cell.HorizontalAlign),
                            .Margin = New Thickness(0, 1, 0, 0)
                        }
                        stack.Children.Add(tbSub)
                    End If

                    Grid.SetColumn(stack, colIdx)
                    CellsGrid.Children.Add(stack)
                End If
            Next
        End Sub

        Private Function GetHorizontalAlign(alignStr As String) As HorizontalAlignment
            Select Case If(alignStr, "").ToLowerInvariant()
                Case "center"
                    Return HorizontalAlignment.Center
                Case "right"
                    Return HorizontalAlignment.Right
                Case Else
                    Return HorizontalAlignment.Left
            End Select
        End Function

        Private Sub RowContainer_MouseEnter(sender As Object, e As MouseEventArgs)
            RowContainer.Background = BrushHover
            RowContainer.BorderBrush = BrushBorderHover
        End Sub

        Private Sub RowContainer_MouseLeave(sender As Object, e As MouseEventArgs)
            Dim row = TryCast(DataContext, ReportRowItem)
            RowContainer.Background = If(row IsNot Nothing AndAlso row.IsEvenRow, BrushEven, BrushWhite)
            RowContainer.BorderBrush = BrushBorderNormal
        End Sub
    End Class
End Namespace

