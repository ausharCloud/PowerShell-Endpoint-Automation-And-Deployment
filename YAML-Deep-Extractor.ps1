<#
.SYNOPSIS
Fetches a YAML configuration, parses the version and URL, and extracts nested payloads using 7-Zip.

.DESCRIPTION
Automates the deployment of applications that hide their latest versions in YAML configuration files and use nested zip payloads inside NSIS installers (e.g. app-32.7z inside PLUGINSDIR).
#>

function Get-YamlVersion {
    param([string]$YamlUrl)
    try {
        $response = Invoke-WebRequest -Uri $YamlUrl -UseBasicParsing
        $reader = New-Object System.IO.StreamReader($response.RawContentStream, [System.Text.Encoding]::UTF8)
        $yamlText = $reader.ReadToEnd()
        $reader.Dispose()

        $versionPatterns = @(
            'version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)',
            'url:\s*.*?([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)\.exe'
        )

        $version = $null
        foreach ($pattern in $versionPatterns) {
            if ($yamlText -match $pattern) {
                $version = $matches[1]
                break
            }
        }

        $filename = "Installer.exe"
        if ($yamlText -match 'url:\s*.*?([^/]+\.exe)') {
            $filename = $matches[1]
        }

        if (-not $version) { throw "No version pattern matched in YAML content" }

        return @{ Version = $version; Filename = $filename }
    } catch {
        throw "Failed to fetch YAML: $_"
    }
}

function Extract-NestedInstaller {
    param(
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][string]$OutputFolder,
        [Parameter(Mandatory)][string]$SevenZipPath
    )
    
    $extractedTemp = Join-Path $OutputFolder "ExtractedTemp"
    $appFolder = Join-Path $OutputFolder "App"
    
    if (Test-Path $extractedTemp) { Remove-Item -Path $extractedTemp -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $appFolder) { Remove-Item -Path $appFolder -Recurse -Force -ErrorAction SilentlyContinue }
    
    New-Item -ItemType Directory -Path $extractedTemp -Force | Out-Null
    New-Item -ItemType Directory -Path $appFolder -Force | Out-Null
    
    Write-Host "Extracting main installer archive..."
    $extractProcess = Start-Process -FilePath $SevenZipPath -ArgumentList "x `"$InstallerPath`" -o`"$extractedTemp`" -y" -Wait -PassThru -NoNewWindow
    
    if ($extractProcess.ExitCode -ne 0) { throw "7-Zip extraction failed with exit code $($extractProcess.ExitCode)" }
    
    $nestedArchive = Join-Path $extractedTemp "`$PLUGINSDIR\app-32.7z"
    
    if (Test-Path $nestedArchive) {
        Write-Host "Extracting nested application archive..."
        $nestedProcess = Start-Process -FilePath $SevenZipPath -ArgumentList "x `"$nestedArchive`" -o`"$appFolder`" -y" -Wait -PassThru -NoNewWindow
        
        if ($nestedProcess.ExitCode -ne 0) { throw "7-Zip nested extraction failed with exit code $($nestedProcess.ExitCode)" }
        Remove-Item -Path $extractedTemp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Extraction complete: $appFolder"
    } else {
        throw "Nested archive not found at: $nestedArchive"
    }
}
