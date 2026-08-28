Imports System
Imports System.Globalization
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media

Namespace Controls
    ''' <summary>
    ''' DateBoxControl — أداة إدخال وتنسيق التاريخ اليدوي الموحدة في النظام (UserControl).
    ''' تدعم الربط التلقائي Two-Way مع SelectedDate و Text، التنسيق الذكي (01052026 -> 01/05/2026)،
    ''' والتنقل بمفتاح Enter، والتظليل اللوني للقيم غير الصحيحة.
    ''' </summary>
    Public Class DateBoxControl
        Inherits UserControl

        Private _isInternalChange As Boolean = False

        ' ══════════════════════════════════════════════════════
        '  Dependency Properties
        ' ══════════════════════════════════════════════════════

        Public Shared ReadOnly SelectedDateProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(SelectedDate), GetType(DateTime?),
                GetType(DateBoxControl),
                New FrameworkPropertyMetadata(Nothing,
                    FrameworkPropertyMetadataOptions.BindsTwoWayByDefault,
                    AddressOf OnSelectedDateChanged))

        Public Property SelectedDate As DateTime?
            Get
                Return CType(GetValue(SelectedDateProperty), DateTime?)
            End Get
            Set(value As DateTime?)
                SetValue(SelectedDateProperty, value)
            End Set
        End Property

        Public Shared ReadOnly TextProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(Text), GetType(String),
                GetType(DateBoxControl),
                New FrameworkPropertyMetadata(String.Empty,
                    FrameworkPropertyMetadataOptions.BindsTwoWayByDefault,
                    AddressOf OnTextChanged))

        Public Property Text As String
            Get
                Return CStr(GetValue(TextProperty))
            End Get
            Set(value As String)
                SetValue(TextProperty, value)
            End Set
        End Property

        Public Shared ReadOnly WatermarkProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(Watermark), GetType(String),
                GetType(DateBoxControl),
                New PropertyMetadata("يوم/شهر/سنة"))

        Public Property Watermark As String
            Get
                Return CStr(GetValue(WatermarkProperty))
            End Get
            Set(value As String)
                SetValue(WatermarkProperty, value)
            End Set
        End Property

        Public Shared ReadOnly DateFormatProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(DateFormat), GetType(String),
                GetType(DateBoxControl),
                New PropertyMetadata("dd/MM/yyyy"))

        Public Property DateFormat As String
            Get
                Return CStr(GetValue(DateFormatProperty))
            End Get
            Set(value As String)
                SetValue(DateFormatProperty, value)
            End Set
        End Property

        Public Shared ReadOnly IsReadOnlyProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(IsReadOnly), GetType(Boolean),
                GetType(DateBoxControl),
                New PropertyMetadata(False))

        Public Property IsReadOnly As Boolean
            Get
                Return CBool(GetValue(IsReadOnlyProperty))
            End Get
            Set(value As Boolean)
                SetValue(IsReadOnlyProperty, value)
            End Set
        End Property

        ' ══════════════════════════════════════════════════════
        '  Events
        ' ══════════════════════════════════════════════════════

        Public Shared ReadOnly SelectedDateChangedEvent As RoutedEvent =
            EventManager.RegisterRoutedEvent(NameOf(SelectedDateChanged),
                RoutingStrategy.Bubble,
                GetType(RoutedPropertyChangedEventHandler(Of DateTime?)),
                GetType(DateBoxControl))

        Public Custom Event SelectedDateChanged As RoutedPropertyChangedEventHandler(Of DateTime?)
            AddHandler(value As RoutedPropertyChangedEventHandler(Of DateTime?))
                Me.AddHandler(SelectedDateChangedEvent, value)
            End AddHandler
            RemoveHandler(value As RoutedPropertyChangedEventHandler(Of DateTime?))
                Me.RemoveHandler(SelectedDateChangedEvent, value)
            End RemoveHandler
            RaiseEvent(sender As Object, e As RoutedPropertyChangedEventArgs(Of DateTime?))
                Me.RaiseEvent(e)
            End RaiseEvent
        End Event

        Public Sub New()
            InitializeComponent()
            Me.Padding = New Thickness(0, 2, 0, 2)
            Me.Margin = New Thickness(0, 0, 0, 0)
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Property Changed Callbacks
        ' ══════════════════════════════════════════════════════

        Private Shared Sub OnSelectedDateChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, DateBoxControl)
            If ctrl Is Nothing OrElse ctrl._isInternalChange Then Return

            Dim newDate = CType(e.NewValue, DateTime?)
            ctrl._isInternalChange = True
            Try
                If newDate.HasValue Then
                    ctrl.DateTextBox.Text = newDate.Value.ToString(ctrl.DateFormat)
                    ctrl.Text = ctrl.DateTextBox.Text
                    ctrl.DateTextBox.Foreground = Brushes.Black
                    ctrl.DateTextBox.ToolTip = Nothing
                Else
                    ctrl.DateTextBox.Text = String.Empty
                    ctrl.Text = String.Empty
                End If
            Finally
                ctrl._isInternalChange = False
            End Try

            Dim args As New RoutedPropertyChangedEventArgs(Of DateTime?)(
                CType(e.OldValue, DateTime?), newDate, SelectedDateChangedEvent)
            ctrl.RaiseEvent(args)
        End Sub

        Private Shared Sub OnTextChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, DateBoxControl)
            If ctrl Is Nothing OrElse ctrl._isInternalChange Then Return

            Dim newText = CStr(e.NewValue)
            ctrl._isInternalChange = True
            Try
                If ctrl.DateTextBox.Text <> newText Then
                    ctrl.DateTextBox.Text = If(newText, String.Empty)
                End If
            Finally
                ctrl._isInternalChange = False
            End Try
        End Sub

        ' ══════════════════════════════════════════════════════
        '  UI Event Handlers
        ' ══════════════════════════════════════════════════════

        Private Sub DateTextBox_GotFocus(sender As Object, e As RoutedEventArgs)
            DateTextBox.SelectAll()
        End Sub

        Private Sub DateTextBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim req As New TraversalRequest(FocusNavigationDirection.Next)
                DateTextBox.MoveFocus(req)
            End If
        End Sub

        Private Sub DateTextBox_TextChanged(sender As Object, e As TextChangedEventArgs)
            If _isInternalChange Then Return
            _isInternalChange = True
            Try
                Text = DateTextBox.Text
            Finally
                _isInternalChange = False
            End Try
        End Sub

        Private Sub DateTextBox_LostFocus(sender As Object, e As RoutedEventArgs)
            Dim raw = DateTextBox.Text.Trim().Replace("-", "/").Replace(".", "/")
            If String.IsNullOrWhiteSpace(raw) Then
                _isInternalChange = True
                Try
                    SelectedDate = Nothing
                    Text = String.Empty
                    DateTextBox.Foreground = Brushes.Black
                    DateTextBox.ToolTip = Nothing
                Finally
                    _isInternalChange = False
                End Try
                Return
            End If

            ' Format 8-digits numeric: 01052026 -> 01/05/2026
            If raw.Length = 8 AndAlso Not raw.Contains("/") Then
                raw = raw.Substring(0, 2) & "/" & raw.Substring(2, 2) & "/" & raw.Substring(4, 4)
            End If

            Dim parsed As DateTime
            Dim formats = New String() {"dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "yyyy/MM/dd", "yyyy-MM-dd", "d-M-yyyy", "dd-MM-yyyy"}
            If DateTime.TryParseExact(raw, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then
                _isInternalChange = True
                Try
                    Dim formatted = parsed.ToString(DateFormat)
                    DateTextBox.Text = formatted
                    Text = formatted
                    SelectedDate = parsed
                    DateTextBox.Foreground = Brushes.Black
                    DateTextBox.ToolTip = Nothing
                Finally
                    _isInternalChange = False
                End Try
            Else
                DateTextBox.Foreground = Brushes.Red
                DateTextBox.ToolTip = $"صيغة تاريخ غير صحيحة — استخدم: {DateFormat}"
            End If
        End Sub
    End Class
End Namespace
