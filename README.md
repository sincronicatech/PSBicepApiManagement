# PSBicepApiManagement

Powershell module to export/import a single api from Azure Api Management using Azure Bicep. Uses 
- PSBicepParser.Powershell to create and parse Bicep files (https://github.com/sincronicatech/PSBicepParser.Powershell)
- Microsoft.PowerShell.ConsoleGuiTools module to create a simple GUI

The module exposes the following 

### Export-PSBicepApiManagementApi

Exports the last revision of a single API from an Azure Api Management instance to a Bicep file. Works also with Consumption Api Management instances. 

### Export-PSBicepApiManagementApiVersionSet

Exports the last revision of all APIs in a Api Version Set from an Azure Api Management instance to a Bicep file. Works also with Consumption Api Management instances. 

### Import-PSBicepApiManagementApi

Imports a Bicep file containing an export of an Api Management Api.

### Copy-PSBicepApiManagementApiWithGUI

Exposes a very simple GUI to help operators to export and import Apis from Api Management instances. Acts as orchestrator of the previous functions.


## Example

Just call the Copy-PSBicepApiManagementApiWithGUI module. It prints the other function calls.
