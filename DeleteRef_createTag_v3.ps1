# Delete current tag if it exist

param (
    [string]$organization, 
    [string]$project = "Project_Abc",
    [string]$repositoryId = "12345678-abcd-efgh-ijkl-1234567890ab",
    [string]$tagToCreate = "dev",
    [string]$accessToken = $env:PAT,
    [string]$tagToDelete = "myTag"
)

# Define Azure DevOps REST API URLs
$baseUrl = "https://dev.azure.com/$organization/$project"


# Check tag from repo
$refsUrl = "$baseUrl/_apis/git/repositories/$repositoryId/refs`?api-version=7.1&filter=tags/$tagToDelete"

$getTagResp = Invoke-RestMethod -Uri $refsUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Get -ErrorAction Stop

if ($getTagResp.value) {

    # Delete tag
    $deleteTagUrl = "$baseUrl/_apis/git/repositories/$repositoryId/refs"
    $body = @{
                name=$getTagResp.value.name
                newObjectId="0000000000000000000000000000000000000000"
                oldObjectId=$getTagResp.value.objectId
            
            }
    $body = $body | ConvertTo-Json
    $body = '[' + $body + ']'

    $deleteTagResp = Invoke-WebRequest -Uri $deleteTagUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken")); accept = "application/json;api-version=5.0-preview.1;excludeUrls=true;enumsAsNumbers=true;msDateFormat=true;noArrayWrap=true"} -Method Post -Body $body -ContentType "application/json"


    if ($deleteTagResp.StatusCode -eq 200){
        Write-Host "Tag '$tagToDelete' has been deleted."
    }
        
} else {
    Write-Host "Tag '$tagToDelete' doesn't exist. Can't Delete."
}


##############################################
# Create tag

# Define Azure DevOps REST API URLs
$baseUrl = "https://dev.azure.com/$organization/$project"
$reposUrl = "$baseUrl/_apis/git/repositories/$repositoryId"

# Check if the tag already exists
$refsUrl = "$reposUrl/refs`?api-version=7.1&filter=tags/$tagToCreate"

$getTagResp = Invoke-RestMethod -Uri $refsUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Get -ErrorAction Stop

if (!($getTagResp.value.name -and $getTagResp.value.name.EndsWith($tagToCreate))) {
    echo "Tag '$tagToCreate' doesn't exist. Creating it..."
    # Get the latest commit SHA
    $latestCommitUrl = "$reposUrl/commits?searchCriteria.`$top=1&api-version=7.1"
    $latestCommitResponse = Invoke-RestMethod -Uri $latestCommitUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))}
    $latestCommitSha = $latestCommitResponse.value.commitId

    # Create new tag
    $createTagUrl = "$reposUrl/annotatedtags?api-version=6.0"
    $createTagBody = @{
        "taggedObject" = @{
            "objectId" = $latestCommitSha
        }
        "name" = $tagToCreate
        "taggedBy" = @{
            "name" = "Azure DevOps Release Pipelines"
        }
        "message" = "Tag created by Azure DevOps Release Pipelines"
    } | ConvertTo-Json

    $createResponse = Invoke-RestMethod -Uri $createTagUrl -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))} -Method Post -Body $createTagBody -ErrorAction Stop -ContentType "application/json"
    if ($createResponse.name -eq $tagToCreate){
        Write-Host "Tag '$tagToCreate' was created successfully."
    }
    else {
        Write-Host "Error encountered while trying to create '$tagToCreate' tag"
    }
}
else {
    Write-Host "Tag '$tagToCreate' already exists."
}
