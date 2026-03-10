$connString = "Data Source=192.168.43.129\SQLEXPRESS;Initial Catalog=VegtablityDB;User ID=Mohamed;Password=125630;TrustServerCertificate=True"
$sqlFile = "d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql"

$fileContent = (Get-Content $sqlFile -Raw).ToLower()

$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.Open()

$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT s.name AS SchemaName, t.name AS TableName FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.is_ms_shipped = 0"
$reader = $cmd.ExecuteReader()

while ($reader.Read()) {
    $schema = $reader["SchemaName"].ToLower()
    $table = $reader["TableName"].ToLower()
    $token1 = "table [$schema].[$table]"
    $token2 = "table $schema.$table"
    
    if (-not $fileContent.Contains($token1) -and -not $fileContent.Contains($token2)) {
        Write-Host "Real Missing Table: $schema.$table"
    }
}
$reader.Close()
$conn.Close()
