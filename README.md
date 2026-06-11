# 💻 Advanced PowerShell & PSADT Packaging

This directory contains a collection of highly advanced PowerShell scripts, custom functions, and PowerShell App Deployment Toolkit (PSADT) packages. Over my career, I have successfully packaged **77+ enterprise applications**, ranging from simple MSIs to incredibly complex legacy software requiring custom reverse-engineering.

### 📜 Highlighted Scripts

#### Zero-Touch & OS Deployment
- **`Win11-ZeroTouch-Upgrader.ps1`**: An advanced, zero-touch Windows 11 upgrade script that fully bypasses TPM, CPU, RAM, and Storage checks. It dynamically writes bypasses to `HKLM\SYSTEM\Setup\LabConfig`, generates a custom `unattend.xml` answer file on the fly, and hex-edits `setupconfig.dat` to spoof a "Server" installation environment.

#### Advanced Registry & Payload Delivery
- **`Offline-Registry-Mounter.ps1`**: A function designed to natively iterate over every user profile on a system, explicitly load offline `ntuser.dat` hives for logged-out profiles and the Default profile via `reg load`, inject configuration, and cleanly unload the hives with garbage collection.
- **`YAML-Deep-Extractor.ps1`**: Automates the deployment of nested payloads by fetching and parsing a live YAML configuration via Regex, downloading the installer, and feeding it to `7z.exe` twice to locate and extract a hidden `.7z` payload deep inside the NSIS `PLUGINSDIR`.

#### PSADT Packaging Masterclasses
- **`Wrapperless-NSIS-Deployer.ps1`**: Bypasses mandatory GUI installers by reverse-engineering NSIS payloads. Uses 7-Zip to extract internal archives to user profiles and fabricates completely custom "Add/Remove Programs" registry entries to spoof a system-wide installation.
- **`Dynamic-InstallShield-Uninstaller.ps1`**: Brilliantly bypasses legacy InstallShield uninstaller limitations. It dynamically discovers the application's `ProductGuid` and `DisplayVersion` from the registry and builds a custom InstallShield Answer File (`.iss`) line-by-line on the fly to force a silent uninstallation.
- **`AppX-Provisioning-Workflow.ps1`**: A bulletproof deployment workflow for AppX packages. Provisions system-wide, registers for all logged-in users, and features dynamic fallback to downloading the latest legacy MSI version directly from a parsed vendor JSON manifest if the AppX install fails.
- **`Nutrikids-POS-GUI-Installer.ps1`**: A fully DPI-aware, dynamically scaling Windows Forms GUI built entirely in native PowerShell (no XAML) to standardize the installation of archaic, multi-component POS software.
- **`Salesforce-Aura-Scraper.ps1`**: A raw Salesforce Aura API scraper built in PowerShell that extracts direct installer URLs from vendor portals, entirely skipping manual downloads.
