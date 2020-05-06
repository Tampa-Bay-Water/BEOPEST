param(
	[string]$src=$(throw "Must specify Current0 src"),
	[int[]]$vid=@(1..82),
	[int[]]$inid=@(1..6)
	)
trap { break }

$all_vid = @(1..83);
# test if $src exist
if (-not (Test-Path $src -PathType Container)) {
	Write-Error 'Error: Specified current0 source folder not exist!'
	return
}

# convert list of instances to folder names
$script:d_instances = $inid |%{"C:\IHM\$($_.ToString('Current0'))"}

# Setup flags
[Bool[]]$done = @(); $all_vid |%{$done += $true}
$vid |%{$done[$_] = $false}
$script:procs = @()

# Delete instances
Write-Host "Push-Current0: Spawning process to delete instances" -fore Yellow

$vgrids = F:\VGRIDS\Get-Vgrids.ps1 -v $vid
$delete_job = Invoke-Command -ComputerName $vgrids -ScriptBlock {
	param ($d_instances)
    if (Test-Path $d_instances -PathType Container) {
	    Remove-Item $d_instances -Recurse -Force |Out-Null
    }
} -ArgumentList (,$d_instances) -AsJob
Write-Host "Push-Current0: Wait for deleting process to complete ..." -fore Yellow
Wait-Job $delete_job

Write-Host "Push-Current0: Check for completion of deleting" -fore Yellow
<#
$temp = ''
foreach ($v in $vgrids) {
	foreach ($d in $d_instances) {
		$d = $d -replace 'C\:\\',"\\$v\C$\"
		if (Test-Path -Path $d -PathType Any) { $temp += "$d`r" }
	}
}
if ($temp -ne '') {
	throw "Push-Current0: Error: Deleteing was incomplete on `r`n$temp"
}
#>
$temp = $vgrids |%{ $v=$_; $d_instances |%{
    $_ -ireplace 'C:',"\\$v\C$" |?{Test-Path $_ -PathType Container} }}
if ($temp -ne $null) {
    Write-Warning "Push-Current0: Warning: Deleteing CurrentX was incomplete on: `r`n$temp"
    Write-Host "Enter debug mode, type `$host.ExitNestedPrompt() to continue." -fore Yellow

    ## break to fix
    $host.EnterNestedPrompt() #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
}

# Number of tree branches
$n_tree = 2
$script:cred = Import-Clixml -Path `
    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_mdce_cred.xml")
#    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_$($env:USERNAME.Substring(0,4))_cred.xml")

################################################################################
# supporting functions
<#
function Invoke-CopyTree {
	param([string]$r,[int]$n=2)
	$d_root = "\\$r\C`$\IHM"
	foreach ($i in 1..$n) {
		$child = Get-IdleMachine
		if ($child) {
            $v = $child.ToString('vgrid00')
			Write-Host "Push-Current0: Spawning process for $v from $r" -fore Yellow
			$done[$child] = $true;
			# Copy commands
			$copy_cmd = ''
			$d_instances |
				%{$copy_cmd += 'cp '+(Split-Path $_ -Leaf)+" $_ -R -Fo -V;"}
			$proc = Invoke-Command -ComputerName $child.ToString('vgrid00\.vgrid\.net') -ScriptBlock {
				param($copy_cmd,$d_root)
				Set-Location -Path $d_root
				Invoke-Expression $copy_cmd
			} -ArgumentList $copy_cmd,$d_root -AsJob -Authentication Credssp -Credential $cred
#			Add-Member -InputObject $proc -MemberType NoteProperty `
#				-Name Root -Value $child.ToString('vgrid00')
			$global:_procs += $proc
		}
	}
    return $child
}
#>

function Invoke-CopyTree {
	param([string]$r,[int]$n=2)
	$d_root = "\\$r\C`$\IHM"
	foreach ($i in 1..$n) {
		$child = Get-IdleMachine
		if ($child) {
            $v = $child.ToString('vgrid00')
            $d_dest = "\\$v\C`$\IHM"
			Write-Host "Push-Current0: Spawning process for $v from $r" -fore Yellow
			$done[$child] = $true;
			# Copy commands
            $copy_cmd = ''
			$d_instances |
				%{$copy_cmd += "cp $d_root\$(Split-Path $_ -Leaf) . -R -Fo -V;"}
			#$copy_cmd = "cp $d_root\Current? . -Fo -R -V"
			$proc = Invoke-Command -ComputerName "$v.vgrid.net" -ScriptBlock {
				param($copy_cmd,$d_dest)
				Set-Location -Path C:\IHM
				Invoke-Expression $copy_cmd
			} -ArgumentList $copy_cmd,$d_dest -Credential $cred -Authentication Credssp -AsJob
			$global:_procs += $proc
		}
	}
    return $child
}

function Get-IdleMachine {
	$rtnval = $null
	foreach ($i in $vid) {
		if (!$done[$i]) { $rtnval = $i; break }
	}
	return $rtnval
}

################################################################################

# set first vgrid machine to copy
$root = Get-IdleMachine
if ($root) { $done[$root] = $true }
else { return }
$root_str = $root.ToString('vgrid00')

# Remove old and copy new instance folders on $root
Write-Host "Push-Current0: Creating master currentX on $root_str ..." -fore Yellow
$d_cur = "\\$root_str\c`$\ihm"
$procs = @();
foreach ($i in $d_instances) {
	$i = Split-Path $i -Leaf
	$d = "$d_cur\$i";
	Write-Host "Push-Current0: Spawning copy '$d' process ..." -fore Yellow
	#$proc = F:\VGRIDS\Start-App.ps1 -arg "cp $src -dest $d -R -Fo -V"
	$proc = Start-Job -ScriptBlock {
		param($cmd)
		Invoke-Expression $cmd
	} -ArgumentList "cp $src -dest $d -R -Fo -V"
	$procs += $proc
}
Write-Host "Push-Current0: Wait for copying process to complete ..." -fore Yellow
Wait-Job $procs
if ($vid.Length -eq 1) { return }

# Use binary tree to make copy starting from root
# Use pulling-copy instead of pushing-copy to distribute processing power to slaves
$global:_procs = @();
$child = Invoke-CopyTree -r $root_str -n $n_tree

$_roots = @()
do {
	Wait-Job $_procs
	foreach ($p in 0..($_procs.Count-1)) {
		if (!$_procs[$p]) { continue }
		$v = $_procs[$p].Location -ireplace '.vgrid.net'
		$child = Invoke-CopyTree -r $v -n $n_tree;
        if ($child) { $_roots += $_procs[$p] }
		#$_procs[$p] = $null
	}
} until (!$child)
Wait-Job $_procs

# Check for nested CurrentX folder 
# (not clean delete of CurrentX earlier due to locked .mdf)
$temp = $vgrids |?{Test-Path \\$_\c$\IHM\Current?\Current? -PathType Container}
if ($temp -ne $null) {
    Write-Warning "Push-Current0: Warning: Nested CurrentX were detected on: `r`n$temp"
    Write-Host "Enter debug mode, type `$host.ExitNestedPrompt() to continue." -fore Yellow

    ## break to fix
    $host.EnterNestedPrompt() #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
}
