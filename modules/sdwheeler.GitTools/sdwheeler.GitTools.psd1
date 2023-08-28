# Module manifest for module 'sdwheeler.GitTools'
# Generated by: Sean D. Wheeler <sewhee@microsoft.com>
# Generated on: 9/10/2021
@{
    RootModule        = '.\sdwheeler.GitTools.psm1'
    ModuleVersion     = '1.1.1'
    GUID              = '7e0bfe6d-a3a7-44ff-8a04-8b471d2d4f43'
    Author            = 'Sean D. Wheeler <sewhee@microsoft.com>'
    CompanyName       = 'Microsoft'
    Copyright         = '(c) Microsoft. All rights reserved.'
    Description       = 'Collection of tools to work with Git and GitHub repositories.'
    # PowerShellVersion = ''
    # RequiredModules = @()
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    # TypesToProcess = @()
    # FormatsToProcess = @()
    # NestedModules = @()
    FunctionsToExport = @(
        'Select-Branch',
        'Get-BranchInfo',
        'Get-BranchStatus',
        'Get-DevOpsWorkItem',
        'Get-GitBranchChanges',
        'Get-GitMergeBase',
        'Get-LastCommit',
        'Get-Issue',
        'Get-IssueList',
        'Get-MyRepos',
        'Get-PrFiles',
        'Get-RepoStatus',
        'Open-Repo',
        'Import-GHIssueToDevOps',
        'Import-GitHubLabels',
        'Invoke-GitHubApi',
        'Remove-Branch',
        'Get-GitHubLabels',
        'Get-PrMerger',
        'New-DevOpsWorkItem',
        'Update-DevOpsWorkItem',
        'New-IssueBranch',
        'New-MergeToLive',
        'New-PrFromBranch',
        'Update-RepoData',
        'Show-RepoData',
        'Sync-AllRepos',
        'Sync-Branch',
        'Sync-Repo'
    )
    CmdletsToExport   = @()
    VariablesToExport = ''
    AliasesToExport   = 'goto', 'checkout', 'syncall', 'nib', 'killbr', 'srd', 'open'
    # List of all files packaged with this module
    # FileList = @()
    # HelpInfoURI = ''
    PrivateData       = @{
        PSData = @{
            Tags                     = @()
            LicenseUri               = 'https://github.com/sdwheeler/tools-by-sean/blob/main/LICENSE'
            ProjectUri               = 'https://github.com/sdwheeler/tools-by-sean/modules/sdwheeler.GitTools'
            RequireLicenseAcceptance = $false
        }
    }
}
