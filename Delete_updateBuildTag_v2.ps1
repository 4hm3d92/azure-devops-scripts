# Delete current tag if it exist
param (
    [string]$organization,
    [string]$project = "Project_Abc",
    [string]$repositoryId = "xxx",
    [string]$tagToCreate = "dev",
    [string]$accessToken = $env:PAT,
    [string]$tagToDelete = "dev"
)

# Define Azure DevOps REST API URLs
$baseUrl = "https://dev.azure.com/$organization/$project"
$buildUrl = "$baseUrl/_apis/build/builds?api-version=7.1-preview.3&repositoryId=$repositoryId&repositoryType=TfsGit&queryorder=startTimeDescending&`$top=1"
$build = Invoke-RestMethod -Uri $buildUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Get -ErrorAction Stop

$latestBuildId = $build[0].value.id


# Check tags from latest build on repo
$buildTagsUrl = "$baseUrl/_apis/build/builds/$latestBuildId/tags?api-version=7.1-preview.3"

$buildTags = $null
$buildTags = Invoke-RestMethod -Uri $buildTagsUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Get -ErrorAction Stop

if ($buildTags.value.Contains($tagToDelete)) {

    # Delete tag
    $deleteTagUrl = "$baseUrl/_apis/build/builds/$latestBuildId/tags/$tagToDelete`?api-version=7.1-preview.3"
    $deleteResponse = Invoke-WebRequest -Uri $deleteTagUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Delete
    
    if ($deleteResponse.StatusCode -eq 200){
        Write-Host "Tag '$tagToDelete' has been deleted."
    }
        
} else {
    Write-Host "Tag '$tagToDelete' doesn't exist."
}


##############################################
# Create tag

# Define Azure DevOps REST API URLs
$baseUrl = "https://dev.azure.com/$organization/$project"
$buildTagsUrl = "$baseUrl/_apis/build/builds/$latestBuildId/tags/$tagToCreate`?api-version=7.1-preview.3"

# Create tag
$createResponse = Invoke-WebRequest -Uri $buildTagsUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Put -ErrorAction Stop
if ($createResponse.StatusCode -eq 200){
    Write-Host "Tag '$tagToCreate' was created successfully."
}
else {
    Write-Host "Error encountered while trying to create '$tagToCreate' tag"
}
