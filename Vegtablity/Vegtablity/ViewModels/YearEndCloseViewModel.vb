Imports System.Collections.ObjectModel
Imports System.Windows
Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers

Namespace ViewModels
    Public Class YearEndCloseViewModel
        Inherits BaseViewModel

        Private ReadOnly _accountingService As New AccountingService()

        ' === Properties ===

        Private _closingDate As Date = New Date(Now.Year, 12, 31)
        Public Property ClosingDate As Date
            Get
                Return _closingDate
            End Get
            Set(value As Date)
                _closingDate = value
                OnPropertyChanged()
                _closingDateText = value.ToString("dd/MM/yyyy")
                OnPropertyChanged(NameOf(ClosingDateText))
                PreviewNetProfit()
            End Set
        End Property

        Private _closingDateText As String = New Date(Now.Year, 12, 31).ToString("dd/MM/yyyy")
        Public Property ClosingDateText As String
            Get
                Return _closingDateText
            End Get
            Set(value As String)
                _closingDateText = If(value, "")
                OnPropertyChanged(NameOf(ClosingDateText))
            End Set
        End Property

        Private _netProfitPreview As Decimal = 0
        Public Property NetProfitPreview As Decimal
            Get
                Return _netProfitPreview
            End Get
            Set(value As Decimal)
                _netProfitPreview = value
                OnPropertyChanged()
            End Set
        End Property

        Private _netProfitLabel As String = "صافي الربح"
        Public Property NetProfitLabel As String
            Get
                Return _netProfitLabel
            End Get
            Set(value As String)
                _netProfitLabel = value
                OnPropertyChanged()
            End Set
        End Property

        Private _retainedEarningsAccountID As Integer = 0
        Public Property RetainedEarningsAccountID As Integer
            Get
                Return _retainedEarningsAccountID
            End Get
            Set(value As Integer)
                _retainedEarningsAccountID = value
                OnPropertyChanged()
            End Set
        End Property

        Private _isLoading As Boolean = False
        Public Property IsLoading As Boolean
            Get
                Return _isLoading
            End Get
            Set(value As Boolean)
                _isLoading = value
                OnPropertyChanged()
            End Set
        End Property

        Private _statusMessage As String = ""
        Public Property StatusMessage As String
            Get
                Return _statusMessage
            End Get
            Set(value As String)
                _statusMessage = value
                OnPropertyChanged()
            End Set
        End Property

        ' === Commands ===
        Public Property CloseYearCommand As RelayCommand

        Public Sub New()
            CloseYearCommand = New RelayCommand(AddressOf ExecuteCloseYear, AddressOf CanCloseYear)
            
            ' Initial load
            LoadRetainedEarningsAccount()
            PreviewNetProfit()
        End Sub

        Private Sub LoadRetainedEarningsAccount()
            Try
                ' Find the retained earnings account by code '31' as previously set in the Initial Accounts SP
                Dim accounts = _accountingService.GetAllAccounts()
                Dim reAcc = accounts.FirstOrDefault(Function(a) a.AccountCode = "311")
                If reAcc IsNot Nothing Then
                    RetainedEarningsAccountID = reAcc.AccountID
                    StatusMessage = "حساب الإقفال: " & reAcc.AccountName
                Else
                    StatusMessage = "تنبيه: الرجاء تهيئة الحسابات الذكية أولاً لإنشاء حساب 'أرباح وخسائر مبقاة'"
                End If
            Catch ex As Exception
                StatusMessage = "حدث خطأ أثناء تحميل الحسابات"
            End Try
        End Sub

        Private Sub PreviewNetProfit()
            Try
                ' Preview net profit using the ProfitLoss procedure (from the beginning of time up to the closing date)
                Dim report = _accountingService.GetProfitLoss(New Date(1900, 1, 1), ClosingDate, 0)
                
                Dim totalRev = report.Items.Where(Function(i) i.AccountType = "Revenue").Sum(Function(i) i.Balance)
                Dim totalExp = report.Items.Where(Function(i) i.AccountType = "Expenses").Sum(Function(i) i.Balance)
                
                ' Formula requested by user:
                Dim netProfit = totalRev + totalExp
                NetProfitPreview = netProfit

                If netProfit < 0 Then
                    NetProfitLabel = "صافي الربح المتوقع:"
                Else
                    NetProfitLabel = "صافي الخسارة المتوقعة:"
                End If
            Catch ex As Exception
                NetProfitPreview = 0
                NetProfitLabel = "غير قادر على حساب النتيجة:"
            End Try
        End Sub

        Private Function CanCloseYear(obj As Object) As Boolean
            Return RetainedEarningsAccountID > 0 AndAlso Not IsLoading
        End Function

        Private Sub ExecuteCloseYear(obj As Object)
            ' Validation and Warning
            Dim confirmResult = MessageBox.Show(
                "تحذير: هذه العملية ستقوم بإقفال حسابات الإيرادات والمصروفات حتى تاريخ " & ClosingDate.ToString("yyyy/MM/dd") & " ولن يمكنك التراجع عن هذا السند! هل تريد الاستمرار؟",
                "تأكيد الإقفال السنوي", MessageBoxButton.YesNo, MessageBoxImage.Warning)

            If confirmResult <> MessageBoxResult.Yes Then Return

            Try
                IsLoading = True
                
                ' For standard execution, UserID = 1 (can be attached to identity later)
                Dim result = _accountingService.CloseFiscalYear(ClosingDate, RetainedEarningsAccountID, 1)
                
                If result.ResultID > 0 Then
                    MessageBox.Show(result.ResultMsg & vbCrLf & "رقم القيد العام: " & result.EntryNo & vbCrLf & "رقم قيد الإقفال: " & result.ResultID,
                                    "نجاح عملية الإقفال", MessageBoxButton.OK, MessageBoxImage.Information)
                    StatusMessage = "تم إقفال السنة بنجاح."
                    
                    ' Refresh preview (Should now be 0)
                    PreviewNetProfit()
                Else
                    MessageBox.Show(result.ResultMsg, "نتيجة الإقفال", MessageBoxButton.OK, MessageBoxImage.Asterisk)
                End If

            Catch ex As Exception
                MessageBox.Show("خطأ غير متوقع أثناء عملية الإقفال: " & ex.Message, "حطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            Finally
                IsLoading = False
            End Try
        End Sub
    End Class
End Namespace
