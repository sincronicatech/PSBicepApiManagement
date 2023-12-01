#workaround for https://github.com/Azure/azure-powershell/issues/19399

function ConvertToPOCO($obj){
    if($obj.GetType().name -eq 'PSCustomObject'){
        $members = $obj|Get-Member -MemberType Properties
        $toReturn = @{}
        foreach($member in $members){
            $memberName = $member.Name
            $toReturn[$member.Name] = ConvertToPOCO -obj $obj.$memberName
        }
        return $toReturn
    }
    else{
        return "'$obj'"
    }
}

function Export-PSBicepApiManagementSchemaData (
    $resourceGroupName,
    $apiManagementName,
    $ApiId
)
{
    $context = New-AzApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apiManagementName
    $api = Get-AzApiManagementApi -Context $context -ApiId $apiId
    $operations=Get-AzApiManagementOperation -Context $context -ApiId $ApiId
    $allSchemasId = @()
    $allSchemasId += $operations.Responses.Representations.SchemaId
    $allSchemasId += $operations.Request.Representations.SchemaId

    $schemaIds = @()+($allSchemasId|select -Unique)
    if($schemaIds.count -eq 0){
        return $null
    }
    if($schemaIds.Count -gt 1){
        throw "Too many schemas found. Unsupported"
    }
    $schemaIdName = $schemaIds[0]
    $apiDefinition = export-azapiManagementApi -Context $context -ApiId $Apiid -SpecificationFormat 'OpenApiJson'|ConvertFrom-Json -Depth 30
    
    $schemaResource= New-PSBicepResource -Identifier 'operationSchema' -ResourceType '''Microsoft.ApiManagement/service/apis/schemas@2023-03-01-preview''' -Name "'$schemaIdName'" -Parent "service_$($apiManagementName.Replace('-','_'))_name_$ApiId"
    $schemaResource.Attributes = @{
        'properties' = @{
            'contentType'='''application/vnd.oai.openapi.components+json''';
            'document'=@{
                'components'=@{
                    'schemas'= ConvertToPOCO -obj $apiDefinition.components.schemas
                }
            }
        }
    }

    return $schemaResource
}