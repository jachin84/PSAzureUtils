<#
.SYNOPSIS
    Create a new Resource Group.
.DESCRIPTION
    New-ResourceGroup create a new Azure Resource Group if an existing Resource Group with the same name cannot be found.
#>
function New-ResourceGroup {
    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup])]
    param (
        # The name of the Resource Group. Can be an existing or new Resource Group.
        [Parameter(Mandatory=$true)]
        $Name,

        # The location to deploy the Resource Group. If the Resource Group already exists this parameter does not apply.
        [Parameter(Mandatory=$true)]
        $Location
    )

    # Only create the resource group if it doesn't already exist
    $resourceGroup = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if(!$resourceGroup) {
        Write-Verbose "$Name does not existing and will be created."
        $resourceGroup = New-AzResourceGroup -Name $Name -Location $Location -ErrorAction Stop
    }
    else {
        Write-Warning "$Name already exists."
    }

    Write-Output $resourceGroup
}

<#
.SYNOPSIS
    Generate a name for ARM deployments.
.DESCRIPTION
    Get-DeploymentName is a helper function to generate a unique name for ARM template deployment.

    Either ResourceGroupName or Name can be specified, not both. The current date and time are
    appended in the format yyyyMMdd-HHmm and returned as Name_DateTime.

    Eg. Production_20170227-0034
#>
function Get-DeploymentName {
    [CmdletBinding(DefaultParameterSetName="RG")]
    [OutputType([string])]
    param (
        # The name of the Resource Group.
        [Parameter(Mandatory=$true,ParameterSetName="RG")]
        $ResourceGroupName,

        # The name of the deployment.
        [Parameter(Mandatory=$true,ParameterSetName="Name")]
        $Name
    )

    $utcNow = ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmm')
    $deploymentName = "{0}_{1}"

    if ($PsCmdlet.ParameterSetName -eq "RG") {
        Write-Output ($deploymentName -f $ResourceGroupName, $utcNow)
    }
    else {
        Write-Output ($deploymentName -f $Name, $utcNow)
    }
}

<#
.SYNOPSIS
    Validate a given subscription is the expected subscription.
.DESCRIPTION
    Test-Subscription is a helper function to validate that the given subscription
    matches the expected subscription.

    The name from the subscription object is compared with the given subscription name.
    Note that Subscription is a PSAzureContext object.
#>
function Test-Subscription {
    [CmdletBinding()]
    param (
        # The Azure subscription obtained from Get-AzContext or a similar cmdlet.
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureContext]
        $Subscription,

        # The name of the Azure Subscription.
        [Parameter(Mandatory=$true)]
        [string]
        $SubscriptionName
    )

    $givenSubscriptionName = $Subscription.Subscription.SubscriptionName
    if($givenSubscriptionName -eq $SubscriptionName)
    {
        Write-Error ("Given subscription is `"{0}`", Expecting `"{1}`"." -f $givenSubscriptionName, $SubscriptionName)
        Write-Output $false
    }
    else{
        Write-Output $true
        Write-Verbose ("Subscription: {0}, SubscriptionId: {1}, TenantId: {2}" -f $SubscriptionName, $Subscription.Subscription.Id, $Subscription.Tenant.Id)
    }
}

<#
.SYNOPSIS
    Get an Azure Access token.
.DESCRIPTION
    Get-AccessToken attempts to dump an access token for the give resource identifier to the console.
#>
function Get-AccessToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateNotNullOrEmpty()]
        $Context=(Get-AzContext),

        [Parameter(Mandatory=$false, Position=1)]
        [string]
        $Resource = "https://management.azure.com"
    )

    if ($null -eq $Context) {
        throw [System.ArgumentNullException]::new("Context")
    }

    $authenticationFactory = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory
    $token = $authenticationFactory.Authenticate($Context.Account, $Context.Environment, $Context.Tenant.Id, $null, "Never", $null, $Resource)
    Write-Output $token.AccessToken

}

function Connect-Azure
{
    [CmdletBinding(DefaultParameterSetName="Subscription")]
    Param
    (
        # TenantId
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Subscription")]
        [string]
        $SubscriptionId,

        # TenantId
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Tenant")]
        [string]
        $TenantId
    )

    if ($PsCmdlet.ParameterSetName -eq "Subscription") {
        Connect-AzureSubscription -SubscriptionId $SubscriptionId
    }else {
        Connect-AzureTenant -TenantId $TenantId
    }
}

function Connect-AzureTenant
{
    [CmdletBinding()]
    Param
    (
        # TenantId
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $TenantId
    )

    ## Attempt to connect to Azure
    $subscriptions = $null
    try {
        $subscriptions = Get-AzSubscription -TenantId $tenantId
    }
    catch [System.Management.Automation.PSInvalidOperationException] {
        Write-Warning "No existing connection to TenantId: $tenantId"
    }

    if (!$subscriptions) {
        $azAccount = Connect-AzAccount -Tenant $tenantId -ErrorAction Stop

        if (($null -eq $azAccount) -or ($azAccount.Context.Tenant.Id -ne $tenantId)) {
            Write-Error "Could not connect to Azure." -ErrorAction Stop
        }
    }

    Write-Output (Get-AzContext)
}

function Connect-AzureSubscription
{
    [CmdletBinding()]
    Param
    (
        # TenantId
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $SubscriptionId
    )

    ## Attempt to connect to Azure
    $subscriptions = $null
    try {
        $subscriptions = Get-AzSubscription -SubscriptionId $SubscriptionId
    }
    catch [System.Management.Automation.PSInvalidOperationException] {
        Write-Warning "No existing connection to TenantId: $tenantId"
    }

    if (!$subscriptions) {
        $azAccount = Connect-AzAccount -ErrorAction Stop

        if (($null -eq $azAccount) -or ($azAccount.Context.Subscription.Id -ne $SubscriptionId)) {
            Write-Error "Could not connect to Azure." -ErrorAction Stop
        }
    }

    Write-Output (Get-AzContext)
}