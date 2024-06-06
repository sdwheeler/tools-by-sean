#-------------------------------------------------------
#region Crypto Functions
#-------------------------------------------------------
function Get-Hash {
    param([string]$cleartext,
        [string[]]$algorithms = @('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')
    )
    $inputBytes = [System.Text.Encoding]::ASCII.GetBytes($cleartext)
    foreach ($alg in $algorithms) {
        $hashprovider = [Security.Cryptography.HashAlgorithm]::Create($alg)
        $bytes = $hashprovider.ComputeHash($inputBytes)
        $hash = -Join ($bytes | ForEach-Object { '{0:x2}' -f $_ })
        "{0}`t{1}" -f $alg, $hash
    }
}
#-------------------------------------------------------
function Show-Certificate {
    [CmdletBinding(DefaultParameterSetName='ByPath')]
    param(
        [Parameter(ValueFromPipelineByPropertyName, Position = 0, ParameterSetName='ByPath')]
        [Alias('PSPath')]
        [string[]]$Path,

        [Parameter(ValueFromPipeline, Position = 0, ParameterSetName='ByCert')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [switch]$Multiline
    )
    begin {
        function SelectProperties {
            param(
                [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
            )

            $Certificate | Select-Object -Property Subject, DNSNameList, NotBefore, NotAfter,
            Issuer, PolicyId, Archived, FriendlyName, SerialNumber, Thumbprint, HasPrivateKey,
            @{ N = 'SignatureAlgorithm';  E = { $_.SignatureAlgorithm.FriendlyName } },
            @{ N = 'CertTemplateInfo';    E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Certificate Template Information' }).Format($multiline) } },
            @{ N = 'KeyUsage';            E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Key Usage' }).Format($multiline) } },
            @{ N = 'EnhKeyUsage';         E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Enhanced Key Usage' }).Format($multiline) } },
            @{ N = 'AppPolicies';         E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Application Policies' }).Format($multiline) } },
            @{ N = 'SubjectKeyId';        E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Key Identifier' }).Format($multiline) } },
            @{ N = 'AuthorityKeyId';      E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Authority Key Identifier' }).Format($multiline) } },
            @{ N = 'CRLDistPoints';       E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'CRL Distribution Points' }).Format($multiline) } },
            @{ N = 'AuthorityInfoAccess'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Authority Information Access' }).Format($multiline) } },
            @{ N = 'SubjectAltName';      E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }).Format($multiline) } },
            @{ N = 'BasicConstraints';    E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Basic Constraints' }).Format($multiline) } }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            foreach ($certpath in $Path) {
                SelectProperties (Get-Item $certpath)
            }
        } else {
            SelectProperties $Certificate
        }
    }
}
#endregion
#-------------------------------------------------------
