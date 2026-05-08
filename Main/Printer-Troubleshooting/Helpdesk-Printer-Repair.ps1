# ==========================================
# PRINTER AI TECHNICIAN TOOLKIT (ONE FILE)
# Windows 10/11 Helpdesk Recovery System
# ==========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =========================
# ADMIN CHECK
# =========================
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    [System.Windows.Forms.MessageBox]::Show(
        "Run as Administrator for full repair functionality.",
        "Printer AI Toolkit",
        "OK",
        "Warning"
    )
}

# =========================
# LOGGING
# =========================
$LogFile = Join-Path $PSScriptRoot "printer-ai.log"

function Write-Log {
    param($msg)
    Add-Content -Path $LogFile -Value "$(Get-Date -Format o) - $msg" -ErrorAction SilentlyContinue
}

# =========================
# CORE AI DIAGNOSTICS ENGINE
# =========================
function Get-SpoolerAIStatus {
    $spooler = Get-Service Spooler -ErrorAction SilentlyContinue
    $proc = Get-Process spoolsv -ErrorAction SilentlyContinue

    $cpu = if ($proc) { ($proc | Measure-Object CPU -Sum).Sum } else { 0 }
    $ram = if ($proc) { [math]::Round($proc.WorkingSet64 / 1MB,2) } else { 0 }

    [pscustomobject]@{
        SpoolerStatus = $spooler.Status
        SpoolsvPID    = if ($proc) { $proc.Id } else { "N/A" }
        CPUTime       = $cpu
        RAM_MB        = $ram
    }
}

function Get-PrinterAIReport {
    $printers = Get-Printer -ErrorAction SilentlyContinue
    $jobs = Get-PrintJob -ErrorAction SilentlyContinue
    $sp = Get-SpoolerAIStatus

    return @(
        "=== PRINTER AI AUDIT ===",
        "Spooler Status: $($sp.SpoolerStatus)",
        "Spoolsv PID: $($sp.SpoolsvPID)",
        "CPU Time: $($sp.CPUTime)",
        "RAM: $($sp.RAM_MB) MB",
        "Printers Installed: $($printers.Count)",
        "Active Jobs: $($jobs.Count)",
        "========================"
    ) -join "`r`n"
}

# =========================
# REPAIR ENGINE (SAFE)
# =========================
function Invoke-FixSpooler {
    Write-Log "Spooler restart"
    Restart-Service Spooler -Force
    return "Spooler restarted successfully."
}

function Invoke-ClearQueue {
    Write-Log "Clearing print queue"
    Get-PrintJob -ErrorAction SilentlyContinue | Remove-PrintJob -ErrorAction SilentlyContinue
    return "Print queue cleared."
}

function Invoke-DeepReset {
    Write-Log "Deep reset started"
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    Remove-Item "$env:windir\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
    Start-Service Spooler
    return "Deep spooler reset completed."
}

function Invoke-DriverPanel {
    Start-Process "printui.exe" "/s /t2"
    return "Opened printer driver manager."
}

function Invoke-RemovePrinters {
    Get-Printer | ForEach-Object {
        Remove-Printer -Name $_.Name -ErrorAction SilentlyContinue
    }
    return "All printers removed (restart recommended)."
}

# =========================
# UI (CLEAN ENTERPRISE STYLE)
# =========================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Printer AI Technician Toolkit"
$form.Size = New-Object System.Drawing.Size(980, 650)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

$title = New-Object System.Windows.Forms.Label
$title.Text = "Printer AI Technician System"
$title.Font = New-Object System.Drawing.Font("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Top = 10
$title.Left = 10
$form.Controls.Add($title)

# Output Box (CLEAN)
$output = New-Object System.Windows.Forms.TextBox
$output.Multiline = $true
$output.ScrollBars = "Vertical"
$output.Font = New-Object System.Drawing.Font("Consolas",10)
$output.Top = 60
$output.Left = 10
$output.Width = 940
$output.Height = 500
$output.ReadOnly = $true
$form.Controls.Add($output)

function Print($msg) {
    $output.AppendText("`r`n$msg")
}

# =========================
# BUTTON STYLE HELP
# =========================
function New-Button($text,$x,$y,$action) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Left = $x
    $b.Top = $y
    $b.Width = 180
    $b.Height = 30
    $b.Add_Click($action)
    $form.Controls.Add($b)
}

# =========================
# ACTIONS PANEL
# =========================
New-Button "AI Printer Audit" 10 30 {
    Print (Get-PrinterAIReport)
}

New-Button "Restart Spooler" 200 30 {
    Print (Invoke-FixSpooler)
}

New-Button "Clear Queue" 390 30 {
    Print (Invoke-ClearQueue)
}

New-Button "Deep Reset Fix" 580 30 {
    Print (Invoke-DeepReset)
}

New-Button "Drivers Panel" 770 30 {
    Print (Invoke-DriverPanel)
}

New-Button "Remove All Printers" 10 570 {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Remove ALL printers?",
        "Confirm Action",
        "YesNo",
        "Warning"
    )
    if ($confirm -eq "Yes") {
        Print (Invoke-RemovePrinters)
    }
}

# =========================
# AUTO START REPORT
# =========================
Print "Printer AI Toolkit Loaded..."
Print "Run 'AI Printer Audit' to analyze system."

Write-Log "Toolkit started"

# =========================
# RUN
# =========================
[void]$form.ShowDialog()
