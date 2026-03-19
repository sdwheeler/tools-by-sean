<################################################
- Demo script for sdwheeler.ReleaseInfo module.
- Turn on Screencast mode.
#################################################>
throw "This is a demo script. Run each line separately using F8. Don't use F5."

##################################################
# https://www.powershellgallery.com/packages/sdwheeler.ReleaseInfo

Get-Command -Module sdwheeler.ReleaseInfo
#################################################
#region endoflife.date
# Example - https://endoflife.date/ubuntu

# List items in endoflife.date by category (with tab completion)
Get-EndOfLife -Category os

# Get end of life information for Ubuntu releases
Get-EndOfLife -Name ubuntu

# Get end of life information   for OS releases supported by PowerShell
Get-OSEndOfLife debian, ubuntu

#endregion endoflife.date
#################################################
#region GitHub release information
# These functions require $env:GITHUB_TOKEN containing a GitHub personal access token

# Get the history of the latest releases of PowerShell
Get-PSReleaseHistory

# Get the history of the latest release of PowerShell
Get-PSReleaseHistory -Version v7.6

# Show syntax for Get-PSReleaseHistory
Get-Command Get-PSReleaseHistory -Syntax

# Get a list of assests for the latest release of PowerShell
Get-PSReleasePackage -Tag v7.6.0

# Show syntax for Get-PSReleasePackage
Get-Command Get-PSReleasePackage -Syntax

#endregion GitHub release information
#################################################
#region PMC packages
# https://packages.microsoft.com/

# Search PMC for PowerShell packages
Find-PmcPackage

#endregion PMC packages
#################################################
#region Docker images

Get-Command -Name Find-DockerImage, Find-DotnetDockerInfo | ft -AutoSize

# Search dotnet/dotnet-docker for SDK images containing PowerShell
Find-DotnetDockerInfo

#endregion Docker images
#################################################
