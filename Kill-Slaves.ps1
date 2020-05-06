param([int[]]$vid=@(1..14+16..37))
trap { break }

# Get root of a process
function Get-RootProcess {
	param($proc)
	while ($true) {
		$p = $proc
		$proc = Get-WmiObject win32_process -com $p.csname -cred $cred |
			where { $_.ProcessID -eq $p.ParentProcessID }
		if (-not $proc) { break }
	}
	return $p
}

if (-not $cred) {
	$cred = Get-Credential -cred "$env:USERDOMAIN\$env:USERNAME"
}
$vgrids = F:\VGRIDS\Get-Vgrids -vid $vid
$kprocs = @()
foreach ($v in $vgrids) {
	$ps = Get-WmiObject win32_process -com $v -filt "Name='pslave.exe'" -cred $cred 
	if ($ps) {
#$host.EnterNestedPrompt()
		# The following lines are commented out since slaves parentprocess do not existed
		# due to slave.exe is spawned by actvate-slaves.ps1 not from cmd.exe
		# $root = Get-RootProcess -proc $ps[0]
		# $k = &F:\VGRIDS\Get-ProcessTree.ps1 -RootProc $root
		foreach ($k in $ps) { $kprocs = $kprocs + $k }
	}
	
	# cmd window
	$k = Get-WmiObject win32_process -com $v -cred $cred |
		where {$_.CommandLine -match '.*Activate-Slaves.*'}
	if ($k) { $kprocs = $kprocs + $k }
}

foreach ($p in $kprocs) {
	$status = $p.terminate(0)
}
#return $kprocs