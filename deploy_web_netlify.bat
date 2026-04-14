@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\deploy_web_netlify.ps1" %*
exit /b %ERRORLEVEL%
