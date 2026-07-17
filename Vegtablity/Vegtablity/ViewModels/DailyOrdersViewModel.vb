Imports System.Collections.ObjectModel
Imports System.Windows.Input
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers
Imports System.Threading.Tasks

Namespace ViewModels
    Public Class DailyOrdersViewModel
        Inherits BaseViewModel

        Private ReadOnly _orderService As New OrderService()

        ' === Properties ===

        Private _selectedDate As Date = Date.Today
        Public Property SelectedDate As Date
            Get
                Return _selectedDate
            End Get
            Set(value As Date)
                _selectedDate = value
                SelectedDateText = value.ToString("dd/MM/yyyy")
                OnPropertyChanged()
                LoadOrders()
            End Set
        End Property

        Private _selectedDateText As String = Date.Today.ToString("dd/MM/yyyy")
        Public Property SelectedDateText As String
            Get
                Return _selectedDateText
            End Get
            Set(value As String)
                _selectedDateText = value
                OnPropertyChanged()
            End Set
        End Property

        Private _orders As New ObservableCollection(Of DailyOrder)()
        Public Property Orders As ObservableCollection(Of DailyOrder)
            Get
                Return _orders
            End Get
            Set(value As ObservableCollection(Of DailyOrder))
                _orders = value
                OnPropertyChanged()
            End Set
        End Property

        Private _isLoading As Boolean
        Public Property IsLoading As Boolean
            Get
                Return _isLoading
            End Get
            Set(value As Boolean)
                _isLoading = value
                OnPropertyChanged()
            End Set
        End Property

        ' === Commands ===

        Public ReadOnly Property RefreshCommand As ICommand
            Get
                Return New RelayCommand(Sub(o) LoadOrders())
            End Get
        End Property

        Public ReadOnly Property ToggleCardCommand As ICommand
            Get
                Return New RelayCommand(Sub(o)
                                            Dim ord = TryCast(o, DailyOrder)
                                            If ord IsNot Nothing Then
                                                ord.IsExpanded = Not ord.IsExpanded
                                            End If
                                        End Sub)
            End Get
        End Property

        Public Sub New()
            LoadOrders()
        End Sub

        Public Sub LoadOrders()
            IsLoading = True
            Orders.Clear()

            ' Fetch headers in background
            Task.Run(Sub()
                         Try
                             Dim fetched = _orderService.GetDailyOrders(SelectedDate)
                             
                             ' Load details for each header
                             For Each ord In fetched
                                 Dim details = _orderService.GetInvoiceDetails(ord.InvID)
                                 System.Windows.Application.Current.Dispatcher.Invoke(Sub()
                                                                   ord.Details = New ObservableCollection(Of InvoiceDetail)(details)
                                                                   Orders.Add(ord)
                                                               End Sub)
                             Next
                         Catch ex As Exception
                             ' ignore
                         Finally
                             System.Windows.Application.Current.Dispatcher.Invoke(Sub() IsLoading = False)
                         End Try
                     End Sub)
        End Sub
    End Class
End Namespace
