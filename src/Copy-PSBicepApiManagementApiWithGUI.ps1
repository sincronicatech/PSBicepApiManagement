function Copy-PSBicepApiManagementApiWithGUI()
{
    $ErrorActionPreference = 'Stop'

    try{
        Get-AzContext|Out-Null
    }
    catch{
        connect-azAccount|Out-Null
    }

    function Get-ApiManagement($env){
        Get-AzSubscription | Out-ConsoleGridView -Title "Select $env subscription" -OutputMode Single | Set-AzContext | Out-Null

        $apim = Get-AzApiManagement | ForEach-Object{
            $obj = "" |Select-Object Name,ResourceGroup, Apim
            $obj.Name = $_.Name
            $obj.ResourceGroup = $_.ResourceGroupName
            $obj.apim = $_
            $obj
        } | Out-ConsoleGridView -Title "Select $env Api Management" -OutputMode Single
        if($null -eq $apim)
        {
            throw "No api management service selected"
        }
        $apim.Apim
    }
    $SubscriptionIdFinder = [regex]'^/subscriptions/(.*?)/.*$'

    $sourceApiManagement = Get-ApiManagement -env 'source'
    $sourceSubscriptionId = $SubscriptionIdFinder.Replace($sourceApiManagement.Id,'$1')

    $sourceVersionSet = $null
    $Response = Read-Host -Prompt 'Do you want to export a single api version or all versions of an api? [ONE/all]'
    if($response -ne 'all')
    {
        $sourceapimcontext = New-AzApiManagementContext -ResourceId $sourceApiManagement.Id
        $sourceapiobj = Get-AzApiManagementApi -Context $sourceapimcontext | ForEach-Object{
            $obj = "" |Select-Object Name,Path,ApiVersion,ApiId,Api
            $obj.Name = $_.Name
            $obj.Path = $_.Path
            $obj.ApiVersion = $_.ApiVersion
            $obj.ApiId = $_.ApiId
            $obj.Api = $_
            $obj
        } | Out-ConsoleGridView -Title "Select source Api" -OutputMode Single

        if($null -eq $sourceapiobj)
        {
            throw "No api selected"
        }

        $sourceApi = $sourceapiobj.Api
        $sourceelement = $sourceApi.ApiId
    }
    else{
        $sourceapimcontext = New-AzApiManagementContext -ResourceId $sourceApiManagement.Id
        $sourceVersionSetObj = Get-AzApiManagementApiVersionSet -Context $sourceapimcontext | ForEach-Object{
            $obj = "" |Select-Object Name,VersionSetId
            $obj.Name = $_.DisplayName
            $obj.VersionSetId = $_.ApiVersionSetId
            $obj
        } | Out-ConsoleGridView -Title "Select source Api Version set" -OutputMode Single

        if($null -eq $sourceVersionSetObj)
        {
            throw "No api version selected"
        }

        $sourceVersionSet = $sourceVersionSetObj
        $sourceelement = $sourceVersionSet.VersionSetId

    }

    $targetFile = "$Env:temp\$($sourceelement)"

    write-host "Source"
    write-host "    API Mamanagement"
    write-host "        SubscriptionId: $sourceSubscriptionId"
    write-host "        Resource Group: $($sourceApiManagement.ResourceGroupName)"
    write-host "        Name:           $($sourceApiManagement.Name)"

    if($null -ne $sourceVersionSet){
        write-host "    API version set"
        write-host "        Name:           $($sourceVersionSet.Name)"
        write-host "        Id:             $($sourceVersionSet.VersionSetId)"
    }
    else{
        write-host "    API"
        write-host "        Name:           $($sourceapi.Name)"
        write-host "        Version:        $($sourceapi.ApiVersion)"
        write-host "        Id:             $($sourceapi.ApiId)"
    }
    write-host ""
    write-host "Temporary target file: $targetFile"
    write-host ""
    if($null -ne $sourceVersionSet){
        write-host "Executing '.\Export-PSBicepApiManagementApiVersionSet -SubscriptionId '$sourceSubscriptionId' -ResourceGroupName '$($sourceApiManagement.ResourceGroupName)' -ApiManagementName '$($sourceApiManagement.Name)' -ApiVersionSetId $($sourceVersionSet.VersionSetId) -TargetFile '$($targetFile)''"
        Export-PSBicepApiManagementApiVersionSet -SubscriptionId $sourceSubscriptionId -ResourceGroupName $sourceApiManagement.ResourceGroupName -ApiManagementName $sourceApiManagement.Name -ApiVersionSetId $sourceVersionSet.VersionSetId -TargetFile $targetFile
    }
    else{
        write-host "Executing '.\Export-PSBicepApiManagementApi -SubscriptionId '$sourceSubscriptionId' -ResourceGroupName '$($sourceApiManagement.ResourceGroupName)' -ApiManagementName '$($sourceApiManagement.Name)' -ApiId '$($sourceapi.ApiId)' -TargetFile '$($targetFile)''"
        Export-PSBicepApiManagementApi -SubscriptionId $sourceSubscriptionId -ResourceGroupName $sourceApiManagement.ResourceGroupName -ApiManagementName $sourceApiManagement.Name -ApiId $sourceapi.ApiId -TargetFile $targetFile
    }
    $targetApiManagement = Get-ApiManagement -env 'target'
    $TargetSubscriptionId = $SubscriptionIdFinder.Replace($targetApiManagement.Id,'$1')

    write-host "Target"
    write-host "    API Mamanagement"
    write-host "        SubscriptionId: $TargetSubscriptionId"
    write-host "        Resource Group: $($targetApiManagement.ResourceGroupName)"
    write-host "        Name:           $($targetApiManagement.Name)"
    write-host ""

    write-host "Executing '.\Import-PSBicepApiManagementApi -SubscriptionId '$TargetSubscriptionId' -ResourceGroupName '$($targetApiManagement.ResourceGroupName)' -ApiManagementName '$($targetApiManagement.Name)' -TargetFile '$($targetFile)''"
    Import-PSBicepApiManagementApi -SubscriptionId $TargetSubscriptionId -ResourceGroupName $targetApiManagement.ResourceGroupName -ApiManagementName $targetApiManagement.Name -TargetFile $targetFile

}