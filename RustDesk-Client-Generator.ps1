# =======================================================================
# RustDesk Client Generator with Encrypted Credentials
# =======================================================================
# This PowerShell script generates a customized RustDesk installer script 
# and a batch file to run it with appropriate execution policy settings. 
# It supports optional #encryption of configuration data 
#( public key / perm password ) and optional email notification
#( also can be encrypted ) after installation.
# =======================================================================
# by: jonpotz
# https://github.com/jonpotz/
# =======================================================================


# --- Self-elevate to Administrator if needed ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"   # Trigger UAC prompt
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Warning "User declined the UAC prompt. Exiting."
    }
    exit
}

function Encrypt-String {
    param(
        [string]$PlainText,
        [string]$Password
    )
    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.KeySize = 256
    $aes.BlockSize = 128
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $key = [Text.Encoding]::UTF8.GetBytes($Password.PadRight(32).Substring(0,32))
    $aes.Key = $key
    $aes.IV = $key[0..15]

    $encryptor = $aes.CreateEncryptor()
    $bytes = [Text.Encoding]::UTF8.GetBytes($PlainText)
    $encrypted = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length)

    [Convert]::ToBase64String($encrypted)
}

# Prompt user for config values
$relayServer = Read-Host "Enter the relay server ip or domain"
$publicKey = Read-Host "Enter the public key"
$passwordPlain = Read-Host "Enter the password to login to the client"

# Ask if user wants encryption
do {
    $encryptChoice = Read-Host "Do you want to encrypt the data in the generated script? (y/n)"
    $encryptChoice = $encryptChoice.ToLower()
} while ($encryptChoice -ne "y" -and $encryptChoice -ne "n" -and $encryptChoice -ne "yes" -and $encryptChoice -ne "no")

$useEncryption = ($encryptChoice -eq "y" -or $encryptChoice -eq "yes")

# Ask about email functionality
do {
    $emailChoice = Read-Host "Do you want to include email functionality to send log and ID after installation? (y/n)"
    $emailChoice = $emailChoice.ToLower()
} while ($emailChoice -ne "y" -and $emailChoice -ne "n" -and $emailChoice -ne "yes" -and $emailChoice -ne "no")

$useEmail = ($emailChoice -eq "y" -or $emailChoice -eq "yes")

# Initialize variables
$encPasswordPlain = ""
$smtpServer = ""
$smtpPort = ""
$fromEmail = ""
$fromPassword = ""
$toEmail = ""

# Get encryption password if needed
if ($useEncryption) {
    $encPassword = Read-Host "Enter a password that will be asked when installing the client (used to decrypt the info in the client script)" -AsSecureString
    $encPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($encPassword))
}

# Get email settings if needed
if ($useEmail) {
    Write-Host "`nEmail Configuration:"
    $smtpServer = Read-Host "Enter SMTP server (e.g., smtp.gmail.com)"
    $smtpPort = Read-Host "Enter SMTP port (e.g., 587 for TLS, 465 for SSL)"
    $fromEmail = Read-Host "Enter sender email address"
    $fromPassword = Read-Host "Enter sender email password (or app password)" -AsSecureString
    $fromPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($fromPassword))
    $toEmail = Read-Host "Enter recipient email address"
}

# Prepare configuration values
if ($useEncryption) {
    # Encrypt secrets
    $configRelay = Encrypt-String $relayServer $encPasswordPlain
    $configKey = Encrypt-String $publicKey $encPasswordPlain
    $configPass = Encrypt-String $passwordPlain $encPasswordPlain
    
    if ($useEmail) {
        $configSmtpServer = Encrypt-String $smtpServer $encPasswordPlain
        $configSmtpPort = Encrypt-String $smtpPort $encPasswordPlain
        $configFromEmail = Encrypt-String $fromEmail $encPasswordPlain
        $configFromPassword = Encrypt-String $fromPasswordPlain $encPasswordPlain
        $configToEmail = Encrypt-String $toEmail $encPasswordPlain
    }
} else {
    # Use plain text
    $configRelay = $relayServer
    $configKey = $publicKey
    $configPass = $passwordPlain
    
    if ($useEmail) {
        $configSmtpServer = $smtpServer
        $configSmtpPort = $smtpPort
        $configFromEmail = $fromEmail
        $configFromPassword = $fromPasswordPlain
        $configToEmail = $toEmail
    }
}

# Generate the installer script based on choices
$installerScript = @'
# ===================================
# RustDesk Installer Script
# ===================================


# --- Self-elevate to Administrator if needed ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Warning "User declined the UAC prompt. Exiting."
    }
    exit
}

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# === Setup log file in script directory ===
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logFile = Join-Path $scriptDir "rustdesk_install.log"

function Write-Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts - $msg" | Out-File -Append -FilePath $logFile
    Write-Verbose $msg
}

'@

# Add decryption function if encryption is used
if ($useEncryption) {
    $installerScript += @'

function Decrypt-String {
    param(
        [string]$EncryptedText,
        [string]$Password
    )
    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.KeySize = 256
    $aes.BlockSize = 128
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $key = [Text.Encoding]::UTF8.GetBytes($Password.PadRight(32).Substring(0,32))
    $aes.Key = $key
    $aes.IV = $key[0..15]

    $decryptor = $aes.CreateDecryptor()
    $bytes = [Convert]::FromBase64String($EncryptedText)
    $decryptedBytes = $decryptor.TransformFinalBlock($bytes, 0, $bytes.Length)

    [Text.Encoding]::UTF8.GetString($decryptedBytes)
}

'@
}

$installerScript += @'

Write-Log "Starting RustDesk installation..."

'@

# Add configuration section based on encryption choice
if ($useEncryption) {
    $installerScript += @'

# Prompt for decryption password at install time
$decryptPassword = Read-Host "Enter decryption password"

try {
    # Decrypt the config secrets
    $relayServer = Decrypt-String("CONFIG_RELAY") $decryptPassword
    $publicKey = Decrypt-String("CONFIG_KEY") $decryptPassword
    $passwordPlain = Decrypt-String("CONFIG_PASS") $decryptPassword

'@
    if ($useEmail) {
        $installerScript += @'
    # Decrypt email settings
    $smtpServer = Decrypt-String("CONFIG_SMTP_SERVER") $decryptPassword
    $smtpPort = Decrypt-String("CONFIG_SMTP_PORT") $decryptPassword
    $fromEmail = Decrypt-String("CONFIG_FROM_EMAIL") $decryptPassword
    $fromPassword = Decrypt-String("CONFIG_FROM_PASSWORD") $decryptPassword
    $toEmail = Decrypt-String("CONFIG_TO_EMAIL") $decryptPassword

'@
    }
    
    $installerScript += @'
    Write-Log "Configuration decrypted successfully"
    Write-Log "Relay server: [HIDDEN]"
    Write-Log "Public key: [HIDDEN]"
    Write-Log "Password: [HIDDEN]"
} catch {
    Write-Log "ERROR: Failed to decrypt configuration - $_"
    Write-Error "Failed to decrypt configuration. Check password and try again."
    exit 1
}

'@
} else {
    $installerScript += @'

# Configuration values (plain text)
$relayServer = "CONFIG_RELAY"
$publicKey = "CONFIG_KEY"
$passwordPlain = "CONFIG_PASS"

'@
    if ($useEmail) {
        $installerScript += @'
# Email configuration (plain text)
$smtpServer = "CONFIG_SMTP_SERVER"
$smtpPort = "CONFIG_SMTP_PORT"
$fromEmail = "CONFIG_FROM_EMAIL"
$fromPassword = "CONFIG_FROM_PASSWORD"
$toEmail = "CONFIG_TO_EMAIL"

'@
    }
    
    $installerScript += @'
Write-Log "Configuration loaded successfully"
Write-Log "Relay server: [HIDDEN]"
Write-Log "Public key: [HIDDEN]"
Write-Log "Password: [HIDDEN]"

'@
}

# Add email function if needed
if ($useEmail) {
    $installerScript += @'

function Send-EmailNotification {
    param(
        [string]$RustDeskId,
        [string]$LogContent
    )
    try {
        $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtpClient.EnableSsl = $true
        $smtpClient.Credentials = New-Object Net.NetworkCredential($fromEmail, $fromPassword)
        
        $mailMessage = New-Object Net.Mail.MailMessage
        $mailMessage.From = $fromEmail
        $mailMessage.To.Add($toEmail)
        $mailMessage.Subject = "RustDesk Installation Complete - ID: $RustDeskId"
        
        $body = @"
RustDesk installation has been completed successfully.

RustDesk ID: $RustDeskId
Relay Server: $relayServer
Installation Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer Name: $env:COMPUTERNAME
Username: $env:USERNAME

Installation Log:
$LogContent
"@
        
        $mailMessage.Body = $body
        $smtpClient.Send($mailMessage)
        Write-Log "Email notification sent successfully to $toEmail"
    } catch {
        Write-Log "Failed to send email notification: $_"
    }
}

'@
}

# Continue with the main installation code
$installerScript += @'

# -- Begin RustDesk install code --

# Paths and variables
$downloadUrl    = "https://github.com/rustdesk/rustdesk/releases/download/1.4.1/rustdesk-1.4.1-x86_64.exe"
$installerPath  = "C:\Temp\rustdesk.exe"
$installDir     = "C:\Program Files\RustDesk"
$serviceName    = "RustDesk"

# Config paths
$userConfigPath = "C:\Users\$env:USERNAME\AppData\Roaming\RustDesk\config\RustDesk2.toml"
$svcConfigPath  = "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml"

# Compose TOML config with secrets
$tomlContent = @"
rendezvous_server = '$relayServer`:21116'
nat_type = 1
serial = 0

[options]
custom-rendezvous-server = '$relayServer'
key = '$publicKey'
"@

# Create Temp dir
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
    Write-Log "Created Temp directory"
} else {
    Write-Log "Temp directory exists"
}

Write-Log "Downloading RustDesk installer..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
Write-Log "Download complete."

Write-Log "Installing RustDesk silently..."
$proc = Start-Process -FilePath $installerPath -ArgumentList "--silent-install" -PassThru
if (-not $proc.WaitForExit(15000)) {
    Write-Log "Installer timed out, killing process."
    $proc.Kill()
    throw "RustDesk installer timed out."
}
Write-Log "Installation complete."

Start-Sleep -Seconds 10

# Verify install dir
if (-not (Test-Path $installDir)) {
    $installDir = "C:\Program Files (x86)\RustDesk"
    if (-not (Test-Path $installDir)) {
        Write-Log "RustDesk install directory not found."
        throw "RustDesk install directory not found."
    }
}
Write-Log "Using RustDesk install directory: $installDir"

Set-Location $installDir

Write-Log "Installing RustDesk service..."
$svcProc = Start-Process -FilePath ".\rustdesk.exe" -ArgumentList "--install-service" -NoNewWindow -PassThru
if (-not $svcProc.WaitForExit(15000)) {
    Write-Log "Service install timed out, killing."
    $svcProc.Kill()
    throw "RustDesk service install timed out."
}
Write-Log "Service installed."

Start-Sleep -Seconds 5

# Stop service if running
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Log "Stopping RustDesk service to update config..."
    Stop-Service $service.Name -Force
    Start-Sleep -Seconds 5
} else {
    Write-Log "RustDesk service not running; killing rustdesk.exe processes..."
    Get-Process rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

# Write config files
foreach ($path in @($userConfigPath, $svcConfigPath)) {
    $dir = Split-Path $path
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Log "Created config directory: $dir"
    }
    Set-Content -Path $path -Value $tomlContent -Encoding UTF8
    Write-Log "Wrote config to $path"
}

Write-Log "Starting RustDesk service..."
Start-Service -Name $serviceName
Start-Sleep -Seconds 10

Write-Log "Setting RustDesk password..."
& .\rustdesk.exe --password $passwordPlain
Write-Log "Password set."

Start-Sleep -Seconds 5

Write-Log "Retrieving RustDesk ID..."
$rustdesk_id_raw = cmd.exe /c ".\rustdesk.exe --get-id | more"
if (-not [string]::IsNullOrEmpty($rustdesk_id_raw)) {
    $rustdesk_id = $rustdesk_id_raw.Trim()
} else {
    $rustdesk_id = ''
}

if ([string]::IsNullOrEmpty($rustdesk_id)) {
    Write-Log "Warning: RustDesk ID command returned empty."
} else {
    Write-Log "RustDesk ID: $rustdesk_id"
}

Write-Log "Installation complete."

'@

# Add email sending if enabled
if ($useEmail) {
    $installerScript += @'

# Send email notification if configured
if ($smtpServer -and $fromEmail -and $toEmail) {
    Write-Log "Sending email notification..."
    $logContent = Get-Content $logFile -Raw
    Send-EmailNotification -RustDeskId $rustdesk_id -LogContent $logContent
}

'@
}

$installerScript += @'

# Open the log file for review
Start-Process notepad.exe $logFile
'@

# Replace placeholders with actual values
$installerScript = $installerScript.Replace("CONFIG_RELAY", $configRelay)
$installerScript = $installerScript.Replace("CONFIG_KEY", $configKey)
$installerScript = $installerScript.Replace("CONFIG_PASS", $configPass)

if ($useEmail) {
    $installerScript = $installerScript.Replace("CONFIG_SMTP_SERVER", $configSmtpServer)
    $installerScript = $installerScript.Replace("CONFIG_SMTP_PORT", $configSmtpPort)
    $installerScript = $installerScript.Replace("CONFIG_FROM_EMAIL", $configFromEmail)
    $installerScript = $installerScript.Replace("CONFIG_FROM_PASSWORD", $configFromPassword)
    $installerScript = $installerScript.Replace("CONFIG_TO_EMAIL", $configToEmail)
}

# ====== NEW: Create subdirectory ClientInstall and output files there ======

$clientInstallDir = Join-Path -Path $PSScriptRoot -ChildPath "ClientInstall"

if (-not (Test-Path $clientInstallDir)) {
    New-Item -Path $clientInstallDir -ItemType Directory -Force | Out-Null
    Write-Output "Created directory: $clientInstallDir"
} else {
    Write-Output "Directory already exists: $clientInstallDir"
}

# Define output paths for installer script and batch file
$installerFilePath = Join-Path -Path $clientInstallDir -ChildPath "ClientInstall.ps1"
$batchFilePath = Join-Path -Path $clientInstallDir -ChildPath "RunMe.bat"

# Save the installer PowerShell script
$installerScript | Out-File -FilePath $installerFilePath -Encoding UTF8
Write-Output "Installer script generated at: $installerFilePath"

# Create the batch file content
$batchContent = @"
@echo off
powershell -noexit -ExecutionPolicy Bypass -File ClientInstall.ps1
"@

# Save the batch file
$batchContent | Out-File -FilePath $batchFilePath -Encoding ASCII
Write-Output "Batch file generated at: $batchFilePath"

# Inform user about encryption and email settings
if ($useEncryption) {
    Write-Output "This script uses encryption. Provide the decryption password when running the installer."
} else {
    Write-Output "This script contains plain text configuration data."
}

if ($useEmail) {
    Write-Output "Email notifications are enabled and will be sent to: $toEmail"
}

Write-Output "`nDistribute the contents of the 'ClientInstall' folder to target machines for installation."

