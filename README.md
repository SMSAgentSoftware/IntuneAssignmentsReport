# Intune Assignments Report

The Intune Assignments Report is a Power BI report intended to give you a single pane of glass into your assigned items in Microsoft Intune. It uses Azure automation to extract the data from Microsoft Graph and export it in CSV format to an Azure storage account. The CSV file is the data source for the Power BI report.

The report can help you identify which Entra groups are being used in your assignments, how many assigned items you have and their types, the use of virtual groups (all users/devices) and any assignment filters in use.

![alt text][screenshot]

[screenshot]: https://github.com/SMSAgentSoftware/IntuneAssignmentsReport/blob/main/Report%20screenshot.png "Report screenshot"

## Supported assignable items
Currently the solution supports at least the following assignable items. Most have been tested but not all. If you find any issues or want to add any missing assignable items, please raise an issue on this repository.
- Apps
- Compliance policies
- Configuration policies
- Windows Autopilot deployment profiles
- Enrollment configurations
- Enrollment profiles
- Customization policies
- App protection policies
- App configuration policies
- Policy sets
- E-books
- S mode supplemental policies
- iOS app provisioning profiles
- Windows 365 provisioning policies
- Windows 365 user settings
- Scripts and remediations
- Windows Feature Update profiles
- Windows Quality Update profiles
- Windows Driver Update profiles
- eSIM cellular profiles
- Security baselines
- Endpoint security policies
- RBAC Roles
- Scope tags
- Multi admin approvals
- Terms and conditions

## Currently unsupported items
- Conditional access policies
- Organizational messages
- Anything unique to the Intune Suite
- Anything unique to Autopatch
