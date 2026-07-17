<#
.SYNOPSIS
A fully DPI-aware, dynamically scaling Windows Forms GUI built entirely in PowerShell for a complex Point-of-Sale (POS) suite.

.DESCRIPTION
This script demonstrates advanced GUI creation without XAML or external binaries. 
It features DPI awareness, dynamic layout scaling relative to screen width, and complex event handling.
It was engineered to wrap an archaic, multi-component POS software suite (Nutrikids) that lacked silent installers, allowing field technicians to simply check boxes for the required components and deploy them cleanly.
#>

# ---------------------------------------------------------------------------
# DPI awareness — tell Windows this process handles DPI itself so we get
# real logical pixels (not the virtualized 96-DPI bitmap-scaled ones)
# ---------------------------------------------------------------------------
try {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class NKDpi {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@ -ErrorAction SilentlyContinue
    [NKDpi]::SetProcessDPIAware() | Out-Null
} catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# Layout constants — form width scales with screen, everything derives from it
# ---------------------------------------------------------------------------
$screenW  = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width
$F_WIDTH  = [Math]::Max(560, [Math]::Min(1400, [int]($screenW * 0.45)))
$F_MARGIN = 20
$F_INNER  = $F_WIDTH - ($F_MARGIN * 2)
$COL1     = $F_MARGIN
$COL2     = $F_MARGIN + [int]($F_INNER / 2) + 6
$BTN_W    = [int]($F_INNER / 2) - 6

# sc: sqrt-damped scale factor. Baseline 560px=1.0, at 1400px=1.58
$BASE_W = 560.0
$sc     = [Math]::Max(1.0, [Math]::Sqrt($F_WIDTH / $BASE_W))

# ---------------------------------------------------------------------------
# Colours & Fonts
# ---------------------------------------------------------------------------
$cBg      = [System.Drawing.Color]::FromArgb(245, 245, 245)
$cBlue    = [System.Drawing.Color]::FromArgb(0, 114, 198)
$cWhite   = [System.Drawing.Color]::White

$fSzTitle  = [float]([Math]::Max(11, [int](11 * $sc)))
$fSzBtn    = [float]([Math]::Max( 9, [int]( 9 * $sc)))
$fTitle    = New-Object System.Drawing.Font('Segoe UI', $fSzTitle,  [System.Drawing.FontStyle]::Bold)
$fBtn      = New-Object System.Drawing.Font('Segoe UI', $fSzBtn)

$textH = [System.Windows.Forms.TextRenderer]::MeasureText('Mg', $fBtn).Height
$BTN_H = $textH + [int](14 * $sc)

# ---------------------------------------------------------------------------
# Helper: New-Btn
# ---------------------------------------------------------------------------
function New-Btn {
    param (
        [string]$Text, [int]$X, [int]$Y, [int]$W = $BTN_W, [int]$H = $BTN_H,
        [System.Drawing.Color]$Color, [System.Drawing.Font]$Font = $fBtn
    )
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $Text
    $b.Location  = New-Object System.Drawing.Point($X, $Y)
    $b.Size      = New-Object System.Drawing.Size($W, $H)
    $b.Font      = $Font
    $b.BackColor = $Color
    $b.ForeColor = $cWhite
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    return $b
}

# ---------------------------------------------------------------------------
# Main Form Assembly
# ---------------------------------------------------------------------------
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text            = 'Archaic POS Updater GUI'
$mainForm.StartPosition   = 'CenterScreen'
$mainForm.FormBorderStyle = 'FixedDialog'
$mainForm.MaximizeBox     = $false
$mainForm.BackColor       = $cBg
$mainForm.Size            = New-Object System.Drawing.Size($F_WIDTH, 400)

$lblTitle          = New-Object System.Windows.Forms.Label
$lblTitle.Text     = 'POS Modular Installer Tool'
$lblTitle.Font     = $fTitle
$lblTitle.Location = New-Object System.Drawing.Point($F_MARGIN, 20)
$lblTitle.AutoSize = $true

$btnInstall = New-Btn -Text 'Install / Update All Components' -X $F_MARGIN -Y 100 -W $F_INNER -H $BTN_H -Color $cBlue
$btnInstall.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Initiating complex multi-component installation routine...", "Installer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$mainForm.Controls.AddRange(@($lblTitle, $btnInstall))

$mainForm.Activate()
[void]$mainForm.ShowDialog()
