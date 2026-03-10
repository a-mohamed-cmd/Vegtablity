$sqlFile = "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql"
$fileContent = (Get-Content $sqlFile -Raw)

# 1. Count Tables in File based on CREATE TABLE
$tableMatches = [regex]::Matches($fileContent, 'CREATE\s+TABLE\s+\[?([a-zA-Z0-9_]+)\]?\.\[?([a-zA-Z0-9_]+)\]?', 'IgnoreCase')
$tablesInFile = @()
foreach ($m in $tableMatches) {
    # Schema.Table
    $tablesInFile += ($m.Groups[1].Value + "." + $m.Groups[2].Value).ToLower()
}
$tablesInFile = $tablesInFile | Select-Object -Unique

# 2. Count Procedures/Triggers/Views in File
$modMatches = [regex]::Matches($fileContent, 'CREATE\s+(PROCEDURE|TRIGGER|VIEW)\s+\[?([a-zA-Z0-9_]+)\]?\.\[?([a-zA-Z0-9_]+)\]?', 'IgnoreCase')
$modsInFile = @()
foreach ($m in $modMatches) {
    $modsInFile += ($m.Groups[2].Value + "." + $m.Groups[3].Value).ToLower()
}
$modsInFile = $modsInFile | Select-Object -Unique

# 3. Connect to DB and Count
$connString = "Data Source=192.168.43.129\SQLEXPRESS;Initial Catalog=VegtablityDB;User ID=Mohamed;Password=125630;TrustServerCertificate=True"
$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.Open()

# Tables
$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT s.name AS s_name, t.name AS t_name FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.is_ms_shipped = 0"
$reader = $cmd.ExecuteReader()
$dbTables = @()
while ($reader.Read()) {
    $dbTables += ($reader["s_name"].ToString() + "." + $reader["t_name"].ToString()).ToLower()
}
$reader.Close()

# Modules
$cmd.CommandText = "SELECT s.name AS s_name, o.name AS o_name FROM sys.sql_modules m JOIN sys.objects o ON m.object_id = o.object_id JOIN sys.schemas s ON o.schema_id = s.schema_id WHERE o.is_ms_shipped = 0"
$reader = $cmd.ExecuteReader()
$dbMods = @()
while ($reader.Read()) {
    $dbMods += ($reader["s_name"].ToString() + "." + $reader["o_name"].ToString()).ToLower()
}
$reader.Close()
$conn.Close()

Write-Host "--- Summary ---"
Write-Host "Tables in DB: $($dbTables.Count)"
Write-Host "Tables in File: $($tablesInFile.Count)"
Write-Host "Modules (SP/Triggers/Views) in DB: $($dbMods.Count)"
Write-Host "Modules in File: $($modsInFile.Count)"

Write-Host "`n--- Missing Tables in File ---"
foreach ($tbl in $dbTables) {
    if ($tablesInFile -notcontains $tbl) {
        Write-Host "Missing Table: $tbl"
    }
}

Write-Host "`n--- Missing Modules in File ---"
foreach ($mod in $dbMods) {
    if ($modsInFile -notcontains $mod) {
        Write-Host "Missing Module: $mod"
    }
}
