Imports System
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Controls
    Partial Public Class LeaveRowControl
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            AddHandler Me.DataContextChanged, AddressOf OnDataContextChanged
            AddHandler Me.Loaded, AddressOf OnLoaded
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            UpdateBadges()
        End Sub

        Private Sub OnDataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs)
            UpdateBadges()
        End Sub

        Public Sub UpdateBadges()
            Dim leave = TryCast(Me.DataContext, EmployeeLeave)
            If leave Is Nothing OrElse DelayBadge Is Nothing OrElse StatusBadge Is Nothing Then Return

            ' 1: Update Delay Badge
            If leave.DelayDays > 0 Then
                DelayBadge.Background = New SolidColorBrush(Color.FromRgb(254, 226, 226)) '#FEE2E2
                DelayBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(254, 202, 202))
                DelayBadge.BorderThickness = New Thickness(1)
                DelayText.Foreground = New SolidColorBrush(Color.FromRgb(220, 38, 38)) '#DC2626
                DelayText.Text = $"⚠️ +{leave.DelayDays} يوم"
            Else
                DelayBadge.Background = New SolidColorBrush(Color.FromRgb(240, 253, 244)) '#F0FDF4
                DelayBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(187, 247, 208))
                DelayBadge.BorderThickness = New Thickness(1)
                DelayText.Foreground = New SolidColorBrush(Color.FromRgb(22, 163, 74)) '#16A34A
                DelayText.Text = "✓ منتظم"
            End If

            ' 2: Update Status Badge
            If leave.ResumptionDate.HasValue OrElse String.Equals(leave.Status, "Completed", StringComparison.OrdinalIgnoreCase) Then
                StatusBadge.Background = New SolidColorBrush(Color.FromRgb(209, 250, 229)) '#D1FAE5
                StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(167, 243, 208))
                StatusBadge.BorderThickness = New Thickness(1)
                StatusText.Foreground = New SolidColorBrush(Color.FromRgb(5, 150, 105)) '#059669
                StatusText.Text = "✓ تم المباشرة"
            ElseIf String.Equals(leave.Status, "Approved", StringComparison.OrdinalIgnoreCase) Then
                StatusBadge.Background = New SolidColorBrush(Color.FromRgb(254, 243, 199)) '#FEF3C7
                StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(253, 230, 138))
                StatusBadge.BorderThickness = New Thickness(1)
                StatusText.Foreground = New SolidColorBrush(Color.FromRgb(217, 119, 6)) '#D97706
                StatusText.Text = "⏳ سارية"
            Else
                StatusBadge.Background = New SolidColorBrush(Color.FromRgb(241, 245, 249))
                StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(226, 232, 240))
                StatusBadge.BorderThickness = New Thickness(1)
                StatusText.Foreground = New SolidColorBrush(Color.FromRgb(71, 85, 105))
                StatusText.Text = If(String.IsNullOrWhiteSpace(leave.Status), "🕒 معلقة", leave.Status)
            End If
        End Sub

        Private Sub PrintLeave_Click(sender As Object, e As RoutedEventArgs)
            Dim leave = TryCast(Me.DataContext, EmployeeLeave)
            If leave Is Nothing Then Return

            Dim parentListBox = FindVisualParent(Of ListBox)(Me)
            Dim vm = If(parentListBox IsNot Nothing, TryCast(parentListBox.DataContext, HRLeavesViewModel), Nothing)
            If vm IsNot Nothing AndAlso vm.PrintLeaveCommand IsNot Nothing Then
                vm.PrintLeaveCommand.Execute(leave)
            End If
        End Sub

        Private Sub PrintCommencement_Click(sender As Object, e As RoutedEventArgs)
            Dim leave = TryCast(Me.DataContext, EmployeeLeave)
            If leave Is Nothing Then Return

            Dim parentListBox = FindVisualParent(Of ListBox)(Me)
            Dim vm = If(parentListBox IsNot Nothing, TryCast(parentListBox.DataContext, HRLeavesViewModel), Nothing)
            If vm IsNot Nothing AndAlso vm.PrintCommencementCommand IsNot Nothing Then
                vm.PrintCommencementCommand.Execute(leave)
            End If
        End Sub

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
