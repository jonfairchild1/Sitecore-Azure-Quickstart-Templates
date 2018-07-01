$thumbprint = (New-SelfSignedCertificate `
    -Subject "CN=$env:COMPUTERNAME @ Sitecore, Inc." `
    -Type SSLServerAuthentication `
    -FriendlyName "$env:USERNAME Certificate").Thumbprint

    $certificateFilePath = "C:\Temp\$thumbprint.pfx"

Export-PfxCertificate `
    -cert cert:\LocalMachine\MY\$thumbprint `
    -FilePath "$certificateFilePath" `
    -Password (Read-Host -Prompt "Password" -AsSecureString)

$Secure_String_Pwd = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force

& .\deployment.ps1 -CertificatePassword $Secure_String_Pwd -CertificateRawFilePath $certificateFilePath