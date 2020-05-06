param(
	[int[]]$vid=@(1..48),
	[int[]]$inid=@(1..7),
	[string[]]$files
	)
trap { break }

if (-not $cred) {
	$cred = Get-Credential -Cred kuhntucker\wanakule
}

if (!$files) { $files = $input }

$vgrids = F:\VGRIDS\Get-Vgrids.ps1 -v $vid
foreach ($v in $vgrids) {
	foreach ($cid in $inid) {
		#if ( !(F:\VGRIDS\Is-Blade -cs $v) -and ($cid -gt 4)) { break }
		$c = $cid.ToString("Current0");
		if ( !(Test-Path \\$v\c$\IHM\$c -PathType container) ) { continue }
		foreach ($f in $files) {
			Copy-Item $f \\$v\c$\IHM\$c -recurse -force -verbose
		}
	}
}
