# Define known malicious file hashes and keywords
$fileHashes = @(
    '0c1554888ce9ed0da1583dbdf7b31651',
    '988fc0d23e6e30c2c46ccec9bbff50b7453b8ba9'
)
$keywords = @('upstyle', 'backdoor')

# Define timeframe for the query (last 1 hour)
$startTime = (Get-Date).AddHours(-1)

# Initialize results
$fileEvents = @()
$processEvents = @()

# Function to check if a log source exists
function Test-LogSource {
    param (
        [string]$logName
    )
    try {
        # Check if log exists
        Get-WinEvent -ListLog $logName -ErrorAction Stop
        return $true
    } catch {
        Write-Output "Log source '$logName' is not available or accessible."
        return $false
    }
}

# Check and retrieve file-related events from the Security log if available
if (Test-LogSource -logName "Security") {
    try {
        $fileEvents = Get-WinEvent -LogName Security -FilterXPath "*[System[TimeCreated[@SystemTime >= '$($startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))']]]" | Where-Object {
            $_.TimeCreated -ge $startTime -and (
                ($_.Properties | Where-Object { $fileHashes -contains $_.Value }) -or
                ($keywords | Where-Object { $_ -in $_.Message })
            )
        }
    } catch {
        Write-Output "Could not retrieve file-related events from Security log. Error: $_"
    }
} else {
    Write-Output "Security log is not available or accessible."
}

# Check and retrieve process-related events from the Security log if available
if (Test-LogSource -logName "Security") {
    try {
        $processEvents = Get-WinEvent -LogName Security -FilterXPath "*[System[TimeCreated[@SystemTime >= '$($startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))']]]" | Where-Object {
            $_.TimeCreated -ge $startTime -and (
                ($_.Message -match 'powershell\.exe|cmd\.exe') -and
                ($keywords | Where-Object { $_ -in $_.Message })
            )
        }
    } catch {
        Write-Output "Could not retrieve process-related events from Security log. Error: $_"
    }
} else {
    Write-Output "Security log is not available or accessible."
}

# Output results
Write-Output "File-related Events:"
if ($fileEvents.Count -gt 0) {
    $fileEvents | Format-Table TimeCreated, Id, Message
} else {
    Write-Output "No file-related events found or log not accessible."
}

Write-Output "`nProcess-related Events:"
if ($processEvents.Count -gt 0) {
    $processEvents | Format-Table TimeCreated, Id, Message
} else {
    Write-Output "No process-related events found or log not accessible."
}
