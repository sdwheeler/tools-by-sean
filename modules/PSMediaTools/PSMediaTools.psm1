#---------------------------------------------------------------------
#region File utilities
#---------------------------------------------------------------------
function capitalize {
    <#
    .SYNOPSIS
        Capitalizes the components of a media filename.

    .DESCRIPTION
        This function takes a media filename and capitalizes the components of the title while
        leaving the season and episode information intact. It uses a regular expression to identify
        the season and episode pattern (e.g., S01E01) and then capitalizes the title components
        accordingly.

    .PARAMETER inputString
        The media filename to be processed.

    .EXAMPLE
        PS> capitalize "the.office.s01e01.pilot.mkv"

        The.Office.S01E01.Pilot.mkv
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [string]
        $inputString
    )

    if ($inputString -match '([\w\s]+)(S\d\dE\d\d\s)(?<ep>.+)(\.\w{3,4})') {
       $title = $Matches.ep.Trim().ToLower()
       $parts = $title -split '\s'
       $newString = ''
       $parts = foreach ($part in $parts) {
           if ($part.Length -gt 0) {
               $part.Substring(0,1).ToUpper() + $part.Substring(1, $part.Length - 1)
           }
       }
       $newString = $parts -join ' '
    }
    if ($newString) {
        $inputString -replace [regex]::Escape($Matches.ep), $newString
    } else {
        $inputString
    }
}
#---------------------------------------------------------------------
function Rename-MediaFile {
    <#
    .SYNOPSIS
        Renames media files to a standardized format.

    .DESCRIPTION
        This function takes a path a directory or one or more files and renames the media files by
        removing predefined tokens from the name. It capitalizes the components of the filename
        while preserving the season and episode information.

    .PARAMETER path
        The path to the directory containing the media files to be renamed. It accepts wildcards to
        specify multiple files. If you provide a directory, it processes all files in that
        directory.

    .EXAMPLE
        PS>  Rename-MediaFile .\The.Last.Show.on.TV.01x06.720p.HEVC.x265-MeGusta.mkv

            Directory: C:\Users\username\Downloads

        Mode                 LastWriteTime         Length Name
        ----                 -------------         ------ ----
        -a---            2/6/2026  3:14 PM      246285730 The Last Show On TV S01E06.mkv

    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [SupportsWildcards()]
        [string]$path
    )
    $tokens = Get-Content $PSScriptRoot\filename-tokens.txt

    $pattern='[\s\.-](' + ($tokens -join '|') + ')'
    $wordlist = 'a', 'an', 'and', 'for', 'of', 'the', 'to'
    Get-ChildItem $path -File -Exclude *.txt,*.ps1  | ForEach-Object {
        $file=$_.basename
        $ext = $_.extension
        $file=$file -replace $pattern
        $file=$file -replace '[-,_\(\)\[\]\.]', ' '
        $file=$file -replace '\s{2,}', ' '
        $file=$file.trim()
        $words = $file -split ' '
        for ($c = 0; $c -lt $words.Count; $c++) {
            if ($words[$c] -match 's[0-9]{1,3}e[0-9]{1,3}') {
                $words[$c] = $words[$c].ToUpper()
            }
            elseif ($words[$c] -match '([0-9]{1,3})x([0-9]{1,3})') {
                $words[$c] = 'S{0}E{1}' -f $Matches[1],$Matches[2]
            }
            else {
                if ($c -eq 0 -or $words[$c] -notin $wordlist) {
                    $words[$c] = $words[$c].Substring(0, 1).ToUpper() + $words[$c].Substring(1)
                } else {
                    $words[$c] = $words[$c].ToLower()
                }
            }
        }
        $file=$words -join ' '
        $newName = $file + $ext
        Rename-Item $_ (capitalize $newName) -PassThru
    }
}
#---------------------------------------------------------------------
function Rename-RarFile {
    <#
    .SYNOPSIS
        Renames archive (usually RAR) files to a standardized format based on the contents of the
        archive.

    .DESCRIPTION
        This function takes a path to one or more archive files and renames them based on the
        contents of the archive. It uses the 7-Zip command-line tool to inspect the contents of the
        archive and extract information such as the name of the payload and the part index of a
        multi-part archive. The function then renames the archive files according to a specified
        format, which can be one of `r00`, `parts`, or `name`. The goal is to normalize the naming
        of archive files so that they can be properly unpacked by 7-Zip.

    .PARAMETER Path
        The path to the archive files to be renamed. It accepts wildcards to specify multiple files.

    .PARAMETER Format
        The format to use for renaming the archive files. Valid options are `r00`, `parts`, and
        `name`. The default is `r00`.

        - `r00`: Renames files using the RAR naming convention (e.g., `example.rar`, `example.r00`,
          `example.r01`, etc.).
        - `parts`: Renames files using a parts-based naming convention (e.g., `example.part001.rar`,
          `example.part002.rar`, etc.).
        - `name`: Renames files using the name of the payload but keeps the existing extension.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [SupportsWildcards()]
        [string[]]$Path,
        [ValidateSet('r00','parts','name')]
        [string]$Format = 'r00'
    )
    Get-ChildItem $Path -file | ForEach-Object {
        $srcfile = $_.Name
        $rarExt = $_.Extension
        $rarname = ''

        $r = (7z l $_ -slt |
                Select-String 'Path|Index') -replace '\\', '/' |
                Select-Object -Unique |
                ConvertFrom-StringData
        $x = [int]$r.'Volume Index'
        $payload = if ($r.path[1] -like '*/*') {
            $r.path[1].split('/')[-1]
        } else {
            $r.path[1]
        }
        $vidext = $payload.split('.')[-1]
        $basename = $payload -replace ".$vidext"

        switch ($Format) {
            'name' {
                $rarname = '{0}{1}' -f $basename, $rarExt
            }
            'parts' {
                $rarname = '{0}.part{1:000}.rar' -f $basename, $x
            }
            'r00' {
                if ($x -eq 0) {
                    $rarname = '{0}.rar' -f $basename
                } else {
                    $rarname = '{0}.r{1:00}' -f $basename, ($x-1)
                }
            }
        }
        Rename-Item $srcfile $rarname -PassThru
    }
}
#---------------------------------------------------------------------
#region FFMpeg Functions
#---------------------------------------------------------------------
function Convert-MediaFormat {
    <#
    .SYNOPSIS
        Converts media files to a standardized format using FFMpeg tools.

    .DESCRIPTION
        This function takes a path to one or more media files and converts them to a standardized
        format using FFMpeg. It identifies the video, audio, and subtitle streams in the input
        files and constructs the appropriate FFMpeg command to convert the media while preserving
        the desired streams. The function also supports options for rescaling the video and
        excluding subtitles from the output.

        The media files are converted from the input format to MKV files with HEVC video and AAC
        audio codecs. The function maps the first video stream and the first English audio stream
        to the output, and the largest English subtitle stream if it exists. All other streams are
        ignored. The output files are saved in a `fix` subdirectory with the same base name but a
        `.mkv` extension.

    .PARAMETER Path
        The path to the media files to be converted. It accepts wildcards to specify multiple
        files. If you provide a directory, it processes all files in that directory.

    .PARAMETER NoSubs
        A switch parameter that, when set, indicates that no subtitles should be included in the
        output files. By default, the function includes the largest English subtitle stream if it
        exists.

    .PARAMETER Rescale
        An optional parameter that specifies the target resolution for rescaling the video. Valid
        options are `540p`, `720p`, `1080p`, `2K`, `2160p`, and `4K`. If this parameter is
        provided, the output videos will be rescaled to the specified resolution using the
        appropriate FFMpeg scaling filter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SupportsWildcards()]
        [string[]]$Path,
        [switch]$NoSubs,
        [ValidateSet('540p','720p','1080p','2K','2160p','4K')]
        [string]$Rescale
    )

    if (-not (Test-Path -Path .\fix)) { $null = mkdir .\fix }
    switch ($Rescale) {
        '540p'  { $scale = '960:540'   }
        '720p'  { $scale = '1280:720'  }
        '1080p' { $scale = '1920:1080' }
        '2K'    { $scale = '2048:1080' }
        '2160p' { $scale = '3840:2160' }
        '4K'    { $scale = '4096:2160' }
        default { $scale = ''          }
    }
    if ($Rescale) {
        Write-Verbose "Output videos will be rescaled to $scale."
    }

    if ($NoSubs) {
        Write-Verbose 'No subtitles will be included in output files.'
    } else {
        $NoSubs = $false
    }

    foreach ($p in $Path) {
        Get-ChildItem $p -file | ForEach-Object {
            $streams = Get-FFMpegStreamData $_.FullName

            $video = $streams | Where-Object type -EQ 'video' | Select-Object -First 1
            $audio = $streams | Where-Object type -EQ 'audio'
            if ($audio.count -gt 1) {
                $aac = $audio | Where-Object codec -EQ 'aac'
                if ($null -eq $aac) {
                    $audio = $audio[0]
                } else {
                    $audio = $aac
                }
            }
            $subtitle = $streams |
                Where-Object type -eq subtitle |
                Sort-Object size -Descending |
                Select-Object -First 1

            $params = @()
            $params += '-hide_banner'
            $params += '-i'
            $params += '.\{0}' -f $_.Name
            $params += '-vcodec'
            $params += 'hevc'
            $params += '-acodec'
            $params += 'aac'
            $params += '-map'
            $params += $video.id
            if ($Rescale) {
                $params += '-vf'
                $params += "scale=$scale"
            }
            $params += '-map'
            $params += $audio.id
            if (-not $NoSubs -and $null -ne $subtitle) {
                $params += '-scodec'
                $params += 'subrip'
                $params += '-map'
                $params += $subtitle.id
            }
            $params += '-preset'
            $params += 'slow'
            $params += '.\fix\{0}.mkv' -f $_.BaseName

            Write-Verbose "params: $params"

            ffmpeg.exe @params
        }
    }
}
#---------------------------------------------------------------------
function Copy-MediaStreams {
    <#
    .SYNOPSIS
        Copies media streams from input files to output files using FFMpeg without re-encoding.

    .DESCRIPTION
        This function takes a path to one or more media files and copies the video, audio, and
        subtitle streams to new MKV files using FFMpeg. It identifies the first video stream, the
        first English audio stream, and the largest English subtitle stream in the input files and
        constructs the appropriate FFMpeg command to copy these streams to the output files without
        re-encoding. The output files are saved in a `fix` subdirectory with the same base name but
        a `.mkv` extension.

        This command is useful for quickly remuxing media files to a standardized format without
        changing the codecs or quality of the streams.

    .PARAMETER Path
        The path to the media files to be processed. It accepts wildcards to specify multiple
        files. If you provide a directory, it processes all files in that directory.

    .PARAMETER NoSubs
        A switch parameter that, when set, indicates that no subtitles should be included in the
        output files. By default, the function includes the largest English subtitle stream if it
        exists.

    .PARAMETER Rescale
        An optional parameter that specifies the target resolution for rescaling the video. Valid
        options are `540p`, `720p`, `1080p`, `2K`, `2160p`, and `4K`. If this parameter is
        provided, the output videos will be rescaled to the specified resolution using the
        appropriate FFMpeg scaling filter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SupportsWildcards()]
        [string[]]$Path,
        [switch]$NoSubs,
        [ValidateSet('540p','720p','1080p','2K','2160p','4K')]
        [string]$Rescale
    )

    if (-not (Test-Path -Path .\fix)) { $null = mkdir .\fix }
    switch ($Rescale) {
        '540p'  { $scale = '960:540'   }
        '720p'  { $scale = '1280:720'  }
        '1080p' { $scale = '1920:1080' }
        '2K'    { $scale = '2048:1080' }
        '2160p' { $scale = '3840:2160' }
        '4K'    { $scale = '4096:2160' }
        default { $scale = ''          }
    }
    if ($Rescale) {
        Write-Verbose "Output videos will be rescaled to $scale."
    }

    if ($NoSubs) {
        Write-Verbose 'No subtitles will be included in output files.'
    } else {
        $NoSubs = $false
    }

    foreach ($p in $Path) {
        Get-ChildItem $p -file | ForEach-Object {
            $streams = Get-FFMpegStreamData $_.FullName
            $video = $streams | Where-Object type -EQ 'video' | Select-Object -First 1
            $audio = $streams | Where-Object type -EQ 'audio'
            $subtitle = $streams |
                Where-Object {$_.type -eq 'subtitle' -and $_.language -eq 'eng'} |
                Sort-Object size -Descending |
                Select-Object -First 1

            $params = @()
            $params += '-hide_banner'
            $params += '-i'
            $params += '.\{0}' -f $_.Name
            $params += '-vcodec'
            $params += 'copy'
            $params += '-acodec'
            $params += 'copy'
            $params += '-map'
            $params += $video.id
            $params += '-map'
            $params += $audio.id
            if ($Rescale) {
                $params += '-vf'
                $params += "scale=$scale"
                $params += '-crf'
                $params += '18'
            }
            if (-not $NoSubs -and $null -ne $subtitle) {
                $params += '-scodec'
                $params += 'copy'
                $params += '-map'
                $params += $subtitle.id
            }
            $params += '-preset'
            $params += 'slow'
            $params += '.\fix\{0}.mkv' -f $_.BaseName

            Write-Verbose "params: $params"

            & ffmpeg.exe @params
        }
    }
}
#---------------------------------------------------------------------
function Get-FFMpegFileData {
    <#
    .SYNOPSIS
        Retrieves format information about media files using FFMpeg.
    .DESCRIPTION
        This function takes a path to one or more media files and retrieves format information
        about each file using the FFMpeg tool `ffprobe`. It extracts details such as the format
        name, file size, duration, bitrate, and filename. The information is returned as custom
        PowerShell objects with a type name of `FFMpegFileInfo`.

    .PARAMETER Path
        The path to the media files for which to retrieve format information. It accepts wildcards
        to specify multiple files. If you provide a directory, it processes all files in that
        directory.

    .EXAMPLE
        PS> Get-FFMpegFileData '.\The Last Show On TV S01E06.mkv'

        format               size duration bitrate filename
        ------               ---- -------- ------- --------
        Matroska / WebM 234.88 MB 00:41:13     797 The Last Show On TV S01E06.mkv
    #>
    [CmdletBinding()]
    param(
        [SupportsWildcards()]
        [string[]]$Path = '*'
    )

    foreach ($p in $Path) {
        $files = Get-ChildItem $p -file
        foreach ($file in $files) {
            $format = ffprobe.exe -show_format -i $file.FullName -loglevel quiet -of json |
                ConvertFrom-Json -Depth 10 | Select-Object -exp format
            $format | ForEach-Object {
                [pscustomobject]@{
                    PSTypeName = 'FFMpegFileInfo'
                    format     = $_.format_long_name
                    size       = $_.size
                    duration   = (New-TimeSpan -Seconds $_.duration).ToString()
                    bitrate    = $_.bit_rate
                    filename   = $file.Name
                }
            }
        }
    }
}
#---------------------------------------------------------------------
function Get-FFMpegStreamData {
    <#
    .SYNOPSIS
        Retrieves stream information about media files using FFMpeg.

    .DESCRIPTION
        This function takes a path to one or more media files and retrieves stream information about
        each file using the FFMpeg tool `ffprobe`. It extracts details such as the stream index,
        type, codec, language, size, channels, layout, duration, resolution, title, and filename.

    .PARAMETER Path
        The path to the media files for which to retrieve stream information. It accepts wildcards
        to specify multiple files. If you provide a directory, it processes all files in that
        directory.

    .PARAMETER All
        If specified, retrieves all streams. Otherwise, only retrieves streams with language 'eng'
        or 'und'.

    .EXAMPLE
        PS> Get-FFMpegStreamData '.\The Last Show On TV S01E06.mkv'

        index id  type  codec language size channels layout    duration resolution title filename
        ----- --  ----  ----- -------- ---- -------- ------    -------- ---------- ----- --------
        0     0:0 video hevc  und                              00:41:13 1280x720         The Last Show On TV S01E06.mkv
        1     0:1 audio ac3   und                  6 5.1(side) 00:41:13 48000 Hz         The Last Show On TV S01E06.mkv
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [SupportsWildcards()]
        [string[]]$Path = '*',
        [switch]$All
    )

    foreach ($p in $Path) {
        Get-ChildItem $p -file | ForEach-Object {
            $filename = $_.Name
            $result = ffprobe.exe -show_streams $_.fullname -of json -loglevel quiet |
                ConvertFrom-Json -Depth 10
            $streams = $result.streams | ForEach-Object {
                [pscustomobject]@{
                    PSTypeName = 'FFMpegStreamInfo'
                    index      = $_.index
                    id         = '0:{0}' -f $_.index
                    type       = $_.codec_type
                    codec      = $_.codec_name
                    language   = $_.tags.language ?? 'und'
                    size       = if ($null -ne $_.tags.NUMBER_OF_BYTES) {
                            $_.tags.NUMBER_OF_BYTES
                        } elseif ($null -ne $_.tags.'NUMBER_OF_BYTES-eng') {
                            $_.tags.'NUMBER_OF_BYTES-eng'
                        } else {
                            $null
                        }
                    channels   = $_.channels
                    layout     = $_.channel_layout
                    duration   = if ($null -ne $_.duration) {
                            (New-TimeSpan -Seconds $_.duration).ToString()
                        } elseif ($null -ne $_.tags.DURATION) {
                            $_.tags.DURATION.split('.')[0]
                        } elseif ($null -ne $_.tags.'DURATION-eng') {
                            $_.tags.'DURATION-eng'.split('.')[0]
                        } else {
                            ''
                        }
                    resolution = if ($_.codec_type -eq 'video') {
                            '{0}x{1}' -f $_.width, $_.height
                        } elseif ($_.codec_type -eq 'audio') {
                            '{0} Hz' -f $_.sample_rate
                        } else {
                            ''
                        }
                    title      = $_.tags.title
                    filename   = $filename
                }
            }
            if ($All) {
                $streams
            } else {
                $streams | Where-Object language -in 'eng', 'und'
            }
        }
    }
}
#---------------------------------------------------------------------
function ffprobe {
    <#
    .SYNOPSIS
        Retrieves format or stream information about media files using `ffprobe.exe`.

    .DESCRIPTION
        This function takes a path to one or more media files and retrieves detailed format or
        stream information about each file using the `ffprobe.exe` tool.

    .PARAMETER Path
        The path to the media files for which to retrieve information. It accepts wildcards to
        specify multiple files. If you provide a directory, it processes all files in that
        directory.

    .PARAMETER Type
        The type of information to retrieve. Valid options are `format` and `streams`. The default
        is `format`.

    .EXAMPLE
        PS> ffprobe -Path '.\The Last Show On TV S01E06.mkv' -Type format

        filename         : C:\Users\useranem\Downloads\The Last Show On TV S01E06.mkv
        nb_streams       : 2
        nb_programs      : 0
        format_name      : matroska,webm
        format_long_name : Matroska / WebM
        start_time       : 0.000000
        duration         : 2473.471000
        size             : 246285730
        bit_rate         : 796567
        probe_score      : 100
        tags             : @{ENCODER=Lavf61.5.101}

    .EXAMPLE
        PS> ffprobe -Path '.\The Last Show On TV S01E06.mkv' -Type streams

        index                : 0
        codec_name           : hevc
        codec_long_name      : H.265 / HEVC (High Efficiency Video Coding)
        profile              : Main 10
        codec_type           : video
        codec_tag_string     : [0][0][0][0]
        codec_tag            : 0x0000
        width                : 1280
        height               : 720
        coded_width          : 1280
        coded_height         : 720
        closed_captions      : 0
        film_grain           : 0
        has_b_frames         : 2
        sample_aspect_ratio  : 1:1
        display_aspect_ratio : 16:9
        pix_fmt              : yuv420p10le
        level                : 93
        color_range          : tv
        color_space          : bt709
        chroma_location      : left
        field_order          : progressive
        refs                 : 1
        r_frame_rate         : 24000/1001
        avg_frame_rate       : 24000/1001
        time_base            : 1/1000
        start_pts            : 0
        start_time           : 0.000000
        extradata_size       : 2481
        disposition          : @{default=1; dub=0; original=0; comment=0; lyrics=0; karaoke=0; forced=0; hearing_impaired=0;
                               visual_impaired=0; clean_effects=0; attached_pic=0; timed_thumbnails=0; captions=0;
                               descriptions=0; metadata=0; dependent=0; still_image=0}
        tags                 : @{ENCODER=Lavc61.11.100 libx265; DURATION=00:41:13.471000000}

        index            : 1
        codec_name       : ac3
        codec_long_name  : ATSC A/52A (AC-3)
        codec_type       : audio
        codec_tag_string : [0][0][0][0]
        codec_tag        : 0x0000
        sample_fmt       : fltp
        sample_rate      : 48000
        channels         : 6
        channel_layout   : 5.1(side)
        bits_per_sample  : 0
        r_frame_rate     : 0/0
        avg_frame_rate   : 0/0
        time_base        : 1/1000
        start_pts        : 0
        start_time       : 0.000000
        bit_rate         : 384000
        disposition      : @{default=1; dub=0; original=0; comment=0; lyrics=0; karaoke=0; forced=0; hearing_impaired=0;
                           visual_impaired=0; clean_effects=0; attached_pic=0; timed_thumbnails=0; captions=0; descriptions=0;
                           metadata=0; dependent=0; still_image=0}
        tags             : @{DURATION=00:41:13.440000000}

    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [SupportsWildcards()]
        [string[]]$Path = '*',
        [ValidateSet('format','streams')]
        [string]$Type = 'format'
    )
    foreach ($file in (Get-ChildItem $Path -file)) {
        switch ($Type) {
            'format' {
                ffprobe.exe -show_format -i $file.FullName -of json -loglevel quiet |
                    ConvertFrom-Json -Depth 10 |
                    Select-Object -ExpandProperty format
            }
            'streams' {
                ffprobe.exe -show_streams -i $file.FullName -of json -loglevel quiet |
                    ConvertFrom-Json -Depth 10 |
                    Select-Object -ExpandProperty streams
            }
        }
    }
}
#---------------------------------------------------------------------
function Split-Chapters {
    <#
    .SYNOPSIS
        Splits media files into chapters based on chapter information using FFMpeg.

    .DESCRIPTION
        This function takes a path to one or more media files and splits them into separate files
        based on chapter information extracted using the FFMpeg tool `ffprobe`. It retrieves the
        chapter information from the input files and uses FFMpeg to create separate MP3 files for
        each chapter. The output files are named using the base name of the input file followed by
        the chapter title.

    .PARAMETER Path
        The path to the media files to be split into chapters. It accepts wildcards to specify
        multiple files. If you provide a directory, it processes all files in that directory.
    #>
    param(
        [Parameter(Mandatory)]
        [SupportsWildcards()]
        [string[]]$Path
    )

    foreach ($p in $Path) {
        foreach ($file in Get-ChildItem -Path $p) {
            $chaptersJson = Join-Path $file.Directory 'chapters.json'
            ffprobe.exe -i $file -print_format json -show_chapters -loglevel error > $chaptersJson
            $chapters = Get-Content $chaptersJson | ConvertFrom-Json -Depth 20

            foreach ($c in $chapters.chapters) {
                $start = $c.start_time
                $end = $c.end_time
                $chapter = $c.tags.title -replace ':', ' -'
                if ($chapters.count -lt 100) {
                    $newname = ('{0:D2} - ' -f $c.id), "$chapter.mp3" -join ''
                } elseif ($chapters.count -ge 100 -and $chapters.count -lt 1000) {
                    $newname = ('{0:D2} - ' -f $c.id), "$chapter.mp3" -join ''
                } else {
                    $newname = ('{0:D3} - ' -f $c.id), "$chapter.mp3" -join ''
                }
                $outfile = Join-Path $file.Directory $newname
                ffmpeg -hide_banner -i $file -ss $start -to $end -acodec mp3 -map 0:0 $outfile
            }
        }
    }
}
#---------------------------------------------------------------------
#endregion
#---------------------------------------------------------------------
#region PSPlex functions
#---------------------------------------------------------------------
# These functions depend on the PSPlex module, which provides cmdlets for interacting with a
# Plex Media Server. See https://github.com/robinmalik/PSPlex.
#---------------------------------------------------------------------
# Get the library names and keys so we can use them for autocompletion in Update-Plex.
$libraries = @{}
Get-PlexLibrary | ForEach-Object { $libraries.Add($_.title, $_.key) }
#---------------------------------------------------------------------
function Update-Plex {
    <#
    .SYNOPSIS
        Updates specified Plex libraries.

    .DESCRIPTION
        This function takes one or more Plex library names as input and updates those libraries on
        the Plex Media Server.

    .PARAMETER Library
        An array of Plex library names to be updated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0, ValueFromPipeline)]
        [string[]]$Library
    )
    process {
        foreach ($i in $Library) {
            $id = $libraries[$i]
                $null = Update-PlexLibrary -Id $id
        }
    }
}
#---------------------------------------------------------------------
# Register an argument completer for the Library parameter of Update-Plex to provide autocompletion
# of library names.
$sbLibraries = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $libraries.Keys |
        Where-Object { $_ -like "*$wordToComplete*" } |
        ForEach-Object {if ($_ -match ' ') {"'$_'"} else {$_}}
}
Register-ArgumentCompleter -CommandName Update-Plex -ParameterName Library -ScriptBlock $sbLibraries
#---------------------------------------------------------------------
#endregion
#---------------------------------------------------------------------
