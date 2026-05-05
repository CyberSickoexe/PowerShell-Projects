# IT Support PowerShell Admin Toolkit – Advanced System Information GUI

## Executive Summary

The **IT Support PowerShell Admin Toolkit** is an enterprise-grade Windows automation and diagnostics solution designed to centralize and streamline core system administration tasks. It replaces fragmented command-line workflows with a unified, interactive GUI built on Windows Forms, enabling IT professionals to monitor, diagnose, and maintain systems efficiently.

At its core, the toolkit provides a **real-time System Information Dashboard** and an **advanced network and system analysis suite**, delivering actionable insights for faster troubleshooting and improved operational visibility.

---

## Core Features

### 1. System Information Dashboard

A real-time GUI-based system monitoring panel providing live telemetry and system health visibility, including:

* Operating System details (edition, build, version, patch level)
* CPU architecture, core count, and performance data
* Memory usage and availability statistics
* Disk health, capacity, and free space reporting
* Active network adapter status and MAC address inventory
* Live refresh-based system monitoring view

---

### 2. Event Log Monitoring & Analysis

* Reads Windows **System** and **Application** logs
* Filters **Errors and Warnings (last 48 hours)**
* Displays structured event summaries in GUI
* Full message inspection for selected events
* Exportable event logs for reporting and audits

---

### 3. Advanced Network Diagnostics Suite

A comprehensive network analysis module including:

* Active TCP connection mapping with process attribution
* DNS resolution forensics across multiple resolvers
* Traceroute path analysis with latency and bottleneck detection
* Suspicious connection detection (known high-risk ports)
* Network snapshot and baseline comparison system
* Change detection between known-good and current state

---

### 4. Service & Startup Visibility

* Real-time Windows service inventory (status, name, display name)
* Startup program enumeration for persistence analysis
* System-wide service health overview
* Exportable service dataset for documentation and review

---

### 5. Performance Monitoring (Live Charting)

* Real-time CPU usage tracking
* Memory utilization monitoring
* Live graphical performance dashboard
* Pause/resume monitoring controls
* Rolling data window for continuous analysis

---

### 6. Automated System Reporting Tool

* One-click system report generation
* Outputs:

  * OS, CPU, RAM, disk, and network summaries
  * Recent event log highlights
* Detects potential issues and suggests remediation actions
* Optional scheduled daily report generation (Task Scheduler integration)

---

### 7. Network Baseline & Security Analysis

* Save known-good network state snapshots
* Compare current vs baseline connections
* Detect:

  * New connections
  * Missing or changed connections
* Suspicious activity detection based on port heuristics
* Supports proactive intrusion and anomaly identification

---

## Architecture & Technical Design

* **Platform:** PowerShell 5.1+
* **UI Framework:** Windows Forms (.NET System.Windows.Forms)
* **Data Model:** PSCustomObject-based structured outputs
* **Core APIs Used:**

  * CIM/WMI (`Get-CimInstance`, `Get-WmiObject`)
  * Networking (`Get-NetAdapter`, `Get-NetTCPConnection`, `Resolve-DnsName`)
  * Event Logs (`Get-WinEvent`)
  * Performance Counters (`Get-Counter`)
* **Design Approach:**

  * Modular function-based architecture
  * Separation of UI, diagnostics, and data layers
  * Reusable diagnostic components
* **Error Handling:**

  * Try/Catch-based fault tolerance across all system calls
  * Graceful degradation when system APIs are unavailable
* **Dependencies:**

  * Native Windows components only
  * Optional RSAT modules for extended administrative features

---

## Target Audience

* IT Support Engineers
* System Administrators
* Network Operations Center (NOC) Technicians
* Desktop Support Teams
* Infrastructure and Security Analysts

---

## Operational Requirements

* Windows PowerShell 5.1 or later
* Administrator privileges recommended for full diagnostics
* Windows environment with standard system cmdlets available
* Optional: RSAT tools for Active Directory and advanced management features

---

## Usage Overview

### System Report Tool

* Click **Run Report** to generate a full system snapshot
* Review system health, disk usage, and event logs
* Identify potential system issues automatically

### Scheduled Reporting

* Click **Schedule Daily Report**
* Automatically creates a Windows Task Scheduler job
* Runs daily at 8:00 AM local time

---

## Key Benefits

* Centralized IT diagnostics in a single interface
* Reduced reliance on manual PowerShell commands
* Faster incident response and troubleshooting
* Improved visibility into system and network behavior
* Lightweight, native Windows solution with no external dependencies

---

## Summary

The **IT Support PowerShell Admin Toolkit** delivers a unified operational platform for Windows system management, combining real-time monitoring, advanced diagnostics, and automated reporting. It is designed to enhance efficiency, reduce manual workload, and provide deep visibility into enterprise IT environments.

