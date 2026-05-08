# 🖨️ Printer AI Technician Toolkit (Windows 10/11)

This project is an **enterprise-grade Printer Troubleshooting + AI Technician automation system** built in a single PowerShell GUI script.

It replaces traditional standalone scripts with a **centralized intelligent repair interface** capable of:
- Diagnosing printer and spooler health in real time
- Automatically fixing common Windows printing issues
- Resetting and repairing the print spooler
- Providing helpdesk-ready system audit reports

---

## 🚀 Current System Status (In Development)

This project has evolved from individual scripts into a **full AI-assisted technician toolkit**.

### 🧠 Now Implemented (Core AI Toolkit)

| Feature / Function            | Description |
|------------------------------|-------------|
| `Printer AI Audit Engine`    | Real-time system analysis of spooler, CPU, RAM, printer count, and active jobs |
| `Spooler PID Tracking`       | Detects `spoolsv.exe` process ID for deep diagnostics |
| `AI Health Report`           | Generates structured printer health report for helpdesk use |
| `Auto Fix Mode` (planned expansion) | One-click repair workflow for common printing issues |
| `Deep Spooler Reset`        | Stops spooler, clears corrupted queue, restarts service safely |
| `Driver Management Panel`    | Opens Windows native driver UI (`printui.exe`) |
| `Full Printer Removal Tool`  | Removes all printers for system reset scenarios |
| `Logging System`             | Tracks all actions into `printer-ai.log` for auditing |

---

## 🔧 Repair Capabilities

The toolkit currently handles:

### 🛠️ Print System Fixes
- Restart Windows Print Spooler
- Clear stuck print queues
- Deep spooler reset (service + spool folder cleanup)
- Recover frozen or ghost print jobs

### 🖨️ Printer Management
- List installed printers
- Remove all printers (reset mode)
- Open driver management console
- Analyze printer count and system state

### 📊 AI Diagnostics Engine
- Spooler status monitoring
- CPU usage tracking for `spoolsv.exe`
- RAM usage analysis
- Active job detection
- System health reporting

---

## 🧠 Architecture Upgrade (New Direction)

This project is transitioning from simple scripts into a:

> **“AI Technician Automation System for Windows Printing Infrastructure”**

### Key design improvements:
- Single-file enterprise GUI (PowerShell WinForms)
- Modular diagnostic + repair engine
- Automated logging system
- Helpdesk-ready output formatting
- Expandable AI decision logic layer (future upgrade)

---

## 📂 Project Structure (Logical View)

Even though this is a **single-file toolkit**, it functions like a modular system:

| Module | Purpose |
|--------|--------|
| UI Layer | Windows Forms technician interface |
| Diagnostics Engine | Printer + spooler analysis |
| Repair Engine | Fix and recovery functions |
| Logging System | Audit trail for all actions |
| AI Report Generator | Helpdesk-ready system output |

---

## ⚙️ Requirements

- Windows 10 / Windows 11
- PowerShell 5.1+
- Administrator privileges (required for full repair access)
- Built-in Windows Print Spooler service enabled

---

## ▶️ Usage

Run PowerShell as Administrator:

```powershell
.\Printer-AI-Technician-Toolkit.ps1

```
