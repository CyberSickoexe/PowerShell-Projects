#requires -Version 5.1
param([string]$OutputPath)

function Add-UIAssembly {
    param([string]$Name)
    if (-not [AppDomain]::CurrentDomain.GetAssemblies().Name -contains $Name) {
        Add-Type -AssemblyName $Name
    }
}

Add-UIAssembly 'System.Windows.Forms'
Add-UIAssembly 'System.Drawing'
Add-UIAssembly 'System.Windows.Forms.DataVisualization'

function New-Button {
    param(
        [string]$Text,
        [int]$Left = 0,
        [int]$Top = 0,
        [int]$Width = 100
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Left = $Left
    $button.Top = $Top
    $button.Width = $Width
    return $button
}

function New-TextBox {
    param(
        [bool]$Multiline = $false,
        [string]$FontName = 'Consolas',
        [int]$FontSize = 10,
        [bool]$ReadOnly = $false
    )
    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline = $Multiline
    $box.Font = New-Object System.Drawing.Font($FontName, $FontSize)
    $box.ReadOnly = $ReadOnly
    $box.ScrollBars = 'Both'
    return $box
}

function New-Grid {
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = 'Fill'
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AutoGenerateColumns = $true
    $grid.AutoSizeColumnsMode = 'Fill'
    $grid.SelectionMode = 'FullRowSelect'
    $grid.MultiSelect = $false
    return $grid
}

function Update-Status {
    param([string]$Message)
    $statusLabel.Text = $Message
}

function Get-ProcessesSafe {
    try {
        Get-Process -ErrorAction Stop |
            Sort-Object CPU -Descending |
            Select-Object -First 100 |
            ForEach-Object {
                [PSCustomObject]@{
                    Id = $_.Id
                    Name = $_.ProcessName
                    CPU = [math]::Round($_.CPU, 2)
                    RAM_MB = [math]::Round($_.WorkingSet64 / 1MB, 1)
                    Handles = $_.Handles
                    Threads = $_.Threads.Count
                }
            }
    } catch {
        Write-Warning "Unable to collect process information: $($_.Exception.Message)"
        return @()
    }
}

function Get-NetworkSnapshot {
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Select-Object Name, Status, MacAddress, LinkSpeed
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Select-Object InterfaceAlias, IPAddress
        $dns = Get-DnsClientServerAddress -ErrorAction Stop | Select-Object InterfaceAlias, @{Name='ServerAddresses';Expression={[string]::Join(', ', $_.ServerAddresses)}}
        $routes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Select-Object InterfaceAlias, NextHop

        return [PSCustomObject]@{
            Adapters = $adapters
            IP = $ip
            DNS = $dns
            Gateway = $routes
        }
    } catch {
        return [PSCustomObject]@{
            Adapters = @()
            IP = @()
            DNS = @()
            Gateway = @()
            Error = $_.Exception.Message
        }
    }
}

$script:NetworkBaselineFile = Join-Path -Path $PSScriptRoot -ChildPath 'network-baseline.json'

function Get-NetworkConnectionsAdvanced {
    $connections = Get-NetTCPConnection -ErrorAction SilentlyContinue |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                LocalAddress  = $_.LocalAddress
                LocalPort     = $_.LocalPort
                RemoteAddress = $_.RemoteAddress
                RemotePort    = $_.RemotePort
                State         = $_.State
                PID           = $_.OwningProcess
                ProcessName   = if ($proc) { $proc.ProcessName } else { 'UNKNOWN' }
                Path          = if ($proc) { $proc.Path } else { 'N/A' }
            }
        }

    return $connections | Sort-Object State, ProcessName
}

function Resolve-DNSForensics {
    param([string]$Host)

    $result = [PSCustomObject]@{
        Host = $Host
        ARecords = @()
        AAAARecords = @()
        CNAME = @()
        DNSResolvers = @()
        Errors = @()
    }

    try {
        $dns = Resolve-DnsName -Name $Host -ErrorAction Stop
        $result.ARecords = ($dns | Where-Object Type -eq 'A').IPAddress
        $result.AAAARecords = ($dns | Where-Object Type -eq 'AAAA').IPAddress
        $result.CNAME = ($dns | Where-Object Type -eq 'CNAME').NameHost
    } catch {
        $result.Errors += $_.Exception.Message
    }

    $servers = Get-DnsClientServerAddress -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty ServerAddresses |
        ForEach-Object { $_ } | Sort-Object -Unique

    foreach ($server in $servers) {
        if (-not $server) { continue }
        try {
            $serverDns = Resolve-DnsName -Name $Host -Server $server -ErrorAction Stop
            $result.DNSResolvers += [PSCustomObject]@{
                Server = $server
                Records = ($serverDns | Select-Object Type, NameHost, IPAddress | ForEach-Object {
                    if ($_.Type -eq 'A' -or $_.Type -eq 'AAAA') { return "${_.Type}: $($_.IPAddress)" }
                    if ($_.Type -eq 'CNAME') { return "${_.Type}: $($_.NameHost)" }
                    return "${_.Type}: $($_.Type)"
                }) -join '; '
                Status = 'OK'
            }
        } catch {
            $result.DNSResolvers += [PSCustomObject]@{
                Server = $server
                Records = $_.Exception.Message
                Status = 'FAIL'
            }
        }
    }

    return $result
}

function Get-TracerouteAnalysis {
    param(
        [string]$Target,
        [int]$Pings = 2
    )

    $trace = tracert -d $Target 2>&1
    $hops = @()
    $previous = 0

    foreach ($line in $trace | Where-Object { $_ -match '^	*\d+' }) {
        $parts = ($line -replace 'ms','') -split '\s+' | Where-Object { $_ -ne '' }
        if ($parts.Count -lt 5) { continue }

        $hop = [int]$parts[0]
        $t1 = $parts[1]
        $t2 = $parts[2]
        $t3 = $parts[3]
        $address = $parts[4]
        $avgPing = $null
        $bottleneck = 'No'

        if ($address -and $address -ne '*') {
            $pingSamples = try {
                Test-Connection -ComputerName $address -Count $Pings -ErrorAction Stop |
                    Select-Object -ExpandProperty ResponseTime
            } catch {
                @()
            }
            if ($pingSamples.Count) {
                $avgPing = [math]::Round(($pingSamples | Measure-Object -Average).Average, 1)
                if ($previous -gt 0 -and ($avgPing - $previous) -gt 30) {
                    $bottleneck = 'Likely'
                }
                $previous = $avgPing
            }
        }

        $hops += [PSCustomObject]@{
            Hop = $hop
            Address = $address
            Probe1 = $t1
            Probe2 = $t2
            Probe3 = $t3
            AvgPingMs = $avgPing
            Bottleneck = $bottleneck
            Raw = $line.Trim()
        }
    }

    return $hops
}

function Find-SuspiciousConnections {
    $ports = 4444,5555,1337,6666,31337
    $suspicious = Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object {
            $_.State -eq 'Established' -and $_.RemotePort -in $ports
        }

    return $suspicious | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Remote = "$($_.RemoteAddress):$($_.RemotePort)"
            State = $_.State
            Process = if ($proc) { $proc.ProcessName } else { 'UNKNOWN' }
            PID = $_.OwningProcess
            Path = if ($proc) { $proc.Path } else { 'N/A' }
        }
    }
}

function Get-NetworkBaseline {
    $baseline = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('o')
        Connections = Get-NetworkConnectionsAdvanced | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, PID, ProcessName
        Listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess
    }

    $baseline | ConvertTo-Json -Depth 4 | Set-Content -Path $script:NetworkBaselineFile -Force
    return $script:NetworkBaselineFile
}

function Compare-NetworkBaseline {
    if (-not (Test-Path $script:NetworkBaselineFile)) {
        return [PSCustomObject]@{
            Status = 'MissingBaseline'
            Message = "Baseline file not found. Use Save-NetworkBaseline to create one."
        }
    }

    $baseline = Get-Content -Path $script:NetworkBaselineFile -Raw | ConvertFrom-Json
    $currentConnections = Get-NetworkConnectionsAdvanced | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, PID, ProcessName
    $baselineConnections = $baseline.Connections | ForEach-Object {
        "$($_.LocalAddress):$($_.LocalPort)->$($_.RemoteAddress):$($_.RemotePort):$($_.State):$($_.ProcessName)"
    }
    $currentKeys = $currentConnections | ForEach-Object {
        "$($_.LocalAddress):$($_.LocalPort)->$($_.RemoteAddress):$($_.RemotePort):$($_.State):$($_.ProcessName)"
    }

    $newConnections = $currentConnections | Where-Object {
        $key = "$($_.LocalAddress):$($_.LocalPort)->$($_.RemoteAddress):$($_.RemotePort):$($_.State):$($_.ProcessName)"
        -not ($baselineConnections -contains $key)
    }
    $missingConnections = $baseline.Connections | Where-Object {
        $key = "$($_.LocalAddress):$($_.LocalPort)->$($_.RemoteAddress):$($_.RemotePort):$($_.State):$($_.ProcessName)"
        -not ($currentKeys -contains $key)
    }

    return [PSCustomObject]@{
        Status = 'Compared'
        BaselineTimestamp = $baseline.Timestamp
        NewConnections = $newConnections
        MissingConnections = $missingConnections
        NewConnectionCount = $newConnections.Count
        MissingConnectionCount = $missingConnections.Count
    }
}

function Run-CommandToBox {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    $output = try { & $Command 2>&1 } catch { $_.Exception.Message }
    $text = if ($output) { $output | Out-String } else { "(no output)" }
    $netBox.AppendText("$Label`r`n")
    $netBox.AppendText($text)
    $netBox.AppendText("`r`n")
}

# Build UI
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Admin Sentinel Enterprise V2'
$form.Size = New-Object System.Drawing.Size(1250, 760)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Spring = $true
$statusStrip.Items.Add($statusLabel) | Out-Null
$form.Controls.Add($statusStrip)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.Top = 0
$form.Controls.Add($tabs)

$panelTop = New-Object System.Windows.Forms.Panel
$panelTop.Height = 50
$panelTop.Dock = 'Top'
$form.Controls.Add($panelTop)

# Process Tab
$tabProc = New-Object System.Windows.Forms.TabPage
$tabProc.Text = 'Processes'
$tabs.TabPages.Add($tabProc)

$procPanel = New-Object System.Windows.Forms.Panel
$procPanel.Height = 40
$procPanel.Dock = 'Top'
$tabProc.Controls.Add($procPanel)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Left = 10
$txtFilter.Top = 10
$txtFilter.Width = 260
$txtFilter.PlaceholderText = 'Filter by process name...'
$procPanel.Controls.Add($txtFilter)

$btnRefresh = New-Button -Text 'Refresh' -Left 280 -Top 7 -Width 100
$procPanel.Controls.Add($btnRefresh)

$btnExportProcesses = New-Button -Text 'Export CSV' -Left 390 -Top 7 -Width 100
$procPanel.Controls.Add($btnExportProcesses)

$gridProcesses = New-Grid
$gridProcesses.Dock = 'Fill'
$tabProc.Controls.Add($gridProcesses)

function Load-Processes {
    $data = Get-ProcessesSafe
    if ($txtFilter.Text.Trim()) {
        $pattern = [regex]::Escape($txtFilter.Text.Trim())
        $data = $data | Where-Object { $_.Name -match $pattern }
    }
    $gridProcesses.DataSource = $data
    Update-Status "Loaded $($data.Count) processes."
}

$btnRefresh.Add_Click({ Load-Processes })
$txtFilter.Add_TextChanged({ Load-Processes })
$btnExportProcesses.Add_Click({
    if (-not $gridProcesses.DataSource) { return }
    $exportPath = Join-Path -Path $PSScriptRoot -ChildPath "process-list_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $gridProcesses.DataSource | Export-Csv -Path $exportPath -NoTypeInformation -Force
    Update-Status "Processes exported to $exportPath"
})

# Performance Tab
$tabPerf = New-Object System.Windows.Forms.TabPage
$tabPerf.Text = 'Performance'
$tabs.TabPages.Add($tabPerf)

$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Dock = 'Fill'
$tabPerf.Controls.Add($chart)

$area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$area.AxisX.Title = 'Samples'
$area.AxisY.Title = 'Usage %'
$area.AxisY.Minimum = 0
$area.AxisY.Maximum = 100
$chart.ChartAreas.Add($area)

$cpuSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
$cpuSeries.Name = 'CPU'
$cpuSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$cpuSeries.Color = [System.Drawing.Color]::Tomato
$cpuSeries.BorderWidth = 2

$ramSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
$ramSeries.Name = 'RAM'
$ramSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$ramSeries.Color = [System.Drawing.Color]::RoyalBlue
$ramSeries.BorderWidth = 2

$chart.Series.Add($cpuSeries)
$chart.Series.Add($ramSeries)
$chart.Legends.Add((New-Object System.Windows.Forms.DataVisualization.Charting.Legend))

$perfPanel = New-Object System.Windows.Forms.Panel
$perfPanel.Height = 40
$perfPanel.Dock = 'Top'
$tabPerf.Controls.Add($perfPanel)

$lblPerf = New-Object System.Windows.Forms.Label
$lblPerf.Text = 'Realtime processor and memory usage'
$lblPerf.Left = 10
$lblPerf.Top = 13
$perfPanel.Controls.Add($lblPerf)

$btnPause = New-Button -Text 'Pause' -Left 280 -Top 7 -Width 100
$perfPanel.Controls.Add($btnPause)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2500
$timer.Add_Tick({
    try {
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
        $os = Get-CimInstance Win32_OperatingSystem
        $ramUsage = (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100

        $cpuSeries.Points.AddY([math]::Round($cpuUsage, 1))
        $ramSeries.Points.AddY([math]::Round($ramUsage, 1))

        while ($cpuSeries.Points.Count -gt 40) { $cpuSeries.Points.RemoveAt(0); $ramSeries.Points.RemoveAt(0) }
        Update-Status "Realtime performance updated. CPU $([math]::Round($cpuUsage,1))%, RAM $([math]::Round($ramUsage,1))%"
    } catch {
        Update-Status "Performance update failed: $($_.Exception.Message)"
    }
})

$pauseState = $false
$btnPause.Add_Click({
    if ($pauseState) {
        $timer.Start()
        $btnPause.Text = 'Pause'
        Update-Status 'Performance monitoring resumed.'
    } else {
        $timer.Stop()
        $btnPause.Text = 'Resume'
        Update-Status 'Performance monitoring paused.'
    }
    $pauseState = -not $pauseState
})

# Network Analyzer Tab
$tabNet = New-Object System.Windows.Forms.TabPage
$tabNet.Text = 'Network Analyzer'
$tabs.TabPages.Add($tabNet)

$netPanel = New-Object System.Windows.Forms.Panel
$netPanel.Height = 48
$netPanel.Dock = 'Top'
$tabNet.Controls.Add($netPanel)

$txtTarget = New-Object System.Windows.Forms.TextBox
$txtTarget.Left = 10
$txtTarget.Top = 12
$txtTarget.Width = 160
$txtTarget.Text = '8.8.8.8'
$netPanel.Controls.Add($txtTarget)

$btnFullScan = New-Button -Text 'Full Scan' -Left 180 -Top 8 -Width 90
$netPanel.Controls.Add($btnFullScan)

$btnDNSCheck = New-Button -Text 'DNS Check' -Left 280 -Top 8 -Width 90
$netPanel.Controls.Add($btnDNSCheck)

$btnActiveConns = New-Button -Text 'Active Connections' -Left 380 -Top 8 -Width 120
$netPanel.Controls.Add($btnActiveConns)

$btnSuspicious = New-Button -Text 'Suspicious Activity' -Left 510 -Top 8 -Width 120
$netPanel.Controls.Add($btnSuspicious)

$btnBaselineCompare = New-Button -Text 'Baseline Compare' -Left 640 -Top 8 -Width 120
$netPanel.Controls.Add($btnBaselineCompare)

$btnSaveBaseline = New-Button -Text 'Save Baseline' -Left 770 -Top 8 -Width 100
$netPanel.Controls.Add($btnSaveBaseline)

$btnClearNet = New-Button -Text 'Clear' -Left 880 -Top 8 -Width 90
$netPanel.Controls.Add($btnClearNet)

$netBox = New-TextBox -Multiline:$true -ReadOnly:$true
$netBox.Dock = 'Fill'
$netBox.Font = New-Object System.Drawing.Font('Consolas', 10)
$tabNet.Controls.Add($netBox)

$btnFullScan.Add_Click({
    $netBox.Clear()
    $netBox.AppendText('=== ACTIVE CONNECTIONS ===`r`n')
    Get-NetworkConnectionsAdvanced | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }

    $netBox.AppendText('=== SUSPICIOUS ACTIVITY ===`r`n')
    Find-SuspiciousConnections | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }

    $netBox.AppendText('=== TRACEROUTE ANALYSIS ===`r`n')
    Get-TracerouteAnalysis -Target $txtTarget.Text | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }
})

$btnDNSCheck.Add_Click({
    $netBox.Clear()
    $result = Resolve-DNSForensics -Host $txtTarget.Text
    $netBox.AppendText("=== DNS FORENSICS for $($result.Host) ===`r`n")
    $netBox.AppendText("A Records: $([string]::Join(', ', $result.ARecords))`r`n")
    $netBox.AppendText("AAAA Records: $([string]::Join(', ', $result.AAAARecords))`r`n")
    $netBox.AppendText("CNAME: $([string]::Join(', ', $result.CNAME))`r`n`r`n")
    $netBox.AppendText('--- Resolver Comparison ---`r`n')
    $result.DNSResolvers | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }
    if ($result.Errors.Count) {
        $netBox.AppendText('--- Errors ---`r`n')
        $result.Errors | ForEach-Object { $netBox.AppendText("$_`r`n") }
    }
})

$btnActiveConns.Add_Click({
    $netBox.Clear()
    $netBox.AppendText('=== ACTIVE CONNECTIONS ===`r`n')
    Get-NetworkConnectionsAdvanced | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }
})

$btnSuspicious.Add_Click({
    $netBox.Clear()
    $netBox.AppendText('=== SUSPICIOUS CONNECTIONS ===`r`n')
    Find-SuspiciousConnections | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }
})

$btnBaselineCompare.Add_Click({
    $netBox.Clear()
    $result = Compare-NetworkBaseline
    if ($result.Status -eq 'MissingBaseline') {
        $netBox.AppendText($result.Message + "`r`n")
        return
    }
    $netBox.AppendText("Baseline timestamp: $($result.BaselineTimestamp)`r`n")
    $netBox.AppendText("New connections: $($result.NewConnectionCount)`r`n")
    $netBox.AppendText("Missing connections: $($result.MissingConnectionCount)`r`n`r`n")
    if ($result.NewConnectionCount -gt 0) {
        $netBox.AppendText('--- New Connections ---`r`n')
        $result.NewConnections | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }
    }
    if ($result.MissingConnectionCount -gt 0) {
        $netBox.AppendText('--- Missing Baseline Connections ---`r`n')
        $result.MissingConnections | Format-Table -AutoSize | Out-String | ForEach-Object { $netBox.AppendText($_) }
    }
})

$btnSaveBaseline.Add_Click({
    $path = Get-NetworkBaseline
    $netBox.Clear()
    $netBox.AppendText("Baseline saved to: $path`r`n")
})

$btnClearNet.Add_Click({ $netBox.Clear(); Update-Status 'Network output cleared.' })

# Event Logs Tab
$tabEvents = New-Object System.Windows.Forms.TabPage
$tabEvents.Text = 'Event Logs'
$tabs.TabPages.Add($tabEvents)

$eventsPanel = New-Object System.Windows.Forms.Panel
$eventsPanel.Height = 40
$eventsPanel.Dock = 'Top'
$tabEvents.Controls.Add($eventsPanel)

$comboLogs = New-Object System.Windows.Forms.ComboBox
$comboLogs.Left = 10
$comboLogs.Top = 10
$comboLogs.Width = 180
$comboLogs.DropDownStyle = 'DropDownList'
$comboLogs.Items.AddRange(@('System','Application','Security'))
$comboLogs.SelectedIndex = 0
$eventsPanel.Controls.Add($comboLogs)

$btnLoadEvents = New-Button -Text 'Load Events' -Left 200 -Top 7 -Width 100
$eventsPanel.Controls.Add($btnLoadEvents)

$btnExportEvents = New-Button -Text 'Export' -Left 310 -Top 7 -Width 100
$eventsPanel.Controls.Add($btnExportEvents)

$eventsSplit = New-Object System.Windows.Forms.SplitContainer
$eventsSplit.Dock = 'Fill'
$eventsSplit.Orientation = 'Horizontal'
$eventsSplit.SplitterDistance = 320
$tabEvents.Controls.Add($eventsSplit)

$gridEvents = New-Grid
$eventsSplit.Panel1.Controls.Add($gridEvents)

$eventDetail = New-TextBox -Multiline:$true -ReadOnly:$true
$eventDetail.Dock = 'Fill'
$eventsSplit.Panel2.Controls.Add($eventDetail)

function Load-Events {
    $logName = $comboLogs.SelectedItem
    $events = Get-WinEvent -LogName $logName -MaxEvents 50 -ErrorAction SilentlyContinue |
        Where-Object { $_.LevelDisplayName -in 'Error', 'Warning' } |
        Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message
    $gridEvents.DataSource = $events
    Update-Status "Loaded $($events.Count) events from $logName."
}

$btnLoadEvents.Add_Click({ Load-Events })
$gridEvents.Add_CellClick({
    if ($gridEvents.SelectedRows.Count -gt 0) {
        $selected = $gridEvents.SelectedRows[0].DataBoundItem
        $eventDetail.Text = $selected.Message
    }
})
$btnExportEvents.Add_Click({
    if (-not $gridEvents.DataSource) { return }
    $exportPath = Join-Path -Path $PSScriptRoot -ChildPath "events_$($comboLogs.SelectedItem)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $gridEvents.DataSource | Export-Csv -Path $exportPath -NoTypeInformation -Force
    Update-Status "Event log exported to $exportPath"
})

# Services Tab
$tabSvc = New-Object System.Windows.Forms.TabPage
$tabSvc.Text = 'Services'
$tabs.TabPages.Add($tabSvc)

$svcPanel = New-Object System.Windows.Forms.Panel
$svcPanel.Height = 40
$svcPanel.Dock = 'Top'
$tabSvc.Controls.Add($svcPanel)

$btnLoadSvc = New-Button -Text 'Refresh' -Left 10 -Top 7 -Width 100
$svcPanel.Controls.Add($btnLoadSvc)

$btnExportSvc = New-Button -Text 'Export' -Left 120 -Top 7 -Width 100
$svcPanel.Controls.Add($btnExportSvc)

$svcSplit = New-Object System.Windows.Forms.SplitContainer
$svcSplit.Dock = 'Fill'
$svcSplit.Orientation = 'Horizontal'
$svcSplit.SplitterDistance = 360
$tabSvc.Controls.Add($svcSplit)

$gridServices = New-Grid
$svcSplit.Panel1.Controls.Add($gridServices)

$startupBox = New-TextBox -Multiline:$true -ReadOnly:$true
$startupBox.Dock = 'Fill'
$svcSplit.Panel2.Controls.Add($startupBox)

function Load-Services {
    $services = Get-Service | Select-Object Status, Name, DisplayName | Sort-Object Status, Name
    $gridServices.DataSource = $services
    $startupBox.Clear()
    $startupBox.AppendText('=== STARTUP PROGRAMS ===`r`n')
    Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location |
        Format-Table -AutoSize | Out-String | ForEach-Object { $startupBox.AppendText($_) }
    Update-Status "Loaded $($services.Count) services and startup commands."
}

$btnLoadSvc.Add_Click({ Load-Services })
$btnExportSvc.Add_Click({
    if (-not $gridServices.DataSource) { return }
    $exportPath = Join-Path -Path $PSScriptRoot -ChildPath "services_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $gridServices.DataSource | Export-Csv -Path $exportPath -NoTypeInformation -Force
    Update-Status "Services exported to $exportPath"
})

# Start timers and initial load
$timer.Start()
Load-Processes
Load-Services
Update-Status 'Ready.'

[void]$form.ShowDialog()
