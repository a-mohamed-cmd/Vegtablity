Imports System.Windows
Imports System.Windows.Input

Namespace ViewModels
    Public Class LicenseViewModel
        Inherits BaseViewModel

        Private _licenseService As Services.LicenseService
        Private _hardwareID As String
        Private _statusMessage As String
        Private _isLicensed As Boolean

        Public Sub New()
            Try
                _licenseService = New Services.LicenseService()
                HardwareID = _licenseService.GetHardwareID()
            Catch ex As Exception
                StatusMessage = "خطأ في الاتصال بقاعدة البيانات: " & ex.Message
                _isLicensed = False
            End Try
        End Sub

        Public Property HardwareID As String
            Get
                Return _hardwareID
            End Get
            Set(value As String)
                SetProperty(_hardwareID, value)
            End Set
        End Property

        Public Property StatusMessage As String
            Get
                Return _statusMessage
            End Get
            Set(value As String)
                SetProperty(_statusMessage, value)
            End Set
        End Property

        Public ReadOnly Property CopyCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf CopyHardwareID)
            End Get
        End Property

        Public ReadOnly Property ExitCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExitApplication)
            End Get
        End Property

        Public ReadOnly Property RefreshCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf CheckLicense)
            End Get
        End Property

        Private Sub CopyHardwareID(obj As Object)
            If Not String.IsNullOrEmpty(HardwareID) Then
                Clipboard.SetText(HardwareID)
                StatusMessage = "تم نسخ كود الجهاز إلى الحافظة."
            Else
                StatusMessage = "لم يتم توليد كود الجهاز بعد."
            End If
        End Sub

        Private Sub ExitApplication(obj As Object)
            Application.Current.Shutdown()
        End Sub

        Public Sub CheckLicense(Optional obj As Object = Nothing)
            If _licenseService Is Nothing Then Return ' Safety check
            _isLicensed = _licenseService.IsLicensed(HardwareID)

            If _isLicensed Then
                StatusMessage = "تم التحقق من الترخيص بنجاح. جاري تشغيل النظام..."
                ' Navigate to Login Window
                Dim loginWin As New Views.LoginWindow()
                loginWin.Show()
                If Application.Current.MainWindow IsNot Nothing AndAlso Application.Current.MainWindow IsNot loginWin Then
                    Application.Current.MainWindow.Close()
                End If
            Else
                StatusMessage = "هذا الجهاز غير مرخص. يرجى تزويد المسؤول بكود الجهاز أعلاه."
            End If
        End Sub
    End Class
End Namespace
