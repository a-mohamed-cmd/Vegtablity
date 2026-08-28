Imports System
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Input
Imports System.Windows.Media
Imports Vegtablity.Models
Imports Vegtablity.ViewModels

Namespace Controls
    Partial Public Class PartnerCardControl
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            AddHandler Me.DataContextChanged, AddressOf OnDataContextChanged
            AddHandler Me.Loaded, AddressOf OnLoaded
        End Sub

        Private Sub OnLoaded(sender As Object, e As RoutedEventArgs)
            UpdateCardStyling()
        End Sub

        Private Sub OnDataContextChanged(sender As Object, e As DependencyPropertyChangedEventArgs)
            UpdateCardStyling()
        End Sub

        ''' <summary>
        ''' عند النقر على منطقة بيانات الشريك الرئيسية — فتح القائمة الجانبية للتعديل.
        ''' </summary>
        Private Sub PartnerDetailsArea_MouseLeftButtonUp(sender As Object, e As MouseButtonEventArgs)
            Dim partner = TryCast(Me.DataContext, Partner)
            If partner Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm Is Nothing Then Return

            If partner.PartnerType = "Supplier" Then
                vm.SelectedSupplier = partner
                vm.IsSupplierPanelVisible = True
            Else
                vm.SelectedCustomer = partner
                vm.IsCustomerPanelVisible = True
            End If
        End Sub

        Public Sub UpdateCardStyling()
            Dim partner = TryCast(Me.DataContext, Partner)
            If partner Is Nothing OrElse TypeBadge Is Nothing Then Return

            ' 1: Type Badge Colors
            If partner.PartnerType = "Supplier" Then
                TypeBadge.Background = New SolidColorBrush(Color.FromRgb(254, 243, 199)) '#FEF3C7
                TypeBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(253, 230, 138)) '#FDE68A
                TypeText.Foreground = New SolidColorBrush(Color.FromRgb(180, 83, 9)) '#B45309
            Else
                TypeBadge.Background = New SolidColorBrush(Color.FromRgb(239, 246, 255)) '#EFF6FF
                TypeBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(191, 219, 254)) '#BFDBFE
                TypeText.Foreground = New SolidColorBrush(Color.FromRgb(29, 78, 216)) '#1D4ED8
            End If

            ' 2: Balance Color
            If TxtBalance IsNot Nothing Then
                If partner.CurrentBalance < 0 Then
                    TxtBalance.Foreground = New SolidColorBrush(Color.FromRgb(220, 38, 38)) '#DC2626 (Red)
                ElseIf partner.CurrentBalance > 0 Then
                    TxtBalance.Foreground = New SolidColorBrush(Color.FromRgb(5, 150, 105)) '#059669 (Emerald)
                Else
                    TxtBalance.Foreground = New SolidColorBrush(Color.FromRgb(71, 85, 105)) '#475569 (Slate)
                End If
            End If
        End Sub

        ''' <summary>
        ''' عند النقر على بطاقة عرض سعر محددة — فتح هذا العرض مباشرة في شاشة عروض الأسعار.
        ''' </summary>
        Private Sub QuoteButton_Click(sender As Object, e As RoutedEventArgs)
            e.Handled = True
            Dim btn = TryCast(sender, Button)
            If btn Is Nothing Then Return

            Dim quoteSummary = TryCast(btn.DataContext, PartnerQuoteSummaryItem)
            If quoteSummary Is Nothing OrElse quoteSummary.RawQuote Is Nothing Then Return

            Dim vm = FindParentViewModel()
            If vm Is Nothing Then Return

            If quoteSummary.PartnerType = "Supplier" Then
                Dim pq = TryCast(quoteSummary.RawQuote, PurchaseQuoteHeader)
                If pq IsNot Nothing Then
                    vm.ViewPurchaseQuoteCommand.Execute(pq)
                End If
            Else
                Dim q = TryCast(quoteSummary.RawQuote, QuoteHeader)
                If q IsNot Nothing Then
                    vm.ViewQuoteCommand.Execute(q)
                End If
            End If
        End Sub

        Private Function FindParentViewModel() As PartnersViewModel
            Dim parentUc = FindVisualParent(Of UserControl)(Me)
            Dim vm = If(parentUc IsNot Nothing, TryCast(parentUc.DataContext, PartnersViewModel), Nothing)
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
