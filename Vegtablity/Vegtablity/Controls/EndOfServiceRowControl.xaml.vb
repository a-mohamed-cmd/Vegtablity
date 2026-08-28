Imports System
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Controls
    Partial Public Class EndOfServiceRowControl
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
            Dim s = TryCast(Me.DataContext, EndOfServiceSettlement)
            If s Is Nothing OrElse ReasonBadge Is Nothing Then Return

            Select Case s.DepartureReason
                Case "Resignation"
                    ReasonBadge.Background = New SolidColorBrush(Color.FromRgb(245, 243, 255)) '#F5F3FF
                    ReasonBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(221, 214, 254))
                    ReasonBadge.BorderThickness = New Thickness(1)
                    ReasonText.Foreground = New SolidColorBrush(Color.FromRgb(124, 58, 237)) '#7C3AED
                    ReasonText.Text = "استقالة"

                Case "Termination"
                    ReasonBadge.Background = New SolidColorBrush(Color.FromRgb(255, 241, 242)) '#FFF1F2
                    ReasonBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(254, 205, 211))
                    ReasonBadge.BorderThickness = New Thickness(1)
                    ReasonText.Foreground = New SolidColorBrush(Color.FromRgb(225, 29, 72)) '#E11D48
                    ReasonText.Text = "إنهاء خدمة"

                Case "ContractExpiry"
                    ReasonBadge.Background = New SolidColorBrush(Color.FromRgb(239, 246, 255)) '#EFF6FF
                    ReasonBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(191, 219, 254))
                    ReasonBadge.BorderThickness = New Thickness(1)
                    ReasonText.Foreground = New SolidColorBrush(Color.FromRgb(37, 99, 235)) '#2563EB
                    ReasonText.Text = "انتهاء عقد"

                Case "Retirement"
                    ReasonBadge.Background = New SolidColorBrush(Color.FromRgb(236, 253, 245)) '#ECFDF5
                    ReasonBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(167, 243, 208))
                    ReasonBadge.BorderThickness = New Thickness(1)
                    ReasonText.Foreground = New SolidColorBrush(Color.FromRgb(5, 150, 105)) '#059669
                    ReasonText.Text = "تقاعد"

                Case Else
                    ReasonBadge.Background = New SolidColorBrush(Color.FromRgb(241, 245, 249))
                    ReasonBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(226, 232, 240))
                    ReasonBadge.BorderThickness = New Thickness(1)
                    ReasonText.Foreground = New SolidColorBrush(Color.FromRgb(71, 85, 105))
                    ReasonText.Text = If(String.IsNullOrWhiteSpace(s.DepartureReason), "تصفية", s.DepartureReason)
            End Select
        End Sub

        Private Sub PrintSettlement_Click(sender As Object, e As RoutedEventArgs)
            Dim s = TryCast(Me.DataContext, EndOfServiceSettlement)
            If s Is Nothing Then Return

            Dim parentListBox = FindVisualParent(Of ListBox)(Me)
            Dim vm = If(parentListBox IsNot Nothing, TryCast(parentListBox.DataContext, HREndOfServiceViewModel), Nothing)
            If vm Is Nothing Then
                Dim parentUc = FindVisualParent(Of UserControl)(Me)
                vm = If(parentUc IsNot Nothing, TryCast(parentUc.DataContext, HREndOfServiceViewModel), Nothing)
            End If

            If vm IsNot Nothing AndAlso vm.PrintSettlementCommand IsNot Nothing Then
                vm.PrintSettlementCommand.Execute(s)
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
