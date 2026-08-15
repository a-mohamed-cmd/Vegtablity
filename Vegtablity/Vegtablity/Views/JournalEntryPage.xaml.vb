Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media

Namespace Views
    Partial Public Class JournalEntryPage
        Public Sub New()
            InitializeComponent()
        End Sub

        ' ══════════════════════════════════════════════════
        '  Global Page Keyboard Shortcuts (F2, F5, Ctrl+S, Ctrl+P)
        ' ══════════════════════════════════════════════════
        Private Sub UserControl_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm Is Nothing Then Return

            ' 1. F2: قيد جديد (يعمل من أي مكان بالشاشة)
            If e.Key = Key.F2 Then
                e.Handled = True
                If vm.NewCommand IsNot Nothing AndAlso vm.NewCommand.CanExecute(Nothing) Then
                    vm.NewCommand.Execute(Nothing)
                End If
                Return
            End If

            ' 2. F5: تحديث البيانات وإعادة تحميل القائمة
            If e.Key = Key.F5 Then
                e.Handled = True
                If vm.RefreshCommand IsNot Nothing AndAlso vm.RefreshCommand.CanExecute(Nothing) Then
                    vm.RefreshCommand.Execute(Nothing)
                End If
                Return
            End If

            ' 3. Ctrl + S: حفظ القيد
            If (Keyboard.Modifiers = ModifierKeys.Control) AndAlso e.Key = Key.S Then
                e.Handled = True
                If vm.SaveCommand IsNot Nothing AndAlso vm.SaveCommand.CanExecute(Nothing) Then
                    vm.SaveCommand.Execute(Nothing)
                End If
                Return
            End If

            ' 4. Ctrl + P: طباعة القيد
            If (Keyboard.Modifiers = ModifierKeys.Control) AndAlso e.Key = Key.P Then
                e.Handled = True
                If vm.PrintCommand IsNot Nothing AndAlso vm.PrintCommand.CanExecute(Nothing) Then
                    vm.PrintCommand.Execute(Nothing)
                End If
                Return
            End If

            ' 5. Ctrl + D: ترحيل القيد إلى الدفتر العام
            If (Keyboard.Modifiers = ModifierKeys.Control) AndAlso e.Key = Key.D Then
                e.Handled = True
                If vm.PostCommand IsNot Nothing AndAlso vm.PostCommand.CanExecute(Nothing) Then
                    vm.PostCommand.Execute(Nothing)
                End If
                Return
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  JournalRowControl Event Handlers
        ' ══════════════════════════════════════════════════

        Private Sub JournalRow_RequestAddNewRow(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm IsNot Nothing Then
                vm.AddLine()
                
                ' التركيز المباشر على اختيار الحساب في السطر المضاف الجديد
                Dispatcher.BeginInvoke(New Action(Sub()
                    If DetailsItemsControl IsNot Nothing AndAlso DetailsItemsControl.Items.Count > 0 Then
                        Dim lastIndex = DetailsItemsControl.Items.Count - 1
                        Dim container = DetailsItemsControl.ItemContainerGenerator.ContainerFromIndex(lastIndex)
                        If container IsNot Nothing Then
                            Dim rowCtrl = FindVisualChild(Of Controls.JournalRowControl)(container)
                            If rowCtrl IsNot Nothing Then
                                rowCtrl.FocusAccount()
                            End If
                        End If
                    End If
                End Sub), Windows.Threading.DispatcherPriority.Background)
            End If
        End Sub

        Private Sub JournalRow_RequestDeleteRow(sender As Object, e As EventArgs)
            Dim rowCtrl = TryCast(sender, Controls.JournalRowControl)
            If rowCtrl Is Nothing Then Return
            Dim detail = TryCast(rowCtrl.DataContext, Models.JournalDetail)
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm IsNot Nothing AndAlso detail IsNot Nothing Then
                vm.DeleteLineCommand.Execute(detail)
            End If
        End Sub

        Private Sub JournalRow_AmountChanged(sender As Object, e As EventArgs)
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            If vm IsNot Nothing Then
                vm.UpdateTotals()
            End If
        End Sub

        ' ══════════════════════════════════════════════════
        '  Sidebar Collapse / Expand Animation
        ' ══════════════════════════════════════════════════
        Private Sub ToggleButton_Click(sender As Object, e As RoutedEventArgs)
            If ListColumn Is Nothing OrElse JournalListBorder Is Nothing Then Return
            Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
            
            Dim isCollapsing As Boolean = (ListColumn.Width.Value > 50)
            Dim startVal As Double = If(isCollapsing, 310, 0)
            Dim endVal As Double = If(isCollapsing, 0, 310)

            Dim anim As New System.Windows.Media.Animation.DoubleAnimation() With {
                .From = startVal,
                .To = endVal,
                .Duration = TimeSpan.FromMilliseconds(220),
                .EasingFunction = New System.Windows.Media.Animation.CubicEase() With {.EasingMode = System.Windows.Media.Animation.EasingMode.EaseOut}
            }
            
            AddHandler anim.Completed, Sub(s, args)
                                          ListColumn.Width = New GridLength(endVal)
                                       End Sub
            JournalListBorder.BeginAnimation(FrameworkElement.WidthProperty, anim)
            ListColumn.Width = New GridLength(endVal)
        End Sub

        ' ══════════════════════════════════════════════════
        '  Date TextBox Handlers
        ' ══════════════════════════════════════════════════
        Private Sub Date_LostFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim raw = tb.Text.Trim().Replace("-", "/").Replace(".", "/")
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If
            Dim parsed As DateTime
            If DateTime.TryParseExact(raw, {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy"},
                                      System.Globalization.CultureInfo.InvariantCulture,
                                      System.Globalization.DateTimeStyles.None, parsed) Then
                Dim vm = TryCast(Me.DataContext, ViewModels.JournalEntryViewModel)
                If vm IsNot Nothing AndAlso vm.CurrentJournal IsNot Nothing Then
                    vm.CurrentJournal.JDate = parsed
                    tb.Text = parsed.ToString("dd/MM/yyyy")
                    tb.Foreground = System.Windows.Media.Brushes.Black
                    tb.ToolTip = "أدخل التاريخ: dd/MM/yyyy أو ddMMyyyy"
                End If
            Else
                tb.Foreground = System.Windows.Media.Brushes.Red
                tb.ToolTip = "صيغة تاريخ غير صحيحة — استخدم: dd/MM/yyyy"
            End If
        End Sub

        Private Sub Date_GotFocus(sender As Object, e As System.Windows.RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb IsNot Nothing Then tb.SelectAll()
        End Sub
    
        Private Sub Date_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, System.Windows.Controls.TextBox)
                If tb IsNot Nothing Then
                    Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                    tb.MoveFocus(request)
                End If
            End If
        End Sub

        Private Async Sub ShowSnackbar(message As String)
            If SnackbarBorder Is Nothing Then Return
            SnackbarText.Text = message
            SnackbarIcon.Text = "⚠️"
            SnackbarBorder.Visibility = Visibility.Visible
            Await System.Threading.Tasks.Task.Delay(3000)
            SnackbarBorder.Visibility = Visibility.Collapsed
        End Sub

        Private Function FindVisualChild(Of T As Visual)(parent As Visual) As T
            If parent Is Nothing Then Return Nothing
            For i As Integer = 0 To VisualTreeHelper.GetChildrenCount(parent) - 1
                Dim child = VisualTreeHelper.GetChild(parent, i)
                If child IsNot Nothing AndAlso TypeOf child Is T Then
                    Return CType(child, T)
                Else
                    Dim childOfChild = FindVisualChild(Of T)(child)
                    If childOfChild IsNot Nothing Then Return childOfChild
                End If
            Next
            Return Nothing
        End Function

    End Class
End Namespace
