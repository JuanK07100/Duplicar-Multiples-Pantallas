@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0DuplicarPantallas.ps1"
echo.
echo Presiona cualquier tecla para cerrar...
pause > nul