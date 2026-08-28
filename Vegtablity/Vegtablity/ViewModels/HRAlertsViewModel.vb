Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Diagnostics
Imports System.Linq
Imports System.Windows
Imports System.Windows.Input
Imports Vegtablity.Helpers
Imports Vegtablity.Models.HR
Imports Vegtablity.Services

Namespace ViewModels
    Public Class HRAlertsViewModel
        Inherits BaseViewModel

        Private ReadOnly _hrService As New HRService()
        Private ReadOnly _allAlerts As New List(Of HRAlertItem)()

        Public Property Alerts As ObservableCollection(Of HRAlertItem)

        Private _searchText As String = String.Empty
        Public Property SearchText As String
            Get
                Return _searchText
            End Get
            Set(value As String)
                If SetProperty(_searchText, value) Then
                    ApplyFilter()
                End If
            End Set
        End Property

        Private _selectedFilter As String = "All" ' All, Expired, ExpiringSoon
        Public Property SelectedFilter As String
            Get
                Return _selectedFilter
            End Get
            Set(value As String)
                If SetProperty(_selectedFilter, value) Then
                    ApplyFilter()
                End If
            End Set
        End Property

        Private _expiredCount As Integer = 0
        Public Property ExpiredCount As Integer
            Get
                Return _expiredCount
            End Get
            Set(value As Integer)
                SetProperty(_expiredCount, value)
            End Set
        End Property

        Private _expiringSoonCount As Integer = 0
        Public Property ExpiringSoonCount As Integer
            Get
                Return _expiringSoonCount
            End Get
            Set(value As Integer)
                SetProperty(_expiringSoonCount, value)
            End Set
        End Property

        Private _totalAlertsCount As Integer = 0
        Public Property TotalAlertsCount As Integer
            Get
                Return _totalAlertsCount
            End Get
            Set(value As Integer)
                SetProperty(_totalAlertsCount, value)
            End Set
        End Property

        Private _filteredCount As Integer = 0
        Public Property FilteredCount As Integer
            Get
                Return _filteredCount
            End Get
            Set(value As Integer)
                SetProperty(_filteredCount, value)
            End Set
        End Property

        Public Property RefreshCommand As ICommand
        Public Property SendReminderCommand As ICommand
        Public Property SetFilterCommand As ICommand

        Public Sub New()
            Alerts = New ObservableCollection(Of HRAlertItem)()
            RefreshCommand = New RelayCommand(Sub() LoadAlerts())
            SendReminderCommand = New RelayCommand(AddressOf SendReminder)
            SetFilterCommand = New RelayCommand(AddressOf ExecuteSetFilter)

            LoadPermissions("HRAlerts")
            LoadAlerts()
        End Sub

        Public Sub LoadAlerts()
            Try
                Dim list = _hrService.GetActiveAlerts()
                _allAlerts.Clear()
                If list IsNot Nothing Then
                    _allAlerts.AddRange(list)
                End If

                ExpiredCount = _allAlerts.Where(Function(a) a.AlertStatus = "Expired").Count()
                ExpiringSoonCount = _allAlerts.Where(Function(a) a.AlertStatus = "ExpiringSoon").Count()
                TotalAlertsCount = _allAlerts.Count

                ApplyFilter()
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء فحص تنبيهات الوثائق: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

        Private Sub ExecuteSetFilter(parameter As Object)
            Dim filterName = TryCast(parameter, String)
            If Not String.IsNullOrWhiteSpace(filterName) Then
                SelectedFilter = filterName
            End If
        End Sub

        Private Sub ApplyFilter()
            Dim query = _allAlerts.AsEnumerable()

            ' 1. Filter by Status
            If SelectedFilter = "Expired" Then
                query = query.Where(Function(a) a.AlertStatus = "Expired")
            ElseIf SelectedFilter = "ExpiringSoon" Then
                query = query.Where(Function(a) a.AlertStatus = "ExpiringSoon")
            End If

            ' 2. Filter by Search Query
            If Not String.IsNullOrWhiteSpace(SearchText) Then
                Dim term = SearchText.Trim().ToLower()
                query = query.Where(Function(a) _
                    (If(a.EmployeeName, "").ToLower().Contains(term)) OrElse
                    (If(a.EmployeeCode, "").ToLower().Contains(term)) OrElse
                    (If(a.Department, "").ToLower().Contains(term)) OrElse
                    (If(a.FieldNameAr, "").ToLower().Contains(term))
                )
            End If

            Dim filteredList = query.ToList()
            Alerts.Clear()
            For Each item In filteredList
                Alerts.Add(item)
            Next
            FilteredCount = Alerts.Count
        End Sub

        Private Sub SendReminder(parameter As Object)
            Dim item = TryCast(parameter, HRAlertItem)
            If item Is Nothing Then Return

            Dim statusLine As String
            If item.AlertStatus = "Expired" Then
                statusLine = $"⚠️ حالة الوثيقة: منتهية منذ {Math.Abs(item.DaysRemaining)} يوم."
            Else
                statusLine = $"⏳ المهلة المتبقية: تنتهي خلال {item.DaysRemaining} يوم."
            End If

            Dim msg = $"📢 *تذكير إداري بتجديد وثيقة رسمية*" & vbCrLf &
                      $"👤 الموظف: {item.EmployeeName} ({item.EmployeeCode})" & vbCrLf &
                      $"🏢 القسم: {If(String.IsNullOrWhiteSpace(item.Department), "عام", item.Department)}" & vbCrLf &
                      $"📄 الوثيقة: {item.FieldNameAr}" & vbCrLf &
                      $"📅 تاريخ الانتهاء: {item.ExpiryDate:yyyy/MM/dd}" & vbCrLf &
                      $"{statusLine}" & vbCrLf &
                      $"----------------------------------" & vbCrLf &
                      $"يرجى التكرم بمراجعة إدارة الموارد البشرية لتسليم المستندات المطلوبة للتجديد وتفادي أي غرامات أو توقف بالعمل." & vbCrLf &
                      $"مع خالص التحية والتقدير."

            Try
                ' 1. نسخ النص إلى الحافظة تلقائياً للاحتياط
                Clipboard.SetText(msg)

                Dim encodedText = Uri.EscapeDataString(msg)
                Dim appUrl = $"whatsapp://send?text={encodedText}"
                Dim webUrl = $"https://web.whatsapp.com/send?text={encodedText}"

                ' 2. فحص وجود تطبيق WhatsApp للكمبيوتر أولاً
                Dim isAppInstalled As Boolean = False
                Try
                    Using key = Microsoft.Win32.Registry.ClassesRoot.OpenSubKey("whatsapp")
                        If key IsNot Nothing Then
                            isAppInstalled = True
                        End If
                    End Using
                Catch
                End Try

                Dim launchedDesktop As Boolean = False
                If isAppInstalled Then
                    Try
                        Process.Start(New ProcessStartInfo(appUrl) With {.UseShellExecute = True})
                        launchedDesktop = True
                    Catch
                        launchedDesktop = False
                    End Try
                End If

                ' 3. في حال عدم وجود التطبيق أو تعذر فتحه، فتح موقع WhatsApp Web في المتصفح
                If Not launchedDesktop Then
                    Try
                        Process.Start(New ProcessStartInfo(webUrl) With {.UseShellExecute = True})
                    Catch exWeb As Exception
                        MessageBox.Show($"تم نسخ رسالة التذكير للموظف '{item.EmployeeName}' إلى الحافظة بنجاح.", "إشعار وتذكير", MessageBoxButton.OK, MessageBoxImage.Information)
                    End Try
                End If
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء تجهيز إشعار واتساب: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Warning)
            End Try
        End Sub
    End Class
End Namespace


