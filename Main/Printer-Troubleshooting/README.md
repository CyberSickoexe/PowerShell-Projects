````markdown
# Printer Troubleshooting Tools

This folder contains PowerShell scripts and utilities to help IT Support professionals diagnose and resolve common printer issues quickly and efficiently.

---

## Planned and Existing Scripts

| Script / Feature               | Description                                              |
|-------------------------------|----------------------------------------------------------|
| `Get-PrinterStatus.ps1`       | Retrieve current status of installed printers            |
| `Clear-PrintQueue.ps1`        | Clear stuck print jobs from the print queue              |
| `Restart-PrintSpooler.ps1`    | Restart the Windows Print Spooler service                 |
| `Install-PrinterDriver.ps1`   | Automate installation of printer drivers                  |
| `Set-DefaultPrinter.ps1`      | Set the default printer for the current user              |
| `List-NetworkPrinters.ps1`    | List all network printers accessible to the user          |
| `Test-PrinterConnectivity.ps1`| Test network connectivity to a specified printer          |
| `Remove-Printer.ps1`          | Remove a printer from the system                            |
| `Add-NetworkPrinter.ps1`      | Add a network printer by IP or hostname                     |

---

## Getting Started

### Prerequisites

- Windows PowerShell 5.1+  
- Proper user permissions to manage printers and services  
- Network access to printers when applicable  

### Running Scripts

Open PowerShell with appropriate permissions and navigate to this folder:

```powershell
cd .\Printer-Troubleshooting\Scripts\
.\Get-PrinterStatus.ps1 -PrinterName "HP_LaserJet_400"
````

---

## Contribution Guidelines

* Comment and document your scripts clearly
* Test scripts on multiple Windows versions if possible
* Follow consistent naming conventions
* Submit pull requests to contribute new scripts or improvements

---

## License

MIT License

---

*Simplify your printer support with automation!*

```
