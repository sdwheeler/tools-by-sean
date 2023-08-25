#-------------------------------------------------------
#region Media utilities
#-------------------------------------------------------
function Get-JpegMetadata {
    <#
    .EXAMPLE
    PS C:\img> Get-JpegMetadata .\natural.jpg

    Name                           Value
    ----                           -----
    Copyright
    Rating                         0
    Dispatcher
    ApplicationName                S5830XXKPO
    IsSealed                       True
    Comment
    IsFrozen                       True
    Keywords
    IsFixedSize                    False
    CameraManufacturer             SAMSUNG
    CanFreeze                      True
    IsReadOnly                     True
    DateTaken                      22.09.2014 17:13:28
    Location                       /
    Subject
    CameraModel                    GT-S5830
    Format                         jpg
    Author                         greg zakharov
    Title                          Autumn
    .NOTES
    Author: greg zakharov
    #>
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateScript( { (Test-Path $_) -and ($_ -match '\.[jpg|jpeg]$') } ) ]
        [String]$FileName
    )

    Add-Type -AssemblyName PresentationCore
    $FileName = Convert-Path $FileName

    try {
        $fs = [IO.File]::OpenRead($FileName)

        $dec = New-Object Windows.Media.Imaging.JpegBitmapDecoder(
            $fs,
            [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreColorProfile,
            [Windows.Media.Imaging.BitmapCacheOption]::Default
        )

        [Windows.Media.Imaging.BitmapMetadata].GetProperties() | ForEach-Object {
            $raw = $dec.Frames[0].Metadata
            $res = @{}
        } {
            if ($_.Name -ne 'DependencyObjectType') {
                $res[$_.Name] = $(
                    if ($_ -eq 'Author') { $raw.($_.Name)[0] } else { $raw.($_.Name) }
                )
            }
        } { $res } #foreach
    }
    catch {
        $_.Exception.InnerException
    }
    finally {
        if ($null -ne $fs) { $fs.Close() }
    }
}
#-------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -ge 6) {
    function Get-MediaInfo {
        param (
            [string[]]$path,
            [switch]$Recurse,
            [switch]$Full
        )

        foreach ($item in $path) {
            if ((Get-Item $item).PSIsContainer) { $item = $item + '\*' }
            Get-ChildItem -Recurse:$Recurse -Path $item -File -Exclude *.txt, *.jpg, *.metathumb, *.xml |
                ForEach-Object {
                    $media = [TagLib.File]::Create($_.FullName)
                    if ($Full) {
                        $media.Tag
                    }
                    else {
                        $media.Tag |
                            Select-Object @{l = 'Artist'; e = { $_.Artists[0] } },
                            Album,
                            @{l = 'Disc'; e = { '{0} of {1}' -f $_.Disc, $_.DiscCount } },
                            Track,
                            Title,
                            Genres
                        }
                    }
        }
    }

    function Set-MedaInfo {
        param (
            [string[]]$path,
            [string]$Album,
            [string[]]$Artists,
            [int32]$Track,
            [string]$Title,
            [string[]]$Genres,
            [int32]$Disc,
            [int32]$DiscCount
        )
        foreach ($item in $path) {
            Get-ChildItem $item -File | ForEach-Object {
                $media = [TagLib.File]::Create($_.FullName)
                if ($Album) { $media.Tag.Album = $Album }
                if ($Artists) { $media.Tag.Artists = $Artists }
                if ($Track) { $media.Tag.Track = $Track }
                if ($Title) { $media.Tag.Title = $Title }
                if ($Genres) { $media.Tag.Genres = $Genres }
                if ($Disc) { $media.Tag.Disc = $Disc }
                if ($DiscCount) { $media.Tag.DiscCount = $DiscCount }
                $media.save()
                $media.Tag |
                    Select-Object @{l = 'Artist'; e = { $_.Artists[0] } },
                    Album,
                    @{l = 'Disc'; e = { '{0} of {1}' -f $_.Disc, $_.DiscCount } },
                    Track,
                    Title,
                    Genres
                }
            }
    }
}
#-------------------------------------------------------
#endregion
