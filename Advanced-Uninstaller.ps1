<#
.SYNOPSIS
Searches the Windows Registry for installed applications matching a given name and extracts uninstall information.

.DESCRIPTION
This function scans HKLM (64-bit and 32-bit) and the current user's HKU registry hive to find software entries.
It retrieves display names, install locations, and uninstall strings (both interactive and quiet).

.PARAMETER AppName
The name (or partial name) of the application to search for. Defaults to "*" for all applications.

.PARAMETER ShowDetails
If enabled, the function splits the executable from its arguments to display parsed uninstall commands.

.EXAMPLE
Get-UninstallInfo -AppName "Google Chrome" -ShowDetails
#>
function Get-UninstallInfo {
    param (
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$AppName = "*", # Default to all apps if no name is provided

        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails # Optional: Show parsed executable and adjusted arguments
    )

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $loggedInUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
    $loggedInSID = (New-Object System.Security.Principal.NTAccount($loggedInUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    $paths += "Registry::HKEY_USERS\$loggedInSID\Software\Microsoft\Windows\CurrentVersion\Uninstall"

    Write-Host "`n--- Found Applications Matching '$AppName' ---`n"

    foreach ($path in $paths) {
        Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $app = Get-ItemProperty $_.PSPath
                if ($app.DisplayName -and $app.DisplayName -like "*$AppName*") {
                    Write-Host "Display Name: $($app.DisplayName)"
                    Write-Host "Registry Path: $($_.PSPath)"
                    if ($app.InstallLocation) { Write-Host "Install Location: $($app.InstallLocation)" }
                    if ($app.QuietUninstallString) { Write-Host "QuietUninstallString: $($app.QuietUninstallString)" }
                    if ($app.UninstallString) { Write-Host "UninstallString: $($app.UninstallString)" }

                    if ($ShowDetails -and $app.UninstallString) {
                        $exe, $args = $app.UninstallString -split "\s+", 2
                        Write-Host "Parsed Executable: $exe"
                        Write-Host "Arguments: $args"
                    }

                    Write-Host "----------------------------------------------------`n"
                }
            } catch {
                Write-Warning "Could not read registry key: $($_.PSPath)"
            }
        }
    }
}

<#
.SYNOPSIS
Silently uninstalls an application by dynamically locating its uninstall string in the Windows Registry.

.DESCRIPTION
This function automatically translates interactive MSI uninstall strings (using /i) to silent removal strings (/x /qn).
For other installers, it intelligently parses the executable path and arguments, executing them silently.

.PARAMETER AppName
The precise or partial name of the application to remove.

.EXAMPLE
Uninstall-Application -AppName "Adobe Acrobat"
#>
function Uninstall-Application {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $uninstallPaths) {
        $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue

        foreach ($key in $keys) {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -like "*$AppName*" -and $props.UninstallString) {
                $uninstallString = $props.UninstallString.Trim()
                Write-Host "`nFound: $($props.DisplayName)"
                Write-Host "Original Uninstall String: $uninstallString"

                # Adjust for msiexec
                if ($uninstallString -match 'msiexec\.exe') {
                    $uninstallString = $uninstallString -replace '/i', '/x'
                    if ($uninstallString -notmatch '/x') {
                        $uninstallString += " /x"
                    }
                    if ($uninstallString -notmatch '/qn') {
                        $uninstallString += " /qn"
                    }
                }

                # Extract executable and arguments
                $pattern = '^(?:"(?<exe>[^"]+)"|(?<exe>\S+))(?:\s+(?<args>.*))?'

                if ($uninstallString -match $pattern) {
                    $exe = $matches['exe']
                    $args = $matches['args']
                    Write-Host "Running: $exe $args"
                    Start-Process -FilePath $exe -ArgumentList $args -Wait
                } else {
                    Write-Warning "Unrecognized uninstall string format: $uninstallString"
                }
            }
        }
    }
}
