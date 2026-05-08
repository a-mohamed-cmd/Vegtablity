import os
import re

views_dir = r"D:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\Views"
files = [
    "SalesInvoicePage", "PurchaseInvoicePage", "QuotePage", 
    "BalanceSheetPage", "AccountStatementPage", "JournalEntryPage", 
    "PaymentVoucherPage", "ProfitLossPage", "ReceiptVoucherPage", 
    "ReportsPage", "VouchersPage", "TrialBalancePage"
]

correct_code = """
        Private Sub Date_PreviewKeyDown(sender As Object, e As System.Windows.Input.KeyEventArgs)
            If e.Key = System.Windows.Input.Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, System.Windows.Controls.TextBox)
                If tb IsNot Nothing Then
                    Dim request As New System.Windows.Input.TraversalRequest(System.Windows.Input.FocusNavigationDirection.Next)
                    tb.MoveFocus(request)
                End If
            End If
        End Sub
"""

for f in files:
    vb_path = os.path.join(views_dir, f + ".xaml.vb")
    if os.path.exists(vb_path):
        with open(vb_path, "r", encoding="utf-8") as file:
            content = file.read()
        
        # Remove the previous faulty injected code
        pattern = re.compile(r'\s*Private Sub Date_PreviewKeyDown.*?End Sub(?:End Class)?', re.DOTALL)
        content = pattern.sub('\n    End Class', content)
        
        # Insert the correct code before the LAST "End Class"
        idx = content.rfind("End Class")
        if idx != -1:
            content = content[:idx] + correct_code + content[idx:]
            
        with open(vb_path, "w", encoding="utf-8", newline='') as file:
            file.write(content)
        print(f"Fixed {f}")
