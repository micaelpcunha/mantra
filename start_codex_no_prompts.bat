@echo off
setlocal EnableExtensions
title Codex Mantra

set "WORKDIR=C:\Users\pinta\asset_app"
set "CODEX_CMD="
set "KNOWN_CODEX=C:\Users\pinta\.vscode\extensions\openai.chatgpt-26.5325.31654-win32-x64\bin\windows-x86_64\codex.exe"

for %%I in (codex.exe) do set "CODEX_CMD=%%~$PATH:I"

if defined CODEX_CMD goto launch

for /f "delims=" %%I in ('where codex.exe 2^>nul') do (
  set "CODEX_CMD=%%I"
  goto launch
)

if exist "%KNOWN_CODEX%" (
  set "CODEX_CMD=%KNOWN_CODEX%"
  goto launch
)

for /f "delims=" %%I in ('dir /b /s "%USERPROFILE%\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe" 2^>nul') do (
  set "CODEX_CMD=%%I"
  goto launch
)

echo Nao foi encontrado o binario do Codex.
echo Abre o VS Code / extensao da OpenAI primeiro ou verifica a instalacao.
pause
exit /b 1

:launch
echo A abrir Codex em %WORKDIR%...
"%CODEX_CMD%" -a never -s workspace-write -C "%WORKDIR%" %*
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
  echo.
  echo O Codex terminou com erro %EXIT_CODE%.
  pause
)
