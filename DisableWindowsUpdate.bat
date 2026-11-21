@echo off
setlocal
set LOG=%~dp0WU_off_log.txt
echo ==== start ==== > "%LOG%"

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Need Administrator. Right-click cmd - Run as administrator, then run this file.
    pause
    exit /b 1
)
echo [OK] Administrator confirmed
echo [OK] admin >> "%LOG%"

echo.
echo [0] Killing running update processes...
for %%P in (MoUsoCoreWorker.exe usoclient.exe TiWorker.exe WaaSMedic.exe) do taskkill /f /im %%P >> "%LOG%" 2>&1

echo.
echo [1] Stopping services...
for %%S in (wuauserv bits dosvc UsoSvc WaaSMedicSvc) do net stop %%S >> "%LOG%" 2>&1

echo.
echo [2] Disabling services...
for %%S in (wuauserv bits dosvc UsoSvc) do (
    sc config %%S start= disabled >> "%LOG%" 2>&1
    echo    %%S disabled
)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f >> "%LOG%" 2>&1
if errorlevel 1 (echo    WaaSMedicSvc FAILED - protected, see note) else (echo    WaaSMedicSvc disabled)

echo.
echo [3] Writing group policy...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DoNotConnectToWindowsUpdateInternetLocations /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1
echo    NoAutoUpdate=1 OK

echo.
echo [4] Extending pause to year 2099...
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesExpiryTime /t REG_SZ /d "2099-12-31T00:00:00Z" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesStartTime /t REG_SZ /d "2024-01-01T00:00:00Z" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesEndTime /t REG_SZ /d "2099-12-31T00:00:00Z" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseQualityUpdatesStartTime /t REG_SZ /d "2024-01-01T00:00:00Z" /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseQualityUpdatesEndTime /t REG_SZ /d "2099-12-31T00:00:00Z" /f >> "%LOG%" 2>&1
echo    Pause until 2099 OK

echo.
echo [5] Disabling scheduled tasks...
for %%T in (
 "\Microsoft\Windows\WindowsUpdate\Scheduled Start"
 "\Microsoft\Windows\WindowsUpdate\Automatic App Update"
 "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"
 "\Microsoft\Windows\UpdateOrchestrator\Universal Orchestrator Start"
 "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker"
 "\Microsoft\Windows\UpdateOrchestrator\Reboot"
 "\Microsoft\Windows\WaaSMedic\PerformRemediation"
) do (
    schtasks /change /tn %%T /disable >> "%LOG%" 2>&1
    if errorlevel 1 (echo    SKIP %%T) else (echo    DONE %%T)
)

echo.
echo [6] Clearing downloaded update cache...
net stop bits >nul 2>&1
rd /s /q "%SystemRoot%\SoftwareDistribution\Download" >nul 2>&1
if exist "%SystemRoot%\SoftwareDistribution\Download" (echo    cache partially in use - rerun after reboot) else (echo    cache cleared)

echo.
echo ==================================================
echo  DONE. REBOOT NOW to take effect.
echo  Verify after reboot:  sc qc wuauserv
echo  Expect: START_TYPE : 4  DISABLED
echo  Log: %LOG%
echo ==================================================
echo ==== end ==== >> "%LOG%"
pause
