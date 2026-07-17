<#
.SYNOPSIS
Applies POS SQL registry settings to ALL user profiles on the machine.

.DESCRIPTION
This script iterates over every user profile on the machine:
- For currently logged-in users, it uses the live HKEY_USERS hive.
- For logged-out users, it temporarily mounts their ntuser.dat hive.
- For the Default user profile, it mounts the default ntuser.dat to ensure all future users inherit the settings.
#>

$Script:POSSQLRegBasePath = 'Software\VB and VBA Program Settings\POSSQL\Settings'
$Script:POSSQLRegValues = @{
    'DB'         = ''
    'PORT'       = ''
    'PWD'        = ''
    'SERVER'     = ''
    'SQLEOD'     = ''
    'SQLRefresh' = ''
    'UID'        = ''
}

function Set-POSRegKeys {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RegistryPath
    )

    try {
        if (-not (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }

        foreach ($valueName in $Script:POSSQLRegValues.Keys) {
            Set-ItemProperty -Path $RegistryPath -Name $valueName -Value $Script:POSSQLRegValues[$valueName] -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Failed to apply registry values at '$RegistryPath'."
    }
}

function Set-POSRegKeysAllProfiles {
    $currentPrincipal = [System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Administrator privileges required. Aborting registry update."
        return
    }

    $loadedSids = (Get-ChildItem 'Registry::HKEY_USERS' | Where-Object { $_.Name -match 'S-1-5-21-' }).PSChildName
    $allProfiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_.LocalPath -notlike '*\AppData*' }

    foreach ($profile in $allProfiles) {
        $sid         = $profile.SID
        $profilePath = $profile.LocalPath
        $hivePath    = Join-Path -Path $profilePath -ChildPath 'ntuser.dat'

        if ($loadedSids -contains $sid) {
            # User is currently logged in. Using live registry hive.
            $fullRegPath = "Registry::HKEY_USERS\$sid\$Script:POSSQLRegBasePath"
            Set-POSRegKeys -RegistryPath $fullRegPath
        }
        elseif (Test-Path $hivePath) {
            # User is logged out. Loading ntuser.dat.
            $tempHiveKey  = 'HKU\TempNKHive'
            $tempHivePSPath = 'Registry::HKEY_USERS\TempNKHive'

            try {
                reg load $tempHiveKey $hivePath | Out-Null
                $fullRegPath = "$tempHivePSPath\$Script:POSSQLRegBasePath"
                Set-POSRegKeys -RegistryPath $fullRegPath
            }
            finally {
                [GC]::Collect()
                Start-Sleep -Seconds 1
                reg unload $tempHiveKey | Out-Null
            }
        }
    }

    # Process Default User (applied to all future new accounts)
    $defaultHivePath = 'C:\Users\Default\ntuser.dat'
    if (Test-Path $defaultHivePath) {
        $tempHiveKey    = 'HKU\DefaultNKHive'
        $tempHivePSPath = 'Registry::HKEY_USERS\DefaultNKHive'

        try {
            reg load $tempHiveKey $defaultHivePath | Out-Null
            $fullRegPathDefault = "$tempHivePSPath\$Script:POSSQLRegBasePath"
            Set-POSRegKeys -RegistryPath $fullRegPathDefault
        }
        finally {
            [GC]::Collect()
            Start-Sleep -Seconds 1
            reg unload $tempHiveKey | Out-Null
        }
    }
}
