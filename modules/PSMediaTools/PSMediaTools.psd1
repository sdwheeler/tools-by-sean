@{
    Author             = 'sdwheeler'
    CmdletsToExport    = @()
    CompanyName        = 'SeanOnIT.org'
    Copyright          = '(c) sdwheeler. All rights reserved.'
    GUID               = 'fe67d104-c67f-4e14-aa84-0ab33ee85b03'
    ModuleVersion      = '1.0.1'
    RootModule         = 'PSMediaTools.psm1'
    NestedModules      = @()
    RequiredAssemblies = @()
    Description        = 'Media processing utilities.'
    HelpInfoURI        = ''
    FormatsToProcess   = @('FFMpegFileData.format.ps1xml')
    RequiredModules    = @('PSPlex')
    ScriptsToProcess   = @()
    TypesToProcess     = @()
    FunctionsToExport  = @(
        'capitalize'
        'Convert-MediaFormat'
        'Copy-MediaStreams'
        'ffprobe'
        'Get-FFMpegFileData'
        'Get-FFMpegStreamData'
        'Rename-MediaFile'
        'Rename-RarFile'
        'Split-Chapters'
        'Update-Plex'
    )
    AliasesToExport    = @()
    VariablesToExport  = @()
    FileList           = @()
    PrivateData        = @{
        PSData = @{
            Tags                       = @()
            LicenseUri                 = 'https://github.com/sdwheeler/tools-by-sean/blob/main/LICENSE'
            ProjectUri                 = 'https://github.com/sdwheeler/tools-by-sean/tree/main/modules/PSMediaTools'
            IconUri                    = 'https://seanonit.org/images/OnIT.png'
            ReleaseNotes               = ''
            Prerelease                 = ''
            RequireLicenseAcceptance   = $false
            ExternalModuleDependencies = @()
        }
    }
}

