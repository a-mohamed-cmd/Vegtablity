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
        Private _isChangePasswordMode As Boolean
        Private _changeUsername As String
        Private _changeUsernameError As String
        Private _changeOldPasswordError As String
        Private _changeNewPasswordError As String
        Private _changeConfirmPasswordError As String
        Private _changeErrorMessage As String
        Private _changeSuccessMessage As String

        Public Property IsChangePasswordMode As Boolean
            Get
                Return _isChangePasswordMode
            End Get
            Set(value As Boolean)
                SetProperty(_isChangePasswordMode, value)
            End Set
        End Property

        Public Property ChangeUsername As String
            Get
                Return _changeUsername
            End Get
            Set(value As String)
                SetProperty(_changeUsername, value)
                If Not String.IsNullOrEmpty(value) Then ChangeUsernameError = Nothing
            End Set
        End Property

        Public Property ChangeUsernameError As String
            Get
                Return _changeUsernameError
            End Get
            Set(value As String)
                SetProperty(_changeUsernameError, value)
            End Set
        End Property

        Public Property ChangeOldPasswordError As String
            Get
                Return _changeOldPasswordError
            End Get
            Set(value As String)
                SetProperty(_changeOldPasswordError, value)
            End Set
        End Property

        Public Property ChangeNewPasswordError As String
            Get
                Return _changeNewPasswordError
            End Get
            Set(value As String)
                SetProperty(_changeNewPasswordError, value)
            End Set
        End Property

        Public Property ChangeConfirmPasswordError As String
            Get
                Return _changeConfirmPasswordError
            End Get
            Set(value As String)
                SetProperty(_changeConfirmPasswordError, value)
            End Set
        End Property

        Public Property ChangeErrorMessage As String
            Get
                Return _changeErrorMessage
            End Get
            Set(value As String)
                SetProperty(_changeErrorMessage, value)
            End Set
        End Property

        Public Property ChangeSuccessMessage As String
            Get
                Return _changeSuccessMessage
            End Get
            Set(value As String)
                SetProperty(_changeSuccessMessage, value)
            End Set
        End Property

        Public ReadOnly Property SwitchToLoginCommand As ICommand
            Get
                Return New Helpers.RelayCommand(Sub(o)
                                                    ClearChangePasswordErrors()
                                                    ClearErrors()
                                                    IsChangePasswordMode = False
                                                End Sub)
            End Get
        End Property

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

        Public Event PasswordChangedSuccessfully As EventHandler

        Public Property IsProcessing As Boolean
            Get
                Return _isProcessing
            End Get
            Set(value As Boolean)
                SetProperty(_isProcessing, value)
                OnPropertyChanged(NameOf(IsNotProcessing))
            End Set
        End Property

        Public ReadOnly Property IsNotProcessing As Boolean
            Get
                Return Not _isProcessing
            End Get
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

        Private Sub ClearChangePasswordErrors()
            ChangeUsernameError = Nothing
            ChangeOldPasswordError = Nothing
            ChangeNewPasswordError = Nothing
            ChangeConfirmPasswordError = Nothing
            ChangeErrorMessage = Nothing
            ChangeSuccessMessage = Nothing
        End Sub

        Private Sub ExecuteForgotPassword(obj As Object)
            ClearChangePasswordErrors()
            ClearErrors()
            ChangeUsername = Username
            IsChangePasswordMode = True
        End Sub

        Public Sub ExecuteChangePassword(oldPassword As String, newPassword As String, confirmPassword As String)
            ClearChangePasswordErrors()

            Dim hasError As Boolean = False

            ' 1. اسم المستخدم
            Dim userReq As String = Helpers.ValidationHelper.IsRequired(ChangeUsername, "اسم المستخدم")
            If userReq IsNot Nothing Then
                ChangeUsernameError = userReq
                hasError = True
            Else
                Dim userMin As String = Helpers.ValidationHelper.MinLength(ChangeUsername, 3, "اسم المستخدم")
                If userMin IsNot Nothing Then
                    ChangeUsernameError = userMin
                    hasError = True
                End If
            End If

            ' 2. كلمة المرور القديمة
            Dim oldReq As String = Helpers.ValidationHelper.IsRequired(oldPassword, "كلمة المرور القديمة")
            If oldReq IsNot Nothing Then
                ChangeOldPasswordError = oldReq
                hasError = True
            End If

            ' 3. كلمة المرور الجديدة
            Dim newReq As String = Helpers.ValidationHelper.IsRequired(newPassword, "كلمة المرور الجديدة")
            If newReq IsNot Nothing Then
                ChangeNewPasswordError = newReq
                hasError = True
            Else
                Dim newMin As String = Helpers.ValidationHelper.MinLength(newPassword, 3, "كلمة المرور الجديدة")
                If newMin IsNot Nothing Then
                    ChangeNewPasswordError = newMin
                    hasError = True
                ElseIf newPassword = oldPassword Then
                    ChangeNewPasswordError = "يجب أن تكون كلمة المرور الجديدة مختلفة عن القديمة."
                    hasError = True
                End If
            End If

            ' 4. تأكيد كلمة المرور الجديدة
            Dim confReq As String = Helpers.ValidationHelper.IsRequired(confirmPassword, "تأكيد كلمة المرور")
            If confReq IsNot Nothing Then
                ChangeConfirmPasswordError = confReq
                hasError = True
            ElseIf confirmPassword <> newPassword Then
                ChangeConfirmPasswordError = "كلمة المرور وتأكيدها غير متطابقين."
                hasError = True
            End If

            If hasError Then Return

            IsProcessing = True

            Task.Run(Sub()
                         Try
                             Dim res = _userService.ChangePassword(ChangeUsername.Trim(), oldPassword, newPassword)

                             Application.Current.Dispatcher.Invoke(Sub()
                                                                       IsProcessing = False
                                                                       If res.Success Then
                                                                           ChangeSuccessMessage = res.Message
                                                                           Username = ChangeUsername
                                                                       Else
                                                                           ChangeErrorMessage = res.Message
                                                                       End If
                                                                   End Sub)
                         Catch ex As Exception
                             Application.Current.Dispatcher.Invoke(Sub()
                                                                       IsProcessing = False
                                                                       ChangeErrorMessage = "حدث خطأ أثناء تعديل كلمة المرور: " & ex.Message
                                                                   End Sub)
                         End Try
                     End Sub)
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
