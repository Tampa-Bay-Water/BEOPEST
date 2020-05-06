param(
	[int[]]$vid=@(1..8+10..12+16..42),
	[int[]]$inid=@(1..7),
	[string[]]$files=@('')
	)
trap { break }

if (-not $cred) {
	$cred = Get-Credential -Cred kuhntucker\wanakule
}

$vgrids = F:\VGRIDS\Get-Vgrids.ps1 -v $vid
foreach ($v in $vgrids) {
	foreach ($cid in $inid) {
		#if ( !(F:\VGRIDS\Is-Blade -cs $v) -and ($cid -gt 4)) { break }
		$c = $cid.ToString("Current0");
		if ( !(Test-Path \\$v\c$\IHM\$c -PathType container) ) { continue }
		if ($files[0]) {
			foreach ($f in $files) {
				Remove-Item \\$v\c$\IHM\$c\$f -recurse -verbose
			}
		}
		else {
			[diagnostics.process]::start("powershell","remove-item \\$v\c$\IHM\$c -recurse -verbose -force")
		}
	}
}
