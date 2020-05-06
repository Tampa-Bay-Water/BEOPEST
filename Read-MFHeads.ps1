param([string]$headfile=$(throw "headfile must be specified"),
	[int[]]$tsteps,[int[]]$cellids,[int[]]$layers,
	[int]$nrow=207,[int]$ncol=183,[int]$nlayer=3)

# function to calculate cell position in a layer given a list of CellID
function Get-ElementOffset {
	param([int[]]$cellid)
	$pos = @()
	foreach ($i in $cellid) {
		$nr = [math]::floor($i/1000.)-1;
		$nc = ($i % 1000)-1;
		$pos += $nr*$ncol+$nc;
	}
	return $pos;
}

# Precision
$word = 4;

# dimensioning return array - this is not a good solution
#$heads = New-Object "single[,,]" $tsteps.length,$layers.length,$cellids.length

# header for each time step is 44 bytes of the following information
# TimeStep As Integer (4)
# Period As Integer (4)
# PeriodTime As Single (4)
# TotalTime As Single (4)
# Text As String 16 bytes
# ByRef Columns As Integer (4)
# ByRef Rows As Integer (4)
# ByRef Layers As Integer (4)
# Constant
$nbytes_layer = [int64]44+$ncol*$nrow*$word;
$nbytes_tstep = [int64]$nbytes_layer*$nlayer;

# Element offset in bytes
$elems = Get-ElementOffset -c $cellids | %{$_*$word}

$heads = @()
$fs = $fs = New-Object system.io.filestream `
	$headfile, ([io.filemode]::Open), ([io.fileaccess]::Read), ([io.fileshare]::none)
foreach ($t in $tsteps) {
	foreach ($l in $layers) {
		$offset = $nbytes_tstep*($t-1)+$nbytes_layer*($l-1)
		$status = $fs.Seek($offset,([io.seekorigin]::begin))
		$rec = New-Object "byte[]" $nbytes_layer
		$status = $fs.Read($rec,0,$nbytes_layer)
		$h = @{TimeStep=$t; Layer=$l;
			Head=0..($cellids.length-1) |%{[BitConverter]::ToSingle($rec,$elems[$_]+44)}
			}
		$heads += $h	
	}
}
$fs.Close()
return $heads
# SIG # Begin signature block
# MIIEMwYJKoZIhvcNAQcCoIIEJDCCBCACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUe1l1M+wM/4xJ9m/F1ZpC84bT
# iE+gggI9MIICOTCCAaagAwIBAgIQneyHtpANWpFM1yC5Th85XDAJBgUrDgMCHQUA
# MCwxKjAoBgNVBAMTIVBvd2VyU2hlbGwgTG9jYWwgQ2VydGlmaWNhdGUgUm9vdDAe
# Fw0wNjExMDYxNTMwNTdaFw0zOTEyMzEyMzU5NTlaMBoxGDAWBgNVBAMTD1Bvd2Vy
# U2hlbGwgVXNlcjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAn5A80nYikrDl
# YFtsz8iC4MQGRjLcoOEIzQxJXw+372LujFOZ1zifsMnS4Ej1PJ5ZRqpojiPmftwm
# p0hB8n3prD8tIjx6OFlvsu97hzZ12Cq2tmiwe6VjS1aIO5C6t4lqmqYhLJxesoB0
# hYW19gpqcxpe7QLYdCERaG1TBCRQtR8CAwEAAaN2MHQwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwXQYDVR0BBFYwVIAQ/IRrJveJZN6ltxrSLbSpXaEuMCwxKjAoBgNVBAMT
# IVBvd2VyU2hlbGwgTG9jYWwgQ2VydGlmaWNhdGUgUm9vdIIQ29T79tpxwapC2pno
# ZytZ6jAJBgUrDgMCHQUAA4GBAF3aqOk39swe5q+2wZL5ZI+pWk1a4TKAxRBFQKUs
# BeROaRrfQyUThGi290VfVFbge0PIWVPwqqbDreXcbhgBLWpI6eGzQJPYueiQ0I3A
# Hun4VR4XH7G1SXLUaXxvUVt1fC0s0biSHZgHlCC85/BdyU9HFZI0BABD2gOKjVx5
# hRDlMYIBYDCCAVwCAQEwQDAsMSowKAYDVQQDEyFQb3dlclNoZWxsIExvY2FsIENl
# cnRpZmljYXRlIFJvb3QCEJ3sh7aQDVqRTNcguU4fOVwwCQYFKw4DAhoFAKB4MBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYE
# FHq/YzpLsHuFt/+H6yyFBKhO+/2WMA0GCSqGSIb3DQEBAQUABIGAOSGcHUrUa7uY
# +fjHE1aiYu1EtGTUMuRW1+K+WbE9HmDDWlBr7g9W6g+iSpZf4VmbL4tgrcUVh0xX
# 7oERL3oYnmaHadoBGH0Pi3cS+GVfgMZyWPLFtTg5fg10VtsBGz4Yuk61Pea9vkQV
# 2KxCdc7lL+t2g9MP4hgPo+FHEqRzMOc=
# SIG # End signature block
