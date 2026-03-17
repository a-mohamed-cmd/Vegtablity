@echo off
setlocal EnableDelayedExpansion

title Vegtablity ERP - Apply Performance Indexes Update

echo ========================================================
echo Vegtablity ERP - Apply Performance Indexes Update
echo ========================================================
echo This script will execute the 19_Performance_Indexes.sql
echo script to add non-clustered and filtered indexes to 
echo the VegtablityDB database, optimizing query performance.
echo.

set SERVER_NAME=.\SQLEXPRESS
set DB_NAME=VegtablityDB
set SQL_FILE=19_Performance_Indexes.sql

echo Server: %SERVER_NAME%
echo Database: %DB_NAME%
echo Script: %SQL_FILE%
echo.

if not exist "%SQL_FILE%" (
    echo [ERROR] SQL script file not found: %SQL_FILE%
    echo Please make sure you are running this batch file from the correct directory.
    pause
    exit /b 1
)



echo.
echo Applying performance indexes...
echo This may take a moment depending on the size of your database...
echo.

sqlcmd -S %SERVER_NAME% -d %DB_NAME% -E -i "%SQL_FILE%" -b -m 1

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo SUCCESS: Performance indexes applied successfully!
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo ERROR: Failed to apply performance indexes.
    echo Please review the errors above.
    echo ========================================================
)

echo.

