[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
$srv = New-Object Microsoft.SqlServer.Management.Smo.Server("192.168.43.129\SQLEXPRESS")
$srv.ConnectionContext.LoginSecure = $false
$srv.ConnectionContext.Login = "Mohamed"
$srv.ConnectionContext.Password = "125630"
$db = $srv.Databases["VegtablityDB"]

if ($db -eq $null) {
    Write-Host "Database VegtablityDB not found!"
    exit 1
}

$scrp = New-Object Microsoft.SqlServer.Management.Smo.Scripter($srv)
$scrp.Options.ScriptSchema = $true
$scrp.Options.ScriptData = $false
$scrp.Options.IncludeIfNotExists = $true
$scrp.Options.ScriptDrops = $false
$scrp.Options.Indexes = $true
$scrp.Options.Triggers = $true
$scrp.Options.Permissions = $false
$scrp.Options.ExtendedProperties = $false
$scrp.Options.ToFileOnly = $true
$scrp.Options.FileName = "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\FullSchema_fromDB.sql"
$scrp.Options.AppendToFile = $true

if (Test-Path "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\FullSchema_fromDB.sql") {
    Remove-Item "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\FullSchema_fromDB.sql"
}

foreach ($table in $db.Tables) { if (!$table.IsSystemObject) { $scrp.Script($table) } }
foreach ($view in $db.Views) { if (!$view.IsSystemObject) { $scrp.Script($view) } }
foreach ($sp in $db.StoredProcedures) { if (!$sp.IsSystemObject) { $scrp.Script($sp) } }
Write-Host "Done scripting schema!"
