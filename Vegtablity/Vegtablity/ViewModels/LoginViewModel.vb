Imports System.Windows
Imports System.Windows.Input
Imports System.Windows.Controls

Namespace ViewModels
    Public Class LoginViewModel
        Inherits BaseViewModel

        Private _userService As New Services.UserService()
        Private _username As String
        Private _errorMessage As String
        Private _usernameError As String
        Private _passwordError As String
        Private _isProcessing As Boolean

        Public Property Username As String
            Get
                Return _username
            End Get
            Set(value As String)
                SetProperty(_username, value)
                ' مسح خطأ الحقل عند الكتابة
                If Not String.IsNullOrEmpty(value) Then UsernameError = Nothing
            End Set
        End Property

        Public Property ErrorMessage As String
            Get
                Return _errorMessage
            End Get
            Set(value As String)
                SetProperty(_errorMessage, value)
            End Set
        End Property

        Public Property UsernameError As String
            Get
                Return _usernameError
            End Get
            Set(value As String)
                SetProperty(_usernameError, value)
            End Set
        End Property

        Public Property PasswordError As String
            Get
                Return _passwordError
            End Get
            Set(value As String)
                SetProperty(_passwordError, value)
            End Set
        End Property

        Public Property IsProcessing As Boolean
            Get
                Return _isProcessing
            End Get
            Set(value As Boolean)
                SetProperty(_isProcessing, value)
            End Set
        End Property

        Public ReadOnly Property LoginCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteLogin, Function(o) Not IsProcessing)
            End Get
        End Property

        Public ReadOnly Property ForgotPasswordCommand As ICommand
            Get
                Return New Helpers.RelayCommand(AddressOf ExecuteForgotPassword)
            End Get
        End Property

        Public ReadOnly Property ExitCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o) Application.Current.Shutdown())
            End Get
        End Property

        Private Sub ClearErrors()
            UsernameError = Nothing
            PasswordError = Nothing
            ErrorMessage = Nothing
        End Sub

        Private Sub ExecuteLogin(parameter As Object)
            ClearErrors()

            Dim passwordBox As PasswordBox = TryCast(parameter, PasswordBox)
            Dim password As String = If(passwordBox IsNot Nothing, passwordBox.Password, String.Empty)

            ' === Per-field validation ===
            Dim hasError As Boolean = False

            ' Username validation
            Dim userReq As String = Helpers.ValidationHelper.IsRequired(Username, "اسم المستخدم")
            If userReq IsNot Nothing Then
                UsernameError = userReq
                hasError = True
            Else
                Dim userMin As String = Helpers.ValidationHelper.MinLength(Username, 3, "اسم المستخدم")
                If userMin IsNot Nothing Then
                    UsernameError = userMin
                    hasError = True
                Else
                    Dim userMax As String = Helpers.ValidationHelper.MaxLength(Username, 50, "اسم المستخدم")
                    If userMax IsNot Nothing Then
                        UsernameError = userMax
                        hasError = True
                    End If
                End If
            End If

            ' Password validation
            Dim passReq As String = Helpers.ValidationHelper.IsRequired(password, "كلمة المرور")
            If passReq IsNot Nothing Then
                PasswordError = passReq
                hasError = True
            Else
                Dim passMin As String = Helpers.ValidationHelper.MinLength(password, 3, "كلمة المرور")
                If passMin IsNot Nothing Then
                    PasswordError = passMin
                    hasError = True
                End If
            End If

            If hasError Then Return

            IsProcessing = True

            Task.Run(Sub()
                         Try
                             Dim user = _userService.Login(Username, password)

                             Application.Current.Dispatcher.Invoke(Sub()
                                                                        IsProcessing = False
                                                                        If user IsNot Nothing Then
                                                                            If user.IsActive Then
                                                                                Services.Session.CurrentUser = user
                                                                                NavigateToMain()
                                                                            Else
                                                                                ErrorMessage = "هذا الحساب غير نشط. راجع المسؤول."
                                                                            End If
                                                                        Else
                                                                            ErrorMessage = "اسم المستخدم أو كلمة المرور غير صحيحة."
                                                                        End If
                                                                    End Sub)
                         Catch ex As Exception
                             Application.Current.Dispatcher.Invoke(Sub()
                                                                        IsProcessing = False
                                                                        ErrorMessage = "حدث خطأ أثناء الاتصال: " & ex.Message
                                                                    End Sub)
                         End Try
                     End Sub)
        End Sub

        Private Sub ExecuteForgotPassword(obj As Object)
            MessageBox.Show("يرجى التواصل مع مسؤول النظام لاستعادة كلمة المرور.", "نسيت كلمة المرور", MessageBoxButton.OK, MessageBoxImage.Information)
        End Sub

        Private Sub NavigateToMain()
            Dim dashWin As New Views.DashboardWindow()
            dashWin.Show()
            
            For Each win As Window In Application.Current.Windows
                If TypeOf win Is Views.LoginWindow Then
                    win.Close()
                    Exit For
                End If
            Next
        End Sub
    End Class
End Namespace
