#part 1
############################################################################################
# Azure DevOps organization URL
$organizationUrl = "https://dev.azure.com/abc"

# Personal Access Token (PAT) with appropriate permissions
$pat = $env:PAT

# Project name
$projectName = "Project_Abc"

# Build pipeline ID
$buildId = "2"

# URL to get variables of the pipeline
$url = "$organizationUrl/$projectName/_apis/build/definitions/${buildId}?api-version=7.2-preview.7"

# Invoke the REST API to get variables
$build = Invoke-RestMethod -Uri $url -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)") )}

$variables = $build.variables.PSObject.Properties

$updateVars = @{}
# Output the variables
foreach ($variable in $variables) {

    Write-Host "Variable name: $($variable.Name)"
    Write-Host "Value: $($variable.Value.value)"
    Write-Host "Is secret: $([bool]$variable.Value.isSecret)"
    Write-Host ""
    if (![bool]$variable.Value.isSecret){
      $updateVars.Add($variable.Name,$variable.Value)
    }
    
}


##################################################

#part 2

$organizationUrl = "https://vsrm.dev.azure.com/abc"
$releasePipelineId = 1

# URL to get release pipelines
$url = "$organizationUrl/$projectName/_apis/release/definitions/${releasePipelineId}?api-version=7.1"

# Invoke the REST API to list release definitions
$releasePipeline = Invoke-RestMethod -Uri $url -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)") )}

$releasePipeline.variables = $updateVars
$jsonBody = $releasePipeline | ConvertTo-Json -Depth 100 -Compress
$json = [Text.Encoding]::UTF8.GetBytes($jsonBody)
#$jsonBody


# URL to update variables in release pipeline
$url = "$organizationUrl/$projectName/_apis/release/definitions?api-version=7.1"

# Invoke the REST API to update variables
Invoke-RestMethod -Uri $url -Method Put -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)") )} -ContentType "application/json" -Body $json 


#######################################################

#part 3 - update it back to the previous or default

$organizationUrl = "https://vsrm.dev.azure.com/abc"
$releasePipelineId = 1

# URL to get release pipelines
$url = "$organizationUrl/$projectName/_apis/release/definitions/${releasePipelineId}?api-version=7.1"

# Invoke the REST API to list release definitions
$releasePipeline = Invoke-RestMethod -Uri $url -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)") )}

$restoreVars = @{}

$restoreVars = @{
    EnvTag = @{value="dev-01"; allowOverride="true"}
    EnvType = @{value="dev"; allowOverride="true"}
    EnvTypeParameter = @{value="dev"; allowOverride="true"}
    EnvName = @{value="01"; allowOverride="true"}
    EnvNameParameter = @{value="1"; allowOverride="true"}
}

$releasePipeline.variables = $restoreVars
$jsonBody = $releasePipeline | ConvertTo-Json -Depth 10 -Compress
#$jsonBody


# URL to update variables in release pipeline
$url = "$organizationUrl/$projectName/_apis/release/definitions?api-version=7.1"

# Invoke the REST API to update variables
Invoke-RestMethod -Uri $url -Method Put -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)") )} -ContentType "application/json" -Body $jsonBody
