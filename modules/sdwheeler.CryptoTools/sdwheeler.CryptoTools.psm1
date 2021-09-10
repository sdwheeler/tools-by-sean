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
    param([string[]]$certificate,
        [switch]$multiline)

    foreach ($certpath in $certificate) {
        $cert = Get-Item $certpath
        $cert | Select-Object -Property Subject, DNSNameList, NotBefore, NotAfter, Issuer, PolicyId, Archived, FriendlyName, SerialNumber, Thumbprint, HasPrivateKey,
        @{ N = 'SignatureAlgorithm'; E = { $_.SignatureAlgorithm.FriendlyName } },
        @{ N = 'CertTemplateInfo'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Certificate Template Information' }).Format($multiline) } },
        @{ N = 'KeyUsage'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Key Usage' }).Format($multiline) } },
        @{ N = 'EnhKeyUsage'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Enhanced Key Usage' }).Format($multiline) } },
        @{ N = 'AppPolicies'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Application Policies' }).Format($multiline) } },
        @{ N = 'SubjectKeyId'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Key Identifier' }).Format($multiline) } },
        @{ N = 'AuthorityKeyId'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Authority Key Identifier' }).Format($multiline) } },
        @{ N = 'CRLDistPoints'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'CRL Distribution Points' }).Format($multiline) } },
        @{ N = 'AuthorityInfoAccess'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Authority Information Access' }).Format($multiline) } },
        @{ N = 'SubjectAltName'; E = { ($_.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }).Format($multiline) } },
        @{ N = 'BasicConstraints'; E = { ($cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Basic Constraints' }).Format($multiline) } }
    }
}
#endregion
#-------------------------------------------------------
