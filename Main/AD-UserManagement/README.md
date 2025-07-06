````markdown
# Active Directory User Management Tools

This folder contains PowerShell scripts and tools designed to help automate and simplify common Active Directory (AD) user and group management tasks for IT Support professionals.

---

## Current and Future Projects

Here are some planned and useful scripts you can expect or create to manage AD users effectively:

| Script / Feature               | Description                                              |
|-------------------------------|----------------------------------------------------------|
| `Create-ADUser.ps1`           | Script to create new AD users with customizable attributes |
| `Reset-UserPassword.ps1`      | Automate password resets for one or multiple users        |
| `Disable-ADUser.ps1`          | Disable user accounts that are inactive or terminated     |
| `Enable-ADUser.ps1`           | Enable previously disabled users                           |
| `Get-ADUserDetails.ps1`       | Retrieve detailed user information from AD                |
| `Add-UserToGroup.ps1`         | Add a user to a security or distribution group            |
| `Remove-UserFromGroup.ps1`    | Remove a user from a group                                 |
| `Unlock-ADUserAccount.ps1`    | Unlock locked user accounts                                |
| `Bulk-UserImport.ps1`         | Import users from CSV for mass user creation              |
| `Audit-ADUserLogon.ps1`       | Check last logon times for AD users                        |

---

## Getting Started

### Prerequisites

- Windows PowerShell 5.1+ or PowerShell Core  
- RSAT tools installed with Active Directory module  
- Proper permissions to query and modify AD objects  

### Running Scripts

Open PowerShell with necessary privileges, then navigate to this folder:

```powershell
cd .\AD-UserManagement\Scripts\
.\Get-ADUserDetails.ps1 -Username "jdoe"
````

---

## Contribution Guidelines

* Add clear comments and help documentation in each script
* Test scripts thoroughly before submitting
* Use consistent naming conventions
* Submit pull requests for new features or fixes

---

## License

MIT License

---

*Streamline your Active Directory management with automation!*

```

