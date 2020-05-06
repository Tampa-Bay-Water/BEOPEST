#--- script block to execute on remote server
param($children,[int]$n_tree=2,$remotehost)

if ($children -isnot 'object[]') {
    $children = $children -split ','
}
$cred = Import-Clixml -Path `
    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_$($env:USERNAME.Substring(0,4))_cred.xml")
#    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_mdce_cred.xml")

$r,$children = $children
$r = @($r)
$n = @(0..($n_tree-1))
do {
    $procs = @()
    $child = @()
    foreach ($c in $r) { $n |%{
        $d_dest,$children = $children
        if (!$d_dest) { continue }
        $child += $d_dest
	    Write-Host "Push-Current0: Spawning process for $v; copy $c to $d_dest" -fore Yellow
        if ($remotehost -imatch $env:COMPUTERNAME) {
	        $procs += Start-Job -ScriptBlock {
		        param($c,$d_dest)
                Copy-Item $c $d_dest -Recurse -Force -Verbose
	        } -ArgumentList $c,$d_dest
        }
        else {
	        $procs += Invoke-Command -ComputerName $remotehost -ScriptBlock {
		        param($c,$d_dest)
                Copy-Item $c $d_dest -Recurse -Force
	        } -ArgumentList $c,$d_dest -Credential $cred -Authentication Credssp -AsJob
        }
    }}
    Write-Host "Push-Current0: Wait for copying process to complete ..." -fore Yellow
    if ($procs) { Wait-Job $procs |Out-Null }

    $r = @($r+$child)
} until (!$children)
#---
