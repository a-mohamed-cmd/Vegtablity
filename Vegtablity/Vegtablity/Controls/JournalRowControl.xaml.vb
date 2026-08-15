Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Collections.ObjectModel
Imports Vegtablity.Models

Namespace Controls
    Public Class JournalRowControl
        Inherits UserControl

        ' ══════════════════════════════════════════════════════
        '  Dependency Properties
        ' ══════════════════════════════════════════════════════

        Public Shared ReadOnly AccountsListProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(AccountsList), GetType(IEnumerable(Of Account)),
                GetType(JournalRowControl),
                New PropertyMetadata(Nothing, AddressOf OnAccountsListChanged))

        Public Property AccountsList As IEnumerable(Of Account)
            Get
                Return CType(GetValue(AccountsListProperty), IEnumerable(Of Account))
            End Get
            Set(value As IEnumerable(Of Account))
                SetValue(AccountsListProperty, value)
            End Set
        End Property

        Public Shared ReadOnly IsLockedProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(IsLocked), GetType(Boolean),
                GetType(JournalRowControl),
                New PropertyMetadata(False))

        Public Property IsLocked As Boolean
            Get
                Return CBool(GetValue(IsLockedProperty))
            End Get
            Set(value As Boolean)
                SetValue(IsLockedProperty, value)
            End Set
        End Property

        ' ══════════════════════════════════════════════════════
        '  Events
        ' ══════════════════════════════════════════════════════

        Public Event RequestAddNewRow As EventHandler
        Public Event RequestDeleteRow As EventHandler
        Public Event AmountChanged As EventHandler

        ' ══════════════════════════════════════════════════════
        '  Initialization & DataContext Sync
        ' ══════════════════════════════════════════════════════

        Public Sub New()
            InitializeComponent()
            AddHandler DataContextChanged, AddressOf OnDataContextChangedHandler
            AddHandler Loaded, AddressOf OnLoadedHandler
        End Sub

        Private Sub OnLoadedHandler(sender As Object, e As RoutedEventArgs)
            If AccountDropdown.ItemsSource Is Nothing AndAlso AccountsList IsNot Nothing Then
                AccountDropdown.ItemsSource = AccountsList
            End If
            SyncAccountFromDataContext()
        End Sub

        Private Shared Sub OnAccountsListChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, JournalRowControl)
            If ctrl Is Nothing Then Return
            Dim list = TryCast(e.NewValue, IEnumerable(Of Account))
            ctrl.AccountDropdown.ItemsSource = list
            ctrl.SyncAccountFromDataContext()
        End Sub

        Private Sub OnDataContextChangedHandler(sender As Object, e As DependencyPropertyChangedEventArgs)
            SyncAccountFromDataContext()
        End Sub

        Private Sub SyncAccountFromDataContext()
            Dim detail = TryCast(Me.DataContext, JournalDetail)
            If detail Is Nothing Then
                AccountDropdown.ClearSelection()
                Return
            End If

            If detail.AccountID > 0 Then
                If AccountsList IsNot Nothing Then
                    Dim matched = AccountsList.FirstOrDefault(Function(a) a.AccountID = detail.AccountID)
                    If matched IsNot Nothing Then
                        AccountDropdown.SelectedItem = matched
                        Return
                    End If
                End If

                ' إذا لم يُعثر على الحساب في القائمة بعد، اعرض النص المتوفر
                Dim txt = If(Not String.IsNullOrEmpty(detail.AccountName),
                             $"{detail.AccountCode}  —  {detail.AccountName}",
                             detail.AccountCode)
                AccountDropdown.SetDisplayText(txt)
            Else
                AccountDropdown.ClearSelection()
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Account SearchableDropdown Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub AccountDropdown_SearchChanged(sender As Object, searchText As String)
            If AccountsList Is Nothing Then Return
            If String.IsNullOrWhiteSpace(searchText) Then
                AccountDropdown.ItemsSource = AccountsList
            Else
                Dim lower = searchText.Trim().ToLower()
                Dim filtered = AccountsList.Where(Function(a) (a.AccountName IsNot Nothing AndAlso a.AccountName.ToLower().Contains(lower)) OrElse
                                                              (a.AccountCode IsNot Nothing AndAlso a.AccountCode.Contains(searchText))).ToList()
                AccountDropdown.ItemsSource = filtered
            End If
        End Sub

        Private Sub AccountDropdown_ItemSelected(sender As Object, item As Object)
            Dim acc = TryCast(item, Account)
            Dim detail = TryCast(Me.DataContext, JournalDetail)
            If acc IsNot Nothing AndAlso detail IsNot Nothing Then
                detail.AccountID = acc.AccountID
                detail.AccountCode = acc.AccountCode
                detail.AccountName = acc.AccountName
            End If
        End Sub

        Private Sub AccountDropdown_ConfirmedAndMoveNext(sender As Object, e As EventArgs)
            FocusDebit()
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Amount Formatting, Clear on Focus & Navigation
        ' ══════════════════════════════════════════════════════

        Private Sub AmountBox_GotFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim txt = tb.Text.Trim()
            If txt = "0" OrElse txt = "0.0" OrElse txt = "0.00" OrElse txt = "0.000" OrElse txt = "0.0000" Then
                tb.Text = ""
            Else
                tb.SelectAll()
            End If
        End Sub

        Private Sub AmountBox_PreviewTextInput(sender As Object, e As TextCompositionEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return

            Dim text = e.Text
            If text = "." OrElse text = "," Then
                If tb.Text.Contains(".") OrElse tb.Text.Contains(",") Then
                    e.Handled = True
                    Return
                End If
                Return
            End If

            For Each ch In text
                If Not Char.IsDigit(ch) Then
                    e.Handled = True
                    Exit Sub
                End If
            Next
        End Sub

        Private Sub DebitBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim detail = TryCast(Me.DataContext, JournalDetail)
                If detail IsNot Nothing Then detail.Debit = val
            End If
            RaiseEvent AmountChanged(Me, EventArgs.Empty)
        End Sub

        Private Sub CreditBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim tb = TryCast(sender, TextBox)
            If tb Is Nothing Then Return
            Dim val As Decimal = 0
            Dim txt = tb.Text.Trim().Replace(",", ".")
            If Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val) Then
                Dim detail = TryCast(Me.DataContext, JournalDetail)
                If detail IsNot Nothing Then detail.Credit = val
            End If
            RaiseEvent AmountChanged(Me, EventArgs.Empty)
        End Sub

        Private Sub DebitBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim val As Decimal = 0
                Dim txt = DebitBox.Text.Trim().Replace(",", ".")
                Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val)

                Dim detail = TryCast(Me.DataContext, JournalDetail)
                If detail IsNot Nothing Then detail.Debit = val
                RaiseEvent AmountChanged(Me, EventArgs.Empty)

                ' إذا كان المدين > 0 ينتقل للبيان، وإذا كان 0 ينتقل للدائن
                If val > 0 Then
                    FocusNotes()
                Else
                    FocusCredit()
                End If
            End If
        End Sub

        Private Sub CreditBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim val As Decimal = 0
                Dim txt = CreditBox.Text.Trim().Replace(",", ".")
                Decimal.TryParse(txt, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, val)

                Dim detail = TryCast(Me.DataContext, JournalDetail)
                If detail IsNot Nothing Then detail.Credit = val
                RaiseEvent AmountChanged(Me, EventArgs.Empty)

                FocusNotes()
            End If
        End Sub

        Private Sub NotesBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim detail = TryCast(Me.DataContext, JournalDetail)
                If detail IsNot Nothing Then detail.Notes = NotesBox.Text.Trim()
                RaiseEvent RequestAddNewRow(Me, EventArgs.Empty)
            End If
        End Sub

        Private Sub DeleteButton_Click(sender As Object, e As RoutedEventArgs)
            RaiseEvent RequestDeleteRow(Me, EventArgs.Empty)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Public Focus Helpers
        ' ══════════════════════════════════════════════════════

        Public Sub FocusAccount()
            Dispatcher.BeginInvoke(New Action(Sub()
                AccountDropdown.Focus()
                Dim tb = TryCast(AccountDropdown.FindName("SearchBox"), TextBox)
                If tb IsNot Nothing Then
                    tb.Focus()
                    tb.SelectionLength = 0
                    tb.CaretIndex = tb.Text.Length
                End If
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusDebit()
            Dispatcher.BeginInvoke(New Action(Sub()
                DebitBox.Focus()
                Dim txt = DebitBox.Text.Trim()
                If txt = "0" OrElse txt = "0.0" OrElse txt = "0.00" OrElse txt = "0.000" Then
                    DebitBox.Text = ""
                Else
                    DebitBox.SelectAll()
                End If
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusCredit()
            Dispatcher.BeginInvoke(New Action(Sub()
                CreditBox.Focus()
                Dim txt = CreditBox.Text.Trim()
                If txt = "0" OrElse txt = "0.0" OrElse txt = "0.00" OrElse txt = "0.000" Then
                    CreditBox.Text = ""
                Else
                    CreditBox.SelectAll()
                End If
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

        Public Sub FocusNotes()
            Dispatcher.BeginInvoke(New Action(Sub()
                NotesBox.Focus()
                NotesBox.SelectAll()
            End Sub), Windows.Threading.DispatcherPriority.Input)
        End Sub

    End Class
End Namespace
