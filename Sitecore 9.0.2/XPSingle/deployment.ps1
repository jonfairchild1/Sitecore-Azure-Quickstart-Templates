param
(
    [Parameter(Mandatory = $false, HelpMessage = "Provide the ARM template URL")]
    [string] $ArmTemplateUrl = "https://sitecorefilesforge.blob.core.windows.net/scfiles/azuredeploy.json",

    [Parameter(Mandatory = $false, HelpMessage = "Provide the ARM parameters file path")]
    [string] $ArmParametersPath = (Resolve-Path ".\azuredeploy.parameters.json"),

    [Parameter(Mandatory = $false, HelpMessage = "Provide the Sitecore license file path")]
    [string] $licenseFilePath = (Resolve-Path ".\license.xml"),

    [Parameter(Mandatory = $false, HelpMessage = "REQUIRED: Provide the certificate file path")]
    [string] $certificateRawFilePath = "",

    [Parameter(Mandatory = $false, HelpMessage = "REQUIRED: Provide the certificate password")]
    [securestring] $certificatePassword = $secureString,

    [Parameter(Mandatory = $false, HelpMessage = "Provide the resource group name")]
    [string] $Name = "sc9dev",

    [Parameter(Mandatory = $false, HelpMessage = "Provide the resource group region")]
    [string] $location = "East US",

    [Parameter(Mandatory = $false, HelpMessage = "Provide the Azure subscription ID")]
    [string] $AzureSubscriptionId = "e9e7a362-4586-4ede-9922-3be80bf6814f",

    # The following parameters should be set if Service Principal is used

    [Parameter(Mandatory = $false, HelpMessage = "Provide tenant ID")]
    [string] $TenantId = "b41b72d0-4e9f-4c26-8a69-f949f367c91d",

    [Parameter(Mandatory = $false, HelpMessage = "Provide application ID")]
    [string] $ApplicationId = "SC9DEV",

    [Parameter(Mandatory = $false, HelpMessage = "Provide a password for SPN application")]
    [string] $ApplicationPassword = "" #TODO: replace by securestring

)
$certificateFilePath = (Resolve-Path $certificateRawFilePath)
$UseServicePrincipal = $false #Set to false if you do not want to use service principal

# read the contents of your Sitecore license file
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path $licenseFilePath | Out-String

# read the contents of your authentication certificate
if ($certificateFilePath) {
  $certificateBlob = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($certificateFilePath))
}

# Create Params Object
# license file needs to be secure string and adding the params as a hashtable is the only way to do it
$additionalParams = New-Object -TypeName Hashtable

$params = Get-Content $ArmParametersPath -Raw | ConvertFrom-Json
foreach($p in $params.parameters | Get-Member -MemberType *Property)
{
    $additionalParams.Add($p.Name, $params.parameters.$($p.Name).value)
}

$additionalParams.Set_Item('licenseXml',$licenseFileContent)
$additionalParams.Set_Item('deploymentId',$Name)

# Inject Certificate Blob and Password into the parameters
if ($certificateBlob) {
  $additionalParams.Set_Item('authCertificateBlob',$certificateBlob)
}
if ($certificatePassword) {
  $additionalParams.Set_Item('authCertificatePassword',$certificatePassword)
}

# The main part
try
{

	# Validate Resouce Group Name
	Write-Host "Validating Resource Group Name..."
	if(!($Name -cmatch '^(?!.*--)[a-z0-9]{2}(|([a-z0-9\-]{0,37})[a-z0-9])$'))
	{
		Write-Error "Name should only contain lowercase letters, digits or dashes,
					 dash cannot be used in the first two or final character,
					 it cannot contain consecutive dashes and is limited between 2 and 40 characters in length!"
		Break;
	}

	Write-Host "Setting Azure RM Context..."

 	if($UseServicePrincipal -eq $true)
	{
		# Use Service Principle
		$secpasswd = ConvertTo-SecureString $ApplicationPassword -AsPlainText -Force
		$mycreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $secpasswd)
		Login-AzureRmAccount -ServicePrincipal -Tenant $TenantId -Credential $mycreds
		#Set-AzureSubscription -SubscriptionId $AzureSubscriptionId
		Set-AzureRmContext -SubscriptionID $AzureSubscriptionId -TenantId $TenantId
	}
	else
	{
		# Use Manual Login
		try
		{
			Write-Host "inside try"
			Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
		}
		catch
		{
			Write-Host "inside catch"
			Login-AzureRmAccount
			Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
		}
	}

 	Write-Host "Check if resource group already exists..."
	$notPresent = Get-AzureRmResourceGroup -Name $Name -ev notPresent -ea 0

	if (!$notPresent)
	{
		New-AzureRmResourceGroup -Name $Name -Location $location
	}

	Write-Host "Starting ARM deployment..."
	New-AzureRmResourceGroupDeployment `
			-Name $Name `
			-ResourceGroupName $Name `
			-TemplateUri $ArmTemplateUrl `
            -TemplateParameterObject $additionalParams `
            -Verbose

	Write-Host "Deployment Complete."
}
catch
{
	Write-Error $_.Exception.Message
	Break
}