Imports System
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media
Imports Vegtablity.Models.HR
Imports Vegtablity.ViewModels

Namespace Controls
    Partial Public Class DocumentAlertRowControl
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
            Dim item = TryCast(Me.DataContext, HRAlertItem)
            If item Is Nothing OrElse StatusBadge Is Nothing Then Return

            Select Case item.AlertStatus
                Case "Expired"
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(239, 68, 68)) '#EF4444
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(254, 242, 242)) '#FEF2F2
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(254, 202, 202)) '#FECACA
                    StatusBadge.BorderThickness = New Thickness(1)
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(220, 38, 38)) '#DC2626
                    StatusIconText.Text = "🔴"

                Case "ExpiringSoon"
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(245, 158, 11)) '#F59E0B
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(255, 251, 235)) '#FFFBEB
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(253, 230, 138)) '#FDE68A
                    StatusBadge.BorderThickness = New Thickness(1)
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(217, 119, 6)) '#D97706
                    StatusIconText.Text = "⏳"

                Case Else
                    StatusStrip.Background = New SolidColorBrush(Color.FromRgb(16, 185, 129)) '#10B981
                    StatusBadge.Background = New SolidColorBrush(Color.FromRgb(236, 253, 245)) '#ECFDF5
                    StatusBadge.BorderBrush = New SolidColorBrush(Color.FromRgb(167, 243, 208)) '#A7F3D0
                    StatusBadge.BorderThickness = New Thickness(1)
                    StatusTextLabel.Foreground = New SolidColorBrush(Color.FromRgb(5, 150, 105)) '#059669
                    StatusIconText.Text = "✅"
            End Select
        End Sub

        Public Sub BtnWhatsApp_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, HRAlertItem)
            If item Is Nothing Then Return

            Dim vm = GetParentViewModel()
            If vm IsNot Nothing AndAlso vm.SendReminderCommand IsNot Nothing Then
                vm.SendReminderCommand.Execute(item)
            Else
                Dim msg = BuildReminderMessage(item)
                Try
                    Clipboard.SetText(msg)

                    Dim encodedText = Uri.EscapeDataString(msg)
                    Dim appUrl = $"whatsapp://send?text={encodedText}"
                    Dim webUrl = $"https://web.whatsapp.com/send?text={encodedText}"

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

                    If Not launchedDesktop Then
                        Try
                            Process.Start(New ProcessStartInfo(webUrl) With {.UseShellExecute = True})
                        Catch exWeb As Exception
                            MessageBox.Show($"تم نسخ رسالة التذكير للموظف '{item.EmployeeName}' إلى الحافظة بنجاح.", "إشعار واتساب", MessageBoxButton.OK, MessageBoxImage.Information)
                        End Try
                    End If
                Catch ex As Exception
                    Clipboard.SetText(msg)
                    MessageBox.Show("تم نسخ نص التذكير إلى الحافظة: " & ex.Message, "إشعار واتساب", MessageBoxButton.OK, MessageBoxImage.Information)
                End Try
            End If
        End Sub


        Public Sub BtnCopyText_Click(sender As Object, e As RoutedEventArgs)
            Dim item = TryCast(Me.DataContext, HRAlertItem)
            If item Is Nothing Then Return


            Dim msg = BuildReminderMessage(item)
            Try
                Clipboard.SetText(msg)
                MessageBox.Show($"تم نسخ رسالة التذكير للموظف '{item.EmployeeName}' بنجاح إلى الحافظة.", "نسخ التنبيه", MessageBoxButton.OK, MessageBoxImage.Information)
            Catch ex As Exception
                MessageBox.Show("تعذر نسخ النص إلى الحافظة: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Warning)
            End Try
        End Sub

        Private Function BuildReminderMessage(item As HRAlertItem) As String
            Dim statusLine As String
            If item.AlertStatus = "Expired" Then
                statusLine = $"⚠️ حالة الوثيقة: منتهية منذ {Math.Abs(item.DaysRemaining)} يوم."
            Else
                statusLine = $"⏳ المهلة المتبقية: تنتهي خلال {item.DaysRemaining} يوم."
            End If

            Return $"📢 *تذكير إداري بتجديد وثيقة رسمية*" & vbCrLf &
                   $"👤 الموظف: {item.EmployeeName} ({item.EmployeeCode})" & vbCrLf &
                   $"🏢 القسم: {If(String.IsNullOrWhiteSpace(item.Department), "عام", item.Department)}" & vbCrLf &
                   $"📄 الوثيقة: {item.FieldNameAr}" & vbCrLf &
                   $"📅 تاريخ الانتهاء: {item.ExpiryDate:yyyy/MM/dd}" & vbCrLf &
                   $"{statusLine}" & vbCrLf &
                   $"----------------------------------" & vbCrLf &
                   $"يرجى التكرم بمراجعة إدارة الموارد البشرية لتسليم المستندات المطلوبة للتجديد وتفادي أي غرامات أو توقف بالعمل." & vbCrLf &
                   $"مع خالص التحية والتقدير."
        End Function

        Private Function GetParentViewModel() As HRAlertsViewModel
            Dim parentListBox = FindVisualParent(Of ListBox)(Me)
            Dim vm = If(parentListBox IsNot Nothing, TryCast(parentListBox.DataContext, HRAlertsViewModel), Nothing)
            If vm Is Nothing Then
                Dim parentUc = FindVisualParent(Of UserControl)(Me)
                vm = If(parentUc IsNot Nothing, TryCast(parentUc.DataContext, HRAlertsViewModel), Nothing)
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
