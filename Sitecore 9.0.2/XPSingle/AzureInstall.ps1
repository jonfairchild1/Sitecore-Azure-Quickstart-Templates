#Define parameters for deployment
$SubscriptionId = "e9e7a362-4586-4ede-9922-3be80bf6814f"
$password = "P@ssw0rd!"


######Create self-signed certificate
$thumbprint = (New-SelfSignedCertificate `
    -Subject "CN=$env:COMPUTERNAME @ Sitecore, Inc." `
    -Type SSLServerAuthentication `
    -FriendlyName "$env:USERNAME Certificate").Thumbprint

    $certificateFilePath = "C:\Temp\$thumbprint.pfx"

Export-PfxCertificate `
    -cert cert:\LocalMachine\MY\$thumbprint `
    -FilePath "$certificateFilePath" `
    -Password (Read-Host -Prompt "Password" -AsSecureString)
######End self signed certificate

####Login to Azure subscription
Add-AzureRMAccount
Set-AzureRMContext -SubscriptionId $SubscriptionId
#####End login


$Secure_String_Pwd = ConvertTo-SecureString $password -AsPlainText -Force

$command = .\deployment.ps1 -CertificatePassword $Secure_String_Pwd -CertificateRawFilePath $certificateFilePath
Invoke-Expression $command 