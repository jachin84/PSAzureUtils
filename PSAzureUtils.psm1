<#
.SYNOPSIS
    Create a new Resource Group.
.DESCRIPTION
    New-ResourceGroup create a new Azure Resource Group if an existing Resource Group with the same name cannot be found.
.PARAMETER Name
    The name of the Resource Group. Can be an existing or new Resource Group.
.PARAMETER Location
    The location to deploy the Resource Group. If the Resource Group already exists this parameter does not apply.

#>
function New-ResourceGroup {
    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup])]
    param (
        [Parameter(Mandatory=$true)]
        $Name,

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
.PARAMETER ResourceGroupName
    The name of the Resource Group.
.PARAMETER Name
    The name of the deployment.
#>
function Get-DeploymentName {
    [CmdletBinding(DefaultParameterSetName="RG")]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true,ParameterSetName="RG")]
        $ResourceGroupName,

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
.PARAMETER Subscription
    The Azure subscription obtained from Get-AzContext or a similar cmdlet.
.PARAMETER SubscriptionName
    The name of the Azure Subscription.
#>
function Test-Subscription {
    [CmdletBinding()]
    param (
        # Subscription
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Microsoft.Azure.Commands.Profile.Models.PSAzureContext]
        $Subscription,

        # SubscriptionName
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
    Get a list of servers, including password, for IaaS Virtual machine deployed in Azure.
.DESCRIPTION
    Get-ServerCredentials reads server.json and retrieves the current credentials from Azure KeyVault.
    The expected format of servers.json is:
        [
            {
                "Name": "tstncuvmsql01",
                "Hostname":"tstncuvmsql01.fhq55.net",
                "Username":"~\\fhqsupport",
                "PasswordKeyVaultSecret": "tstncuvmsql01"
            }
        ]
    The PasswordKeyVaultSecret refers to the Azure KeyVault secret name containing the password.
.PARAMETER Path
    The path to the servers.json file.
.PARAMETER VaultName
    The name of the Azure KeyVault to retrieve passwords from.
.PARAMETER ServerName
    The name of the Azure KeyVault to retrieve passwords from.
#>
function Get-ServerCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [ValidateScript({Test-Path $_ })]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $VaultName,

        [Parameter(Mandatory=$false)]
        [string]
        $ServerName
    )
    
    $serverList = Get-Content $Path -Raw | ConvertFrom-Json

    # filter the list of servers to the given server
    if ($PSBoundParameters.ContainsKey("ServerName")) {
        $serverList = $serverList | Where-Object Name -eq $ServerName    
    }
    
    foreach ($server in $serverList) {
        
        try 
        {
            $password = (Get-AzureKeyVaultSecret -VaultName $VaultName -Name $server.PasswordKeyVaultSecret -ErrorAction Stop).SecretValue
        }
        catch
        {
            Write-Warning "Password could not be obtained for $($server.Name)"
        }
        
        if ($password) 
        {
            Write-Verbose ("Retrieved credentials for {0}." -f $server.Name)
            $credential = [PSCredential]::new($server.Username, $password)

            $server | `
                Add-Member -MemberType NoteProperty -Name "Password" -Value $password -PassThru | `
                Add-Member -MemberType NoteProperty -Name "Credential" -Value $credential
        }
        Write-Output $server
    }
}