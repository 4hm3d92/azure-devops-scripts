# Define parameters
param(
    [string]$organization = "abc",
    [string]$project = "myproject",
    [int]$fromBuildId,
    [int]$toBuildId,
    [string]$tag
)

# Set filenames
$startDate = (Get-Date)
$childFilename = 'workItems_' + $startDate.ToString("yyyyMMdd_hhmmss") + '.csv'
$parentFilename = 'parentWorkItems_' + $startDate.ToString("yyyyMMdd_hhmmss") + '.csv'

Write-Host "[$($startDate.ToString('yyyy\-MM\-dd HH\:mm\:ss'))] Script started."

# Set headers of csv files
"Id,Title,Type,LatestBuildId" | Out-File $childFilename
"Id,Title,Type,LatestBuildId" | Out-File $parentFilename


# Get access token using az command, it should be after az login in the environment.
try {
    $token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv
    Write-Host $token
    if (-not $token) {
        throw "Failed to obtain access token"
    }
}
catch {
    Write-Host "Error obtaining access token"
    exit
}

$headers = @{
    Authorization = "Bearer $token"
    Accept = "application/json"
}

$builds_url_base="https://dev.azure.com/$organization/$project/_apis/build/builds?api-version=7.0&tagFilters=$tag&queryOrder=queueTimeDescending"
$builds_url = $builds_url_base

# Use a list to preserve order of builds in descending time
$buildIds = [System.Collections.Generic.List[string]]@()

do 
{
    $response = Invoke-RestMethod -Uri $builds_url -Headers $headers -Method Get -ContentType application/json -ResponseHeadersVariable response_headers
    
    # Add buildIds to list only if they're in the range of the buildIds parameters
    $response.value.foreach({
        if ($_.id -ge $fromBuildId -and $_.id -le $toBuildId) {
            $buildIds.Add($_.id)
        }
    })

    if ($response_headers["x-ms-continuationtoken"])
    {
        $continuation = $response_headers["x-ms-continuationtoken"]
        $builds_url = $builds_url_base + "&continuationToken=" + [System.Net.WebUtility]::UrlEncode($continuation)
    }
} while ($response_headers["x-ms-continuationtoken"])

Write-Host "Processing $($buildIds.Count) builds with tag `"$tag`" in the range $fromBuildId to $toBuildId"

####################################
$processedWorkItems = [System.Collections.Generic.HashSet[string]]::new()
$processedParentItems = [System.Collections.Generic.HashSet[string]]::new()
$unprocessedParentItems = [System.Collections.Generic.List[string]]::new()

# No of workitems to fetch at once
$chunkSize = 200

foreach ($buildId in $buildIds) {

    $buildWorkItemsUrl = "https://dev.azure.com/$organization/$project/_apis/build/builds/$buildId/workitems?api-version=7.0"

    # Get work items associated with the build
    $workItemsRef = Invoke-RestMethod -Headers $headers -Method Get -uri $buildWorkItemsUrl
    $unprocessedWorkItems = $workItemsRef.value | Where-Object { !$processedWorkItems.Contains($_.id) }

    ###############
    # Process unprocessed workItems, 200 at a time
    Write-Host "Processing $($unprocessedWorkItems.Count) workitems under the build: $buildId"
    for ($i=0; $i -lt $unprocessedWorkItems.Count/$chunkSize; $i++) {
        # Slice of workItems to fetch
        $items = $unprocessedWorkItems[$i*$chunkSize..(($i+1)*$chunkSize-1)]
        $ids = [System.String]::Join(',',($items.id))

        $workItemsUrl = "https://dev.azure.com/$organization/$project/_apis/wit/workitems?ids=$ids&fields=System.Title,System.WorkItemType,System.Parent&api-version=7.0"
        $workItemsResponse = Invoke-RestMethod -Headers $headers -Method Get -uri $workItemsUrl

        $output = foreach ($wi in $workItemsResponse.value) {
            Write-Output "$($wi.id),$($wi.fields.'System.Title'),$($wi.fields.'System.WorkItemType'),$buildId"
            $processedWorkItems.Add($_.id) | Out-Null

            # If the workitem has a parent and parent hasn't been processed yet, add parent to unprocessed list
            if (($parentId = $_.fields.'System.Parent') -and !$processedParentItems.Contains($parentId)) {
                $unprocessedParentItems.Add($parentId)
            }
        }
        # Write batch of workitems to csv file
        $output | Out-File -Append $childFilename
    }

    ##############
    # Process unprocessed parent workItems, max 200 at a time
    Write-Host "Processing $($unprocessedParentItems.Count) parent workitems under the build: $buildId"
    for ($i=0; $i -lt $unprocessedParentItems.Count/$chunkSize; $i++) {
        # Slice of parent workItems to fetch
        $items = $unprocessedParentItems[$i*$chunkSize..(($i+1)*$chunkSize-1)]
        $ids = [System.String]::Join(',',($items.id))

        $workItemsUrl = "https://dev.azure.com/$organization/$project/_apis/wit/workitems?ids=$ids&fields=System.Title,System.WorkItemType,System.Parent&api-version=7.0"
        $workItemsResponse = Invoke-RestMethod -Headers $headers -Method Get -uri $workItemsUrl

        $output = foreach ($wi in $workItemsResponse.value) {
            Write-Output "$($wi.id),$($wi.fields.'System.Title'),$($wi.fields.'System.WorkItemType'),$buildId"
            $processedParentItems.Add($wi.id) | Out-Null
        }
        # Write batch of workitems to csv file
        $output | Out-File -Append $parentFilename
    }
    $unprocessedParentItems.Clear()
}

Write-Host "[$((Get-Date).ToString('yyyy\-MM\-dd HH\:mm\:ss'))] Script ended."
