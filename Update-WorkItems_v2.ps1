# Azure DevOps organization URL
$orgUrl = "https://dev.azure.com/abc"

# Project name
$projectName = "Project_Abc"

# Personal Access Token (PAT) with appropriate permissions
$pat = $env:PAT

# API version
$apiVersion = "6.0"

# Base URL for REST API
$baseUrl = "$orgUrl/$projectName/_apis/wit"

# Authentication headers
$headers = @{
    Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)"))
}

# Get the target query
$queryPath = "Shared Queries/Current Sprint"
$queryEndpoint = "$baseUrl/queries/$($queryPath)?`$expand=all&api-version=$apiVersion"
$targetQuery = Invoke-RestMethod -Uri $queryEndpoint -Method Get -Headers $headers

if ($null -eq $targetQuery) {
    Write-Output "Query '$queryPath' not found"
    return
}

# Get work items using the query
$queryId = $targetQuery.id
$queryItemsEndpoint = "$baseUrl/wiql/$($queryId)?`$expand=all&api-version=$apiVersion"
$queryItemsResponse = Invoke-RestMethod -Uri $queryItemsEndpoint -Method Get -Headers $headers
    
# Extract work items
$workItems = $queryItemsResponse.workItems
if ($workItems.Count -eq 0) {
    Write-Output "No work items found using the query '$queryPath'"
    return
}

# Display work items. Get detailed work item based on
$detailedWorkItems = @()
foreach ($item in $workItems) {
    $workItemId = $item.id
    $workItemEndpoint = "$baseUrl/workitems/$($workItemId)?api-version=$apiVersion"
    $workItem = Invoke-RestMethod -Uri $workItemEndpoint -Method Get -Headers $headers
    $detailedWorkItems += $workItem
}

$detailedWorkItems | Select-Object id, @{Name='title';Expression={$_.fields.'System.Title'}}, @{Name='state';Expression={$_.fields.'System.State'}} 

Write-Output "" #empty line

$newState = "Done"

# Update the state to $newState for each work item
foreach ($item in $workItems) {
    $workItemId = $item.id  
    $updateEndpoint = "$baseUrl/workitems/$($workItemId)?api-version=$apiVersion"
    # Define the update payload
    $updatePayload = @{
        op    = "add"
        path  = "/fields/System.State"
        value = $newState
    }
    $updatePayload = $updatePayload | ConvertTo-Json -Compress
    $updatePayload = "[$updatePayload]"
        
    # Make the request to update the work item
    Invoke-RestMethod -Uri $updateEndpoint -Method Patch -Headers $headers -Body $updatePayload -ContentType "application/json-patch+json" | Out-Null

    Write-Output "Work item $($item.id) updated to '$newState'"
}

# Prepare a message for Microsoft Teams
$teamsMessage = @{
    title = "Work items updated to '$newState':"
    text  = "<br><table><tr><th>Id</th><th>Title</th><th>State</th></tr>" + (($detailedWorkItems | ForEach-Object { "<tr><td>$($_.id)</td><td>$($_.fields.'System.Title')</td><td>$($_.fields.'System.State')</td></tr>" })) + "</table>"

} | ConvertTo-Json -Depth 5

# Post message to Microsoft Teams using Incoming Webhook
$teamsWebhookUrl = "https://abc.webhook.office.com/webhookb2/XXXX/IncomingWebhook/YYY/ZZZ"
Invoke-RestMethod -Uri $teamsWebhookUrl -Method post -Body $teamsMessage -ContentType "application/json" | Out-Null
