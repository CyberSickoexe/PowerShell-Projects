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
    $bindingFlags = [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance
    $doubleBuffered = $grid.GetType().GetProperty('DoubleBuffered', $bindingFlags)
    if ($doubleBuffered) { $doubleBuffered.SetValue($grid, $true, $null) }
    return $grid
}

function Invoke-UIAction {
    param([scriptblock]$Action)

    if (-not $script:AppState -or -not $script:AppState.Form -or $script:AppState.Form.IsDisposed) {
        & $Action
        return
    }

    $form = $script:AppState.Form

    if ($form.InvokeRequired) {
        try {
            $form.Invoke([Action]{
                & $Action
            }) | Out-Null
        }
        catch {
            # fallback if invoke fails (form closing race condition)
            try { & $Action } catch {}
        }
    }
    else {
        & $Action
    }
}

function Write-AppLog {
    param([string]$Message)
    $logPath = Join-Path -Path $PSScriptRoot -ChildPath 'AdminToolkit.log'
    $entry = "$(Get-Date -Format o) [$env:USERNAME] $Message"
    try { Add-Content -Path $logPath -Value $entry -ErrorAction Stop } catch {}
}

function Update-Status {
    param([string]$Message)
    Invoke-UIAction {
        if ($script:AppState -and $script:AppState.StatusLabel) {
            $script:AppState.StatusLabel.Text = [string]$Message
        }
    }
    Write-AppLog "Status updated: $Message"
}

function Append-NetOutput {
    param([string]$Text)
    Invoke-UIAction { $script:AppState.NetBox.AppendText($Text) }
}

function Append-DiagOutput {
    param([string]$Text)
    Invoke-UIAction { if ($diagBox) { $diagBox.AppendText($Text) } }
}

function Append-HealthOutput {
    param([string]$Text)
    Invoke-UIAction { if ($healthBox) { $healthBox.AppendText($Text) } }
}

function Invoke-AsyncAction {
    param(
        [scriptblock]$Work,
        [scriptblock]$OnComplete,
        [scriptblock]$OnAlways,
        [string]$Status = 'Working...'
    )

    Update-Status $Status

    # Use .NET Task instead of PowerShell runspaces (MUCH faster)
    $task = [System.Threading.Tasks.Task]::Run([Action]{
        try {
            return & $Work
        } catch {
            return $_.Exception
        }
    })

    $task.ContinueWith({
        param($t)

        $result = $t.Result

        Invoke-UIAction {
            try {
                if ($result -is [System.Exception]) {
                    Update-Status "Error: $($result.Message)"
                }
                else {
                    if ($OnComplete) { & $OnComplete $result }
                }
            }
            finally {
                if ($OnAlways) { & $OnAlways }
            }
        }

    }) | Out-Null
}

function Set-NetworkButtonsEnabled {
    param([bool]$Enabled)
    if ($script:AppState -and $script:AppState.NetworkButtons) {
        $script:AppState.NetworkButtons.GetEnumerator() | ForEach-Object { $_.Value.Enabled = $Enabled }
    } else {
        $btnFullScan.Enabled = $Enabled
        $btnDNSCheck.Enabled = $Enabled
        $btnActiveConns.Enabled = $Enabled
        $btnSuspicious.Enabled = $Enabled
        $btnBaselineCompare.Enabled = $Enabled
        $btnSaveBaseline.Enabled = $Enabled
        $btnClearNet.Enabled = $Enabled
    }
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
                    CPU = if ($_.CPU -ne $null) { [math]::Round($_.CPU, 2) } else { 0 }
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
$result
function Resolve-DNSForensics {
    param([string]$DnsHost)

    $result = [PSCustomObject]@{
        Host = $DnsHost
        ARecords = @()
        AAAARecords = @()
        CNAME = @()
        DNSResolvers = @()
        Errors = @()
    }

    try {
        $dns = Resolve-DnsName -Name $DnsHost -ErrorAction Stop
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
            $serverDns = Resolve-DnsName -Name $DnsHost -Server $server -ErrorAction Stop
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

    foreach ($line in $trace) {
        if ($line -notmatch '^\s*(\d+)\s+(\d+ ms|\*)\s+(\d+ ms|\*)\s+(\d+ ms|\*)\s+(.+)$') { continue }

        $hop = [int]$Matches[1]
        $t1 = $Matches[2]
        $t2 = $Matches[3]
        $t3 = $Matches[4]
        $address = $Matches[5].Trim()
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

function Get-ConnectionRiskScore {
    param([pscustomobject]$Connection)

    $score = 0
    if ($Connection.ProcessName -eq 'UNKNOWN') { $score += 35 }
    if ($Connection.RemotePort -in 4444,5555,1337,6666,31337) { $score += 35 }
    elseif ($Connection.RemotePort -gt 0 -and $Connection.RemotePort -lt 1024) { $score += 10 }
    if ($Connection.RemoteAddress -notmatch '^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)') { $score += 15 }
    if ($Connection.State -eq 'Established') { $score += 5 }

    $reverse = $null
    try { $reverse = [System.Net.Dns]::GetHostEntry($Connection.RemoteAddress).HostName } catch {}
    if (-not $reverse) { $score += 10 }

    $score = [math]::Min($score, 100)
    $threat = if ($score -ge 70) { 'High' } elseif ($score -ge 40) { 'Medium' } else { 'Low' }

    [PSCustomObject]@{
        RiskScore = $score
        ThreatLevel = $threat
        ReverseDNS = $reverse
    }
}

function Find-SuspiciousConnections {
    $suspicious = Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Established' }

    return $suspicious | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        $connection = [PSCustomObject]@{
            LocalAddress  = $_.LocalAddress
            LocalPort     = $_.LocalPort
            RemoteAddress = $_.RemoteAddress
            RemotePort    = $_.RemotePort
            State         = $_.State
            PID           = $_.OwningProcess
            ProcessName   = if ($proc) { $proc.ProcessName } else { 'UNKNOWN' }
            Path          = if ($proc) { $proc.Path } else { 'N/A' }
        }
        $risk = Get-ConnectionRiskScore -Connection $connection
        [PSCustomObject]@{
            Remote       = "$($connection.RemoteAddress):$($connection.RemotePort)"
            State        = $connection.State
            Process      = $connection.ProcessName
            PID          = $connection.PID
            Path         = $connection.Path
            RiskScore    = $risk.RiskScore
            ThreatLevel  = $risk.ThreatLevel
            ReverseDNS   = $risk.ReverseDNS
            LocalAddress = $connection.LocalAddress
            LocalPort    = $connection.LocalPort
        }
    } | Sort-Object RiskScore -Descending
}

function Get-NetworkBaseline {
    $baseline = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('o')
        Connections = Get-NetworkConnectionsAdvanced | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, PID, ProcessName
        Listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess
    }

    $baseline | ConvertTo-Json -Depth 4 | Set-Content -Path $script:AppState.NetworkBaselineFile -Force
    return $script:AppState.NetworkBaselineFile
}

function Save-NetworkBaseline {
    Get-NetworkBaseline
}

function Compare-NetworkBaseline {
    if (-not (Test-Path $script:AppState.NetworkBaselineFile)) {
        return [PSCustomObject]@{
            Status = 'MissingBaseline'
            Message = "Baseline file not found. Use Get-NetworkBaseline or Save-NetworkBaseline to create one."
        }
    }

    $baseline = Get-Content -Path $script:AppState.NetworkBaselineFile -Raw | ConvertFrom-Json
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

function Invoke-CommandToBox {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    $output = try { & $Command 2>&1 } catch { $_.Exception.Message }
    $text = if ($output) { $output | Out-String } else { "(no output)" }
    if ($script:netBox) {
        $script:netBox.AppendText("$Label`r`n")
        $script:netBox.AppendText($text)
        $script:netBox.AppendText("`r`n")
    } else {
        Write-Host $Label
        Write-Host $text
    }
}

# ========== SYSTEM HEALTH DIAGNOSTICS ==========
function Invoke-SystemHealthDiagnostics {
    $health = @{
        Score = 100
        Status = 'Healthy'
        Warnings = @()
        Errors = @()
        Details = @()
    }

    # Disk Health
    try {
        $disks = Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
            $percentFree = [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1)
            if ($percentFree -lt 10) {
                $health.Warnings += "Disk $($_.DriveLetter): Low space ($percentFree% free)"
                $health.Score -= 15
            }
            [PSCustomObject]@{
                Drive = $_.DriveLetter
                Total_GB = [math]::Round($_.Size / 1GB, 1)
                Free_GB = [math]::Round($_.SizeRemaining / 1GB, 1)
                PercentFree = $percentFree
            }
        }
        $health.Details += @{ DiskHealth = $disks }
    } catch {
        $health.Errors += "Disk check failed: $($_.Exception.Message)"
    }

    # Memory Health
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $memPercent = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
        if ($memPercent -gt 85) {
            $health.Warnings += "Memory usage critical: $memPercent% used"
            $health.Score -= 20
        }
        $health.Details += @{
            MemoryStatus = @{
                TotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
                FreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
                UsedPercent = $memPercent
            }
        }
    } catch {
        $health.Errors += "Memory check failed: $($_.Exception.Message)"
    }

    # System File Integrity (basic)
    try {
        $sfc = sfc /scannow 2>&1 | Select-Object -First 1
        $health.Details += @{ SystemFileCheck = 'Run: sfc /scannow for full check' }
    } catch {}

    # Driver Issues
    try {
        $badDrivers = Get-CimInstance Win32_SystemDriver | Where-Object { $_.State -ne 'Running' } | Measure-Object
        if ($badDrivers.Count -gt 0) {
            $health.Warnings += "$($badDrivers.Count) drivers not running"
            $health.Score -= 10
        }
        $health.Details += @{ StoppedDrivers = $badDrivers.Count }
    } catch {}

    # Windows Update Status
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 AND Type='Software'")
        if ($searchResult.Updates.Count -gt 0) {
            $health.Warnings += "$($searchResult.Updates.Count) Windows updates available"
            $health.Score -= 5
        }
        $health.Details += @{ PendingUpdates = $searchResult.Updates.Count }
    } catch {}

    # Network Configuration
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        $dns = Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 } | Measure-Object
        $health.Details += @{
            NetworkAdapters = $adapters.Count
            DNSServers = $dns.Count
        }
    } catch {}

    # Determine overall status
    if ($health.Errors.Count -gt 0) { $health.Status = 'Critical' }
    elseif ($health.Score -lt 50) { $health.Status = 'Critical' }
    elseif ($health.Score -lt 80) { $health.Status = 'Warning' }
    else { $health.Status = 'Healthy' }

    return $health
}

# ========== PROCESS SPIKE DETECTION & ANALYSIS ==========
$script:ProcessBaseline = @{}

function Update-ProcessBaseline {
    $procs = Get-Process | Select-Object ProcessName, @{N='CPU';E={$_.CPU}}, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}}
    $script:ProcessBaseline = @{}
    $procs | ForEach-Object {
        $key = $_.ProcessName
        if (-not $script:ProcessBaseline[$key]) {
            $script:ProcessBaseline[$key] = @{ Count = 1; TotalCPU = $_.CPU; TotalRAM = $_.RAM_MB }
        } else {
            $script:ProcessBaseline[$key].Count++
            $script:ProcessBaseline[$key].TotalCPU += $_.CPU
            $script:ProcessBaseline[$key].TotalRAM += $_.RAM_MB
        }
    }
}

function Find-ProcessAnomalies {
    $current = Get-Process | Select-Object ProcessName, @{N='CPU';E={$_.CPU}}, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}}
    $anomalies = @()

    $current | ForEach-Object {
        $procName = $_.ProcessName
        $baseline = $script:ProcessBaseline[$procName]
        if ($baseline) {
            $avgCPU = $baseline.TotalCPU / $baseline.Count
            $avgRAM = $baseline.TotalRAM / $baseline.Count
            if ($_.CPU -gt ($avgCPU * 2)) {
                $anomalies += [PSCustomObject]@{
                    Process = $procName
                    Type = 'CPU Spike'
                    Current = $_.CPU
                    Baseline = [math]::Round($avgCPU, 1)
                    Severity = if ($_.CPU -gt ($avgCPU * 5)) { 'High' } else { 'Medium' }
                }
            }
            if ($_.RAM_MB -gt ($avgRAM * 1.5)) {
                $anomalies += [PSCustomObject]@{
                    Process = $procName
                    Type = 'Memory Growth'
                    Current = $_.RAM_MB
                    Baseline = [math]::Round($avgRAM, 1)
                    Severity = if ($_.RAM_MB -gt ($avgRAM * 3)) { 'High' } else { 'Medium' }
                }
            }
        }
    }
    return $anomalies | Sort-Object Severity -Descending
}

# ========== NETWORK TROUBLESHOOTING ASSISTANT ==========
function Invoke-NetworkDiagnostics {
    param([string]$Target = '8.8.8.8')
    
    $diagnostics = @{
        Summary = ''
        IssueType = ''
        RootCauses = @()
        Recommendations = @()
        Details = @{}
    }

    # DNS Resolution Test
    $dnsOk = $false
    try {
        $dns = Resolve-DnsName -Name $Target -ErrorAction Stop
        $dnsOk = $true
        $diagnostics.Details.DNS = 'OK'
    } catch {
        $diagnostics.Details.DNS = "FAILED: $($_.Exception.Message)"
        $diagnostics.RootCauses += 'DNS misconfiguration or server unavailable'
        $diagnostics.Recommendations += 'Check DNS servers (ipconfig /all)'
        $diagnostics.Recommendations += 'Flush DNS cache (ipconfig /flushdns)'
    }

    # Ping Test
    $pingOk = $false
    try {
        $ping = Test-Connection -ComputerName $Target -Count 1 -ErrorAction Stop
        $pingOk = $true
        $diagnostics.Details.Ping = "OK ($($ping.ResponseTime)ms)"
    } catch {
        $diagnostics.Details.Ping = 'FAILED'
        if (-not $dnsOk) {
            $diagnostics.RootCauses += 'Cannot resolve hostname'
        } else {
            $diagnostics.RootCauses += 'No route to host (gateway/network issue)'
            $diagnostics.Recommendations += 'Check gateway: route print'
            $diagnostics.Recommendations += 'Test local connectivity: ping 127.0.0.1'
        }
    }

    # Traceroute Analysis
    if ($dnsOk) {
        try {
            $trace = tracert -d $Target 2>&1 | Select-Object -Last 10
            $timeouts = @($trace | Where-Object { $_ -match '\*' }).Count
            if ($timeouts -gt 0) {
                $diagnostics.Details.Traceroute = "Partial: $timeouts hops unreachable"
                $diagnostics.RootCauses += 'Packet loss or firewall blocking'
            } else {
                $diagnostics.Details.Traceroute = 'OK'
            }
        } catch {}
    }

    # Network Adapter Status
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if ($adapters.Count -eq 0) {
        $diagnostics.RootCauses += 'No active network adapters'
        $diagnostics.Recommendations += 'Check network adapter drivers'
    }
    $diagnostics.Details.Adapters = $adapters.Count

    # Determine issue type
    if (-not $dnsOk) { $diagnostics.IssueType = 'DNS Issue' }
    elseif (-not $pingOk) { $diagnostics.IssueType = 'Connectivity Issue' }
    else { $diagnostics.IssueType = 'No Issues Detected' }

    $diagnostics.Summary = "Network Status: $($diagnostics.IssueType)"
    return $diagnostics
}

# ========== PROCESS & APPLICATION CONFLICT ANALYZER ==========
function Find-AppConflicts {
    $conflicts = @()

    # Link event log errors to processes
    try {
        $criticalEvents = Get-WinEvent -LogName Application -MaxEvents 100 -ErrorAction SilentlyContinue |
            Where-Object { $_.LevelDisplayName -in 'Error', 'Critical' }

        $eventsBySource = $criticalEvents | Group-Object -Property ProviderName

        $runningProcs = @(Get-Process | Select-Object -ExpandProperty ProcessName -Unique)

        $eventsBySource | ForEach-Object {
            $source = $_.Name
            $count = $_.Count
            $matchingProc = $runningProcs | Where-Object { $source -like "*$_*" }

            if ($count -gt 5) {
                $conflicts += [PSCustomObject]@{
                    Source = $source
                    ErrorCount = $count
                    LinkedProcess = if ($matchingProc) { $matchingProc | Select-Object -First 1 } else { 'Unknown' }
                    Severity = if ($count -gt 20) { 'Critical' } else { 'Warning' }
                    TimeRange = "Last 100 events"
                }
            }
        }
    } catch {}

    # Detect high-CPU processes with recent errors
    $highCPUProcs = Get-Process | Where-Object { $_.CPU -gt 10 } | Select-Object -First 5
    $highCPUProcs | ForEach-Object {
        $procName = $_.ProcessName
        $recentErrors = Get-WinEvent -LogName Application -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -like "*$procName*" -and $_.LevelDisplayName -in 'Error', 'Warning' }
        if ($recentErrors.Count -gt 0) {
            $conflicts += [PSCustomObject]@{
                Source = $procName
                ErrorCount = $recentErrors.Count
                LinkedProcess = $procName
                Severity = 'High'
                TimeRange = 'Recent'
            }
        }
    }

    return $conflicts | Sort-Object Severity -Descending | Select-Object -Unique -Property Source
}

# ========== REPAIR ACTIONS ==========
$script:RepairActions = @(
    @{
        Name = 'Flush DNS Cache'
        Description = 'Clear DNS resolver cache to resolve DNS-related issues'
        Command = { ipconfig /flushdns }
        Category = 'Network'
        Safe = $true
    },
    @{
        Name = 'Restart Network Adapters'
        Description = 'Disable and re-enable all network adapters'
        Command = { Get-NetAdapter | ForEach-Object { Disable-NetAdapter -Name $_.Name -Confirm:$false; Start-Sleep 1; Enable-NetAdapter -Name $_.Name -Confirm:$false } }
        Category = 'Network'
        Safe = $true
    },
    @{
        Name = 'Clear Temporary Files'
        Description = 'Remove Windows temporary files to free disk space'
        Command = { Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue }
        Category = 'Disk'
        Safe = $true
    },
    @{
        Name = 'Restart Windows Update Service'
        Description = 'Restart WU service to resolve update issues'
        Command = { Stop-Service wuauserv -Force; Start-Sleep 2; Start-Service wuauserv }
        Category = 'System'
        Safe = $true
    },
    @{
        Name = 'Disable Startup Programs (NonEssential)'
        Description = 'Disable non-essential startup programs to improve boot time'
        Command = { Get-CimInstance Win32_StartupCommand | Where-Object { $_.Command -notlike '*windows*' -and $_.Command -notlike '*microsoft*' } | ForEach-Object { Disable-ScheduledTask -TaskName $_.Name -Confirm:$false -ErrorAction SilentlyContinue } }
        Category = 'Startup'
        Safe = $false
    }
)

function Get-RepairActionDetails {
    param([int]$Index)
    if ($Index -ge 0 -and $Index -lt $script:RepairActions.Count) {
        return $script:RepairActions[$Index]
    }
    return $null
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
$script:statusLabel = $statusLabel
$script:AppState = [pscustomobject]@{
    Form = $form
    StatusLabel = $statusLabel
}
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
if ($txtFilter.PSObject.Properties['PlaceholderText']) {
    $txtFilter.PlaceholderText = 'Filter by process name...'
} else {
    $txtFilter.Text = 'Filter by process name...'
}
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

$filterTimer = New-Object System.Windows.Forms.Timer
$filterTimer.Interval = 400
$filterTimer.Add_Tick({ $filterTimer.Stop(); Load-Processes })

$btnRefresh.Add_Click({ Load-Processes })
$txtFilter.Add_TextChanged({ $filterTimer.Stop(); $filterTimer.Start() })
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
$script:netBox = $netBox
# ===================== FAST ASYNC QUEUE ENGINE =====================
$script:TaskQueue = [System.Collections.Concurrent.BlockingCollection[scriptblock]]::new()

$script:WorkerJob = Start-Job -ArgumentList $script:TaskQueue -ScriptBlock {
    param($queue)

    try {
        while ($true) {
            $job = $queue.Take()
            & $job
        }
    }
    catch {
        # exit cleanly if queue is disposed
    }
}

$btnFullScan.Add_Click({
    Invoke-UIAction { $script:AppState.NetBox.Clear() }
    $target = $txtTarget.Text
    Set-NetworkButtonsEnabled -Enabled $false
    Invoke-AsyncAction -Status 'Running full network scan...' -Work {
        $output = '=== ACTIVE CONNECTIONS ===`r`n'
        $output += (Get-NetworkConnectionsAdvanced | Format-Table -AutoSize | Out-String)
        $output += '`r`n=== SUSPICIOUS ACTIVITY ===`r`n'
        $output += (Find-SuspiciousConnections | Format-Table -AutoSize | Out-String)
        $output += '`r`n=== TRACEROUTE ANALYSIS ===`r`n'
        $output += (Get-TracerouteAnalysis -Target $target | Format-Table -AutoSize | Out-String)
        $output
    } -OnComplete {
        param($result)
        Append-NetOutput($result)
        Update-Status 'Network full scan completed.'
    } -OnAlways { Set-NetworkButtonsEnabled -Enabled $true }
})

$btnDNSCheck.Add_Click({
    Invoke-UIAction { $script:AppState.NetBox.Clear() }
    $target = $txtTarget.Text
    Set-NetworkButtonsEnabled -Enabled $false
    Invoke-AsyncAction -Status 'Resolving DNS...' -Work {
        $result = Resolve-DNSForensics -DnsHost $target
        $output = "=== DNS FORENSICS for $($result.Host) ===`r`n"
        $output += "A Records: $([string]::Join(', ', $result.ARecords))`r`n"
        $output += "AAAA Records: $([string]::Join(', ', $result.AAAARecords))`r`n"
        $output += "CNAME: $([string]::Join(', ', $result.CNAME))`r`n`r`n"
        $output += '--- Resolver Comparison ---`r`n'
        $output += ($result.DNSResolvers | Format-Table -AutoSize | Out-String)
        if ($result.Errors.Count) {
            $output += '--- Errors ---`r`n'
            $output += ($result.Errors | ForEach-Object { "$_`r`n" }) -join ''
        }
        $output
    } -OnComplete {
        param($result)
        Append-NetOutput($result)
        Update-Status 'DNS check completed.'
    } -OnAlways { Set-NetworkButtonsEnabled -Enabled $true }
})

$btnActiveConns.Add_Click({
    Invoke-UIAction { $script:AppState.NetBox.Clear() }
    Set-NetworkButtonsEnabled -Enabled $false
    Invoke-AsyncAction -Status 'Loading active connections...' -Work {
        Get-NetworkConnectionsAdvanced | Format-Table -AutoSize | Out-String
    } -OnComplete {
        param($result)
        Append-NetOutput('=== ACTIVE CONNECTIONS ===`r`n')
        Append-NetOutput($result)
        Update-Status 'Active connections loaded.'
    } -OnAlways { Set-NetworkButtonsEnabled -Enabled $true }
})

$btnSuspicious.Add_Click({
    Invoke-UIAction { $script:AppState.NetBox.Clear() }
    Set-NetworkButtonsEnabled -Enabled $false
    Invoke-AsyncAction -Status 'Checking suspicious connections...' -Work {
        Find-SuspiciousConnections | Format-Table -AutoSize | Out-String
    } -OnComplete {
        param($result)
        Append-NetOutput('=== SUSPICIOUS CONNECTIONS ===`r`n')
        Append-NetOutput($result)
        Update-Status 'Suspicious connections loaded.'
    } -OnAlways { Set-NetworkButtonsEnabled -Enabled $true }
})

$btnBaselineCompare.Add_Click({
    Invoke-UIAction { $script:AppState.NetBox.Clear() }
    Set-NetworkButtonsEnabled -Enabled $false
    Invoke-AsyncAction -Status 'Comparing baseline...' -Work {
        $result = Compare-NetworkBaseline
        $output = ''
        if ($result.Status -eq 'MissingBaseline') {
            $output = $result.Message + "`r`n"
        } else {
            $output = "Baseline timestamp: $($result.BaselineTimestamp)`r`n"
            $output += "New connections: $($result.NewConnectionCount)`r`n"
            $output += "Missing connections: $($result.MissingConnectionCount)`r`n`r`n"
            if ($result.NewConnectionCount -gt 0) {
                $output += '--- New Connections ---`r`n'
                $output += ($result.NewConnections | Format-Table -AutoSize | Out-String)
            }
            if ($result.MissingConnectionCount -gt 0) {
                $output += '--- Missing Baseline Connections ---`r`n'
                $output += ($result.MissingConnections | Format-Table -AutoSize | Out-String)
            }
        }
        $output
    } -OnComplete {
        param($result)
        Append-NetOutput($result)
        Update-Status 'Baseline comparison completed.'
    } -OnAlways { Set-NetworkButtonsEnabled -Enabled $true }
})

$btnSaveBaseline.Add_Click({
    Invoke-UIAction { $script:AppState.NetBox.Clear() }
    Set-NetworkButtonsEnabled -Enabled $false
    Invoke-AsyncAction -Status 'Saving baseline...' -Work {
        Get-NetworkBaseline
    } -OnComplete {
        param($path)
        Append-NetOutput("Baseline saved to: $path`r`n")
        Update-Status 'Baseline saved.'
    } -OnAlways { Set-NetworkButtonsEnabled -Enabled $true }
})

$btnClearNet.Add_Click({ Invoke-UIAction { $script:AppState.NetBox.Clear() }; Update-Status 'Network output cleared.' })

# Network Diagnostics Tab
$tabNetDiag = New-Object System.Windows.Forms.TabPage
$tabNetDiag.Text = 'Network Diags'
$tabs.TabPages.Add($tabNetDiag)

$diagPanel = New-Object System.Windows.Forms.Panel
$diagPanel.Height = 48
$diagPanel.Dock = 'Top'
$tabNetDiag.Controls.Add($diagPanel)

$txtDiagTarget = New-Object System.Windows.Forms.TextBox
$txtDiagTarget.Left = 10
$txtDiagTarget.Top = 12
$txtDiagTarget.Width = 160
$txtDiagTarget.Text = '8.8.8.8'
$diagPanel.Controls.Add($txtDiagTarget)

$btnRunNetDiag = New-Button -Text 'Run Diagnostics' -Left 180 -Top 8 -Width 120
$diagPanel.Controls.Add($btnRunNetDiag)

$btnNetTroubleshoot = New-Button -Text 'Troubleshoot Issues' -Left 310 -Top 8 -Width 140
$diagPanel.Controls.Add($btnNetTroubleshoot)

$diagBox = New-TextBox -Multiline:$true -ReadOnly:$true
$diagBox.Dock = 'Fill'
$tabNetDiag.Controls.Add($diagBox)

$btnRunNetDiag.Add_Click({
    Invoke-UIAction { $diagBox.Clear() }
    $target = $txtDiagTarget.Text
    Invoke-AsyncAction -Status 'Running network diagnostics...' -Work {
        $diag = Invoke-NetworkDiagnostics -Target $target
        $output = "[============== NETWORK DIAGNOSTICS REPORT ==============]`r`n`r`n"
        $output += "Target: $target`r`n"
        $output += "Status: $($diag.Summary)`r`n"
        $output += "Issue Type: $($diag.IssueType)`r`n`r`n"
        $output += "CONNECTIVITY TESTS:`r`n"
        $diag.Details.GetEnumerator() | ForEach-Object {
            $output += "  $($_.Key): $($_.Value)`r`n"
        }
        if ($diag.RootCauses.Count -gt 0) {
            $output += "`r`nPROBABLE ROOT CAUSES:`r`n"
            $diag.RootCauses | ForEach-Object { $output += "  - $_`r`n" }
        }
        if ($diag.Recommendations.Count -gt 0) {
            $output += "`r`nRECOMMENDATIONS:`r`n"
            $diag.Recommendations | ForEach-Object { $output += "  > $_`r`n" }
        }
        $output
    } -OnComplete {
        param($result)
        $diagBox.AppendText($result)
        Update-Status 'Network diagnostics completed.'
    }
})

$btnNetTroubleshoot.Add_Click({
    Invoke-UIAction { $diagBox.Clear() }

    $target = $txtDiagTarget.Text

    Invoke-AsyncAction -Status 'Troubleshooting network issues...' -Work {
        $diag = Invoke-NetworkDiagnostics -Target $target

        $output = "TROUBLESHOOTING ANALYSIS FOR: $target`r`n"
        $output += ("=" * 50) + "`r`n`r`n"

        if ($diag.IssueType -eq 'No Issues Detected') {
            $output += "[OK] No network issues detected!`r`n"
            $output += "Network is operating normally.`r`n"
        }
        else {
            $output += "[WARNING] ISSUE DETECTED: $($diag.IssueType)`r`n`r`n"

            $output += "ROOT CAUSES:`r`n"
            if ($diag.RootCauses.Count -eq 0) {
                $output += "  - Unable to determine root cause`r`n"
            } else {
                $diag.RootCauses | ForEach-Object { $output += "  - $_`r`n" }
            }

            $output += "`r`nRECOMMENDED FIXES:`r`n"
            if ($diag.Recommendations.Count -eq 0) {
                $output += "  - No recommendations available`r`n"
            } else {
                $i = 1
                $diag.Recommendations | ForEach-Object {
                    $output += "  $i. $_`r`n"
                    $i++
                }
            }
        }

        return $output
    } -OnComplete {
        param($result)
        Append-DiagOutput $result
        Update-Status 'Network troubleshooting completed.'
    }
})

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

$btnLoadEvents.Add_Click({
    Invoke-AsyncAction -Status "Loading $($comboLogs.SelectedItem) events..." -Work {
        $logName = $comboLogs.SelectedItem
        Get-WinEvent -LogName $logName -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.LevelDisplayName -in 'Error', 'Warning' } |
            Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message
    } -OnComplete {
        param($events)
        $gridEvents.DataSource = $events
        Update-Status "Loaded $($events.Count) events from $($comboLogs.SelectedItem)."
    }
})
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

$btnLoadSvc.Add_Click({
    Invoke-AsyncAction -Status 'Loading services and startup programs...' -Work {
        $services = Get-Service | Select-Object Status, Name, DisplayName | Sort-Object Status, Name
        $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
            Select-Object Name, Command, Location |
            Format-Table -AutoSize | Out-String
        [PSCustomObject]@{
            Services = $services
            Startup = $startup
        }
    } -OnComplete {
        param($result)
        $gridServices.DataSource = $result.Services
        $startupBox.Clear()
        $startupBox.AppendText('=== STARTUP PROGRAMS ===`r`n')
        $startupBox.AppendText($result.Startup)
        Update-Status "Loaded $($result.Services.Count) services and startup commands."
    }
})
$btnExportSvc.Add_Click({
    if (-not $gridServices.DataSource) { return }
    $exportPath = Join-Path -Path $PSScriptRoot -ChildPath "services_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $gridServices.DataSource | Export-Csv -Path $exportPath -NoTypeInformation -Force
    Update-Status "Services exported to $exportPath"
})

# System Health Diagnostics Tab
$tabHealth = New-Object System.Windows.Forms.TabPage
$tabHealth.Text = 'System Health'
$tabs.TabPages.Add($tabHealth)

$healthPanel = New-Object System.Windows.Forms.Panel
$healthPanel.Height = 40
$healthPanel.Dock = 'Top'
$tabHealth.Controls.Add($healthPanel)

$btnRunHealthCheck = New-Button -Text 'Run Full Diagnostics' -Left 10 -Top 7 -Width 150
$healthPanel.Controls.Add($btnRunHealthCheck)

$btnExportHealth = New-Button -Text 'Export Report' -Left 170 -Top 7 -Width 120
$healthPanel.Controls.Add($btnExportHealth)

$healthBox = New-TextBox -Multiline:$true -ReadOnly:$true
$healthBox.Dock = 'Fill'
$tabHealth.Controls.Add($healthBox)

$btnRunHealthCheck.Add_Click({
    Invoke-UIAction { $healthBox.Clear() }
    Invoke-AsyncAction -Status 'Running system health diagnostics...' -Work {
        Update-ProcessBaseline
        $health = Invoke-SystemHealthDiagnostics
        $output = "[============== SYSTEM HEALTH DIAGNOSTIC REPORT ==============]`r`n`r`n"
        $output += "Overall Status: $($health.Status)`r`n"
        $output += "Health Score: $($health.Score)/100`r`n`r`n"
        if ($health.Errors.Count -gt 0) {
            $output += "ERRORS:`r`n"
            $health.Errors | ForEach-Object { $output += "  [ERROR] $_`r`n" }
            $output += "`r`n"
        }
        if ($health.Warnings.Count -gt 0) {
            $output += "WARNINGS:`r`n"
            $health.Warnings | ForEach-Object { $output += "  [WARN] $_`r`n" }
            $output += "`r`n"
        }
        $output += "DETAILS:`r`n"
        $health.Details | ForEach-Object {
            $_.GetEnumerator() | ForEach-Object {
                $output += "`r`n  $($_.Key):`r`n"
                if ($_.Value -is [array]) {
                    $_.Value | ForEach-Object { $output += "    $_`r`n" }
                } elseif ($_.Value -is [hashtable]) {
                    $_.Value.GetEnumerator() | ForEach-Object { $output += "    $($_.Key): $($_.Value)`r`n" }
                } else {
                    $output += "    $($_.Value)`r`n"
                }
            }
        }
        $output
    } -OnComplete {
        param($result)
        Append-HealthOutput($result)
        Update-Status 'System health check completed.'
    }
})

$btnExportHealth.Add_Click({
    if (-not $healthBox.Text) { return }
    $exportPath = Join-Path -Path $PSScriptRoot -ChildPath "health-report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $healthBox.Text | Set-Content -Path $exportPath -Force
    Update-Status "Health report exported to $exportPath"
})

# Application Conflicts Tab
$tabConflicts = New-Object System.Windows.Forms.TabPage
$tabConflicts.Text = 'App Conflicts'
$tabs.TabPages.Add($tabConflicts)

$conflictPanel = New-Object System.Windows.Forms.Panel
$conflictPanel.Height = 40
$conflictPanel.Dock = 'Top'
$tabConflicts.Controls.Add($conflictPanel)

$btnAnalyzeConflicts = New-Button -Text 'Analyze Conflicts' -Left 10 -Top 7 -Width 140
$conflictPanel.Controls.Add($btnAnalyzeConflicts)

$btnRefreshAnomalies = New-Button -Text 'Check Anomalies' -Left 160 -Top 7 -Width 130
$conflictPanel.Controls.Add($btnRefreshAnomalies)

$btnExportConflicts = New-Button -Text 'Export' -Left 300 -Top 7 -Width 100
$conflictPanel.Controls.Add($btnExportConflicts)

$gridConflicts = New-Grid
$tabConflicts.Controls.Add($gridConflicts)

$btnAnalyzeConflicts.Add_Click({
    Invoke-AsyncAction -Status 'Analyzing application conflicts...' -Work {
        Find-AppConflicts | ForEach-Object {
            [PSCustomObject]@{
                Application = $_.Source
                'Error Count' = $_.ErrorCount
                'Linked Process' = $_.LinkedProcess
                Severity = $_.Severity
                Details = $_.TimeRange
            }
        }
    } -OnComplete {
        param($result)
        $gridConflicts.DataSource = $result
        Update-Status "Found $($result.Count) potential conflicts."
    }
})

$btnRefreshAnomalies.Add_Click({
    Invoke-AsyncAction -Status 'Detecting process anomalies...' -Work {
        Find-ProcessAnomalies
    } -OnComplete {
        param($result)
        $gridConflicts.DataSource = $result
        Update-Status "Found $($result.Count) process anomalies."
    }
})

$btnExportConflicts.Add_Click({
    if (-not $gridConflicts.DataSource) { return }
    $exportPath = Join-Path -Path $PSScriptRoot -ChildPath "conflicts_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $gridConflicts.DataSource | Export-Csv -Path $exportPath -NoTypeInformation -Force
    Update-Status "Conflicts exported to $exportPath"
})

# Repair Actions Tab
$tabRepair = New-Object System.Windows.Forms.TabPage
$tabRepair.Text = 'Repair `& Fix'
$tabs.TabPages.Add($tabRepair)

$repairPanel = New-Object System.Windows.Forms.Panel
$repairPanel.Height = 40
$repairPanel.Dock = 'Top'
$tabRepair.Controls.Add($repairPanel)

$btnListActions = New-Button -Text 'Show Repair Actions' -Left 10 -Top 7 -Width 150
$repairPanel.Controls.Add($btnListActions)

$repairSplit = New-Object System.Windows.Forms.SplitContainer
$repairSplit.Dock = 'Fill'
$repairSplit.Orientation = 'Horizontal'
$repairSplit.SplitterDistance = 200
$tabRepair.Controls.Add($repairSplit)

$gridActions = New-Grid
$repairSplit.Panel1.Controls.Add($gridActions)

$repairDetailBox = New-TextBox -Multiline:$true -ReadOnly:$true
$repairDetailBox.Dock = 'Fill'
$repairSplit.Panel2.Controls.Add($repairDetailBox)

$btnListActions.Add_Click({
    $actions = $script:RepairActions | ForEach-Object {
        [PSCustomObject]@{
            Action = $_.Name
            Category = $_.Category
            Safe = if ($_.Safe) { '✓ Yes' } else { '⚠️ Requires caution' }
            Description = $_.Description
        }
    }
    $gridActions.DataSource = $actions
    Update-Status "Listed $($script:RepairActions.Count) repair actions."
})

$gridActions.Add_CellClick({
    if ($gridActions.SelectedRows.Count -gt 0) {
        $idx = $gridActions.SelectedRows[0].Index
        $action = $script:RepairActions[$idx]
        $repairDetailBox.Clear()
        $repairDetailBox.AppendText("ACTION: $($action.Name)`r`n")
        $repairDetailBox.AppendText("CATEGORY: $($action.Category)`r`n")
        $repairDetailBox.AppendText("SAFE: $(if ($action.Safe) { 'Yes' } else { 'No - Requires caution' })`r`n")
        $repairDetailBox.AppendText("`r`nDESCRIPTION:`r`n$($action.Description)`r`n`r`n")
        $repairDetailBox.AppendText("[Click 'Execute Selected Action' to run]`r`n")
    }
})

$btnExecuteRepair = New-Button -Text 'Execute Selected Action' -Left 10 -Top 7 -Width 150
$repairPanel.Controls.Add($btnExecuteRepair)

$btnExecuteRepair.Add_Click({
    if ($gridActions.SelectedRows.Count -eq 0) {
        Update-Status "No action selected."
        return
    }

    $idx = $gridActions.SelectedRows[0].Index
    $action = $script:RepairActions[$idx]

    if (-not $action.Safe) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "This action requires caution.`r`nContinue anyway?",
            "Confirm Risky Action",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            Update-Status "Action execution cancelled by user."
            return
        }
    }

    Invoke-AsyncAction -Status "Executing: $($action.Name)..." -Work {
        try {
            & $action.Command
            "[SUCCESS] Action completed successfully at $(Get-Date -Format 'HH:mm:ss')"
        } catch {
            "[FAILED] Action failed: $($_.Exception.Message)"
        }
    } -OnComplete {
        param($result)
        $repairDetailBox.AppendText("`r`n$result`r`n")
        Update-Status "Action execution completed."
    }
})

# Start timers and initial load
$timer.Start()
Load-Processes
Load-Services
Update-Status 'Ready.'

[void]$form.ShowDialog()
