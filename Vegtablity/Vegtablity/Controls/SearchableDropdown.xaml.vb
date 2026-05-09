Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Collections
Imports System.Reflection

Namespace Controls

    ''' <summary>
    ''' SearchableDropdown — بديل نظيف لـ ComboBox بدون أي تعارض بين الأحداث.
    ''' يعتمد على TextBox + Popup + ListBox.
    ''' الاستخدام:
    '''   - اربط ItemsSource بالقائمة المفلترة في الـ ViewModel
    '''   - اشترك في SearchChanged لتنفيذ الفلترة (قاعدة بيانات أو محلية)
    '''   - اشترك في ItemSelected لمعالجة الاختيار
    '''   - DisplayMemberPath يحدد الخاصية التي تُعرض كنص
    ''' </summary>
    Public Class SearchableDropdown
        Inherits UserControl

        ' ══════════════════════════════════════════════════════
        '  Dependency Properties
        ' ══════════════════════════════════════════════════════

        ''' <summary>مصدر البيانات — القائمة المفلترة (ObservableCollection أو List)</summary>
        Public Shared ReadOnly ItemsSourceProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(ItemsSource), GetType(IEnumerable),
                GetType(SearchableDropdown),
                New PropertyMetadata(Nothing, AddressOf OnItemsSourceChanged))

        Public Property ItemsSource As IEnumerable
            Get
                Return CType(GetValue(ItemsSourceProperty), IEnumerable)
            End Get
            Set(value As IEnumerable)
                SetValue(ItemsSourceProperty, value)
            End Set
        End Property

        ''' <summary>العنصر المختار الحالي</summary>
        Public Shared ReadOnly SelectedItemProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(SelectedItem), GetType(Object),
                GetType(SearchableDropdown),
                New FrameworkPropertyMetadata(Nothing,
                    FrameworkPropertyMetadataOptions.BindsTwoWayByDefault,
                    AddressOf OnSelectedItemChanged))

        Public Overloads Property SelectedItem As Object
            Get
                Return GetValue(SelectedItemProperty)
            End Get
            Set(value As Object)
                SetValue(SelectedItemProperty, value)
            End Set
        End Property

        ''' <summary>اسم الخاصية المستخدمة لعرض النص في الـ TextBox وقائمة النتائج</summary>
        Public Shared ReadOnly DisplayMemberPathProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(DisplayMemberPath), GetType(String),
                GetType(SearchableDropdown),
                New PropertyMetadata(String.Empty, AddressOf OnDisplayMemberPathChanged))

        Public Property DisplayMemberPath As String
            Get
                Return CStr(GetValue(DisplayMemberPathProperty))
            End Get
            Set(value As String)
                SetValue(DisplayMemberPathProperty, value)
            End Set
        End Property

        ''' <summary>نص placeholder يظهر عندما الـ TextBox فارغ</summary>
        Public Shared ReadOnly WatermarkProperty As DependencyProperty =
            DependencyProperty.Register(NameOf(Watermark), GetType(String),
                GetType(SearchableDropdown),
                New PropertyMetadata("ابحث..."))

        Public Property Watermark As String
            Get
                Return CStr(GetValue(WatermarkProperty))
            End Get
            Set(value As String)
                SetValue(WatermarkProperty, value)
            End Set
        End Property

        ' ══════════════════════════════════════════════════════
        '  Events
        ' ══════════════════════════════════════════════════════

        ''' <summary>يُطلَق عندما يكتب المستخدم نصاً — استخدمه لتنفيذ الفلترة</summary>
        Public Event SearchChanged As EventHandler(Of String)

        ''' <summary>يُطلَق عند اختيار عنصر (بالماوس أو Enter)</summary>
        Public Event ItemSelected As EventHandler(Of Object)

        ''' <summary>يُطلَق عند الضغط Enter بعد التأكيد — للانتقال للحقل التالي</summary>
        Public Event ConfirmedAndMoveNext As EventHandler

        ' ══════════════════════════════════════════════════════
        '  Private State — متغير واحد فقط لمنع التعارض
        ' ══════════════════════════════════════════════════════

        Private _busy As Boolean = False      ' يمنع أي معالجة أثناء التحديثات البرمجية
        Private _isInitialized As Boolean = False
        Private _pendingText As String = Nothing  ' نص ينتظر التطبيق بعد التحميل

        ' ══════════════════════════════════════════════════════
        '  Initialization
        ' ══════════════════════════════════════════════════════

        Public Sub New()
            InitializeComponent()
            AddHandler Loaded, AddressOf OnLoaded
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            _isInitialized = True
            UpdateListBox()
            If Not String.IsNullOrEmpty(Watermark) Then
                Helpers.WatermarkHelper.SetWatermark(SearchBox, Watermark)
            End If
            ' تطبيق أي نص معلق كان مقترحاً قبل التحميل
            If _pendingText IsNot Nothing Then
                _busy = True
                SearchBox.Text = _pendingText
                _busy = False
                _pendingText = Nothing
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Dependency Property Callbacks
        ' ══════════════════════════════════════════════════════

        Private Shared Sub OnItemsSourceChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, SearchableDropdown)
            If ctrl Is Nothing OrElse Not ctrl._isInitialized Then Return
            ctrl.UpdateListBox()
            ' إذا كانت القائمة مفتوحة وفيها نتائج، ابقِها مفتوحة
            If ctrl.ItemsList.Items.Count > 0 AndAlso ctrl.IsEnabled Then
                ctrl.DropPopup.IsOpen = True
            End If
        End Sub

        Private Shared Sub OnSelectedItemChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, SearchableDropdown)
            If ctrl Is Nothing OrElse ctrl._busy Then Return

            Dim displayText As String
            If e.NewValue IsNot Nothing Then
                displayText = ctrl.GetDisplayText(e.NewValue)
            Else
                displayText = String.Empty
            End If

            If ctrl._isInitialized Then
                ' الـ Control جاهز — حدّث فوراً
                ctrl._busy = True
                ctrl.SearchBox.Text = displayText
                ctrl._busy = False
            Else
                ' الـ Control لم يتحمّل بعد — احفظ النص لتطبيقه في OnLoaded
                ctrl._pendingText = displayText
            End If
        End Sub

        Private Shared Sub OnDisplayMemberPathChanged(d As DependencyObject, e As DependencyPropertyChangedEventArgs)
            Dim ctrl = TryCast(d, SearchableDropdown)
            If ctrl Is Nothing OrElse Not ctrl._isInitialized Then Return
            ctrl.UpdateListBox()
        End Sub

        ' ══════════════════════════════════════════════════════
        '  ListBox Sync
        ' ══════════════════════════════════════════════════════

        Private Sub UpdateListBox()
            If ItemsList Is Nothing Then Return

            If Not String.IsNullOrEmpty(DisplayMemberPath) Then
                ' استخدم DataTemplate ليعرض الخاصية المطلوبة
                Dim factory As New FrameworkElementFactory(GetType(TextBlock))
                factory.SetBinding(TextBlock.TextProperty, New Data.Binding(DisplayMemberPath))
                factory.SetValue(TextBlock.PaddingProperty, New Thickness(0))
                Dim template As New DataTemplate()
                template.VisualTree = factory
                ItemsList.ItemTemplate = template
            Else
                ItemsList.DisplayMemberPath = Nothing
                ItemsList.ItemTemplate = Nothing
            End If

            ItemsList.ItemsSource = ItemsSource
        End Sub

        ' ══════════════════════════════════════════════════════
        '  TextBox Events
        ' ══════════════════════════════════════════════════════

        Private Sub SearchBox_TextChanged(sender As Object, e As TextChangedEventArgs)
            If _busy OrElse Not _isInitialized Then Return
            If Not IsEnabled Then Return

            ' إذا كان النص يتطابق مع الاختيار الحالي → تحديث برمجي، تجاهله
            If SelectedItem IsNot Nothing Then
                Dim currentDisplay = GetDisplayText(SelectedItem)
                If SearchBox.Text = currentDisplay Then Return
            End If

            ' المستخدم غيَّر النص → امسح الاختيار الحالي
            _busy = True
            SelectedItem = Nothing
            _busy = False

            ' أطلق حدث الفلترة
            RaiseEvent SearchChanged(Me, SearchBox.Text)
        End Sub

        Private Sub SearchBox_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Select Case e.Key
                Case Key.Down
                    ' انتقل لقائمة النتائج
                    If ItemsList.Items.Count > 0 Then
                        DropPopup.IsOpen = True
                        ItemsList.Focus()
                        ItemsList.SelectedIndex = 0
                        Dim container = TryCast(ItemsList.ItemContainerGenerator.ContainerFromIndex(0), ListBoxItem)
                        If container IsNot Nothing Then container.Focus()
                        e.Handled = True
                    End If

                Case Key.Enter
                    e.Handled = True
                    If DropPopup.IsOpen AndAlso ItemsList.SelectedItem IsNot Nothing Then
                        CommitSelection(ItemsList.SelectedItem)
                    ElseIf ItemsList.Items.Count = 1 Then
                        CommitSelection(ItemsList.Items(0))
                    ElseIf SelectedItem IsNot Nothing Then
                        ' الاختيار موجود بالفعل → انتقل مباشرة
                        DropPopup.IsOpen = False
                        RaiseEvent ConfirmedAndMoveNext(Me, EventArgs.Empty)
                    Else
                        ' لا يوجد اختيار — حاول تطابق جزئي
                        Dim match = FindPartialMatch(SearchBox.Text)
                        If match IsNot Nothing Then
                            CommitSelection(match)
                        End If
                    End If

                Case Key.Escape
                    DropPopup.IsOpen = False
                    e.Handled = True
            End Select
        End Sub

        Private Sub SearchBox_GotFocus(sender As Object, e As RoutedEventArgs)
            SearchBox.SelectAll()
        End Sub

        Private Sub SearchBox_LostFocus(sender As Object, e As RoutedEventArgs)
            ' لا تُغلق الـ Popup مباشرة — قد يكون المستخدم ينقر على عنصر في القائمة
            ' الـ Popup يُغلق تلقائياً بـ StaysOpen=False
        End Sub

        ' ══════════════════════════════════════════════════════
        '  ListBox Events
        ' ══════════════════════════════════════════════════════

        Private Sub ItemsList_MouseLeftButtonUp(sender As Object, e As MouseButtonEventArgs)
            Dim item = ItemsList.SelectedItem
            If item Is Nothing Then
                ' المستخدم نقر ولكن SelectedItem لم يتعين بعد — ابحث من الموضع
                Dim hit = TryCast(e.OriginalSource, FrameworkElement)
                If hit IsNot Nothing Then item = hit.DataContext
            End If
            If item IsNot Nothing Then CommitSelection(item)
        End Sub

        Private Sub ItemsList_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            Select Case e.Key
                Case Key.Enter
                    If ItemsList.SelectedItem IsNot Nothing Then CommitSelection(ItemsList.SelectedItem)
                    e.Handled = True
                Case Key.Escape
                    DropPopup.IsOpen = False
                    SearchBox.Focus()
                    e.Handled = True
                Case Key.Up
                    If ItemsList.SelectedIndex = 0 Then
                        ' العودة للـ TextBox عند بداية القائمة
                        SearchBox.Focus()
                        e.Handled = True
                    End If
            End Select
        End Sub

        Private Sub DropPopup_Opened(sender As Object, e As EventArgs)
            ' تأكد من أن عرض الـ Popup مساوٍ لعرض الـ TextBox
            If PopupBorder IsNot Nothing Then
                PopupBorder.MinWidth = SearchBox.ActualWidth
            End If
        End Sub

        ' ══════════════════════════════════════════════════════
        '  Core Logic
        ' ══════════════════════════════════════════════════════

        ''' <summary>تأكيد الاختيار — يُعيِّن SelectedItem ويُغلق القائمة ويُطلق الأحداث</summary>
        Private Sub CommitSelection(item As Object)
            If item Is Nothing Then Return

            _busy = True
            SelectedItem = item
            SearchBox.Text = GetDisplayText(item)
            SearchBox.CaretIndex = SearchBox.Text.Length
            DropPopup.IsOpen = False
            _busy = False

            RaiseEvent ItemSelected(Me, item)
            RaiseEvent ConfirmedAndMoveNext(Me, EventArgs.Empty)

            ' أعد التركيز للـ TextBox
            SearchBox.Focus()
        End Sub

        ''' <summary>استخراج نص العرض من كائن باستخدام DisplayMemberPath عبر Reflection</summary>
        Private Function GetDisplayText(item As Object) As String
            If item Is Nothing Then Return String.Empty
            If String.IsNullOrEmpty(DisplayMemberPath) Then Return item.ToString()
            Try
                Dim prop = item.GetType().GetProperty(DisplayMemberPath)
                If prop IsNot Nothing Then
                    Dim val = prop.GetValue(item)
                    If val IsNot Nothing Then Return val.ToString() Else Return String.Empty
                End If
            Catch
            End Try
            Return item.ToString()
        End Function

        ''' <summary>بحث جزئي في ItemsSource عند الضغط Enter بدون اختيار</summary>
        Private Function FindPartialMatch(searchText As String) As Object
            If ItemsSource Is Nothing OrElse String.IsNullOrWhiteSpace(searchText) Then Return Nothing
            Dim lower = searchText.Trim().ToLower()
            For Each item In ItemsSource
                Dim display = GetDisplayText(item).ToLower()
                If display = lower Then Return item  ' تطابق كامل أولاً
            Next
            ' تطابق جزئي
            Dim results As New List(Of Object)
            For Each item In ItemsSource
                If GetDisplayText(item).ToLower().Contains(lower) Then results.Add(item)
            Next
            If results.Count = 1 Then Return results(0)
            Return Nothing
        End Function

        ' ══════════════════════════════════════════════════════
        '  Public API
        ' ══════════════════════════════════════════════════════

        ''' <summary>افتح القائمة برمجياً</summary>
        Public Sub OpenDropdown()
            If IsEnabled Then DropPopup.IsOpen = True
        End Sub

        ''' <summary>أغلق القائمة برمجياً</summary>
        Public Sub CloseDropdown()
            DropPopup.IsOpen = False
        End Sub

        ''' <summary>امسح الاختيار والنص</summary>
        Public Sub ClearSelection()
            _busy = True
            SelectedItem = Nothing
            If _isInitialized Then
                SearchBox.Text = String.Empty
            End If
            _pendingText = Nothing
            _busy = False
        End Sub

        ''' <summary>
        ''' تعيين نص محدد مباشرة دون الحاجة لكائن Partner.
        ''' مفيد عند تحميل فاتورة وعرض اسم الشريك فوراً بغض النظر عن حالة التهيئة.
        ''' </summary>
        Public Sub SetDisplayText(text As String)
            _busy = True
            If _isInitialized Then
                SearchBox.Text = If(text, String.Empty)
            Else
                _pendingText = If(text, String.Empty)
            End If
            _busy = False
        End Sub

    End Class

End Namespace
