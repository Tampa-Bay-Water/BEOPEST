param(
	[string]$headfile=$(throw "headfile must be specified"),
	[string]$potfile=$(throw "potfile must be specified")
	)

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

function Read-MFHeads {
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
}

function Import-Excel {
	param(
		[string]$f_xls=$(throw "Excel filename must be specified"),
		[string]$sheet='Sheet1',
		[string]$range=''
		)
	trap { break }
	$xls = New-Object -com "ADODB.Connection"
	$strConnection = 'DRIVER={Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)};'
	$strConnection += "ReadOnly=1;HDR=Yes;DBQ=$f_xls;"
	#$strConnection += "DefaultDir=$d_xls;"
	$xls.Open($strConnection)
	
	$rs = New-Object -com "ADODB.recordset"
	$rs=$xls.Execute("SELECT * FROM [$sheet`$$range]")
	$temp_data = $rs.GetRows()
	$fields = $rs.fields | %{$_.Name}
	
	$rs.Close()
	$xls.Close()
	
	# $data = @{}
	$data = New-Object 'Object'
	foreach ($i in $temp_data.GetLowerBound(0)..$temp_data.GetUpperBound(0)) {
	# 	$data[$fields[$i]] = $temp_data.GetLowerBound(1)..$temp_data.GetUpperBound(1) | 
	# 		%{$temp_data[$i,$_]}
		Add-Member NoteProperty -in $data -Name $fields[$i] `
			-Value ($temp_data.GetLowerBound(1)..$temp_data.GetUpperBound(1) |
				%{$temp_data[$i,$_]})
	}
	return $data
}

# $pot_list = Import-Csv $potfile |Group-Object -prop StressPeriod
# $tsteps = $pot_list | %{[int]$_.name}
# $layers = @(3)
# $arr_cellid = @{}
# $arr_head = @{}
# $arr_stdev = @{}
# $host.EnterNestedPrompt()
# $pot_list | ForEach-Object {
# 	# time step loop
# 	$arr_cellid[$_.name] = $_.group | %{$_.CellID}
# 	$arr_head[$_.name] = $_.group | %{$_.ObsHead}
# 	$arr_stdev[$_.name] = $_.group | %{$_.Std}
# }
# 
# $head_resid = @()
# foreach ($t in $tsteps) {
# 	$tstr = $t.ToString()
# 	$cellids = $arr_cellid[$tstr]
# 	$sim_head = (F:\VGRIDS\ppest\Read-MFHeads `
# 		-head $headfile -t $t -l $layers -c $cellids).Head
# 	$pot_head = $arr_head[$tstr]
# 	$resid = @{
# 		TimeStep=$t;
# 		CellID=0..($cellids.length-1) |
# 			where {$pot_head[$_].length -gt 0} | %{ $cellids[$_] }; #old spreadsheet has blank head
# 		Residual=0..($sim_head.length-1) |
# 			where {$pot_head[$_].length -gt 0} |
# 			%{ ($sim_head[$_]-[single]$pot_head[$_])/$arr_stdev[$tstr][$_] }
# 		}
# 	$head_resid += $resid
# }
# return $head_resid

###
#$host.EnterNestedPrompt()
###
$pot_list = &Import-Excel -f $potfile -s data
$tsteps = $pot_list.StressPeriod |Sort-Object -Unique 
$layers = @(3)
$head_resid = @()
foreach ($t in $tsteps) {
	$tstr = $t.ToString()
	$tlist = $pot_list.StressPeriod
	$cellids = 0..($tlist.length-1) |
		where {$tlist[$_] -eq $t} | %{$pot_list.CellID[$_]}
	$pot_head = 0..($tlist.length-1) |
		where {$tlist[$_] -eq $t} | %{$pot_list.ObsHead[$_]}
	$pot_std = 0..($tlist.length-1) |
		where {$tlist[$_] -eq $t} | %{$pot_list.Std[$_]}
	$pot_wid = 0..($tlist.length-1) |
		where {$tlist[$_] -eq $t} | %{$pot_list.PSWellID[$_]}
	$flags = 0..($tlist.length-1) |
		where {$tlist[$_] -eq $t} | %{$pot_list.UseForPEST[$_]}
	$sim_head = (&Read-MFHeads `
		-head $headfile -t @($t) -l $layers -c $cellids).Head
	$resid = @{
		TimeStep=$t; PSWellID=$pot_wid; CellID=$cellids; Flag=$flags;
		Residual=0..($sim_head.length-1) |
			%{ ($sim_head[$_]-[single]$pot_head[$_])/$pot_std[$_] }
		}
	$head_resid += $resid
}
return $head_resid
# SIG # Begin signature block
# MIIEMwYJKoZIhvcNAQcCoIIEJDCCBCACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUuj/3Yx+pyDdEFAMlKJM92mUC
# 3c+gggI9MIICOTCCAaagAwIBAgIQneyHtpANWpFM1yC5Th85XDAJBgUrDgMCHQUA
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
# FJ0Lz8yLEdjVVrnHi4CLz3z8Kba4MA0GCSqGSIb3DQEBAQUABIGARiWGNUyhsKzM
# FOsE9pTM16nSBJfOeB140NlvyjAzoQQ9dWcL8BycQbxWR8j2Bjnt91RQOyczAr7p
# 75v2WwTgUJxozF2PkJcDivx17yb7v5s1OAzAL6rWbUrqbsd8NM5sJfmH/TQnsX4F
# h+mQpTqRny+OaCKDnx0xh+zZ6E9VDE4=
# SIG # End signature block
