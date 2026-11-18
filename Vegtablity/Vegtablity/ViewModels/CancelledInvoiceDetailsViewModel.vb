Imports System
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models
Imports Vegtablity.Services

Namespace ViewModels
    ''' <summary>
    ''' ViewModel مستقل تماماً لعرض وطباعة الفاتورة المحذوفة / الملغاة (للقراءة فقط دون حفظ أو تعديل أو ترحيل)
    ''' </summary>
    Public Class CancelledInvoiceDetailsViewModel
        Inherits BaseViewModel

        Private ReadOnly _cancelledService As CancelledInvoiceService
        Private ReadOnly _permissionService As PermissionService

        Private _snapshot As CancelledInvoiceSnapshot
        Public Property Snapshot As CancelledInvoiceSnapshot
            Get
                Return _snapshot
            End Get
            Set(value As CancelledInvoiceSnapshot)
                SetProperty(_snapshot, value)
                NotifyAllDerived()
            End Set
        End Property

        Private _isLoading As Boolean
        Public Property IsLoading As Boolean
            Get
                Return _isLoading
            End Get
            Set(value As Boolean)
                SetProperty(_isLoading, value)
            End Set
        End Property

        Public ReadOnly Property IsSalesInvoice As Boolean
            Get
                Return Snapshot IsNot Nothing AndAlso Snapshot.IsSalesInvoice
            End Get
        End Property

        Public ReadOnly Property HasTempOrderInfo As Boolean
            Get
                Return Snapshot IsNot Nothing AndAlso Snapshot.HasTempOrderInfo
            End Get
        End Property

        Public ReadOnly Property HasPaymentSplits As Boolean
            Get
                Return Snapshot IsNot Nothing AndAlso Snapshot.HasPaymentSplits
            End Get
        End Property

        Public ReadOnly Property HasPaymentLinks As Boolean
            Get
                Return Snapshot IsNot Nothing AndAlso Snapshot.HasPaymentLinks
            End Get
        End Property

        Public ReadOnly Property HasTalabatOrders As Boolean
            Get
                Return Snapshot IsNot Nothing AndAlso Snapshot.HasTalabatOrders
            End Get
        End Property

        Private _canPrintPermission As Boolean = True
        Public ReadOnly Property CanPrint As Boolean
            Get
                Return Snapshot IsNot Nothing AndAlso _canPrintPermission
            End Get
        End Property

        Public ReadOnly Property CanPrintSalesPaper As Boolean
            Get
                Return CanPrint AndAlso IsSalesInvoice
            End Get
        End Property

        Public Property PrintCommand As ICommand
        Public Property ExportPdfCommand As ICommand

        Public Sub New()
            If System.ComponentModel.DesignerProperties.GetIsInDesignMode(New System.Windows.DependencyObject()) Then Return
            _cancelledService = New CancelledInvoiceService()
            _permissionService = New PermissionService()

            PrintCommand = New RelayCommand(AddressOf ExecutePrint, Function(p) CanPrintSalesPaper)
            ExportPdfCommand = New RelayCommand(AddressOf ExecuteExportPdf, Function(p) CanPrint)
            LoadDashboardPrintPermission()
        End Sub

        Private Sub LoadDashboardPrintPermission()
            Try
                If Session.CurrentUser IsNot Nothing Then
                    Dim dash = _permissionService.GetPermissionsForForm(Session.CurrentUser.RoleID, "InvoiceDashboard")
                    If dash IsNot Nothing Then
                        _canPrintPermission = dash.CanPrint
                    End If
                End If
            Catch
                _canPrintPermission = True
            End Try
        End Sub

        Public Sub LoadCancelledInvoice(archiveID As Integer?, originalInvID As Integer)
            Try
                IsLoading = True
                Snapshot = _cancelledService.GetCancelledInvoiceDetails(archiveID, originalInvID)
                If Snapshot Is Nothing Then
                    SnackbarService.ShowWarning($"لم يتم العثور على سجل الفاتورة الملغاة رقم #{originalInvID}.")
                End If
            Catch ex As Exception
                SnackbarService.ShowError(ex, "تعذر تحميل تفاصيل الفاتورة الملغاة")
            Finally
                IsLoading = False
            End Try
        End Sub

        Private Sub NotifyAllDerived()
            OnPropertyChanged(NameOf(IsSalesInvoice))
            OnPropertyChanged(NameOf(HasTempOrderInfo))
            OnPropertyChanged(NameOf(HasPaymentSplits))
            OnPropertyChanged(NameOf(HasPaymentLinks))
            OnPropertyChanged(NameOf(HasTalabatOrders))
            OnPropertyChanged(NameOf(CanPrint))
            OnPropertyChanged(NameOf(CanPrintSalesPaper))
            CommandManager.InvalidateRequerySuggested()
        End Sub

        Private Sub ExecutePrint(parameter As Object)
            If Snapshot Is Nothing Then Return
            Try
                Dim reportData = Snapshot.ToInvoiceReportData()
                If reportData.Details Is Nothing OrElse reportData.Details.Count = 0 Then
                    SnackbarService.ShowWarning("لا توجد أصناف في الفاتورة للطباعة.")
                    Return
                End If

                Dim useCustomDesign As Boolean = False
                Try
                    Dim svc As New SettingsService()
                    Dim company = svc.GetCompanyInfo()
                    If company IsNot Nothing Then useCustomDesign = company.UseCustomInvoiceDesign
                Catch
                End Try

                If useCustomDesign Then
                    Dim printer As New InvoicePrinterCustom()
                    printer.PrintSalesInvoice(reportData)
                Else
                    Dim printer As New InvoicePrinter()
                    printer.PrintSalesInvoice(reportData)
                End If
            Catch ex As Exception
                SnackbarService.ShowError(ex, "تعذر طباعة الفاتورة الملغاة")
            End Try
        End Sub

        Private Sub ExecuteExportPdf(parameter As Object)
            If Snapshot Is Nothing Then Return
            Try
                Dim reportData = Snapshot.ToInvoiceReportData()
                If reportData.Details Is Nothing OrElse reportData.Details.Count = 0 Then
                    SnackbarService.ShowWarning("لا توجد أصناف في الفاتورة لتصديرها.")
                    Return
                End If

                ReportExporter.ExportInvoiceToPdf(reportData, isPurchase:=Not IsSalesInvoice)
            Catch ex As Exception
                SnackbarService.ShowError(ex, "تعذر تصدير الفاتورة الملغاة إلى PDF")
            End Try
        End Sub
    End Class
End Namespace
