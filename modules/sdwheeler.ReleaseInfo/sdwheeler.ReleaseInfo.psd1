# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
@{
    RootModule        = '.\sdwheeler.ReleaseInfo.psm1'
    ModuleVersion     = '1.1.4'
    GUID              = 'd2e623ff-2df3-4fe0-ab87-ec113d40ab89'
    Author            = 'Sean D. Wheeler <sewhee@microsoft.com>'
    CompanyName       = 'Microsoft'
    Copyright         = '(c) Microsoft. MIT License.'
    Description       = @'
    This module contains command to help you find release and support lifecycle information for
    PowerShell and related projects.

    The following commands use GitHub APIs to query release information.

    - Get-DSCReleaseHistory
    - Get-PSReleaseHistory
    - Get-PSReleasePackage

    To use these commands, a GitHub personal access token is required. The token should be stored
    in an environment variable named GITHUB_TOKEN.
'@
    # PowerShellVersion = ''
    RequiredModules   = @(
        'YaYaml'
    )
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    TypesToProcess    = @('EolData.Types.ps1xml')
    FormatsToProcess  = @(
        'DockerInfo.Format.ps1xml'
        'EolData.Format.ps1xml'
        'PmcData.Format.ps1xml'
        'ReleaseData.Format.ps1xml'
    )
    # NestedModules = @()
    FunctionsToExport = @(
        'Find-PmcPackages',
        'Find-DotnetDockerInfo',
        'Find-DockerImages',
        'Get-LinuxDistroStatus',
        'Get-EndOfLife',
        'Get-OSEndOfLife',
        'Get-DSCReleaseHistory',
        'Get-PSReleaseHistory',
        'Get-PSReleasePackage'
    )
    CmdletsToExport   = @()
    VariablesToExport = ''
    AliasesToExport   = ''
    # List of all files packaged with this module
    FileList          = @(
        'DockerInfo.Format.ps1xml'
        'EolData.Format.ps1xml'
        'EolData.Types.ps1xml'
        'PmcData.Format.ps1xml'
        'PmcVersionInfo.jsonc'
        'PowerShellLifecycle.jsonc'
        'ReleaseData.Format.ps1xml'
        'sdwheeler.ReleaseInfo.psd1'
        'sdwheeler.ReleaseInfo.psm1'
    )
    # HelpInfoURI = ''
    PrivateData       = @{
        PSData = @{
            Tags                     = @()
            LicenseUri               = 'https://github.com/sdwheeler/tools-by-sean/blob/main/LICENSE'
            ProjectUri               = 'https://github.com/sdwheeler/tools-by-sean/tree/main/modules/sdwheeler.ReleaseInfo'
            RequireLicenseAcceptance = $false
        }
    }
}
