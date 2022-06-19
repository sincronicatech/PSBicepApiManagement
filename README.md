# apimanagement-api-export-import
Powershell module to export/import a single api from Azure Api Management using Azure Bicep. Uses 
- PSBicepParser.Powershell to create and parse Bicep files (https://github.com/sincronicatech/PSBicepParser.Powershell)
- Microsoft.PowerShell.ConsoleGuiTools module to create a simple GUI

The scripts can be integrated in a CI/CD pipeline.

## Export-ApiManagementApi.ps1

Exports the last revision of a single API from an Azure Api Management instance to a Bicep file. Works also with Consumption Api Management instances. It manages external dependecies (i.e. Application insighs configs) by creating the Bicep resource with the "Existing" flag.
Can also export the last revision of all versions of an Api.

## Import-ApiManagementApi.ps1

Imports a Bicep file containing an export of an Api Management Api.

## Copy-ApiManagementApiWithGUI.ps1

Exposes a very simple GUI to help operators to export and import Apis from Api Management instances. Acts as an orchestrator of the previous two scripts.

