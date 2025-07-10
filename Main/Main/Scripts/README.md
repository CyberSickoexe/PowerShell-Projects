@"
# IT Support PowerShell Admin Toolkit with Advanced System Information GUI

## Executive Summary

The **IT Support PowerShell Admin Toolkit** delivers a cutting-edge, integrated solution engineered to optimize and automate critical Windows system administration and diagnostics workflows. Designed for enterprise environments, this toolkit consolidates multifaceted operational tasks into a sleek, interactive GUI, thereby empowering IT professionals to perform comprehensive system health assessments, proactive maintenance, and remediation — all without deep command-line expertise.

Central to this framework is a dynamic **System Info Report GUI** that furnishes granular real-time telemetry alongside robust automated reporting capabilities, enabling data-driven operational excellence and accelerated incident response.

---

## Core Features & Functional Scope

### 1. System Info Report GUI  
- Feature-rich Windows Forms interface presenting exhaustive system telemetry including:  
  - Precise Operating System metadata (edition, build number, patch level)  
  - Detailed processor architecture and specifications (model, cores, threads)  
  - Comprehensive memory analytics (total, available, utilization metrics)  
  - Granular disk subsystem insights (capacity, free space, filesystem integrity status)  
  - Network interface enumeration with hardware MAC addresses and connectivity status  
- Integrated event log analytics scanning critical Windows System and Application logs for Errors and Warnings within the last 48 hours, with prioritized issue highlighting.  
- Intelligent diagnostics with automated remediation advisories, including filesystem health checks and resource saturation alerts.  
- Real-time report rendering within a scrollable, user-configurable interface panel.  
- Seamless integration with Windows Task Scheduler facilitating configurable, unattended daily report generation (default scheduled at 08:00 local time).

### 2. Advanced Network & Storage Diagnostics  
- Exhaustive network adapter state inspection, IP configuration retrieval, and connectivity verification utilities.  
- Detailed disk utilization statistics supporting capacity planning, fragmentation analysis, and preventative maintenance workflows.

### 3. Active Directory User Management Module *(Optional)*  
- Secure, credential-protected functions enabling granular AD user account management operations such as password resets and account unlocking, leveraging RSAT PowerShell modules.  
- Built with compliance and auditability in mind, suitable for enterprise security policies.

### 4. Network Drive Lifecycle Management  
- Comprehensive cmdlets to programmatically map, unmap, and validate persistent network drives, including credential delegation and session persistence handling.

### 5. Automated Temporary File Purge  
- Scheduled and on-demand cleanup routines targeting user profile temporary directories to reclaim disk space and enhance endpoint performance.

---

## Architectural & Technical Highlights

- **Platform:** Native Windows PowerShell 5.1+ environment, leveraging robust cmdlets (`Get-CimInstance`, `Get-WmiObject`, `Get-WinEvent`, `Get-NetAdapter`) alongside fully managed .NET Windows Forms (`System.Windows.Forms`, `System.Drawing`) for GUI components.  
- **User Experience:** Intuitive, responsive Windows Forms GUI designed for minimal learning curve and maximal operational efficiency — replacing complex CLI commands with straightforward, actionable interfaces.  
- **Error Management:** Comprehensive exception handling and contextual error reporting, delivering precise diagnostics and actionable feedback within the GUI environment.  
- **Code Modularity:** Highly maintainable, well-documented, and extensible architecture facilitating rapid customization and integration into existing IT management workflows.  
- **Minimal External Dependencies:** Zero reliance on third-party software; AD management features require Microsoft RSAT modules installed and configured.

---

## Target Audience

- Senior IT Support Engineers & System Administrators  
- Enterprise Helpdesk & Desktop Support Teams  
- Network Operations Center (NOC) Technicians  
- IT Infrastructure Architects and Automation Engineers

Designed to unify and elevate routine system monitoring, diagnostic, and user management tasks, this toolkit fosters operational consistency, accelerates troubleshooting cycles, and reduces human error in large-scale Windows deployments.

---

## Operational Guidance

1. **Execution Environment:** Launch within elevated Windows PowerShell 5.1+ session to ensure full functionality.  
2. **Diagnostics & Reporting:** Activate the **Run Report** command via the GUI to generate a comprehensive system status snapshot.  
3. **Automation Scheduling:** Employ the **Schedule Daily Report** feature to instantiate a Windows Task Scheduler job for hands-free, periodic reporting.  
4. **Extensibility:** Leverage optional modules for advanced AD user lifecycle management, network drive automation, and disk cleanup tailored to enterprise policies.

---

*Delivering next-generation automation, deep system visibility, and streamlined IT operations — empowering professionals to maintain peak infrastructure performance with confidence and precision.*

"@ | Out-File -FilePath .\README.md -Encoding utf8
