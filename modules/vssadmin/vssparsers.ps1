function ParseProvider {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )

    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i+=2) {
        if ($textBlocks[$i] -ne '') {
            $hash = @{}
            $kvpairs = ($textBlocks[$i] -split "`r`n").Split(':').Trim()

            for ($x = 0; $x -lt $kvpairs.Count; $x++) {
                switch ($kvpairs[$x]) {
                    'Provider name' {
                        $hash.Add('Name',$kvpairs[$x+1].Trim("'"))
                    }
                    'Provider type' {
                        $hash.Add('Type',$kvpairs[$x+1])
                    }
                    'Provider Id' {
                        $hash.Add('Id',([guid]($kvpairs[$x+1])))
                    }
                    'Version' {
                        $hash.Add('Version',[version]$kvpairs[$x+1])
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}

function ParseShadow {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'set ID:' {
                        $id = [guid]$line.Split(':')[1].Trim()
                        $hash.Add('SetId',$id)
                        break
                    }
                    'creation time:' {
                        $datetime = [datetime]($line -split 'time:')[1]
                        $hash.Add('CreateTime',$datetime)
                        break
                    }
                    'Copy ID:' {
                        $id = [guid]$line.Split(':')[1].Trim()
                        $hash.Add('CopyId',$id)
                        break
                    }
                    'Original Volume:' {
                        $value = ($line -split 'Volume:')[1].Trim()
                        if ($value -match '^\((?<name>[A-Z]:)\)(?<path>\\{2}.+\\$)') {
                            $volinfo = [pscustomobject]@{
                                Name = $Matches.name
                                Path = $Matches.path
                            }
                        }
                        $hash.Add('OriginalVolume',$volinfo)
                        break
                    }
                    'Copy Volume:' {
                        $hash.Add('ShadowCopyVolume', $line.Split(':')[1].Trim())
                        break
                    }
                    'Machine:' {
                        $parts = $line.Split(':')
                        $hash.Add($parts[0].Replace(' ',''), $parts[1].Trim())
                        break
                    }
                    'Provider:' {
                        $hash.Add('ProviderName',$line.Split(':')[1].Trim(" '"))
                        break
                    }
                    'Type:' {
                        $hash.Add('Type',$line.Split(':')[1].Trim())
                        break
                    }
                    'Attributes' {
                        $attrlist = $line.Split(': ')[1]
                        $hash.Add('Attributes',$attrlist.Split(', '))
                        break
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}

function ParseShadowStorage {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'volume:' {
                        $parts = $line -split 'volume:'
                        $key = $parts[0].Replace(' ','') + 'Volume'
                        $value = $parts[1].Trim()
                        if ($value -match '^\((?<name>[A-Z]:)\)(?<path>\\{2}.+\\$)') {
                            $volinfo = [pscustomobject]@{
                                Name = $Matches.name
                                Path = $Matches.path
                            }
                        }
                        $hash.Add($key,$volinfo)
                        break
                    }
                    'space:' {
                        $parts = $line.Split(':')
                        $key = $parts[0].Split(' ')[0] + 'Space'
                        $data = $parts[1].TrimEnd(')') -split ' \('
                        $space = [PSCustomObject]@{
                            Size = $data[0].Replace(' ','')
                            Percent = $data[1]
                        }
                        $hash.Add($key, $space)
                        break
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}

function ParseWriter {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'name:' {
                        $hash.Add('Name',($line -split ': ')[1].Trim("'"))
                        break
                    }
                    'Id:' {
                        $parts = $line -split ': '
                        $key = $parts[0].Replace(' ','')
                        $id = [guid]$parts[1].Trim()
                        $hash.Add($key,$id)
                        break
                    }
                    'State:' {
                        $hash.Add('State', ($line -split ': ')[1].Trim())
                        break
                    }
                    'error:' {
                        $hash.Add('LastError', ($line -split ': ')[1].Trim())
                        break
                    }
                }
            }
            [pscustomobject]$hash
        }
    }
}

function ParseVolume {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    for ($i=1; $i -lt $textBlocks.Count; $i++) {
        if ($textBlocks[$i] -ne '') {
            $hash = [ordered]@{}
            $lines = ($textBlocks[$i] -split "`r`n").Trim()

            foreach ($line in $lines) {
                switch -regex ($line) {
                    'path:' {
                        $hash.Add('Path',($line -split ': ')[1].Trim("'"))
                        break
                    }
                    'name:' {
                        $hash.Add('Name',($line -split ': ')[1].Trim("'"))
                        # Output the object and create a new empty hash
                        [pscustomobject]$hash
                        $hash = [ordered]@{}
                        break
                    }
                }
            }
        }
    }
}

function ParseResizeShadowStorage {
    param(
        [Parameter(Mandatory)]
        $cmdResults
    )
    $textBlocks = ($cmdResults | Out-String) -split "`r`n`r`n"

    if ($textBlocks[1] -like 'Error*') {
        Write-Error $textBlocks[1]
    } elseif ($textBlocks[1] -like 'Success*') {
        Get-VssShadowStorage
    } else {
        $textBlocks[1]
    }

}

# ParseProvider (Get-Content .\native-output\providers.txt -Raw)
# ParseShadow (Get-Content .\native-output\shadows.txt -Raw)
# ParseShadowStorage (Get-Content .\native-output\shadowstorage.txt -Raw)
# ParseWriter (Get-Content .\native-output\writers.txt -Raw)
# ParseVolume (Get-Content .\native-output\volumes.txt -Raw)
