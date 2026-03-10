$connString = "Data Source=192.168.43.129\SQLEXPRESS;Initial Catalog=VegtablityDB;User ID=Mohamed;Password=125630;TrustServerCertificate=True"
$sqlFile = "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql"
$outFile = "d:\VB.NET\backup\Vegtablity\Vegtablity\SQL_Missing.sql"

if (Test-Path $outFile) { Remove-Item $outFile }

$fileContent = Get-Content $sqlFile -Raw

$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.Open()

$query = @"
SELECT 
    s.name AS SchemaName, 
    o.name AS ObjectName, 
    o.type_desc AS ObjectType,
    m.definition AS ObjectDefinition
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.is_ms_shipped = 0
"@

$cmd = $conn.CreateCommand()
$cmd.CommandText = $query
$reader = $cmd.ExecuteReader()

$missingCount = 0

while ($reader.Read()) {
    $schemaName = $reader["SchemaName"]
    $objName = $reader["ObjectName"]
    $objType = $reader["ObjectType"]
    $definition = $reader["ObjectDefinition"]

    # Simple check if the name is in the file
    # This might have false positives if the name is used elsewhere, 
    # but it's a good first pass for missing procedures/triggers
    if (-not $fileContent.Contains($objName)) {
        Write-Host "Missing: [$schemaName].[$objName] ($objType)"
        
        $script = "`n-- Missing Object: $schemaName.$objName`n"
        
        if ($objType -eq "SQL_STORED_PROCEDURE") {
            $script += "IF OBJECT_ID('[$schemaName].[$objName]', 'P') IS NOT NULL DROP PROCEDURE [$schemaName].[$objName];`nGO`n"
        }
        elseif ($objType -eq "SQL_TRIGGER") {
            $script += "IF OBJECT_ID('[$schemaName].[$objName]', 'TR') IS NOT NULL DROP TRIGGER [$schemaName].[$objName];`nGO`n"
        }
        elseif ($objType -eq "VIEW") {
            $script += "IF OBJECT_ID('[$schemaName].[$objName]', 'V') IS NOT NULL DROP VIEW [$schemaName].[$objName];`nGO`n"
        }
        
        $script += $definition + "`nGO`n"
        Add-Content $outFile $script
        $missingCount++
    }
}
$reader.Close()

# Check missing tables (just the names)
$queryTables = @"
SELECT s.name AS SchemaName, t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
"@
$cmd.CommandText = $queryTables
$reader = $cmd.ExecuteReader()
while ($reader.Read()) {
    $schema = $reader["SchemaName"]
    $table = $reader["TableName"]
    if (-not $fileContent.Contains("CREATE TABLE [$schema].[$table]") -and -not $fileContent.Contains("CREATE TABLE $schema.$table")) {
        # Check without brackets too
        Write-Host "Might be missing Table: [$schema].[$table]"
    }
}
$reader.Close()
$conn.Close()

Write-Host "Found $missingCount missing programmable objects. Checked tables too."
