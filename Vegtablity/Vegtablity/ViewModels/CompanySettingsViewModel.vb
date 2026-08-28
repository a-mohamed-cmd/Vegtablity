Imports Vegtablity.Models
Imports Vegtablity.Services
Imports Vegtablity.Helpers
Imports Microsoft.Win32
Imports System.IO

Namespace ViewModels
    Public Class CompanySettingsViewModel
        Inherits BaseViewModel

        Private ReadOnly _settingsService As New SettingsService()

        ' === Properties ===
        
        Private _companyName As String
        Public Property CompanyName As String
            Get
                Return _companyName
            End Get
            Set(value As String)
                _companyName = value
                OnPropertyChanged()
            End Set
        End Property

        Private _address As String
        Public Property Address As String
            Get
                Return _address
            End Get
            Set(value As String)
                _address = value
                OnPropertyChanged()
            End Set
        End Property

        Private _phone As String
        Public Property Phone As String
            Get
                Return _phone
            End Get
            Set(value As String)
                _phone = value
                OnPropertyChanged()
            End Set
        End Property

        Private _email As String
        Public Property Email As String
            Get
                Return _email
            End Get
            Set(value As String)
                _email = value
                OnPropertyChanged()
            End Set
        End Property

        Private _logo As Byte()
        Public Property Logo As Byte()
            Get
                Return _logo
            End Get
            Set(value As Byte())
                _logo = value
                OnPropertyChanged()
            End Set
        End Property

        Private _currencySymbol As String
        Public Property CurrencySymbol As String
            Get
                Return _currencySymbol
            End Get
            Set(value As String)
                _currencySymbol = value
                OnPropertyChanged()
            End Set
        End Property

        Private _enableHR As Boolean
        Public Property EnableHR As Boolean
            Get
                Return _enableHR
            End Get
            Set(value As Boolean)
                _enableHR = value
                OnPropertyChanged()
            End Set
        End Property

        Private _currentCompanyInfo As CompanyInfo

        ' === Commands ===
        Public Property SaveCommand As RelayCommand
        Public Property SelectLogoCommand As RelayCommand

        Public Sub New()
            LoadSettings()
            SaveCommand = New RelayCommand(AddressOf ExecuteSave)
            SelectLogoCommand = New RelayCommand(AddressOf ExecuteSelectLogo)
        End Sub

        Private Sub LoadSettings()
            Try
                _currentCompanyInfo = _settingsService.GetCompanyInfo()
                If _currentCompanyInfo IsNot Nothing Then
                    CompanyName = _currentCompanyInfo.CompanyName
                    Address = _currentCompanyInfo.Address
                    Phone = _currentCompanyInfo.Phone
                    Email = _currentCompanyInfo.Email
                    Logo = _currentCompanyInfo.Logo
                    CurrencySymbol = _currentCompanyInfo.CurrencySymbol
                    EnableHR = _currentCompanyInfo.EnableHR
                End If
            Catch ex As Exception
                ' Error handling
            End Try
        End Sub

        Private Sub ExecuteSelectLogo(obj As Object)
            Dim dlg As New OpenFileDialog()
            dlg.Filter = "Image Files|*.jpg;*.jpeg;*.png;*.bmp"
            If dlg.ShowDialog() = True Then
                Logo = File.ReadAllBytes(dlg.FileName)
            End If
        End Sub

        Private Sub ExecuteSave(obj As Object)
            Try
                Dim info As New CompanyInfo() With {
                    .CompanyName = CompanyName,
                    .Address = Address,
                    .Phone = Phone,
                    .Email = Email,
                    .Logo = Logo,
                    .CurrencySymbol = CurrencySymbol,
                    .UnifiedPartnerSearch = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.UnifiedPartnerSearch, True),
                    .UseDetailedInvoiceDesign = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.UseDetailedInvoiceDesign, False),
                    .UseCustomInvoiceDesign = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.UseCustomInvoiceDesign, False),
                    .ProductionMode = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.ProductionMode, False),
                    .EnableDailyOrders = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.EnableDailyOrders, False),
                    .DeliverySystemMode = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.DeliverySystemMode, Nothing),
                    .EnableSalesDiscounts = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.EnableSalesDiscounts, False),
                    .EnableHR = If(_currentCompanyInfo IsNot Nothing, _currentCompanyInfo.EnableHR, False)
                }
                _settingsService.SaveCompanyInfo(info)

                MessageBox.Show("تم حفظ الإعدادات بنجاح", "نجاح", MessageBoxButton.OK, MessageBoxImage.Information)
            Catch ex As Exception
                MessageBox.Show("خطأ أثناء الحفظ: " & ex.Message, "خطأ", MessageBoxButton.OK, MessageBoxImage.Error)
            End Try
        End Sub

    End Class
End Namespace
