Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-NetworkInfo {
    $output = ""
    Get-NetAdapter | ForEach-Object {
        $adapter = $_
        $ipConfig = Get-NetIPAddress -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue

        $ipv4 = ($ipConfig | Where-Object {$_.AddressFamily -eq 'IPv4'}).IPAddress -join ", "
        $ipv6 = ($ipConfig | Where-Object {$_.AddressFamily -eq 'IPv6'}).IPAddress -join ", "

        $output += "Adapter: $($adapter.Name)`n"
        $output += "Status: $($adapter.Status)`n"
        $output += "MAC: $($adapter.MacAddress)`n"
        $output += "Link Speed: $($adapter.LinkSpeed)`n"
        $output += "IPv4: $ipv4`nIPv6: $ipv6`n`n"
    }
    [System.Windows.Forms.MessageBox]::Show($output, "Network Adapter Info")
}

function Map-NetworkDrive {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Map Network Drive"
    $form.Size = New-Object System.Drawing.Size(300,250)
    $form.StartPosition = "CenterScreen"

    $labelDrive = New-Object System.Windows.Forms.Label
    $labelDrive.Text = "Drive Letter:"
    $labelDrive.Location = New-Object System.Drawing.Point(10,20)
    $form.Controls.Add($labelDrive)

    $textDrive = New-Object System.Windows.Forms.TextBox
    $textDrive.Location = New-Object System.Drawing.Point(100,18)
    $form.Controls.Add($textDrive)

    $labelPath = New-Object System.Windows.Forms.Label
    $labelPath.Text = "Network Path:"
    $labelPath.Location = New-Object System.Drawing.Point(10,50)
    $form.Controls.Add($labelPath)

    $textPath = New-Object System.Windows.Forms.TextBox
    $textPath.Location = New-Object System.Drawing.Point(100,48)
    $form.Controls.Add($textPath)

    $chkPersist = New-Object System.Windows.Forms.CheckBox
    $chkPersist.Text = "Persist After Reboot"
    $chkPersist.Location = New-Object System.Drawing.Point(10,80)
    $form.Controls.Add($chkPersist)

    $chkCreds = New-Object System.Windows.Forms.CheckBox
    $chkCreds.Text = "Use Custom Credentials"
    $chkCreds.Location = New-Object System.Drawing.Point(10,105)
    $form.Controls.Add($chkCreds)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = "Map Drive"
    $buttonOK.Location = New-Object System.Drawing.Point(100,140)
    $buttonOK.Add_Click({
        $driveLetter = $textDrive.Text.TrimEnd(":")
        $networkPath = $textPath.Text
        $persist = $chkPersist.Checked
        $useCreds = $chkCreds.Checked

        if (!(Test-Path $networkPath)) {
            [System.Windows.Forms.MessageBox]::Show("Path is not reachable.")
            return
        }

        if (Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $driveLetter -Force
        }

        try {
            if ($useCreds) {
                $cred = Get-Credential
                New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $networkPath -Persist:$persist -Credential $cred
            } else {
                New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $networkPath -Persist:$persist
            }
            [System.Windows.Forms.MessageBox]::Show("Drive ${driveLetter}: mapped to $networkPath")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to map drive: $_")
        }

        $form.Close()
    })
    $form.Controls.Add($buttonOK)
    $form.ShowDialog()
}

function Check-DiskSpace {
    $output = ""
    Get-PSDrive -PSProvider 'FileSystem' | ForEach-Object {
        $freeGB = "{0:N2}" -f ($_.Free / 1GB)
        $totalGB = "{0:N2}" -f (($_.Used + $_.Free) / 1GB)
        $percentFree = ($_.Free / ($_.Used + $_.Free)) * 100

        $output += "Drive: $($_.Name)`nFree: $freeGB GB`nTotal: $totalGB GB`nFree %: {0:N1}%%`n`n" -f $percentFree
    }
    [System.Windows.Forms.MessageBox]::Show($output, "Disk Space")
}

function Clear-TempFiles {
    $tempPath = [System.IO.Path]::GetTempPath()
    try {
        $files = Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        $count = $files.Count
        $files | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("Cleared $count temp files from $tempPath", "Success")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error clearing temp files: $_", "Error")
    }
}

function Reset-UserPassword {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $username = [System.Windows.Forms.Interaction]::InputBox("Enter the username", "Username")
        if (-not $username) { return }
        $password = Read-Host "Enter new password" -AsSecureString

        Set-ADAccountPassword -Identity $username -NewPassword $password -Reset
        Unlock-ADAccount -Identity $username

        [System.Windows.Forms.MessageBox]::Show("Password reset and account unlocked for '$username'", "Success")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error")
    }
}

# GUI MAIN MENU
$formMain = New-Object System.Windows.Forms.Form
$formMain.Text = "Admin Toolkit GUI"
$formMain.Size = New-Object System.Drawing.Size(350,300)
$formMain.StartPosition = "CenterScreen"

$btn1 = New-Object System.Windows.Forms.Button
$btn1.Text = "Network Info"
$btn1.Size = New-Object System.Drawing.Size(300,30)
$btn1.Location = "20,20"
$btn1.Add_Click({ Show-NetworkInfo })
$formMain.Controls.Add($btn1)

$btn2 = New-Object System.Windows.Forms.Button
$btn2.Text = "Map Network Drive"
$btn2.Size = New-Object System.Drawing.Size(300,30)
$btn2.Location = "20,60"
$btn2.Add_Click({ Map-NetworkDrive })
$formMain.Controls.Add($btn2)

$btn3 = New-Object System.Windows.Forms.Button
$btn3.Text = "Check Disk Space"
$btn3.Size = New-Object System.Drawing.Size(300,30)
$btn3.Location = "20,100"
$btn3.Add_Click({ Check-DiskSpace })
$formMain.Controls.Add($btn3)

$btn4 = New-Object System.Windows.Forms.Button
$btn4.Text = "Clear Temp Files"
$btn4.Size = New-Object System.Drawing.Size(300,30)
$btn4.Location = "20,140"
$btn4.Add_Click({ Clear-TempFiles })
$formMain.Controls.Add($btn4)

$btn5 = New-Object System.Windows.Forms.Button
$btn5.Text = "Reset AD Password"
$btn5.Size = New-Object System.Drawing.Size(300,30)
$btn5.Location = "20,180"
$btn5.Add_Click({ Reset-UserPassword })
$formMain.Controls.Add($btn5)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Size = New-Object System.Drawing.Size(300,30)
$btnExit.Location = "20,220"
$btnExit.Add_Click({ $formMain.Close() })
$formMain.Controls.Add($btnExit)

[void]$formMain.ShowDialog()
