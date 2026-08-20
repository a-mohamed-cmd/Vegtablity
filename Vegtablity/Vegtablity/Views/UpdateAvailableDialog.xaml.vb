Imports System.Windows
Imports Vegtablity.Services

Namespace Views
    Public Class UpdateAvailableDialog
        Private ReadOnly _updateInfo As UpdateInfo
        Private ReadOnly _updateService As AutoUpdateService

        Public Sub New(updateInfo As UpdateInfo, updateService As AutoUpdateService)
            InitializeComponent()
            _updateInfo = updateInfo
            _updateService = updateService

            TxtVersionInfo.Text = $"الإصدار الحالي: {_updateInfo.CurrentVersion}  ←  الإصدار الجديد: {_updateInfo.LatestVersion}"
            TxtReleaseNotes.Text = If(String.IsNullOrWhiteSpace(_updateInfo.ReleaseNotes), "تحسينات عامة وإصلاحات في الأداء.", _updateInfo.ReleaseNotes)

            If _updateInfo.IsMandatory Then
                BtnLater.Visibility = Visibility.Collapsed
            End If
        End Sub

        Private Async Sub BtnUpdateNow_Click(sender As Object, e As RoutedEventArgs)
            BtnUpdateNow.IsEnabled = False
            BtnLater.IsEnabled = False
            PnlProgress.Visibility = Visibility.Visible

            Dim success As Boolean = Await _updateService.DownloadAndInstallAsync(_updateInfo, Sub(percent)
                Dispatcher.Invoke(Sub()
                    PrgDownload.Value = percent
                    TxtProgressPercent.Text = $"{percent}%"
                End Sub)
            End Sub)

            If Not success Then
                MessageBox.Show("فشل تنزيل ملف التحديث. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.", "خطأ في التحديث", MessageBoxButton.OK, MessageBoxImage.Error)
                BtnUpdateNow.IsEnabled = True
                BtnLater.IsEnabled = True
                PnlProgress.Visibility = Visibility.Collapsed
            End If
        End Sub

        Private Sub BtnLater_Click(sender As Object, e As RoutedEventArgs)
            Me.Close()
        End Sub
    End Class
End Namespace
