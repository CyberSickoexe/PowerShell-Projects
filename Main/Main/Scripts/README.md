@"
# IT Support PowerShell Admin Toolkit with Advanced System Information GUI

## Executive Summary

The **IT Support PowerShell Admin Toolkit** is an integrated Windows automation and diagnostics solution designed to streamline enterprise system administration. It consolidates core IT operations into a unified, interactive GUI, enabling administrators to perform system monitoring, troubleshooting, and maintenance without relying heavily on command-line workflows.

At its core, the toolkit features a real-time **System Information Dashboard** that provides live telemetry, automated diagnostics, and structured reporting to support faster incident response and informed operational decisions.

---

## Core Features & Functional Scope

### 1. System Information Dashboard
- Windows Forms-based GUI delivering real-time system metrics, including:
  - Operating system details (version, build, edition, patch level)
  - CPU architecture, core count, and thread information
  - Memory utilization and availability statistics
  - Disk capacity, usage, and storage health overview
  - Network adapter status and MAC address reporting
- Event log analysis for System and Application logs (Errors and Warnings)
- Automated system health insights with performance and resource alerts
- Real-time UI updates for continuous monitoring

### 2. Network Diagnostics & Analysis
- Network adapter inspection and IP configuration reporting
- Active connection monitoring with process-level attribution
- DNS resolution and multi-resolver comparison analysis
- Traceroute-based path inspection with latency assessment
- Suspicious connection detection based on known high-risk ports
- Network baseline capture and change comparison for anomaly detection

### 3. Event Log Monitoring
- Retrieval of Windows Event Logs across System, Application, and Security channels
- Filtering of critical warnings and errors
- Detailed event inspection within GUI panel
- Export functionality for reporting and auditing

### 4. Service & Startup Management Overview
- Listing and monitoring of Windows services with status visibility
- Startup program enumeration for system persistence analysis
- Exportable service inventory for administrative review

---

## Architectural & Technical Highlights

- **Platform:** PowerShell 5.1+ with native .NET Windows Forms integration  
- **Core Libraries:** `System.Windows.Forms`, `System.Drawing`, `System.Windows.Forms.DataVisualization`  
- **Design Approach:** Modular function-based architecture for reusable UI and system components  
- **Data Handling:** Structured PSCustomObject outputs for consistent data binding in GUI grids  
- **Error Handling:** Robust try/catch implementation across system and network operations  
- **Performance Design:** Incremental updates for live charts and lightweight polling intervals  
- **Dependencies:** Fully native Windows tooling; optional RSAT modules for extended administrative features  

---

## Target Audience

- IT Support Engineers and System Administrators  
- Network Operations Center (NOC) Technicians  
- Infrastructure and Systems Engineers  
- Helpdesk and Desktop Support Teams  

The toolkit is designed to centralize operational workflows, reduce manual command-line dependency, and improve response efficiency across enterprise Windows environments.

---

## Operational Notes

- Requires Windows PowerShell 5.1 or later  
- Recommended execution in elevated (Administrator) mode for full access to system data  
- GUI-driven workflow replaces most manual diagnostic commands  
- Network baseline feature should be initialized during known-good system state  

---

*An integrated approach to Windows system administration, combining visibility, automation, and diagnostics into a single operational interface.*
"@ | Out-File -FilePath .\README.md -Encoding utf8
