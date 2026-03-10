$connString = "Data Source=192.168.43.129\SQLEXPRESS;Initial Catalog=VegtablityDB;User ID=Mohamed;Password=125630;TrustServerCertificate=True"
$sqlFile = "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql"
$outFile = "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\MissingObjects.sql"

if (Test-Path $outFile) { Remove-Item $outFile }

$fileContent = (Get-Content $sqlFile -Raw).ToLower()

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
    $schemaName = $reader["SchemaName"].ToLower()
    $objName = $reader["ObjectName"].ToLower()
    $objType = $reader["ObjectType"]
    $definition = $reader["ObjectDefinition"]

    $typeKeyword = ""
    if ($objType -eq "SQL_STORED_PROCEDURE") { $typeKeyword = "procedure" }
    elseif ($objType -eq "SQL_TRIGGER") { $typeKeyword = "trigger" }
    elseif ($objType -eq "VIEW") { $typeKeyword = "view" }
    else { $typeKeyword = "function" }

    # Check for CREATE PROCEDURE [schema].[name] or CREATE PROCEDURE schema.name
    $token1 = "create $typeKeyword [$schemaName].[$objName]"
    $token2 = "create $typeKeyword $schemaName.$objName"
    
    if (-not $fileContent.Contains($token1) -and -not $fileContent.Contains($token2)) {
        Write-Host "Missing ${objType}: [${schemaName}].[${objName}]"
        
        $script = "`n-- =============================================`n"
        $script += "-- Auto-Restored Missing Object: [$schemaName].[$objName]`n"
        $script += "-- =============================================`n"
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
$conn.Close()

Write-Host "Found $missingCount missing programmable objects."
