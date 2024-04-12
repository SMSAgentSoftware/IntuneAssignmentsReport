###########################################################################
## Azure automation runbook PowerShell script to export assignments in   ##
## Microsoft Intune to Azure Blob storage where they can be used as a    ##
## datasource for Power BI.                                              ##
###########################################################################

<# Notes:
    Conditional access not included
    May not include features of the Intune Suite
    May not include Autopatch
#>

<# Required API permissions for the service principal
    DeviceManagementApps.Read.All
    DeviceManagementConfiguration.Read.All
    DeviceManagementServiceConfig.Read.All
    CloudPC.Read.All
    DeviceManagementRBAC.Read.All
    GroupMember.Read.All
#>


#region ------------------------------------------------ Variables ------------------------------------------------
$ProgressPreference = 'SilentlyContinue' # Speeds up web requests
$429RetryCount = 5 # How many times to retry a request if a 429 status code is received
$ResourceGroup = "<ResourceGroupName>" # Reource group that hosts the Azure storage account
$StorageAccount = "<StorageAccountName>" # Storage account name
$Container = "intune-assignments" # Container name
$Destination = "$env:Temp" # Temp location to export the the CSV file to
#endregion --------------------------------------------------------------------------------------------------------


#region ---------------------------------------------- API endpoints ----------------------------------------------
# Hash table of MS Graph endpoints to query. Add any new endpoints here, after testing them with the tester code
$ResourceTable = [ordered]@{
    MobileApps = @{
        Url = "deviceAppManagement/mobileApps"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    CompliancePolicies = @{
        Url = "deviceManagement/deviceCompliancePolicies"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    DeviceConfigurations = @{
        Url = "deviceManagement/deviceConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    AutopilotProfiles = @{
        Url = "deviceManagement/windowsAutopilotDeploymentProfiles"
        SelectProperties = "id,displayName"
        RequiresExpand = $true
    }
    DeviceEnrollmentConfigurations = @{
        Url = "deviceManagement/deviceEnrollmentConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $true
    }
    DeviceEnrollmentNotificationsConfigurations = @{
        Url = "deviceManagement/deviceEnrollmentConfigurations"
        FilterUrl = "deviceManagement/deviceEnrollmentConfigurations?`$filter=deviceEnrollmentConfigurationType%20eq%20%27EnrollmentNotificationsConfiguration%27"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    IntuneBrandingProfiles = @{
        Url = "deviceManagement/intuneBrandingProfiles"
        SelectProperties = "id,profileName"
        RequiresExpand = $false
    }
    AppleUserInitiatedEnrollmentProfiles = @{
        Url = "deviceManagement/appleUserInitiatedEnrollmentProfiles"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    ConfigurationPolicies = @{
        Url = "deviceManagement/configurationPolicies"
        SelectProperties = "id,name,templateReference"
        RequiresExpand = $false
    }
    HardwareConfigurations = @{
        Url = "deviceManagement/hardwareConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $true
    }
    GroupPolicyConfigurations = @{
        Url = "deviceManagement/groupPolicyConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    TargetedManagedAppConfigurations = @{
        Url = "deviceAppManagement/targetedManagedAppConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    AndroidManagedAppProtections = @{
        Url = "deviceAppManagement/androidManagedAppProtections"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    IosManagedAppProtections = @{
        Url = "deviceAppManagement/iosManagedAppProtections"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    WindowsInformationProtectionPolicies = @{
        Url = "deviceAppManagement/windowsInformationProtectionPolicies"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    MdmWindowsInformationProtectionPolicies = @{
        Url = "deviceAppManagement/mdmWindowsInformationProtectionPolicies"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    ManagedMobileAppConfigurations = @{
        Url = "deviceAppManagement/mobileAppConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    #ManagedAppPolicies = @{
    #    Url = "deviceAppManagement/managedAppPolicies"
    #    SelectProperties = "id,displayName"
    #    RequiresExpand = $false
    #}
    IosLobAppProvisioningConfigurations = @{
        Url = "deviceAppManagement/iosLobAppProvisioningConfigurations"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    WdacSupplementalPolicies = @{
        Url = "deviceAppManagement/wdacSupplementalPolicies"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    PolicySets = @{
        Url = "deviceAppManagement/policySets"
        SelectProperties = "id,displayName"
        RequiresExpand = $true
    }
    ManagedEBooks = @{
        Url = "deviceAppManagement/managedEBooks"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    ProvisioningPolicies = @{
        Url = "deviceManagement/virtualEndpoint/provisioningPolicies"
        SelectProperties = "id,displayName"
        RequiresExpand = $true
    }
    UserSettings = @{
        Url = "deviceManagement/virtualEndpoint/userSettings"
        SelectProperties = "id,displayName"
        RequiresExpand = $true
    }
    DeviceHealthScripts = @{
        Url = "deviceManagement/deviceHealthScripts"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    DeviceManagementScripts = @{
        Url = "deviceManagement/deviceManagementScripts"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    DeviceShellScripts = @{
        Url = "deviceManagement/deviceShellScripts"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    WindowsFeatureUpdateProfiles = @{
        Url = "deviceManagement/windowsFeatureUpdateProfiles"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    WindowsQualityUpdateProfiles = @{
        Url = "deviceManagement/windowsQualityUpdateProfiles"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    WindowsDriverUpdateProfiles = @{
        Url = "deviceManagement/windowsDriverUpdateProfiles"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    EmbeddedSIMActivationCodePools = @{
        Url = "deviceManagement/embeddedSIMActivationCodePools"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    DeviceManagementIntents = @{
        Url = "deviceManagement/intents"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    RoleAssignments = @{
        Url = "deviceManagement/roleDefinitions"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    CloudPCRoleAssignments = @{
        Url = "roleManagement/cloudPC/roleDefinitions"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    RoleScopeTags = @{
        Url = "deviceManagement/roleScopeTags"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    TermsAndConditions = @{
        Url = "deviceManagement/termsAndConditions"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    OperationApprovalPolicies = @{
        Url = "deviceManagement/operationApprovalPolicies"
        SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    <# - not generally available yet?
    OrganizationalMessages = @{
        Url = "deviceManagement/organizationalMessageDetails"
        #SelectProperties = "id,displayName"
        RequiresExpand = $false
    }
    #>
}
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Functions -------------------------------------------------
# Function to send a web request and handle exceptions
Function script:Invoke-WebRequestPro {
    Param ($URL,$Headers,$Method,$Body)
    If ($Method -eq "POST")
    {
        try 
        {
            $WebRequest = Invoke-WebRequest -Uri $URL -Method $Method -Headers $Headers -ContentType "application/json" -Body $Body -UseBasicParsing
        }
        catch 
        {
            $Response = $_
            $WebRequest = [PSCustomObject]@{
                Message = $response.Exception.Message
                StatusCode = $response.Exception.Response.StatusCode
                StatusDescription = $response.Exception.Response.StatusDescription
            }
        }
    }
    else 
    {
        try 
        {
            $WebRequest = Invoke-WebRequest -Uri $URL -Method $Method -Headers $Headers -UseBasicParsing
        }
        catch 
        {
            $Response = $_
            $WebRequest = [PSCustomObject]@{
                Message = $response.Exception.Message
                StatusCode = $response.Exception.Response.StatusCode
                StatusDescription = $response.Exception.Response.StatusDescription
            }
        }
    }
    Return $WebRequest
}
#endregion --------------------------------------------------------------------------------------------------------


#region --------------------------------------------- Authentication ----------------------------------------------
# For manual testing, get an access token for MS Graph as the current user
# ref: https://gist.github.com/SMSAgentSoftware/664dc71350a6d926ea1ec7f41ad2ed77
# $script:GraphToken = Get-MicrosoftGraphAccessToken 

# For automation, use a service principal (Managed identity etc)
$AuthRetryCount = 5
$AuthRetries = 0
$AuthSuccess = $false
do {
    try 
    {
        $null = Connect-AzAccount -Identity -ErrorAction Stop
        $script:GraphToken = (Get-AzAccessToken -ResourceTypeName MSGraph -ErrorAction Stop).Token
        $AuthSuccess = $true
    }
    catch 
    {
        $AuthErrorMessage = $_.Exception.Message
        $AuthRetries ++
        Write-Warning "Failed to obtain access token: $AuthErrorMessage."
        Start-Sleep -Seconds 10  
    }
}
until ($AuthSuccess -eq $true -or $AuthRetries -ge $AuthRetryCount)
If ($AuthSuccess -eq $false)
{
    throw "Failed to authenticate as the service principal: $AuthErrorMessage"
}
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Tester Code -----------------------------------------------
# This code is just for reference and is used to test the Graph Endpoints to determine the kind of response that is returned
<#
# Get the entity Ids
$URL = "https://graph.microsoft.com/beta/deviceManagement/operationApprovalPolicies"#?`$Select=id,displayName"
$headers = @{'Authorization'="Bearer " + $GraphToken}
$GraphRequest = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
[array]$Content = ($GraphRequest.Content | ConvertFrom-Json).Value

# Get the assignments
$Id = $Content[0].id
$URL = "https://graph.microsoft.com/beta/deviceManagement/operationApprovalPolicies/$Id"
#$URL = "https://graph.microsoft.com/beta/deviceAppManagement/managedAppPolicies/$Id`?expand=assignments"
#$URL = "https://graph.microsoft.com/beta/deviceManagement/organizationalMessageDetails/$Id/assignments"
$headers = @{'Authorization'="Bearer " + $GraphToken}
$GraphRequest = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
$AssignmentContent = ($GraphRequest.Content | ConvertFrom-Json)
$AssignmentContent
#>
#endregion --------------------------------------------------------------------------------------------------------


#region --------------------------------------------- Batch requests ----------------------------------------------
# Here we will loop through the resources and get the assignments for each resource, utilizing batch requests

# Create a list to store the assignments
$AssignmentList = [System.Collections.Generic.List[PSCustomObject]]::new()
# Create a stopwatch to measure the time taken
$Stopwatch = [System.Diagnostics.Stopwatch]::new()

foreach ($MasterResource in $ResourceTable.Keys)
{
    # First we need to get the current list of items for the resouce type
    Write-Output "Processing $MasterResource"
    $Stopwatch.Start()
    $ODataFail = $false
    if ($MasterResource -eq "OrganizationalMessages")
    {
        $URL = "https://graph.microsoft.com/beta/$($ResourceTable[`"$MasterResource`"].Url)"
    }
    elseif ($MasterResource -eq "DeviceEnrollmentNotificationsConfigurations")
    {
        $URL = "https://graph.microsoft.com/beta/$($ResourceTable[`"$MasterResource`"].FilterUrl)&`$Select=$($ResourceTable[`"$MasterResource`"].SelectProperties)"
    }
    else 
    {
        $URL = "https://graph.microsoft.com/beta/$($ResourceTable[`"$MasterResource`"].Url)?`$Select=$($ResourceTable[`"$MasterResource`"].SelectProperties)"
    }
    $headers = @{'Authorization'="Bearer " + $GraphToken}
    $429Count = 0
    do {
        $GraphRequest = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
        If ($GraphRequest.StatusCode -eq 429)
        {
            $429Count++
            Write-Warning "429 status code received. Waiting 30 seconds before retrying"
            Start-Sleep -Seconds 30
        }
    }
    until ($GraphRequest.StatusCode -ne 429 -or $429Count -ge $429RetryCount)  
    If ($GraphRequest.StatusCode -ne 200)
    { 
        Write-Error "Failed to retrieve $MasterResource from MS Graph`: $GraphRequest"
        continue 
    }
    If ($null -eq $GraphRequest.Content)
    {
        Write-Warning "No content returned for $MasterResource"
        continue
    }
    $GraphContentObject = $GraphRequest.Content | ConvertFrom-Json
    $GraphContent = $GraphContentObject.Value

    # If there are more items, get them
    if ($GraphContentObject.'@odata.nextLink')
    {
        do {
            $429Count = 0
            do {
                $GraphRequest = Invoke-WebRequestPro -URL $GraphContentObject.'@odata.nextLink' -Headers $headers -Method GET
                If ($GraphRequest.StatusCode -eq 429)
                {
                    $429Count++
                    Write-Warning "429 status code received. Waiting 30 seconds before retrying"
                    Start-Sleep -Seconds 30
                }
            }
            until ($GraphRequest.StatusCode -ne 429 -or $429Count -ge $429RetryCount)  
            If ($GraphRequest.StatusCode -ne 200)
            { 
                Write-Error "Failed to retrieve $MasterResource from MS Graph`: $GraphRequest"
                $ODataFail = $true
                break 
            }
            $GraphContentObject = $GraphRequest.Content | ConvertFrom-Json
            $GraphContent += $GraphContentObject.Value
        }
        until ($null -eq $GraphContentObject.'@odata.nextLink')
    }
    if ($ODataFail -eq $true)
    {
        continue
    }

    # Get ready to batch the requests to get assignments for each item
    $TotalItems = $GraphContent.Count
    $BatchSize = 20 # Maximum batch size is 20
    $ProcessedItems = 0
    $Responses = @()
    If ($TotalItems -eq 0)
    {
        Write-Warning "No $MasterResource found"
        continue
    }

    # The master batch loop
    do {
        [array]$Batch = $GraphContent | Select -First $BatchSize -Skip $ProcessedItems
        $Requests = @()
        0..($BatchSize - 1) | foreach {
            $resourceId = $($Batch[$_].id)
            If ($null -ne $resourceId)
            {
                # Here we set the correct URL to use for the resource type
                if ($ResourceTable[$MasterResource].RequiresExpand  -eq $true)
                {
                    $url = $ResourceTable[$MasterResource].Url + "/$resourceId`?expand=assignments"
                }
                elseif ($MasterResource -in ("RoleAssignments"))
                {
                    $url = $ResourceTable[$MasterResource].Url + "/$resourceId/roleAssignments"
                }
                elseif ($MasterResource -in ("CloudPCRoleAssignments"))
                {
                    $url = "roleManagement/cloudPC/roleAssignments?`$filter=roleDefinitionId eq '$ResourceId'"
                }
                elseif ($MasterResource -in ("OrganizationalMessages"))
                {
                    $url = "deviceManagement/organizationalMessageDetails/$ResourceId"
                }
                elseif ($MasterResource -in ("OperationApprovalPolicies"))
                {
                    $url = "deviceManagement/operationApprovalPolicies/$ResourceId"
                }
                else 
                {
                    $url = $ResourceTable[$MasterResource].Url + "/$resourceId/assignments"
                }
                $Requests += @{
                    id = $_
                    method = "GET"
                    url = $url
                }
            }
        }

        # Post the batch request
        $BatchRequest = @{
            requests = $Requests
        }
        $BatchRequest = $BatchRequest | ConvertTo-Json
        $URL = "https://graph.microsoft.com/beta/`$batch"
        $headers = @{'Authorization'="Bearer " + $GraphToken}
        $Response = Invoke-WebRequestPro -URL $URL -Headers $headers -Method POST -Body $BatchRequest
        If ($Response.StatusCode -ne 200) 
        { 
            Write-Error "Failed to post batch request: $Response"
            break 
        }
        $BatchResponse = $Response.Content | ConvertFrom-Json
        [array]$BatchResponseStatuses = $BatchResponse.responses.status | Select -Unique

        # Retry the batch request if a 429 status code is received in any of the batch responses
        If ($BatchResponseStatuses -contains 429)
        {
            Write-Warning "429 status code received. Waiting 30 seconds before retrying"
            Start-Sleep -Seconds 30
            $429Count = 1
            do {
                $Response = Invoke-WebRequestPro -URL $URL -Headers $headers -Method POST -Body $BatchRequest
                If ($Response.StatusCode -ne 200) 
                { 
                    Write-Error "Failed to post batch request: $Response"
                    break 
                }
                $BatchResponse = $Response.Content | ConvertFrom-Json
                [array]$BatchResponseStatuses = $BatchResponse.responses.status | Select -Unique
                If ($BatchResponseStatuses -contains 429)
                {
                    $429Count++
                    Write-Warning "429 status code received. Waiting 30 seconds before retrying"
                    Start-Sleep -Seconds 30
                }
            }
            until ($BatchResponseStatuses -notcontains 429 -or $429Count -ge $429RetryCount)
            If ($Response.StatusCode -ne 200) 
            { 
                Write-Error "Failed to post batch request: $Response"
                break 
            }
        }
        # Add successes to the responses array
        if ($BatchResponseStatuses -eq 200)
        {
            $Responses += $BatchResponse
        }
        # If the batch failed, fallback to individual requests
        else 
        {
            $BadStatusCodes = ($BatchResponseStatuses | Where { $_ -ne 200 }) -join ", "
            Write-Warning "Batch request contains bad status codes: $BadStatusCodes. Falling back to individual requests"
            0..($BatchSize - 1) | foreach {
                $resourceId = $($Batch[$_].id)
                If ($null -ne $resourceId)
                {
                    # Here we set the correct URL to use for the resource type
                    if ($ResourceTable[$MasterResource].RequiresExpand -eq $true)
                    {
                        $URL = "https://graph.microsoft.com/beta/$($ResourceTable[`"$MasterResource`"].Url)/$ResourceId`?expand=assignments"
                    }
                    elseif ($MasterResource -in ("RoleAssignments"))
                    {
                        $URL = "https://graph.microsoft.com/beta/$($ResourceTable[`"$MasterResource`"].Url)/$ResourceId/roleAssignments"
                    }
                    elseif ($MasterResource -in ("CloudPCRoleAssignments"))
                    {
                        $URL = "https://graph.microsoft.com/beta/roleManagement/cloudPC/roleAssignments?`$filter=roleDefinitionId eq '$ResourceId'"
                    }
                    elseif ($MasterResource -in ("OrganizationalMessages"))
                    {
                        $url = "https://graph.microsoft.com/beta/deviceManagement/organizationalMessageDetails/$ResourceId"
                    }
                    elseif ($MasterResource -in ("OperationApprovalPolicies"))
                    {
                        $url = "https://graph.microsoft.com/beta/deviceManagement/operationApprovalPolicies/$ResourceId"
                    }
                    else 
                    {
                        $URL = "https://graph.microsoft.com/beta/$($ResourceTable[`"$MasterResource`"].Url)/$ResourceId/assignments"
                    }
                    $headers = @{'Authorization'="Bearer " + $GraphToken}
                    $429Count = 0
                    do {
                        $Response = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
                        If ($Response.StatusCode -eq 429)
                        {
                            $429Count++
                            Write-Warning "429 status code received. Waiting 30 seconds before retrying"
                            Start-Sleep -Seconds 30
                        }
                    }
                    until ($Response.StatusCode -ne 429 -or $429Count -ge $429RetryCount)                     
                    If ($Response.Content)
                    {
                        # Here we extract the information we want to report on
                        $Content = $Response.Content | ConvertFrom-Json
                        If ($ResourceTable[$MasterResource].RequiresExpand -eq $true)
                        {
                            $value = $Content.assignments
                        }
                        elseif ($MasterResource -in ("OrganizationalMessages","OperationApprovalPolicies"))
                        {
                            $value = $Content
                        }
                        else
                        {
                            $value = $Content.value
                        }
                        if ($value.length -gt 0 -or $value.count -gt 0)
                        {
                            foreach ($item in $value)
                            {
                                $resource = $GraphContent | Where-Object { $_.id -eq $resourceId }
                                # Define the resource type
                                $resourceType = $null
                                if ($MasterResource -eq "IntuneBrandingProfiles")
                                {
                                    $resourceType = "intuneBrandingProfile"
                                }
                                elseif ($MasterResource -eq "ConfigurationPolicies")
                                {
                                    if ($Resource.templateReference.templateFamily -eq "none")
                                    {
                                        $resourceType = "configurationPolicySettingsCatalog"
                                    }
                                    else
                                    {
                                        $resourceType = $Resource.templateReference.templateFamily 
                                    }
                                }
                                elseif ($MasterResource -eq "GroupPolicyConfigurations")
                                {
                                    $resourceType = "groupPolicyConfiguration"
                                }
                                elseif ($MasterResource -eq "TargetedManagedAppConfigurations")
                                {
                                    $resourceType = "targetedManagedAppConfiguration"
                                }
                                elseif ($MasterResource -eq "AndroidManagedAppProtections")
                                {
                                    $resourceType = "androidManagedAppProtection"
                                }
                                elseif ($MasterResource -eq "IosManagedAppProtections")
                                {
                                    $resourceType = "iosManagedAppProtection"
                                }
                                elseif ($MasterResource -eq "WindowsInformationProtectionPolicies")
                                {
                                    $resourceType = "windowsInformationProtectionPolicy"
                                }
                                elseif ($MasterResource -eq "MdmWindowsInformationProtectionPolicies")
                                {
                                    $resourceType = "mdmWindowsInformationProtectionPolicy"
                                }
                                elseif ($MasterResource -eq "PolicySets")
                                {
                                    $resourceType = "policySet"
                                }
                                elseif ($MasterResource -eq "ProvisioningPolicies")
                                {
                                    $resourceType = "provisioningPolicy"
                                }
                                elseif ($MasterResource -eq "UserSettings")
                                {
                                    $resourceType = "userSettings"
                                }
                                elseif ($MasterResource -eq "DeviceHealthScripts")
                                {
                                    $resourceType = "deviceHealthScript"
                                }
                                elseif ($MasterResource -eq "DeviceManagementScripts")
                                {
                                    $resourceType = "deviceManagementScript"
                                }
                                elseif ($MasterResource -eq "DeviceShellScripts")
                                {
                                    $resourceType = "deviceShellScript"
                                }
                                elseif ($MasterResource -eq "WindowsQualityUpdateProfiles")
                                {
                                    $resourceType = "windowsQualityUpdateProfile"
                                }
                                elseif ($MasterResource -eq "WindowsFeatureUpdateProfiles")
                                {
                                    $resourceType = "windowsFeatureUpdateProfile"
                                }
                                elseif ($MasterResource -eq "WindowsDriverUpdateProfiles")
                                {
                                    $resourceType = "windowsDriverUpdateProfile"
                                }
                                elseif ($MasterResource -eq "DeviceManagementIntents")
                                {
                                    $resourceType = "deviceManagementIntent"
                                }
                                elseif ($MasterResource -eq "RoleScopeTags")
                                {
                                    $resourceType = "roleScopeTag"
                                }
                                elseif ($MasterResource -eq "TermsAndConditions")
                                {
                                    $resourceType = "termsAndConditions"
                                }
                                elseif ($MasterResource -eq "OrganizationalMessages")
                                {
                                    $resourceType = "organizationalMessage"
                                }
                                elseif ($MasterResource -eq "OperationApprovalPolicies")
                                {
                                    $resourceType = "operationApprovalPolicy"
                                }
                                elseif ($MasterResource -in ("RoleAssignments"))
                                {
                                    # For role assignments, we need to get the assignments for each role definition
                                    $URL = "https://graph.microsoft.com/beta/deviceManagement/roleDefinitions/$($Resource.Id)/roleAssignments/$($item.id)"
                                    $headers = @{'Authorization'="Bearer " + $GraphToken}
                                    $429Count = 0
                                    do {
                                        $roleAssignmentsRequest = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
                                        If ($roleAssignmentsRequest.StatusCode -eq 429)
                                        {
                                            $429Count++
                                            Write-Warning "429 status code received. Waiting 30 seconds before retrying"
                                            Start-Sleep -Seconds 30
                                        }
                                    }
                                    until ($roleAssignmentsRequest.StatusCode -ne 429 -or $429Count -ge $429RetryCount)  
                                    If ($roleAssignmentsRequest.StatusCode -ne 200)
                                    { 
                                        Write-Error "Failed to retrieve a role assignment for $MasterResource from MS Graph`: $roleAssignmentsRequest"
                                        continue 
                                    }
                                    If ($null -eq $roleAssignmentsRequest.Content)
                                    {
                                        Write-Warning "No content returned for a role assignment for $MasterResource"
                                        continue
                                    }
                                    $RoleAssignmentContent = $roleAssignmentsRequest.Content | ConvertFrom-Json
                                    $resourceType = $RoleAssignmentContent.'@odata.Type'.Split('.')[-1]
                                    $resourceName = "$($resource.displayName) > $($RoleAssignmentContent.displayName)"
                                    
                                    # Add the result to the assignment list
                                    foreach ($member in $RoleAssignmentContent.members)
                                    {
                                        $AssignmentList.Add([PSCustomObject]@{
                                            ItemId = $RoleAssignmentContent.id
                                            ItemType = $resourceType
                                            DisplayName = $resourceName
                                            AssignmentType = "groupAssignmentTarget"
                                            Intent = $null
                                            GroupId = $member
                                            GroupDisplayName = $null
                                            FilterId = $null
                                            FilterDisplayName = $null
                                            FilterType = "none"
                                        })
                                    }
                                    continue
                                }
                                elseif ($MasterResource -in ("CloudPCRoleAssignments"))
                                {
                                    $resourceType = "cloudPCRoleAssignment"
                                    $resourceName = "$($resource.displayName) > $($Content.value.displayName)"
                                    foreach ($member in $Content.value.principalIds)
                                    {
                                        $AssignmentList.Add([PSCustomObject]@{
                                            ItemId = $Content.value.id
                                            ItemType = $resourceType
                                            DisplayName = $resourceName
                                            AssignmentType = "groupAssignmentTarget"
                                            Intent = $null
                                            GroupId = $member
                                            GroupDisplayName = $null
                                            FilterId = $null
                                            FilterDisplayName = $null
                                            FilterType = "none"
                                        })
                                    }
                                    continue
                                }
                                elseif ($resource.'@odata.Type')
                                {
                                    $resourceType = $resource.'@odata.Type'.Split('.')[-1]
                                }
                                if ($resource.profileName)
                                {
                                    $resourceName = $resource.profileName
                                }
                                elseif ($resource.displayName)
                                {
                                    $resourceName = $resource.displayName
                                }
                                else 
                                {
                                    $resourceName = $resource.name
                                }
                                if ($MasterResource -eq "OrganizationalMessages")
                                {
                                    foreach ($includeId in $item.targeting.includeIds)
                                    {
                                        $AssignmentList.Add([PSCustomObject]@{
                                            ItemId = $resourceId
                                            ItemType = $resourceType
                                            DisplayName = $resourceName
                                            AssignmentType = "groupAssignmentTarget"
                                            Intent = $null
                                            GroupId = $includeId
                                            GroupDisplayName = $null
                                            FilterId = $null
                                            FilterDisplayName = $null
                                            FilterType = "none"
                                        })
                                    }
                                    foreach ($excludeId in $item.targeting.excludeIds)
                                    {
                                        $AssignmentList.Add([PSCustomObject]@{
                                            ItemId = $resourceId
                                            ItemType = $resourceType
                                            DisplayName = $resourceName
                                            AssignmentType = "exclusionGroupAssignmentTarget"
                                            Intent = $null
                                            GroupId = $includeId
                                            GroupDisplayName = $null
                                            FilterId = $null
                                            FilterDisplayName = $null
                                            FilterType = "none"
                                        })
                                    }
                                }
                                elseif ($MasterResource -eq "OperationApprovalPolicies")
                                {
                                    foreach ($approverGroupId in $item.approverGroupIds)
                                    {
                                        $AssignmentList.Add([PSCustomObject]@{
                                            ItemId = $resourceId
                                            ItemType = $resourceType
                                            DisplayName = $resourceName
                                            AssignmentType = "groupAssignmentTarget"
                                            Intent = $null
                                            GroupId = $approverGroupId
                                            GroupDisplayName = $null
                                            FilterId = $null
                                            FilterDisplayName = $null
                                            FilterType = "none"
                                        })
                                    }
                                }
                                else 
                                {
                                    $AssignmentList.Add([PSCustomObject]@{
                                        ItemId = $resourceId
                                        ItemType = $resourceType
                                        DisplayName = $resourceName
                                        AssignmentType = $item.target.'@odata.type'.Split('.')[-1]
                                        Intent = $item.intent
                                        GroupId = $item.target.groupId
                                        GroupDisplayName = $null
                                        FilterId = $item.target.deviceAndAppManagementAssignmentFilterId
                                        FilterDisplayName = $null
                                        FilterType = $item.target.deviceAndAppManagementAssignmentFilterType
                                    })
                                }   
                            }
                        }
                    }
                }
            }
        }
        
        $ProcessedItems += $BatchSize
    }
    until ($ProcessedItems -ge $TotalItems)

    # Process each response in the batch
    foreach ($response in $responses)
    {
        $subresponses = $response.responses
        foreach ($subresponse in $subresponses)
        {
            # Only process successful batches
            if (($subresponse.status | Select -Unique).ToString() -eq "200")
            {
                # Determine the id of the item
                if ($ResourceTable[$MasterResource].RequiresExpand -eq $true)
                {
                    $resourceId = $subresponse.body.'assignments@odata.context'.Split("'")[-2]
                }
                elseif ($MasterResource -in ("CloudPCRoleAssignments"))
                {
                    $resourceId = $subresponse.body.value.roleDefinitionId
                }
                elseif ($MasterResource -in ("OrganizationalMessages","OperationApprovalPolicies"))
                {
                    $resourceId = $subresponse.body.id
                }
                else
                {
                    $resourceId = $subresponse.body.'@odata.context'.Split("'")[-2]
                }
                $resource = $GraphContent | Where-Object { $_.id -eq $resourceId }

                # Define the resource type
                $resourceType = $null
                if ($MasterResource -eq "IntuneBrandingProfiles")
                {
                    $resourceType = "intuneBrandingProfile"
                }
                elseif ($MasterResource -eq "ConfigurationPolicies")
                {
                    if ($Resource.templateReference.templateFamily -eq "none")
                    {
                        $resourceType = "configurationPolicySettingsCatalog"
                    }
                    else
                    {
                        $resourceType = $Resource.templateReference.templateFamily 
                    }
                }
                elseif ($MasterResource -eq "GroupPolicyConfigurations")
                {
                    $resourceType = "groupPolicyConfiguration"
                }
                elseif ($MasterResource -eq "TargetedManagedAppConfigurations")
                {
                    $resourceType = "targetedManagedAppConfiguration"
                }
                elseif ($MasterResource -eq "AndroidManagedAppProtections")
                {
                    $resourceType = "androidManagedAppProtection"
                }
                elseif ($MasterResource -eq "IosManagedAppProtections")
                {
                    $resourceType = "iosManagedAppProtection"
                }
                elseif ($MasterResource -eq "WindowsInformationProtectionPolicies")
                {
                    $resourceType = "windowsInformationProtectionPolicy"
                }
                elseif ($MasterResource -eq "MdmWindowsInformationProtectionPolicies")
                {
                    $resourceType = "mdmWindowsInformationProtectionPolicy"
                }
                elseif ($MasterResource -eq "PolicySets")
                {
                    $resourceType = "policySet"
                }
                elseif ($MasterResource -eq "ProvisioningPolicies")
                {
                    $resourceType = "provisioningPolicy"
                }
                elseif ($MasterResource -eq "UserSettings")
                {
                    $resourceType = "userSettings"
                }
                elseif ($MasterResource -eq "DeviceHealthScripts")
                {
                    $resourceType = "deviceHealthScript"
                }
                elseif ($MasterResource -eq "DeviceManagementScripts")
                {
                    $resourceType = "deviceManagementScript"
                }
                elseif ($MasterResource -eq "DeviceShellScripts")
                {
                    $resourceType = "deviceShellScript"
                }
                elseif ($MasterResource -eq "WindowsQualityUpdateProfiles")
                {
                    $resourceType = "windowsQualityUpdateProfile"
                }
                elseif ($MasterResource -eq "WindowsFeatureUpdateProfiles")
                {
                    $resourceType = "windowsFeatureUpdateProfile"
                }
                elseif ($MasterResource -eq "WindowsDriverUpdateProfiles")
                {
                    $resourceType = "windowsDriverUpdateProfile"
                }
                elseif ($MasterResource -eq "DeviceManagementIntents")
                {
                    $resourceType = "deviceManagementIntent"
                }
                elseif ($MasterResource -eq "RoleScopeTags")
                {
                    $resourceType = "roleScopeTag"
                }
                elseif ($MasterResource -eq "TermsAndConditions")
                {
                    $resourceType = "termsAndConditions"
                }
                elseif ($MasterResource -eq "OrganizationalMessages")
                {
                    $resourceType = "organizationalMessage"
                }
                elseif ($MasterResource -eq "OperationApprovalPolicies")
                {
                    $resourceType = "operationApprovalPolicy"
                }
                elseif ($MasterResource -in ("RoleAssignments"))
                {
                    If ($subresponse.body.value.Count -gt 0 -or $subresponse.body.length -gt 0)
                    {
                        foreach ($item in $subresponse.body.value)
                        {
                            # For role assignments, we need to get the assignments for each role definition
                            $URL = "https://graph.microsoft.com/beta/deviceManagement/roleDefinitions/$($Resource.Id)/roleAssignments/$($item.id)"
                            $headers = @{'Authorization'="Bearer " + $GraphToken}
                            $429Count = 0
                            do {
                                $roleAssignmentsRequest = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
                                If ($roleAssignmentsRequest.StatusCode -eq 429)
                                {
                                    $429Count++
                                    Write-Warning "429 status code received. Waiting 30 seconds before retrying"
                                    Start-Sleep -Seconds 30
                                }
                            }
                            until ($roleAssignmentsRequest.StatusCode -ne 429 -or $429Count -ge $429RetryCount)  
                            If ($roleAssignmentsRequest.StatusCode -ne 200)
                            { 
                                Write-Error "Failed to retrieve a role assignment for $Resource ($($subresponse.body)) from MS Graph`: $roleAssignmentsRequest"
                                continue 
                            }
                            If ($null -eq $roleAssignmentsRequest.Content)
                            {
                                Write-Warning "No content returned a role assignment for $Resource"
                                continue
                            }
                            $RoleAssignmentContent = $roleAssignmentsRequest.Content | ConvertFrom-Json
                            $resourceType = $RoleAssignmentContent.'@odata.Type'.Split('.')[-1]
                            $resourceName = "$($resource.displayName) > $($RoleAssignmentContent.displayName)"

                            # Add the result to the assignment list
                            foreach ($member in $RoleAssignmentContent.members)
                            {
                                $AssignmentList.Add([PSCustomObject]@{
                                    ItemId = $RoleAssignmentContent.id
                                    ItemType = $resourceType
                                    DisplayName = $resourceName
                                    AssignmentType = "groupAssignmentTarget"
                                    Intent = $null
                                    GroupId = $member
                                    GroupDisplayName = $null
                                    FilterId = $null
                                    FilterDisplayName = $null
                                    FilterType = "none"
                                })
                            }
                        }
                    }
                    continue
                }
                elseif ($MasterResource -in ("CloudPCRoleAssignments"))
                {
                    If ($subresponse.body.value.Count -gt 0 -or $subresponse.body.length -gt 0)
                    {
                        foreach ($item in $subresponse.body.value)
                        {
                            $resourceType = "cloudPCRoleAssignment"
                            $resourceName = "$($resource.displayName) > $($item.displayName)"
                            foreach ($member in $item.principalIds)
                            {
                                $AssignmentList.Add([PSCustomObject]@{
                                    ItemId = $item.id
                                    ItemType = $resourceType
                                    DisplayName = $resourceName
                                    AssignmentType = "groupAssignmentTarget"
                                    Intent = $null
                                    GroupId = $member
                                    GroupDisplayName = $null
                                    FilterId = $null
                                    FilterDisplayName = $null
                                    FilterType = "none"
                                })
                            }
                            continue
                        }
                    }
                    continue
                }
                elseif ($resource.'@odata.Type')
                {
                    $resourceType = $resource.'@odata.Type'.Split('.')[-1]
                }
                if ($resource.profileName)
                {
                    $resourceName = $resource.profileName
                }
                elseif ($resource.displayName)
                {
                    $resourceName = $resource.displayName
                }
                else 
                {
                    $resourceName = $resource.name
                }
                # Determine where to get the assignment info from
                if ($subresponse.body.value)
                {
                    $value = $subresponse.body.value
                }
                elseif ($subresponse.body.targeting -or $subresponse.body.approverGroupIds)
                {
                    [array]$value = $subresponse.body
                }
                else 
                {
                    $value = $subresponse.body.assignments
                }
                if ($value.length -gt 0 -or $value.count -gt 0)
                {
                    foreach ($item in $value)
                    {
                        if ($MasterResource -eq "OrganizationalMessages")
                        {
                            foreach ($includeId in $item.targeting.includeIds)
                            {
                                $AssignmentList.Add([PSCustomObject]@{
                                    ItemId = $resourceId
                                    ItemType = $resourceType
                                    DisplayName = $resourceName
                                    AssignmentType = "groupAssignmentTarget"
                                    Intent = $null
                                    GroupId = $includeId
                                    GroupDisplayName = $null
                                    FilterId = $null
                                    FilterDisplayName = $null
                                    FilterType = "none"
                                })
                            }
                            foreach ($excludeId in $item.targeting.excludeIds)
                            {
                                $AssignmentList.Add([PSCustomObject]@{
                                    ItemId = $resourceId
                                    ItemType = $resourceType
                                    DisplayName = $resourceName
                                    AssignmentType = "exclusionGroupAssignmentTarget"
                                    Intent = $null
                                    GroupId = $includeId
                                    GroupDisplayName = $null
                                    FilterId = $null
                                    FilterDisplayName = $null
                                    FilterType = "none"
                                })
                            }
                        }
                        elseif ($MasterResource -eq "OperationApprovalPolicies")
                        {
                            foreach ($approverGroupId in $item.approverGroupIds)
                            {
                                $AssignmentList.Add([PSCustomObject]@{
                                    ItemId = $resourceId
                                    ItemType = $resourceType
                                    DisplayName = $resourceName
                                    AssignmentType = "groupAssignmentTarget"
                                    Intent = $null
                                    GroupId = $approverGroupId
                                    GroupDisplayName = $null
                                    FilterId = $null
                                    FilterDisplayName = $null
                                    FilterType = "none"
                                })
                            }
                        }
                        else 
                        {
                            $AssignmentList.Add([PSCustomObject]@{
                                ItemId = $resourceId
                                ItemType = $resourceType
                                DisplayName = $resourceName
                                AssignmentType = $item.target.'@odata.type'.Split('.')[-1]
                                Intent = $item.intent
                                GroupId = $item.target.groupId
                                GroupDisplayName = $null
                                FilterId = $item.target.deviceAndAppManagementAssignmentFilterId
                                FilterDisplayName = $null
                                FilterType = $item.target.deviceAndAppManagementAssignmentFilterType
                            })
                        }
                    }
                }
            }
        }
    }
    $Stopwatch.Stop()
    Write-Output "Finished processing $TotalItems $MasterResource in $($Stopwatch.Elapsed.TotalSeconds) seconds"
    $Stopwatch.Reset()
}
#endregion --------------------------------------------------------------------------------------------------------


#region --------------------------------------------- Get Entra groups --------------------------------------------
# Here we will get the display names for the Entra groups used for assignments
$GroupIds = $AssignmentList.GroupId | Select -Unique
If ($GroupIds)
{
    Write-Output "Processing groups"
    $Stopwatch.Start()

    $TotalItems = $GroupIds.Count
    $BatchSize = 20
    $ProcessedItems = 0
    $Responses = @()
    $GroupList = [System.Collections.Generic.List[PSCustomObject]]::new()

    do {
        [array]$Batch = $GroupIds | Select -First $BatchSize -Skip $ProcessedItems
        $Requests = @()
        0..($BatchSize - 1) | foreach {
            $groupId = $Batch[$_]
            If ($null -ne $groupId)
            {
                $Requests += @{
                    id = $_
                    method = "GET"
                    url = "/groups/$groupId"
                }
            }
        }
        $BatchRequest = @{
            requests = $Requests
        }
        $BatchRequest = $BatchRequest | ConvertTo-Json
        $URL = "https://graph.microsoft.com/v1.0/`$batch"
        $headers = @{'Authorization'="Bearer " + $GraphToken}
        $Response = Invoke-WebRequestPro -URL $URL -Headers $headers -Method POST -Body $BatchRequest
        If ($Response.StatusCode -ne 200) 
        { 
            Write-Error "Failed to post batch request: $Response"
            break 
        }
        $BatchResponse = $Response.Content | ConvertFrom-Json
        if (($BatchResponse.responses.status | Select -Unique).ToString() -eq "200")
        {
            $Responses += $BatchResponse
        }
        # If the batch fails, fallback to individual requests
        else 
        {
            $BadStatusCodes = (($BatchResponse.responses.status | Select -Unique) | Where { $_ -ne "200" }) -join ", "
            Write-Warning "Batch request contains bad status codes: $BadStatusCodes. Falling back to individual requests."
            0..($BatchSize - 1) | foreach {
                $GroupId = $Batch[$_]
                If ($null -ne $GroupId)
                {
                    $URL = "https://graph.microsoft.com/v1.0/groups/$GroupId"
                    $headers = @{'Authorization'="Bearer " + $GraphToken}
                    $iResponse = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
                    if ($iResponse.StatusCode -ne 200)
                    {
                        Write-Warning "Failed to retrieve group $GroupId from MS Graph`: $($iResponse.Message)"
                    }
                    If ($iResponse.Content)
                    {
                        $value = ($iResponse.Content | ConvertFrom-Json)
                        if ($null -ne $value)
                        {
                            foreach ($item in $value)
                            {
                                $GroupList.Add([PSCustomObject]@{
                                    GroupId = $item.id
                                    DisplayName = $item.displayName
                                })
                            }
                        }
                    }
                }
            }
        }
        
        $ProcessedItems += $BatchSize
    }
    until ($ProcessedItems -ge $TotalItems)

    foreach ($response in $responses)
    {
        $subresponses = $response.responses
        foreach ($subresponse in $subresponses)
        {
            # Only process successful batches
            if (($subresponse.status | Select -Unique).ToString() -eq "200")
            {
                $value = $subresponse.body
                if ($null -ne $value)
                {
                    $GroupList.Add([PSCustomObject]@{
                        GroupId = $value.id
                        DisplayName = $value.displayName
                    })
                }
            }
        }
    }
    $Stopwatch.Stop()
    Write-Output "Finished processing $($GroupIds.Count) groups in $($Stopwatch.Elapsed.TotalSeconds) seconds"
    $Stopwatch.Reset()
}
#endregion --------------------------------------------------------------------------------------------------------


#region -------------------------------------------- Get Intune filters -------------------------------------------
# Here we will get the display names for the Intune filters used for assignments
$FilterIds = $AssignmentList.FilterId | Select -Unique
If ($FilterIds)
{
    Write-Output "Processing filters"
    $Stopwatch.Start()
    $FilterIds = $FilterIds | Where {$_ -ne "00000000-0000-0000-0000-000000000000"} # Exclude this 'default' filter that exists on some entities
    $TotalItems = $FilterIds.Count
    $BatchSize = 20
    $ProcessedItems = 0
    $Responses = @()
    $FilterList = [System.Collections.Generic.List[PSCustomObject]]::new()

    do {
        [array]$Batch = $FilterIds | Select -First $BatchSize -Skip $ProcessedItems
        $Requests = @()
        0..($BatchSize - 1) | foreach {
            $filterId = $Batch[$_]
            If ($null -ne $filterId)
            {
                $Requests += @{
                    id = $_
                    method = "GET"
                    url = "/deviceManagement/assignmentFilters/$filterId"
                }
            }
        }
        $BatchRequest = @{
            requests = $Requests
        }
        $BatchRequest = $BatchRequest | ConvertTo-Json
        $URL = "https://graph.microsoft.com/beta/`$batch"
        $headers = @{'Authorization'="Bearer " + $GraphToken}
        $Response = Invoke-WebRequestPro -URL $URL -Headers $headers -Method POST -Body $BatchRequest
        If ($Response.StatusCode -ne 200) 
        { 
            Write-Error "Failed to post batch request: $Response"
            break 
        }
        $BatchResponse = $Response.Content | ConvertFrom-Json
        if (($BatchResponse.responses.status | Select -Unique).ToString() -eq "200")
        {
            $Responses += $BatchResponse
        }
        # If the batch failed, fallback to individual requests
        else 
        {
            $BadStatusCodes = (($BatchResponse.responses.status | Select -Unique) | Where { $_ -ne "200" }) -join ", "
            Write-Warning "Batch request contains bad status codes: $BadStatusCodes. Falling back to individual requests."
            0..($BatchSize - 1) | foreach {
                $FilterId = $Batch[$_]
                If ($null -ne $FilterId)
                {
                    $URL = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$FilterId"
                    $headers = @{'Authorization'="Bearer " + $GraphToken}
                    $iResponse = Invoke-WebRequestPro -URL $URL -Headers $headers -Method GET
                    if ($iResponse.StatusCode -ne 200)
                    {
                        Write-Warning "Failed to retrieve filter $FilterId from MS Graph`: $($iResponse.Message)"
                    }
                    If ($iResponse.Content)
                    {
                        $value = ($iResponse.Content | ConvertFrom-Json)
                        if ($null -ne $value)
                        {
                            foreach ($item in $value)
                            {
                                $FilterList.Add([PSCustomObject]@{
                                    FilterId = $item.id
                                    DisplayName = $item.displayName
                                })
                            }
                        }
                    }
                }
            }
        }
        
        $ProcessedItems += $BatchSize
    }
    until ($ProcessedItems -ge $TotalItems)

    foreach ($response in $responses)
    {
        $subresponses = $response.responses
        foreach ($subresponse in $subresponses)
        {
            # Only process successful batches
            if (($subresponse.status | Select -Unique).ToString() -eq "200")
            {
                $value = $subresponse.body
                if ($null -ne $value)
                {
                    $FilterList.Add([PSCustomObject]@{
                        FilterId = $value.id
                        DisplayName = $value.displayName
                    })
                }
            }
        }
    }
    $Stopwatch.Stop()   
    Write-Output "Finished processing $($FilterIds.Count) filters in $($Stopwatch.Elapsed.TotalSeconds) seconds"
    $Stopwatch.Reset()
}
#endregion --------------------------------------------------------------------------------------------------------


#region ------------------------------------------- Update assignment list -----------------------------------------
# Update the assignment list with the group and filter display names
Write-Output "Updating assignment list with group and filter names"
foreach ($Assignment in $AssignmentList)
{
    $Group = $GroupList | Where-Object { $_.GroupId -eq $Assignment.GroupId }
    $Assignment.GroupDisplayName = $Group.DisplayName
    $Filter = $FilterList | Where-Object { $_.FilterId -eq $Assignment.FilterId }
    $Assignment.FilterDisplayName = $Filter.DisplayName
}
Write-Output "$($AssignmentList.Count) assignments processed"  
#endregion --------------------------------------------------------------------------------------------------------


#region ------------------------------------------ Upload CSV to Azure Storage ----------------------------------------
Write-output "Uploading CSV files to Azure storage account"
$AssignmentList | Export-Csv -Path "$Destination\Assignments.csv" -NoTypeInformation -UseCulture -Force
$StorageAccount = Get-AzStorageAccount -Name $StorageAccount -ResourceGroupName $ResourceGroup
try 
{
    $null = Set-AzStorageBlobContent -File "$Destination\Assignments.csv" -Container $Container -Blob "Assignments.csv" -Context $StorageAccount.Context -Force -ErrorAction Stop
}
catch 
{
    throw "Failed to upload to Azure blob storage: $($_.Exception.Message)"
} 
Remove-Item -Path "$Destination\Assignments.csv" -Force
#endregion --------------------------------------------------------------------------------------------------------
