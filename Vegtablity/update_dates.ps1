$viewsDir = "D:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\Views"
$files = @(
    "SalesInvoicePage", "PurchaseInvoicePage", "QuotePage", 
    "BalanceSheetPage", "AccountStatementPage", "JournalEntryPage", 
    "PaymentVoucherPage", "ProfitLossPage", "ReceiptVoucherPage", 
    "ReportsPage", "VouchersPage", "TrialBalancePage"
)

$previewKeyDownCode = @"

        Private Sub Date_PreviewKeyDown(sender As Object, e As KeyEventArgs)
            If e.Key = Key.Enter Then
                e.Handled = True
                Dim tb = TryCast(sender, TextBox)
                If tb IsNot Nothing Then
                    Dim request As New TraversalRequest(FocusNavigationDirection.Next)
                    tb.MoveFocus(request)
                End If
            End If
        End Sub
"@

foreach ($f in $files) {
    # --- Update XAML ---
    $xamlPath = Join-Path $viewsDir "$f.xaml"
    if (Test-Path $xamlPath) {
        $content = [IO.File]::ReadAllText($xamlPath)
        
        # Regex to find LostFocus attributes for dates
        $regex = [regex]'(LostFocus="(InvDate|QuoteDate|ExpiryDate|Date|StartDate|EndDate|PaymentDate|ReceiptDate)_LostFocus")'
        $matches = $regex.Matches($content)
        $modified = $false
        
        foreach ($m in $matches) {
            $startIdx = [Math]::Max(0, $m.Index - 100)
            $snippet = $content.Substring($startIdx, [Math]::Min(200, $content.Length - $startIdx))
            if (-not $snippet.Contains('PreviewKeyDown="Date_PreviewKeyDown"')) {
                $content = $content.Replace($m.Value, $m.Value + ' PreviewKeyDown="Date_PreviewKeyDown"')
                $modified = $true
            }
        }
        
        if ($modified) {
            [IO.File]::WriteAllText($xamlPath, $content, [System.Text.Encoding]::UTF8)
            Write-Host "Updated XAML: $f"
        }
    }
    
    # --- Update Code-Behind ---
    $vbPath = Join-Path $viewsDir "$f.xaml.vb"
    if (Test-Path $vbPath) {
        $content = [IO.File]::ReadAllText($vbPath)
        if (-not $content.Contains("Date_PreviewKeyDown")) {
            $idx = $content.LastIndexOf("End Class")
            if ($idx -gt -1) {
                $content = $content.Insert($idx, $previewKeyDownCode)
                [IO.File]::WriteAllText($vbPath, $content, [System.Text.Encoding]::UTF8)
                Write-Host "Updated VB: $f"
            }
        }
    }
}
