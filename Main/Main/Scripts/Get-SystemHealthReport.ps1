Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "System Info Report"
$form.Size = New-Object System.Drawing.Size(700, 600)
$form.StartPosition = "CenterScreen"

# Create a multiline TextBox for output
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.WordWrap = $true
$textBox.ReadOnly = $true
$textBox.Dock = "Fill"
$form.Controls.Add($textBox)

# Create a panel for buttons
$panel = New-Object System.Windows.Forms.Panel
$panel.Height = 40
$panel.Dock = "Top"
$form.Controls.Add($panel)

# Run Report button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Report"
$btnRun.Width = 100
$btnRun.Left = 10
$btnRun.Top = 5
$panel.Controls.Add($btnRun)

# Schedule Daily Report button
$btnSchedule = New-Object System.Windows.Forms.Button
$btnSchedule.Text = "Schedule Daily Report"
$btnSchedule.Width = 150
$btnSchedule.Left = 120
$btnSchedule.Top = 5
$panel.Controls.Add($btnSchedule)

# Function: Run your existing report logic and output text to the TextBox
function Run-SystemReportInteractive {
    # Clear previous output
    $textBox.Clear()
    $textBox.AppendText("Gathering system information..." + [Environment]::NewLine)

    # Use your existing script logic here but replace Write-Host with $textBox.AppendText

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        if ($os -and $os.LastBootUpTime) {
            try {
                $bootTime = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
                $uptime = (Get-Date) - $bootTime
            }
            catch {
                $textBox.AppendText("Failed to convert LastBootUpTime to DateTime.`n")
                $uptime = $null
            }
        }
        else {
            $textBox.AppendText("LastBootUpTime property not found or empty.`n")
            $uptime = $null
        }

        $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $ram = Get-CimInstance -ClassName Win32_ComputerSystem
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        $netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

        # Event log scanning
        $textBox.AppendText("Scanning event logs for errors and warnings in last 48 hours..." + [Environment]::NewLine)
        $startTime = (Get-Date).AddHours(-48)
        $systemEvents = Get-WinEvent -LogName System -ErrorAction SilentlyContinue | Where-Object { $_.TimeCreated -ge $startTime -and ($_.LevelDisplayName -eq 'Error' -or $_.LevelDisplayName -eq 'Warning') }
        $appEvents = Get-WinEvent -LogName Application -ErrorAction SilentlyContinue | Where-Object { $_.TimeCreated -ge $startTime -and ($_.LevelDisplayName -eq 'Error' -or $_.LevelDisplayName -eq 'Warning') }

        # Display some summary info
        $textBox.AppendText("OS: $($os.Caption) Build $($os.BuildNumber) Version $($os.Version)`n")
        $textBox.AppendText("CPU: $($cpu.Name)`n")
        $textBox.AppendText("RAM: $([math]::Round($ram.TotalPhysicalMemory / 1GB,2)) GB`n")
        if ($uptime) {
            $textBox.AppendText("System Uptime: $([int]$uptime.TotalDays) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes`n")
        } else {
            $textBox.AppendText("System Uptime: Unknown`n")
        }

        # Show disk info
        $textBox.AppendText("Disks:`n")
        foreach ($disk in $disks) {
            $sizeGB = [math]::Round($disk.Size / 1GB,2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB,2)
            $textBox.AppendText("  Drive $($disk.DeviceID): $sizeGB GB total, $freeGB GB free, FileSystem: $($disk.FileSystem)`n")
        }

        # Show network adapters
        $textBox.AppendText("Network Adapters (Up):`n")
        foreach ($adapter in $netAdapters) {
            $textBox.AppendText("  Name: $($adapter.Name), MAC: $($adapter.MacAddress)`n")
        }

        # Show recent errors summary
        $textBox.AppendText("Recent System Errors (last 48 hours): " + $systemEvents.Count + "`n")
        foreach ($evt in $systemEvents | Select-Object -First 10) {
            $textBox.AppendText("  [$($evt.TimeCreated)] ID:$($evt.Id) Source:$($evt.ProviderName) Message: $($evt.Message.Substring(0,[Math]::Min(150,$evt.Message.Length)))`n")
        }

        # You can implement interactive fix dialogs with MessageBox here if needed
        # For example:
        foreach ($evt in $systemEvents + $appEvents) {
            # Simplified example for an error with Event ID 55 (NTFS corruption)
            if ($evt.Id -eq 55) {
                $result = [System.Windows.Forms.MessageBox]::Show("NTFS file system corruption detected in event $($evt.Id). Would you like to schedule chkdsk on reboot?","Auto-fix suggestion",[System.Windows.Forms.MessageBoxButtons]::YesNo)
                if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                    try {
                        fsutil dirty set C:
                        $textBox.AppendText("Chkdsk scheduled for next reboot on C: drive.`n")
                    }
                    catch {
                        $textBox.AppendText("Failed to schedule chkdsk: $_`n")
                    }
                }
            }
        }

        $textBox.AppendText("Report generation complete.`n")

    }
    catch {
        $textBox.AppendText("Failed to gather system info: $_`n")
    }
}

# Schedule Task Registration simplified for GUI
function Register-DailyReportTask {
    $taskName = "DailySystemInfoReport"
    $scriptPath = $MyInvocation.MyCommand.Path

    if ([string]::IsNullOrEmpty($scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Cannot determine script path. Scheduled task registration aborted.","Error")
        return
    }

    if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
        $dailyReportPath = "$env:USERPROFILE\Desktop\SystemReport_Daily.txt"
        $arg = "-NoProfile -WindowStyle Hidden -File `"$scriptPath`" -OutputPath `"$dailyReportPath`""
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
        $trigger = New-ScheduledTaskTrigger -Daily -At 8am
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Generates daily system info report" -Force | Out-Null
        [System.Windows.Forms.MessageBox]::Show("Scheduled daily system report at 8 AM.","Success")
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Scheduled task '$taskName' already exists.","Info")
    }
}

# Button event handlers
$btnRun.Add_Click({ Run-SystemReportInteractive })
$btnSchedule.Add_Click({ Register-DailyReportTask })

# Show the form
[void]$form.ShowDialog()
