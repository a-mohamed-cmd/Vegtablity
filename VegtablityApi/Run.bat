@echo off
Title Vegtabilty Api Server
cd D:\VB.NET\backup\Vegtablity\VegtablityApi
call .\.venv\Scripts\Activate.bat
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
pause