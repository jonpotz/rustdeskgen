# ================================
# RustDesk Config Generator Script
# by: jonpotz
# ================================

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
$relayServer = Read-Host "Enter the relay server ip or domain:"
$publicKey   = Read-Host "Enter the public key:"
$passwordPlain = Read-Host "Enter the password to login to the client:"

# Prompt for encryption password
$encPassword = Read-Host "Enter a password that will be asked when installing the client ( used to decrypt the info in the client script )" -AsSecureString
$encPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($encPassword))

# Encrypt secrets
$encRelay = Encrypt-String $relayServer $encPasswordPlain
$encKey = Encrypt-String $publicKey $encPasswordPlain
$encPass = Encrypt-String $passwordPlain $encPasswordPlain

# The installer script with placeholders for encrypted secrets
$installerScript = @'
# ===================================
# RustDesk Encrypted Installer Script
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

# Prompt for decryption password at install time
$decryptPassword = Read-Host "Enter decryption password"

# Decrypt the config secrets
$relayServer = Decrypt-String("RELAY_ENCRYPTED") $decryptPassword
$publicKey = Decrypt-String("KEY_ENCRYPTED") $decryptPassword
$passwordPlain = Decrypt-String("PASS_ENCRYPTED") $decryptPassword

Write-Output "Decrypted relay server: $relayServer"
Write-Output "Decrypted public key: $publicKey"
Write-Output "Decrypted password: $passwordPlain"

# -- Begin RustDesk install code --

# Paths and variables
$downloadUrl    = "https://github.com/rustdesk/rustdesk/releases/download/1.4.1/rustdesk-1.4.1-x86_64.exe"
$installerPath  = "C:\Temp\rustdesk.exe"
$installDir     = "C:\Program Files\RustDesk"
$serviceName    = "RustDesk"

# Config paths
$userConfigPath = "C:\Users\$env:USERNAME\AppData\Roaming\RustDesk\config\RustDesk2.toml"
$svcConfigPath  = "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml"

# Compose TOML config with decrypted secrets
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
}

Write-Output "Temp directory ready."

# Download installer
Write-Output "Downloading RustDesk installer..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
Write-Output "Download complete."

# Install silently
Write-Output "Installing RustDesk silently..."
$proc = Start-Process -FilePath $installerPath -ArgumentList "--silent-install" -PassThru
if ($proc.WaitForExit(15000) -eq $false) {
    Write-Output "Installer timed out, killing process."
    $proc.Kill()
    throw "RustDesk installer timed out."
}
Write-Output "Installation complete."

Start-Sleep -Seconds 10

# Verify install dir
if (-not (Test-Path $installDir)) {
    $installDir = "C:\Program Files (x86)\RustDesk"
    if (-not (Test-Path $installDir)) {
        throw "RustDesk install directory not found."
    }
}

Set-Location $installDir

# Install service
Write-Output "Installing RustDesk service..."
$svcProc = Start-Process -FilePath ".\rustdesk.exe" -ArgumentList "--install-service" -NoNewWindow -PassThru
if ($svcProc.WaitForExit(15000) -eq $false) {
    Write-Output "Service install timed out, killing."
    $svcProc.Kill()
    throw "RustDesk service install timed out."
}
Write-Output "Service installed."

Start-Sleep -Seconds 5

# Stop service if running
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Output "Stopping RustDesk service to update config..."
    Stop-Service $service.Name -Force
    Start-Sleep -Seconds 5
} else {
    Write-Output "RustDesk service not running; killing rustdesk.exe processes..."
    Get-Process rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

# Write config files
foreach ($path in @($userConfigPath, $svcConfigPath)) {
    $dir = Split-Path $path
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    Set-Content -Path $path -Value $tomlContent -Encoding UTF8
    Write-Output "Wrote config to $path"
}

# Start service
Write-Output "Starting RustDesk service..."
Start-Service -Name $serviceName
Start-Sleep -Seconds 10

# Set password
Write-Output "Setting RustDesk password..."
& .\rustdesk.exe --password $passwordPlain
Write-Output "Password set."

# Wait before getting ID
Start-Sleep -Seconds 5

# Get RustDesk ID
$rustdesk_id_raw = cmd.exe /c ".\rustdesk.exe --get-id | more"
if ([string]::IsNullOrEmpty($rustdesk_id_raw) -eq $false) {
    $rustdesk_id = $rustdesk_id_raw.Trim()
} else {
    $rustdesk_id = ''
}

if ([string]::IsNullOrEmpty($rustdesk_id) -eq $true) {
    Write-Output "Warning: RustDesk ID command returned empty."
} else {
    Write-Output "RustDesk ID: $rustdesk_id"
}

Write-Output "Installation complete."
'@

# Replace placeholders with encrypted strings
$installerScript = $installerScript.Replace("RELAY_ENCRYPTED", $encRelay)
$installerScript = $installerScript.Replace("KEY_ENCRYPTED", $encKey)
$installerScript = $installerScript.Replace("PASS_ENCRYPTED", $encPass)

# Output file in same directory as this generator script
$outFile = Join-Path -Path $PSScriptRoot -ChildPath "RustDesk_Install_Encrypted.ps1"
$installerScript | Out-File -FilePath $outFile -Encoding UTF8

Write-Output "Encrypted installer script generated at: $outFile"
Write-Output "Distribute this script and provide the decryption password to run it."
