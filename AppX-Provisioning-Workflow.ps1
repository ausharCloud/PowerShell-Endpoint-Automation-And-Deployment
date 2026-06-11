<#
.SYNOPSIS
A bulletproof AppX package provisioning workflow with dynamic fallback to an MSI installation.

.DESCRIPTION
This script dynamically scans all user profiles to see who is missing an AppX package. It registers the package for currently logged-on users using `Execute-ProcessAsUser`, and provisions it system-wide using `Add-AppxProvisionedPackage`. If the AppX install fails or isn't found locally, it seamlessly falls back to downloading the latest MSI version directly from a parsed JSON manifest (`Invoke-WebRequest | ConvertFrom-Json`).
#>

# This Family Name is the constant identity across all versions
$AppFamilyName = "TestNav"
$appxPath = Get-ChildItem -Path "$dirFiles" -Filter "PearsonEducationInc.TestNav*.appx" | Select-Object -ExpandProperty FullName -First 1
$baseUrl = "https://download.testnav.com/"
$jsonUrl = "$($baseUrl)installerVersions.json"

# --- PRE-CHECK: Detect installations across all users ---
$existingMSI = Get-InstalledApplication -Name "TestNav"
$provisionedAppX = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$AppFamilyName*" }
$loggedOnUsers = Get-LoggedOnUser
$allUserProfiles = Get-UserProfiles

$usersNeedingAppX = @()
foreach ($profile in $allUserProfiles) {
    if ($profile.NTAccount -match 'SYSTEM|LOCAL SERVICE|NETWORK SERVICE|Public|Default User') { continue }
    
    $userAppX = Get-AppxPackage -Name "*$AppFamilyName*" -User $profile.SID -ErrorAction SilentlyContinue
    if (-not $userAppX) {
        $usersNeedingAppX += $profile
    }
}

$needsInstall = $false
$needsRegistration = $false

if ($existingMSI) {
    $installSuccess = $true
} elseif ($provisionedAppX -and $usersNeedingAppX.Count -eq 0) {
    $installSuccess = $true
} elseif ($provisionedAppX -and $usersNeedingAppX.Count -gt 0) {
    $needsRegistration = $true
    $installSuccess = $false
} else {
    $needsInstall = $true
    $installSuccess = $false
}

# --- REGISTER AppX for logged-on users (if already provisioned) ---
if ($needsRegistration) {
    $provisionedPackagePath = "C:\Program Files\WindowsApps\$($provisionedAppX.PackageName)"
    $manifestPath = Join-Path -Path $provisionedPackagePath -ChildPath "AppxManifest.xml"
    
    foreach ($profile in $usersNeedingAppX) {
        $isLoggedOn = $loggedOnUsers | Where-Object { $_.NTAccount -eq $profile.NTAccount }
        if ($isLoggedOn) {
            # Register from the provisioned package manifest location as the logged-on user
            $registerCommand = "Add-AppxPackage -DisableDevelopmentMode -Register '$manifestPath'"
            Execute-ProcessAsUser -Path "$PSHOME\powershell.exe" -Parameters "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$registerCommand`"" -Wait
        }
    }
    $installSuccess = $true
}

# --- PRIMARY: Full AppX Install (if needed) ---
if ($needsInstall -and $appxPath) {
    try {
        # 1. Provision the package for the machine (SYSTEM context)
        Add-AppxProvisionedPackage -Online -PackagePath $appxPath -SkipLicense -ErrorAction Stop
        
        # 2. Register for ALL currently logged on users
        $newlyProvisionedAppX = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$AppFamilyName*" }
        $newManifestPath = "C:\Program Files\WindowsApps\$($newlyProvisionedAppX.PackageName)\AppxManifest.xml"
        
        foreach ($user in $loggedOnUsers) {
            if ($user.NTAccount -notmatch 'SYSTEM|LOCAL SERVICE|NETWORK SERVICE') {
                $registerCommand = "Add-AppxPackage -DisableDevelopmentMode -Register '$newManifestPath'"
                Execute-ProcessAsUser -Path "$PSHOME\powershell.exe" -Parameters "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$registerCommand`"" -Wait
            }
        }
        $installSuccess = $true
    } catch {
        Write-Log -Message "[APPX] ✗ AppX install failed. Proceeding to MSI fallback method..." -Severity 2
        $installSuccess = $false
    }
}

# --- FALLBACK: Dynamic MSI (Only if AppX failed or unavailable) ---
if ($needsInstall -and -not $installSuccess) {
    try {
        # Fetch latest MSI metadata from Vendor JSON manifest
        $response = Invoke-WebRequest -Uri $jsonUrl -UseBasicParsing -ErrorAction Stop
        $versionData = $response.Content | ConvertFrom-Json
        
        $msiFileName = $versionData.windows_msi
        $downloadUrl = "$($baseUrl)_testnavinstallers/$msiFileName"
        $destinationPath = Join-Path -Path $dirFiles -ChildPath $msiFileName
        
        if (-not (Test-Path $destinationPath)) {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath -UseBasicParsing -ErrorAction Stop
        }
        
        Execute-MSI -Action 'Install' -Path $destinationPath -Parameters '/quiet /norestart'
        $installSuccess = $true
    } catch {
        Write-Log -Message "[CRITICAL] ✗ MSI deployment fallback failed." -Severity 3
    }
}
