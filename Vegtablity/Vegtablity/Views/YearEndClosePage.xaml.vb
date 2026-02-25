Imports System.Windows.Controls
Imports Vegtablity.ViewModels

Namespace Views
    Public Class YearEndClosePage
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
            Me.DataContext = New YearEndCloseViewModel()
        End Sub
    End Class
End Namespace
