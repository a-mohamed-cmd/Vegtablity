Imports System
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Controls
    Partial Public Class CustomFieldCardControl
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            AddHandler Me.DataContextChanged, AddressOf OnDataContextChanged
            AddHandler Me.Loaded, AddressOf OnLoaded
            AddHandler Me.MouseLeftButtonUp, AddressOf OnCardClicked
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            UpdateBadges()
        End Sub

        Private Sub OnDataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs)
            UpdateBadges()
        End Sub

        Private Sub OnCardClicked(sender As Object, e As MouseButtonEventArgs)
            Dim field = TryCast(Me.DataContext, CustomFieldDefinition)
            If field Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm IsNot Nothing Then
                vm.SelectedField = field
            End If
        End Sub

        Public Sub UpdateBadges()
            Dim field = TryCast(Me.DataContext, CustomFieldDefinition)
            If field Is Nothing OrElse TypeBadge Is Nothing Then Return

            ' 1: Field Type Badge Colors & Icons
            Select Case field.FieldType
                Case "Date"
                    TypeBadge.Background = New SolidColorBrush(Color.FromRgb(239, 246, 255)) '#EFF6FF
                    TypeBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(191, 219, 254))
                    TypeBadge.BorderThickness = New Thickness(1)
                    TypeText.Foreground = New SolidColorBrush(Color.FromRgb(29, 78, 216)) '#1D4ED8
                    TypeIcon.Text = "📅"

                Case "Text"
                    TypeBadge.Background = New SolidColorBrush(Color.FromRgb(238, 242, 255)) '#EEF2FF
                    TypeBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(199, 210, 254))
                    TypeBadge.BorderThickness = New Thickness(1)
                    TypeText.Foreground = New SolidColorBrush(Color.FromRgb(67, 56, 202)) '#4338CA
                    TypeIcon.Text = "📝"

                Case "Number"
                    TypeBadge.Background = New SolidColorBrush(Color.FromRgb(254, 243, 199)) '#FEF3C7
                    TypeBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(253, 230, 138))
                    TypeBadge.BorderThickness = New Thickness(1)
                    TypeText.Foreground = New SolidColorBrush(Color.FromRgb(180, 83, 9)) '#B45309
                    TypeIcon.Text = "🔢"

                Case Else
                    TypeBadge.Background = New SolidColorBrush(Color.FromRgb(241, 245, 249))
                    TypeBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(203, 213, 225))
                    TypeBadge.BorderThickness = New Thickness(1)
                    TypeText.Foreground = New SolidColorBrush(Color.FromRgb(51, 65, 85))
                    TypeIcon.Text = "🧩"
            End Select

            ' 2: Status Badge Colors
            If field.IsActive Then
                StatusBadge.Background = New SolidColorBrush(Color.FromRgb(236, 253, 245)) '#ECFDF5
                StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(167, 243, 208))
                StatusBadge.BorderThickness = New Thickness(1)
                StatusText.Foreground = New SolidColorBrush(Color.FromRgb(5, 150, 105)) '#059669
            Else
                StatusBadge.Background = New SolidColorBrush(Color.FromRgb(241, 245, 249))
                StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(203, 213, 225))
                StatusBadge.BorderThickness = New Thickness(1)
                StatusText.Foreground = New SolidColorBrush(Color.FromRgb(100, 116, 139))
            End If

            ' 3: Alert Badge Colors
            If field.IsAlertable Then
                AlertBadge.Background = New SolidColorBrush(Color.FromRgb(255, 251, 235)) '#FFFBEB
                AlertBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(253, 230, 138))
                AlertBadge.BorderThickness = New Thickness(1)
                AlertText.Foreground = New SolidColorBrush(Color.FromRgb(180, 83, 9)) '#B45309
            Else
                AlertBadge.Background = New SolidColorBrush(Color.FromRgb(248, 250, 252))
                AlertBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(226, 232, 240))
                AlertBadge.BorderThickness = New Thickness(1)
                AlertText.Foreground = New SolidColorBrush(Color.FromRgb(148, 163, 184))
            End If
        End Sub

        Private Sub EditField_Click(sender As Object, e As RoutedEventArgs)
            e.Handled = True
            Dim field = TryCast(Me.DataContext, CustomFieldDefinition)
            If field Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm IsNot Nothing Then
                vm.SelectedField = field
            End If
        End Sub

        Private Sub DeleteField_Click(sender As Object, e As RoutedEventArgs)
            e.Handled = True
            Dim field = TryCast(Me.DataContext, CustomFieldDefinition)
            If field Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm IsNot Nothing Then
                vm.DeleteCustomField(field)
            End If
        End Sub

        Private Function FindParentViewModel() As HRSettingsViewModel
            Dim parentListBox = FindVisualParent(Of ListBox)(Me)
            Dim vm = If(parentListBox IsNot Nothing, TryCast(parentListBox.DataContext, HRSettingsViewModel), Nothing)
            If vm Is Nothing Then
                Dim parentUc = FindVisualParent(Of UserControl)(Me)
                vm = If(parentUc IsNot Nothing, TryCast(parentUc.DataContext, HRSettingsViewModel), Nothing)
            End If
            Return vm
        End Function

        Private Function FindVisualParent(Of T As DependencyObject)(child As DependencyObject) As T
            Dim parentObject As DependencyObject = VisualTreeHelper.GetParent(child)
            If parentObject Is Nothing Then Return Nothing
            Dim parent As T = TryCast(parentObject, T)
            If parent IsNot Nothing Then
                Return parent
            Else
                Return FindVisualParent(Of T)(parentObject)
            End If
        End Function
    End Class
End Namespace
