# AzurePS

Scripts for working with Azure PowerShell content.

## check-mdfiles.ps1 / modulepaths.json

This script scans for a list of module manifests. From each module, it gets the list of cmdlets
exported by the module and checks the source code location verify that a markdown file exists for
the cmdlet. The modulepaths.json file contains a list of module names and maps them to the source
location to find the help files.

## fix-azpslinks.ps1

This is a script to find and replace links to Azure PowerShell content contained in Azure docs. The
script transforms the links to point to the new URL structure for Azure PowerShell that was release
in April 2017. If the URL structure changes again, the script will have to be rewritten. The script
assumes the current URL structure is incorrect and will try to correct it. It does not try to
validate the existing URL. This means that the script can only be run once.

## get-asmMapping.ps1

This script read the MAML files for modules to get a list of cmdlets. Then creates a group mapping
file based on mapping the cmdlet to the "module" name for Azure PowerShell Service Management
cmdlets.

## get-changelog.ps1

This script reads all of the change log files in the Resource Manager source tree of Azure
PowerShell and compiles all of the latest changes into C:\temp\ChangeLog.md.

## mapping-scripts

A collection of scripts to create the module and moniker mapping files for Azure PowerShell.

These are a work in progress and require modules saved in a specific folder structure.
