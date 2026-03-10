$connString = "Data Source=192.168.43.129\SQLEXPRESS;Initial Catalog=VegtablityDB;User ID=Mohamed;Password=125630;TrustServerCertificate=True"
$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.Open()

$query = @"
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Sales' AND TABLE_NAME = 'Partners'
ORDER BY ORDINAL_POSITION
"@

$cmd = $conn.CreateCommand()
$cmd.CommandText = $query
$reader = $cmd.ExecuteReader()

Write-Host "--- Sales.Partners Schema ---"
while ($reader.Read()) {
    $col = $reader["COLUMN_NAME"]
    $type = $reader["DATA_TYPE"]
    $len = $reader["CHARACTER_MAXIMUM_LENGTH"]
    $null = $reader["IS_NULLABLE"]
    Write-Host "$col - $type - $len - $null"
}
$reader.Close()
$conn.Close()
