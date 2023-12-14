#-------------------------------------------------------
#region File utilities
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
function Get-FileType {
    param(
        [Parameter(Mandatory, Position = 0)]
        [SupportsWildcards()]
        [string]$Path,

        [switch]$Recurse
    )
    $magic = [ordered]@{
        '53514C69746520666F726D6174203300' = 'SQLite3'
        '213C617263683E0A'                 = 'Debian package'
        '89504E470D0A1A0A'                 = 'PNG'
        'D0CF11E0A1B11AE1'                 = 'COM Object'
        '7573746172003030'                 = 'tar (ustar)'
        '7573746172202000'                 = 'tar (POSIX)'
        '526172211A070100'                 = 'RAR v5+'
        '526172211A0700'                   = 'RAR v1.5-4.0'
        '377ABCAF271C'                     = '7-Zip'
        '474946383761'                     = 'GIF87a'
        '474946383961'                     = 'GIF89a'
        '255044462D'                       = 'PDF'
        '4F676753'                         = 'OGG'
        'FEEDFEED'                         = 'JKS Java Key Store'
        'EDABEEDB'                         = 'RPM package'
        '504B0708'                         = 'ZIP (spanned)'
        'FFFE0000'                         = 'Text UTF32LE'
        '0000FEFF'                         = 'Text UTF32BE'
        'DD736673'                         = 'Text EBCDIC'
        '504B0506'                         = 'ZIP (empty)'
        'FF4FFF51'                         = 'JPEG2000'
        'FFD8FFDB'                         = 'JPEG'
        'FFD8FFE0'                         = 'JPEG'
        'FFD8FFE1'                         = 'JPEG'
        'FFD8FFEE'                         = 'JPEG'
        '504B0304'                         = 'ZIP'
        '494433'                           = 'MP3'
        'EFBBBF'                           = 'Text UTF8BOM'
        'FEFF'                             = 'Text UTF16BE'
        'FFFE'                             = 'Text UTF16LE'
        '4D5A'                             = 'WinEXE'
        '1F8B'                             = 'GZIP (tar.gz)'
        '1F9D'                             = 'LZW (tar.z)'
        '1FA0'                             = 'LZH (tar.z)'
    }

    Get-ChildItem $Path -File -Recurse:$Recurse | ForEach-Object {
        try {
            $fstream = [FileStream]::new($_, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read)
            [byte[]]$buffer = [byte[]]::new(32)
            $null = $fstream.read($buffer, 0, 32)
            $fstream.Close()

            $result = [pscustomobject]@{
                FileType = 'Unknown'
                Path     = $_.Name
            }

            foreach ($key in $magic.keys) {
                $l = $key.length / 2
                $bom = (& { for ($i = 0; $i -lt $l; $i++) { '{0:x2}' -f $buffer[$i] } }) -join ''
                if ($magic.keys -contains $bom) {
                    $result.FileType = $magic[$bom]
                    break
                }
            }
            $result
            if ($result.FileType -eq 'Unknown') {
                Write-Output ($buffer | Format-Hex | Out-String)
            }
        } catch {
            Write-Error $_.Exception.Message
        }
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Media utilities
#-------------------------------------------------------
function Get-ImageMetadata {
    param(
        [Parameter(Mandatory, Position=0)]
        [SupportsWildcards()]
        [String]$Path,

        [switch]$Recurse
    )

    Add-Type -AssemblyName PresentationCore
    $methods = @{
        '.bmp'  = 'BmpBitmapDecoder'
        '.dib'  = 'BmpBitmapDecoder'
        '.gif'  = 'GifBitmapDecoder'
        '.ico'  = 'IconBitmapDecoder'
        '.jpe'  = 'JpegBitmapDecoder'
        '.jpeg' = 'JpegBitmapDecoder'
        '.jpg'  = 'JpegBitmapDecoder'
        '.png'  = 'PngBitmapDecoder'
        '.tiff' = 'TiffBitmapDecoder'
        '.tif'  = 'TiffBitmapDecoder'
    }

    Get-ChildItem -Path $Path -File -Recurse:$Recurse | ForEach-Object {

        $file = $_
        if ($file.Extension -notin $methods.Keys) {
            Write-Warning "File $file is not a supported image type."
        } else {
            try {
                $fs = [IO.File]::OpenRead($file.FullName)
                $typename = "System.Windows.Media.Imaging.$($methods[$file.Extension])"

                $dec = New-Object $typename(
                    $fs,
                    [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreColorProfile,
                    [Windows.Media.Imaging.BitmapCacheOption]::Default
                )

                [Windows.Media.Imaging.BitmapMetadata].GetProperties() | ForEach-Object {
                    $raw = $dec.Frames[0].Metadata
                    $res = @{}
                    $res.Path = $file.FullName
                } {
                    if ($_.Name -ne 'DependencyObjectType') {
                        $res[$_.Name] = $(
                            if ($_ -eq 'Author') { $raw.($_.Name)[0] } else { $raw.($_.Name) }
                        )
                    }
                } { [pscustomobject]$res } #foreach
            }
            catch {
                $_.Exception.InnerException
            }
            finally {
                if ($null -ne $fs) { $fs.Close() }
            }
        }
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
