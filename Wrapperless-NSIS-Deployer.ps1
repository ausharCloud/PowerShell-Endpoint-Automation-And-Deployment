<#
.SYNOPSIS
A completely "wrapperless" deployment script that reverse-engineers an NSIS installer.

.DESCRIPTION
This script was engineered to deploy Cricut Design Space silently across a massive fleet, completely bypassing the vendor's required GUI installer. It:
1. Queries the vendor's undocumented JSON APIs to generate signed download URLs.
2. Uses 7-Zip to silently extract the NSIS installer.
3. Locates a hidden `$PLUGINSDIR\app-32.7z` archive nested inside the extracted files.
4. Extracts that secondary archive directly.
5. Injects the raw application files directly into every existing user profile's AppData folder via `Copy-FileToUserProfiles`.
6. Spoofs a complete machine-wide installation by fabricating custom "Add/Remove Programs" registry entries from scratch.
#>

# --- Config ---
$sevenZipPath = "$dirFiles\7z.exe"  

# --- Step 1: Download latest installer via undocumented API ---
try {
	Write-Log "📥 Downloading latest Cricut Design Space installer..."
	
	Add-Type -AssemblyName System.Web
	
	# Step 1: Get signed latest.json URL
	Write-Log "   Getting latest version metadata..."
	$updateJsonUrl = "https://apis.cricut.com/desktopdownload/UpdateJson?operatingSystem=win32native&shard=a"
	$updateJsonResponse = Invoke-RestMethod -Uri $updateJsonUrl
	$latestJsonUrl = [System.Web.HttpUtility]::HtmlDecode($updateJsonResponse.result)
	
	# Step 2: Get metadata from latest.json
	Write-Log "   Fetching installer details..."
	$metadata = Invoke-RestMethod -Uri $latestJsonUrl
	$installerFile = $metadata.rolloutUpdateFile
	Write-Log "   Latest installer: $installerFile"
	
	# Step 3: Get signed installer URL
	Write-Log "   Retrieving signed download URL..."
	$installerApiUrl = "https://apis.cricut.com/desktopdownload/InstallerFile?fileName=$installerFile&operatingSystem=win32native&shard=a"
	$installerResponse = Invoke-RestMethod -Uri $installerApiUrl
	$signedInstallerUrl = [System.Web.HttpUtility]::HtmlDecode($installerResponse.result)
	
	# Step 4: Download the installer
	$outputPath = Join-Path $dirFiles $installerFile
	
	if (Test-Path $outputPath) {
		$existingSize = (Get-Item $outputPath).Length
		if ($existingSize -ge 50000000) {
			Write-Log "✅ Using existing installer, skipping download"
		} else {
			Remove-Item -Path $outputPath -Force -ErrorAction SilentlyContinue
			$wc = New-Object System.Net.WebClient
			$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
			$wc.Headers.Add("Referer", "https://design.cricut.com/")
			$wc.DownloadFile($signedInstallerUrl, $outputPath)
		}
	} else {
		$wc = New-Object System.Net.WebClient
		$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
		$wc.Headers.Add("Referer", "https://design.cricut.com/")
		$wc.DownloadFile($signedInstallerUrl, $outputPath)
	}
} catch {
	Write-Log "❌ Failed to download installer: $_"
	Exit-Script -ExitCode 1
}

# --- Step 2: Reverse-engineer and extract the NSIS installer ---
try {
	Write-Log "📦 Extracting NSIS installer using 7-Zip..."
	
	$tempExtractPath = Join-Path $dirFiles "temp_extract"
	New-Item -Path $tempExtractPath -ItemType Directory -Force | Out-Null
	
	# Extract the NSIS installer to get $PLUGINSDIR
	$extractArgs = "x `"$outputPath`" -o`"$tempExtractPath`" -y"
	$extractProcess = Start-Process -FilePath $sevenZipPath -ArgumentList $extractArgs -Wait -PassThru -NoNewWindow
	
	# Find the hidden $PLUGINSDIR folder
	$pluginsDir = Join-Path $tempExtractPath "`$PLUGINSDIR"
	
	# Find the nested app-32.7z archive inside $PLUGINSDIR
	$app7z = Get-ChildItem -Path $pluginsDir -Filter "app-*.7z" | Select-Object -First 1
	
	# Extract the nested archive to final destination
	$finalExtractPath = Join-Path $dirFiles "Cricut Design Space"
	New-Item -Path $finalExtractPath -ItemType Directory -Force | Out-Null
	
	$appExtractArgs = "x `"$($app7z.FullName)`" -o`"$finalExtractPath`" -y"
	$appExtractProcess = Start-Process -FilePath $sevenZipPath -ArgumentList $appExtractArgs -Wait -PassThru -NoNewWindow
	
	# Clean up temp extraction folder
	Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
	
} catch {
	Write-Log "❌ Extraction failed: $_"
	Exit-Script -ExitCode 1
}

# --- Step 3: Wrapperless Injection into User Profiles ---
try {
	Write-Log "📂 Injecting raw application files into all user profiles..."
	Copy-FileToUserProfiles -Path "$dirFiles\Cricut Design Space" -Destination "appdata\local\Programs" -Recurse
} catch {
	Write-Log "❌ Deployment to user profiles failed: $_"
	Exit-Script -ExitCode 1
}

# --- Step 4: Fabricate Machine-Wide Registry Entries ---
try {
	Write-Log "📋 Spoofing 'Add/Remove Programs' registry entries for uninstall support..."
	
	# Extract version from installer filename
	$installerFileName = Split-Path $outputPath -Leaf
	$versionMatch = $installerFileName -match 'v(\d+\.\d+\.\d+)'
	$displayVersion = if ($versionMatch) { $Matches[1] } else { "Unknown" }
			
	$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Cricut Design Space"
	$installLocation = "C:\users\default\appdata\local\programs\Cricut Design Space"
	$uninstallString = "c:\windows\temp\cricut\Deploy-Application.exe -DeploymentType Uninstall"
	$displayIcon = "$installLocation\Cricut Design Space.exe"
	$publisher = "Cricut, Inc."
	$installDate = (Get-Date).ToString("yyyyMMdd")
	
	New-Item -Path $regPath -Force | Out-Null
	Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "Cricut Design Space"
	Set-ItemProperty -Path $regPath -Name "DisplayVersion" -Value $displayVersion
	Set-ItemProperty -Path $regPath -Name "Publisher" -Value $publisher
	Set-ItemProperty -Path $regPath -Name "InstallLocation" -Value $installLocation
	Set-ItemProperty -Path $regPath -Name "UninstallString" -Value $uninstallString
	Set-ItemProperty -Path $regPath -Name "DisplayIcon" -Value "$displayIcon,0"
	Set-ItemProperty -Path $regPath -Name "InstallDate" -Value $installDate
	
} catch {
	Write-Log "⚠️ Registry setup encountered an issue: $_"
}
