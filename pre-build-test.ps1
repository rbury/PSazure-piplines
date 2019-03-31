using namespace Microsoft.PowerShell.Commands

# bootstrap - load required modules prior to using them

[CmdletBinding()]
param(

    # Scope to CurrentUser or AllUsers
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"

)

[ModuleSpecification[]]$RequiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules-test
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted

try {

    $RequiredModules | Install-Module -Scope $Scope -Repository PSGallery -SkipPublisherCheck -Verbose

} finally {

    Set-PSRepository PSGallery -InstallationPolicy $Policy

}

$RequiredModules | Import-Module
