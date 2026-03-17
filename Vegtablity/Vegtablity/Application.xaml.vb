Class Application
    Protected Overrides Sub OnStartup(e As StartupEventArgs)
        MyBase.OnStartup(e)

        Try
            ' Create license service to check status quietly
            Dim licenseService As New Services.LicenseService()
            Dim hwid As String = licenseService.GetHardwareID()
            
            If licenseService.IsLicensed(hwid) Then
                ' License is valid, show LoginWindow directly
                Dim loginWin As New Views.LoginWindow()
                ' Set as MainWindow
                Me.MainWindow = loginWin
                loginWin.Show()
            Else
                ' License is invalid, show LicenseWindow
                Dim licenseWin As New Views.LicenseWindow()
                Me.MainWindow = licenseWin
                licenseWin.Show()
            End If
        Catch ex As Exception
            ' If something goes wrong, fallback to LicenseWindow
            Dim licenseWin As New Views.LicenseWindow()
            Me.MainWindow = licenseWin
            licenseWin.Show()
        End Try
    End Sub
End Class
