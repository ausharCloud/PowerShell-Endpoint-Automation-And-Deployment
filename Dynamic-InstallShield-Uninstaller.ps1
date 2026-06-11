<#
.SYNOPSIS
A script that brilliantly bypasses the limitations of legacy InstallShield uninstallers by dynamically generating an Answer File (.iss) on the fly.

.DESCRIPTION
To silently uninstall previous versions of legacy software (like ScanSnap), it is normally required to provide a pre-recorded `.iss` answer file. This becomes impossible when managing hundreds of different unknown versions across a fleet.
This script dynamically discovers the application's `ProductGuid` and `DisplayVersion` from the registry, then builds a custom InstallShield Answer File line-by-line on the fly. This dynamically generated `.iss` file is then fed into the discovered uninstaller using `-s -f1` parameters to force a completely silent, automated uninstallation without requiring any static pre-recorded answer files.
#>

## Remove Any Existing Version of Fujitsu ScanSnap
$AppList = Get-InstalledApplication -Name 'ScanSnap Home'        
ForEach ($App in $AppList)
{
    If($App.UninstallString)
    {
        $GUID = $App.ProductGuid   
        
        # Discover the hidden InstallShield uninstaller executable and setup.ini
        $INI = Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$($GUID)\*" -Include setup.ini -Recurse -ErrorAction SilentlyContinue
        $UninstPath = Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$($GUID)\*" -Include WinSSHomeInstaller*.exe -Recurse -ErrorAction SilentlyContinue
        
        If(($INI.Exists) -and ($UninstPath.Exists))
        {
            Write-Log -Message "Found $($UninstPath.FullName), now attempting to uninstall."
            $ScanSnap = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty | Where-Object {$_.DisplayName -match 'ScanSnap Home' } | Select-Object -Property DisplayName, DisplayVersion, ProductGuid
            
            ## Dynamically generate a custom InstallShield Answer File (.iss) line-by-line using the discovered GUID and Version
            $ISS = "C:\Windows\Temp\uninstall.iss"
            New-Item -Path "$ISS" -Force
            Set-Content -Path "$ISS" -Value "[InstallShield Silent]"
            Add-Content -Path "$ISS" -Value "Version=v7.00"
            Add-Content -Path "$ISS" -Value "File=Response File"
            Add-Content -Path "$ISS" -Value "[File Transfer]"
            Add-Content -Path "$ISS" -Value "OverwrittenReadOnly=NoToAll"
            Add-Content -Path "$ISS" -Value "[$($ScanSnap.ProductGuid)-DlgOrder]"
            Add-Content -Path "$ISS" -Value "Dlg0=$($ScanSnap.ProductGuid)-MessageBox-0"
            Add-Content -Path "$ISS" -Value "Count=2"
            Add-Content -Path "$ISS" -Value "Dlg1=$($ScanSnap.ProductGuid)-SdFinishReboot-0"
            Add-Content -Path "$ISS" -Value "[$($ScanSnap.ProductGuid)-MessageBox-0]"
            Add-Content -Path "$ISS" -Value "Result=6"
            Add-Content -Path "$ISS" -Value "[Application]"
            Add-Content -Path "$ISS" -Value "Name=ScanSnap Home"
            Add-Content -Path "$ISS" -Value "Version=$($ScanSnap.DisplayVersion)"
            Add-Content -Path "$ISS" -Value "Company=PFU"
            Add-Content -Path "$ISS" -Value "Lang=0411"
            Add-Content -Path "$ISS" -Value "[$($ScanSnap.ProductGuid)-SdFinishReboot-0]"
            Add-Content -Path "$ISS" -Value "Result=1"
            Add-Content -Path "$ISS" -Value "BootOption=0"
            
            Start-Sleep -Seconds 5
            
            # Execute the uninstaller silently by feeding it the dynamically generated Answer File
            Execute-Process -Path "$UninstPath" -Parameters "UNINSTALL -removeonly -s -f1""$ISS"" -f2""C:\Windows\Logs\Software\FujitsuScanSnap-Uninstall.log""" -WindowStyle Hidden
            
            Start-Sleep -Seconds 5
        }
    }
}
