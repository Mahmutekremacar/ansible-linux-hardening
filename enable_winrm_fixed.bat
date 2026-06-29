@echo off
TITLE EDR Arena - WinRM Setup
COLOR 0A

fsutil dirty query %systemdrive% >nul
if %errorLevel% NEQ 0 (
    echo Requesting Administrator privileges to configure WinRM...
    goto UACPrompt
) else (
    goto gotAdmin
)

:UACPrompt
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
del "%temp%\getadmin.vbs"
exit /B

:gotAdmin
echo Applying WinRM, Firewall, and Authentication settings...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force; New-NetFirewallRule -DisplayName 'Allow WinRM 5985' -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue | Out-Null; Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force; Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force; Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force; Restart-Service WinRM; Write-Host 'SUCCESS: WinRM is open!' -ForegroundColor Green"
pause >nul
