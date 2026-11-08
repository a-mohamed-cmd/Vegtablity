Imports System.Windows.Controls

Namespace Controls
    ''' <summary>
    ''' UserControl مخصص لعرض تقرير أعمار الديون للعملاء من واقع جدول القيود المحاسبية [Accounting].[JournalEntries]
    ''' يعرض بطاقات تفصيلية لكل عميل مقسمة حسب الفترات العمرية (0-30، 31-60، 61-90، +90 يوم) للفواتير والسداد في نفس الفترة بدلاً من DataGrid
    ''' </summary>
    Partial Public Class JournalDebtAgingControl
        Inherits UserControl

        Public Sub New()
            InitializeComponent()
        End Sub

        Public Sub ScrollToTop()
            If CardsScrollViewer IsNot Nothing Then
                CardsScrollViewer.ScrollToTop()
            End If
        End Sub
    End Class
End Namespace

