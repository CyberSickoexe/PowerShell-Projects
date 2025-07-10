@"
# IT Support PowerShell Admin Toolkit with System Info GUI

## Executive Summary

The **IT Support PowerShell Admin Toolkit** is a comprehensive, unified solution designed to streamline essential system administration and diagnostics tasks within Windows environments. It consolidates critical functions into an intuitive graphical interface, empowering IT professionals to efficiently monitor, maintain, and troubleshoot systems without relying on complex command-line operations.

At its core, the toolkit features an interactive **System Info Report GUI**, providing quick, detailed snapshots of system health and enabling automated daily reporting.

---

## Key Features and Capabilities

### 1. System Info Report GUI  
- Interactive Windows Forms interface displaying detailed system information:  
  - Operating System details (version, build)  
  - CPU model and specifications  
  - Total and available RAM  
  - Disk space usage per drive (size, free space, filesystem)  
  - Active network adapters with MAC addresses  
- Scans recent Windows Event Logs (System and Application) for errors and warnings within the last 48 hours.  
- Summarizes key issues and offers automated suggestions for common critical problems (e.g., scheduling disk checks on NTFS corruption).  
- Enables immediate report generation and display in a scrollable text box.  
- Option to schedule daily automated system reports via Windows Task Scheduler (runs at 8 AM by default).

### 2. Network and Disk Diagnostics  
- Retrieves and presents detailed network adapter status and IP configurations.  
- Provides comprehensive disk usage statistics to aid capacity planning and proactive maintenance.

### 3. Active Directory User Management (Optional)  
- Includes functionality to reset and unlock AD user accounts securely, with credential prompts and compliance considerations. *(Requires RSAT modules.)*

### 4. Network Drive Management  
- Allows mapping and removal of network drives with persistent connection and credential support.

### 5. Temporary File Cleanup  
- Automates clearing of user profile temporary files to improve disk utilization and system responsiveness.

---

## Design and Technology Highlights

- **Windows PowerShell 5.1+ Compatible:**  
  Relies on native cmdlets (`Get-CimInstance`, `Get-WmiObject`, `Get-WinEvent`, `Get-NetAdapter`, etc.) and Windows Forms assemblies (`System.Windows.Forms`, `System.Drawing`) for GUI elements.

- **User-Friendly GUI:**  
  Employs Windows Forms for an intuitive, menu-driven interface enabling point-and-click operations over scripting complexity.

- **Robust Error Handling:**  
  Provides clear feedback, error notifications, and actionable suggestions within the GUI context, minimizing guesswork.

- **Modular and Maintainable Code:**  
  Structured with readable, commented functions facilitating customization and extension.

- **Minimal Dependencies:**  
  Operates entirely within the Windows ecosystem without third-party software, though Active Directory functions require RSAT.

---

## Intended Audience

- IT Support Engineers  
- System Administrators  
- Helpdesk and Desktop Support Staff  
- Network Operations Center (NOC) Technicians

This toolkit suits professionals seeking to unify routine administrative tasks, system diagnostics, and user management into a single accessible tool, enhancing productivity and reducing operational errors.

---

## Usage Overview

1. **Run the Script:** Launch the PowerShell script in a Windows PowerShell 5.1+ session.  
2. **Generate Reports:** Use the **Run Report** button in the GUI to view real-time system diagnostics.  
3. **Schedule Automation:** Click **Schedule Daily Report** to create a scheduled task that outputs daily system reports without manual intervention.  
4. **Extend Toolkit:** Optionally use included modules for AD user management, network drive mapping, and temp file cleanup as per your environment needs.

---

*Empowering IT Professionals with streamlined automation, actionable insights, and intuitive interfaces.*

"@ | Out-File -FilePath .\README.md -Encoding utf8
