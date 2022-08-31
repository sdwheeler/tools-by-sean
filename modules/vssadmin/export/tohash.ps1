function ConvertTo-HashSyntax {
    param(
        [hashtable]$HashData
    )
    function ExpandHash {
        param(
            [hashtable]$hash,
            [int]$indent
        )

        foreach ($key in $hash.keys) {
            switch ($hash[$key].GetType().Name) {
                'Object[]' {
                    if ($hash[$key].Count -eq 0) {
                        '    '*$indent + "{0} = @()" -f $key
                    } else {
                        '    '*$indent + "{0} = '{1}'" -f $key, ($hash[$key] -join "','")
                    }
                    break
                }

                'Hashtable' {
                    '    '*$indent + "$key = @{"
                    ExpandHash $hash[$key] ($indent + 1)
                    '    '*$indent + "}"
                    break
                }

                default {
                    '    '*$indent + "{0} = '{1}'" -f $key, $hash[$key]
                }
            }
            $result
        }
    }

    '@{'
    ExpandHash $HashData 1
    '}'
}

$data = Import-PowerShellDataFile .\VssAdmin.psd1
$data
'-'*20
$data.FunctionsToExport += 'New-Cmdlet'
$data.PrivateData.CrescendoGenerated = Get-Date -Format 'MM/dd/yyyy HH:mm:ss'
if ($null -eq $data.PrivateData.PSData.Tags) {
    $data.PrivateData.PSData.Add('Tags','CrescendoBuilt')
} else {
    switch ($data.PrivateData.PSData.Tags.GetType().Name) {
        'String' {
            if ($data.PrivateData.PSData.Tags -eq '') {
                $data.PrivateData.PSData.Tags = 'CrescendoBuilt'
            } elseif ($data.PrivateData.PSData.Tags -ne 'CrescendoBuilt') {
                $data.PrivateData.PSData.Tags = $data.PrivateData.PSData.Tags + "','CrescendoBuilt"
            }
        }
        'Object[]' {
            if ($data.PrivateData.PSData.Tags -notcontains 'CrescendoBuilt') {
                $data.PrivateData.PSData.Tags += 'CrescendoBuilt'
            }
        }
    }
}
ConvertTo-HashSyntax $data