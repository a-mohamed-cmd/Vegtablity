@echo off
setlocal EnableDelayedExpansion

title Vegtablity ERP - Index Maintenance Script

echo ========================================================
echo Vegtablity ERP - Index Maintenance Script
echo ========================================================
echo This script will execute the 20_Maintenance_Indexes.sql
echo script to REORGANIZE and REBUILD indexes in the 
echo VegtablityDB database, optimizing query performance.
echo.

set SERVER_NAME=.\SQLEXPRESS
set DB_NAME=VegtablityDB
set SQL_FILE=20_Maintenance_Indexes.sql

echo Server: %SERVER_NAME%
echo Database: %DB_NAME%
echo Script: %SQL_FILE%
echo.

if not exist "%SQL_FILE%" (
    echo [ERROR] SQL script file not found: %SQL_FILE%
    echo Please make sure you are running this batch file from the root Vegtablity directory.
    pause
    exit /b 1
)

set /p UserInput="Are you sure you want to perform index maintenance? (Y/N): "
if /I "%UserInput%" NEQ "Y" (
    echo Maintenance cancelled by user.
    pause
    exit /b 0
)

echo.
echo Performing index maintenance...
echo This may take some time depending on database fragmentation...
echo.

sqlcmd -S %SERVER_NAME% -d %DB_NAME% -E -i "%SQL_FILE%" -b -m 1

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo SUCCESS: Index maintenance completed successfully!
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo ERROR: Failed to perform index maintenance.
    echo Please review the errors above.
    echo ========================================================
)

echo.
pause
