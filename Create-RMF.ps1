param(
	[int[]]$vid=@(1..33),
	[int[]]$inid=@(1..16),
    [int]$nyear=6,
	[string]$runname='bp_009'
	)

$avg_sec = 1050
if (Test-Path .\Invoke-Model.ps1 -PathType Leaf) {
    $temp = gc .\Invoke-Model.ps1 |
        ?{$_ -match '\$avgexec_sec \= (\d+)'} |%{[int]$Matches[1]}
    if ($temp -ne $null) { $avg_sec = $temp}
}

# file signature
$file_content = @('prf')

$temp = @()
$etime = ''
foreach ($i in $vid) {
	$v = $i.ToString('vgrid00')
	$m = "$v\_00"
	$inid | %{
# $host.EnterNestedPrompt()
        $p = "\\$v\C`$\IHM\$($_.ToString('Current0'))\"
		$temp += "'$($_.ToString($m))'  $p"
		$etime += ($avg_sec*$nyear).ToString('0  ')
	}
}

# specification
$file_content += $temp.length.ToString('0') + ' 0 5 -100 1 1.5'

# list of slave and instances
$file_content += $temp

# list estimate time - one line
$file_content += $etime

Set-Content (Join-Path	$pwd ($runname+'.rmf')) -value $file_content
