#-------------------------------------------------------
#region File & Directory functions
#-------------------------------------------------------
function New-Directory {
    param($name)
    mkdir $name
    Push-Location .\$name
}
Set-Alias -Name mcd -Value new-directory
#-------------------------------------------------------
function Get-FileEncoding {
    ## Get-FileEncoding   http://poshcode.org/2153
    <#

        .SYNOPSIS

        Gets the encoding of a file

        .EXAMPLE

        Get-FileEncoding.ps1 .\UnicodeScript.ps1

        BodyName          : unicodeFFFE
        EncodingName      : Unicode (Big-Endian)
        HeaderName        : unicodeFFFE
        WebName           : unicodeFFFE
        WindowsCodePage   : 1200
        IsBrowserDisplay  : False
        IsBrowserSave     : False
        IsMailNewsDisplay : False
        IsMailNewsSave    : False
        IsSingleByte      : False
        EncoderFallback   : System.Text.EncoderReplacementFallback
        DecoderFallback   : System.Text.DecoderReplacementFallback
        IsReadOnly        : True
        CodePage          : 1201

    #>

    param(
        ## The path of the file to get the encoding of.
        $Path
    )

    Set-StrictMode -Version Latest

    ## The hashtable used to store our mapping of encoding bytes to their
    ## name. For example, "255-254 = Unicode"
    $encodings = @{}

    ## Find all of the encodings understood by the .NET Framework. For each,
    ## determine the bytes at the start of the file (the preamble) that the .NET
    ## Framework uses to identify that encoding.
    $encodingMembers = [System.Text.Encoding] |
        Get-Member -Static -MemberType Property

    $encodingMembers | ForEach-Object {
        $encodingBytes = [System.Text.Encoding]::($_.Name).GetPreamble() -join '-'
        $encodings[$encodingBytes] = $_.Name
    }

    ## Find out the lengths of all of the preambles.
    $encodingLengths = $encodings.Keys | Where-Object { $_ } |
        ForEach-Object { ($_ -split '-').Count }

    ## Assume the encoding is UTF7 by default
    $result = 'UTF7'

    ## Go through each of the possible preamble lengths, read that many
    ## bytes from the file, and then see if it matches one of the encodings
    ## we know about.
    foreach ($encodingLength in $encodingLengths | Sort-Object -Descending) {
        $bytes = (Get-Content -Encoding byte -ReadCount $encodingLength $path)[0]
        $encoding = $encodings[$bytes -join '-']

        ## If we found an encoding that had the same preamble bytes,
        ## save that output and break.
        if ($encoding) {
            $result = $encoding
            break
        }
    }

    ## Finally, output the encoding.
    [System.Text.Encoding]::$result
}
#-------------------------------------------------------
function Get-IniContent {
    param ([string]$filePath)
    $ini = @{}
    switch -regex -file $FilePath {
        '^\[(.+)\]' {
            # Section
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
        '^(;.*)$' {
            # Comment
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = 'Comment' + $CommentCount
            $ini[$section][$name] = $value
        }
        '(.+?)\s*=(.*)' {
            # Key
            $name, $value = $matches[1..2]
            $ini[$section][$name] = $value -split ', '
        }
    }
    return $ini
}
#-------------------------------------------------------
function Out-IniFile {
    param(
        $InputObject,
        [string]$FilePath
    )
    $outFile = New-Item -ItemType file -Path $Filepath
    foreach ($i in $InputObject.keys) {
        if (!($($InputObject[$i].GetType().Name) -eq 'Hashtable')) {
            #No Sections
            Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
        }
        else {
            #Sections
            Add-Content -Path $outFile -Value "[$i]"
            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match '^Comment[\d]+') {
                    Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
                }
                else {
                    Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])"
                }
            }
            Add-Content -Path $outFile -Value ''
        }
    }
}
#endregion
#-------------------------------------------------------
#region Media utilities
#-------------------------------------------------------
function Fix-RarNames {
    $records = @()
    Get-ChildItem * -file | ForEach-Object {
        $r = (7z l $_ -slt |
                Select-String 'Path|Index') -replace '\\', '/' |
                Select-Object -Unique |
                ConvertFrom-StringData
            $x = ([int]$r.'Volume Index' - 1)
            $record = [pscustomobject]@{
                rar     = $r.path[0]
                ext     = if ($x -lt 0) {'rar'} else {'r{0:00}' -f $x}
                payload = if ($r.path[1] -like '*/*') {$r.path[1].split('/')[-1]} else {$r.path[1]}
            }
            $records += $record
    }
    foreach ($rec in $records) {
        $vidext = $rec.payload.split('.')[-1]
        $name = $rec.payload -replace ".$vidext"
        Rename-Item $rec.rar ('{0}.{1}' -f $name, $rec.ext)
    }
}
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
        [Parameter(Mandatory = $true)]
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
