Imports System.Collections.ObjectModel
Imports System.Windows.Input
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace ViewModels
    Public Class ShiftsViewModel
        Inherits BaseViewModel

        Private ReadOnly _shiftService As New ShiftService()

        Private _shifts As ObservableCollection(Of Shift)
        Private _selectedShift As Shift
        
        Private _salesInvoices As ObservableCollection(Of InvoiceHeader)
        Private _purchaseInvoices As ObservableCollection(Of InvoiceHeader)
        Private _receiptVouchers As ObservableCollection(Of Voucher)
        Private _paymentVouchers As ObservableCollection(Of Voucher)
        Private _nonCashPaymentSummaries As ObservableCollection(Of PaymentMethodSummary)
        
        Private _isDetailsLoading As Boolean
        Private _isLoading As Boolean
        
        ' Calculated Cash Flow Properties
        Private _netCashFlow As Decimal
        Private _expectedEndingCash As Decimal
        Private _cashDifference As Decimal
        Private _totalNonCashAmount As Decimal

        Public Sub New()
            Shifts = New ObservableCollection(Of Shift)()
            SalesInvoices = New ObservableCollection(Of InvoiceHeader)()
            PurchaseInvoices = New ObservableCollection(Of InvoiceHeader)()
            ReceiptVouchers = New ObservableCollection(Of Voucher)()
            PaymentVouchers = New ObservableCollection(Of Voucher)()
            NonCashPaymentSummaries = New ObservableCollection(Of PaymentMethodSummary)()
            LoadShifts()
        End Sub

        Public Property Shifts As ObservableCollection(Of Shift)
            Get
                Return _shifts
            End Get
            Set(value As ObservableCollection(Of Shift))
                SetProperty(_shifts, value)
            End Set
        End Property

        Public Property SelectedShift As Shift
            Get
                Return _selectedShift
            End Get
            Set(value As Shift)
                SetProperty(_selectedShift, value)
                If _selectedShift IsNot Nothing Then
                    LoadShiftDetails(_selectedShift.ShiftID)
                End If
            End Set
        End Property

        Public Property SalesInvoices As ObservableCollection(Of InvoiceHeader)
            Get
                Return _salesInvoices
            End Get
            Set(value As ObservableCollection(Of InvoiceHeader))
                SetProperty(_salesInvoices, value)
            End Set
        End Property

        Public Property PurchaseInvoices As ObservableCollection(Of InvoiceHeader)
            Get
                Return _purchaseInvoices
            End Get
            Set(value As ObservableCollection(Of InvoiceHeader))
                SetProperty(_purchaseInvoices, value)
            End Set
        End Property

        Public Property ReceiptVouchers As ObservableCollection(Of Voucher)
            Get
                Return _receiptVouchers
            End Get
            Set(value As ObservableCollection(Of Voucher))
                SetProperty(_receiptVouchers, value)
            End Set
        End Property

        Public Property PaymentVouchers As ObservableCollection(Of Voucher)
            Get
                Return _paymentVouchers
            End Get
            Set(value As ObservableCollection(Of Voucher))
                SetProperty(_paymentVouchers, value)
            End Set
        End Property

        Public Property NonCashPaymentSummaries As ObservableCollection(Of PaymentMethodSummary)
            Get
                Return _nonCashPaymentSummaries
            End Get
            Set(value As ObservableCollection(Of PaymentMethodSummary))
                SetProperty(_nonCashPaymentSummaries, value)
            End Set
        End Property

        Public Property NetCashFlow As Decimal
            Get
                Return _netCashFlow
            End Get
            Set(value As Decimal)
                SetProperty(_netCashFlow, value)
            End Set
        End Property

        Public Property ExpectedEndingCash As Decimal
            Get
                Return _expectedEndingCash
            End Get
            Set(value As Decimal)
                SetProperty(_expectedEndingCash, value)
            End Set
        End Property

        Public Property CashDifference As Decimal
            Get
                Return _cashDifference
            End Get
            Set(value As Decimal)
                SetProperty(_cashDifference, value)
            End Set
        End Property

        Public Property TotalNonCashAmount As Decimal
            Get
                Return _totalNonCashAmount
            End Get
            Set(value As Decimal)
                SetProperty(_totalNonCashAmount, value)
            End Set
        End Property

        Public Property IsDetailsLoading As Boolean
            Get
                Return _isDetailsLoading
            End Get
            Set(value As Boolean)
                SetProperty(_isDetailsLoading, value)
            End Set
        End Property

        Public Property IsLoading As Boolean
            Get
                Return _isLoading
            End Get
            Set(value As Boolean)
                SetProperty(_isLoading, value)
            End Set
        End Property

        Public ReadOnly Property RefreshCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub() LoadShifts())
            End Get
        End Property

        Private Async Sub LoadShifts()
            IsLoading = True
            Await System.Threading.Tasks.Task.Run(Sub()
                                                      Dim data = _shiftService.GetAllShifts()
                                                      System.Windows.Application.Current.Dispatcher.Invoke(Sub()
                                                                                                                Shifts.Clear()
                                                                                                                For Each s In data
                                                                                                                    Shifts.Add(s)
                                                                                                                Next
                                                                                                            End Sub)
                                                  End Sub)
            IsLoading = False
        End Sub

        Private Async Sub LoadShiftDetails(shiftID As Integer)
            IsDetailsLoading = True
            SalesInvoices.Clear()
            PurchaseInvoices.Clear()
            ReceiptVouchers.Clear()
            PaymentVouchers.Clear()
            NonCashPaymentSummaries.Clear()

            Await System.Threading.Tasks.Task.Run(Sub()
                                                      Dim summary = _shiftService.GetShiftSummary(shiftID)
                                                      Dim vouchers = _shiftService.GetShiftVouchers(shiftID)
                                                      Dim salesInvs = _shiftService.GetShiftInvoices(shiftID, "Sales")
                                                      Dim purchaseInvs = _shiftService.GetShiftInvoices(shiftID, "Purchase")
                                                      Dim paymentTotals = _shiftService.GetShiftPaymentMethodTotals(shiftID)

                                                      System.Windows.Application.Current.Dispatcher.Invoke(Sub()
                                                                                                                If summary IsNot Nothing Then
                                                                                                                    SelectedShift.TotalSales = summary.TotalSales
                                                                                                                    SelectedShift.TotalPurchases = summary.TotalPurchases
                                                                                                                    SelectedShift.TotalPaidSales = summary.TotalPaidSales
                                                                                                                    SelectedShift.TotalPaidPurchases = summary.TotalPaidPurchases
                                                                                                                    SelectedShift.TotalReceiptVouchers = summary.TotalReceiptVouchers
                                                                                                                    SelectedShift.TotalPaymentVouchers = summary.TotalPaymentVouchers
                                                                                                                    SelectedShift.SalesCount = summary.SalesCount
                                                                                                                    SelectedShift.PurchasesCount = summary.PurchasesCount
                                                                                                                    
                                                                                                                    ' Calculate Cash Flow
                                                                                                                    Dim startCash As Decimal = SelectedShift.StartingCash
                                                                                                                    Dim endCash As Decimal = If(SelectedShift.EndingCash.HasValue, SelectedShift.EndingCash.Value, 0)
                                                                                                                    
                                                                                                                    ' Net Cash Flow = Cash Sales + Cash Receipts - Cash Purchases - Cash Expenses
                                                                                                                    NetCashFlow = summary.TotalPaidSales + summary.TotalReceiptVouchers - summary.TotalPaidPurchases - summary.TotalPaymentVouchers
                                                                                                                    ExpectedEndingCash = startCash + NetCashFlow
                                                                                                                    CashDifference = endCash - ExpectedEndingCash
                                                                                                                    
                                                                                                                    OnPropertyChanged(NameOf(SelectedShift))
                                                                                                                End If

                                                                                                                For Each v In vouchers
                                                                                                                    If v.VoucherType = "Receipt" Then
                                                                                                                        ReceiptVouchers.Add(v)
                                                                                                                    ElseIf v.VoucherType = "Payment" Then
                                                                                                                        PaymentVouchers.Add(v)
                                                                                                                    End If
                                                                                                                Next
                                                                                                                
                                                                                                                For Each i In salesInvs
                                                                                                                    SalesInvoices.Add(i)
                                                                                                                Next
                                                                                                                
                                                                                                                For Each i In purchaseInvs
                                                                                                                    PurchaseInvoices.Add(i)
                                                                                                                Next

                                                                                                                ' Populate Payment Method Summaries for Non-Cash & Split methods
                                                                                                                Dim nonCashTotal As Decimal = 0
                                                                                                                If paymentTotals IsNot Nothing Then
                                                                                                                    For Each pt In paymentTotals
                                                                                                                        ' Check Cash Account (Code = 1101 or Name contains صندوق/كاش)
                                                                                                                        Dim isCashAccount As Boolean = (pt.AccountCode IsNot Nothing AndAlso pt.AccountCode = "1101") OrElse (pt.PaymentMethodName IsNot Nothing AndAlso (pt.PaymentMethodName.Contains("كاش") OrElse pt.PaymentMethodName.Contains("صندوق") OrElse pt.PaymentMethodName.ToLower().Contains("cash")))
                                                                                                                        If Not isCashAccount Then
                                                                                                                            NonCashPaymentSummaries.Add(pt)
                                                                                                                            If pt.InvType = "Sales" OrElse pt.InvType = "Receipt" Then
                                                                                                                                nonCashTotal += pt.TotalAmount
                                                                                                                            ElseIf pt.InvType = "Purchase" OrElse pt.InvType = "Payment" Then
                                                                                                                                nonCashTotal -= pt.TotalAmount
                                                                                                                            End If
                                                                                                                        End If
                                                                                                                    Next
                                                                                                                End If
                                                                                                                TotalNonCashAmount = nonCashTotal
                                                                                                            End Sub)
                                                  End Sub)
            IsDetailsLoading = False
        End Sub
    End Class
End Namespace
