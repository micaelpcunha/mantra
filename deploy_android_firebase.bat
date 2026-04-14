@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\deploy_android_firebase.ps1" %*
exit /b %ERRORLEVEL%
