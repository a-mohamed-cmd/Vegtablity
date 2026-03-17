Imports System.IO
Imports System.Windows
Imports System.Windows.Controls
Imports System.Windows.Media
Imports Microsoft.Win32

Namespace Views
    Public Class DbUpdaterPage
        Inherits UserControl

        Private ReadOnly _dbHelper As New Services.DatabaseHelper()
        Private _selectedFilePath As String = ""

        Public Sub New()
            InitializeComponent()
        End Sub

        Private Sub BtnBrowse_Click(sender As Object, e As RoutedEventArgs)
            Dim dlg As New OpenFileDialog()
            dlg.Filter = "ملفات SQL (*.sql)|*.sql"
            dlg.Title = "اختر ملف التحديث"
            
            If dlg.ShowDialog() = True Then
                _selectedFilePath = dlg.FileName
                txtFilePath.Text = Path.GetFileName(_selectedFilePath)
                
                ' Reset feedback
                brdStatus.Visibility = Visibility.Collapsed
                btnExecute.IsEnabled = True
            End If
        End Sub

        Private Async Sub BtnExecute_Click(sender As Object, e As RoutedEventArgs)
            If String.IsNullOrWhiteSpace(_selectedFilePath) OrElse Not File.Exists(_selectedFilePath) Then
                ShowStatus("الرجاء اختيار ملف SQL صحيح أولاً", False)
                Return
            End If

            ' Confirm with user
            Dim result = MessageBox.Show($"هل أنت متأكد من تنفيذ السكربت المسمى '{Path.GetFileName(_selectedFilePath)}'؟" & vbCrLf & "هذا الإجراء قد يؤثر على هيكل البيانات ولا يمكن التراجع عنه بسهولة.",
                                         "تأكيد التنفيذ", MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning)
            
            If result = MessageBoxResult.No Then Return

            ' Execute
            Try
                btnExecute.IsEnabled = False
                btnExecute.Content = "جاري التنفيذ... ⏳"
                ShowStatus("جاري تطبيق التحديثات على قاعدة البيانات، يرجى الانتظار...", True, True)

                ' Ensure we don't freeze the UI 
                Dim scriptContent As String = Await System.Threading.Tasks.Task.Run(Function() File.ReadAllText(_selectedFilePath))
                
                Await System.Threading.Tasks.Task.Run(Sub()
                                                          _dbHelper.ExecuteSqlScript(scriptContent)
                                                      End Sub)
                                                      
                ShowStatus("تم تنفيذ السكربت وتحديث قاعدة البيانات بنجاح! 🎉", True)
                btnExecute.Content = "تم التحديث"
                
            Catch ex As Exception
                ShowStatus($"فشل التنفيذ: {ex.Message}", False)
                btnExecute.IsEnabled = True
                btnExecute.Content = "تنفيذ التحديث الآن 🚀"
            End Try
        End Sub

        Private Sub ShowStatus(message As String, isSuccess As Boolean, Optional isPending As Boolean = False)
            brdStatus.Visibility = Visibility.Visible
            txtStatusMsg.Text = message
            
            If isPending Then
                brdStatus.Background = New SolidColorBrush(Color.FromRgb(245, 158, 11)) ' Amber
                txtStatusIcon.Text = "⏳"
            ElseIf isSuccess Then
                brdStatus.Background = New SolidColorBrush(Color.FromRgb(16, 185, 129)) ' Emerald
                txtStatusIcon.Text = "✅"
            Else
                brdStatus.Background = New SolidColorBrush(Color.FromRgb(239, 68, 68)) ' Red
                txtStatusIcon.Text = "❌"
            End If
        End Sub

    End Class
End Namespace
