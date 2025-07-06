## 1. Full **README.md** with command-line instructions

```markdown
# IT Support PowerShell Tools

## Overview
This repository contains PowerShell scripts to help IT Support professionals automate common tasks such as network info retrieval, AD user management, disk space checking, and more.

---

## Project Structure

```markdown

IT-Support-Tools/
├── Main/
│   ├── Scripts/
│   ├── Outputs/
│   ├── Notes.md
│   └── README.md
├── Printer-Troubleshooting/
│   ├── Scripts/
│   └── README.md
├── AD-UserManagement/
│   ├── Scripts/
│   └── README.md
└── README.md

````

---

## Included Scripts (Main/Scripts)

| Script Name              | Description                                  |
|--------------------------|----------------------------------------------|
| `Get-NetworkInfo.ps1`    | Shows detailed network adapter info          |
| `Reset-UserPassword.ps1` | Resets AD user passwords                       |
| `Check-DiskSpace.ps1`    | Checks disk space and warns if low            |
| `Map-NetworkDrive.ps1`   | Maps a network drive                           |
| `Clear-TempFiles.ps1`    | Clears temporary files to free disk space     |

---

## How to Use

### Step 1: Clone the repository

```powershell
git clone https://github.com/YourUsername/IT-Support-Tools.git
cd IT-Support-Tools
````

### Step 2: Set Execution Policy (if needed)

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Confirm with `Y`.

### Step 3: Run a script

Navigate to the script folder and run:

```powershell
cd .\Main\Scripts\
.\Get-NetworkInfo.ps1
```

---

## Requirements

* Windows PowerShell 5.1 or later (PowerShell Core supported)
* RSAT tools installed for AD scripts
* Proper permissions for certain scripts
* Execution policy allowing script execution

---

## Notes

* Always review scripts before use.
* Customize scripts as needed.
* Scripts contain comments for guidance.

---

## Contributing

Fork the repo, add scripts or fixes, and submit pull requests.

---

## License

MIT License

---

*Happy scripting!*

````

---

## 2. Example **GitHub Actions workflow YAML** for PowerShell scripts testing

Create a file `.github/workflows/powershell.yml` in your repo:

```yaml
name: PowerShell Script CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-powershell:
    runs-on: windows-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Setup PowerShell
        uses: actions/setup-powershell@v2

      - name: Run PowerShell Scripts Syntax Check
        shell: pwsh
        run: |
          # Test syntax for each script in Main/Scripts folder
          Get-ChildItem -Path Main\Scripts -Filter *.ps1 | ForEach-Object {
            Write-Host "Checking syntax of $($_.FullName)"
            pwsh -NoProfile -Command "Test-Expression -Command (Get-Content -Raw $_.FullName)"
          }
````

---

### Explanation:

* **README.md** contains all commands you run in PowerShell.
* **GitHub Actions YAML** automates script syntax checks on every push or pull request to `main`.
* You can expand the workflow to include running scripts, deploying, or other testing.
