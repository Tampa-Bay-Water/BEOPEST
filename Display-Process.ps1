# .\Display-Process -u wanakule 
param(
	[int[]]$vid=1..14+16..32,
	[string[]]$procnames=@('ihm.exe'),
	[int]$interval=1800,
	[double]$etime=2.5, # dump elapsed time in hours
	[double]$ttime, # max time (hours) to terminate
	[string]$user
)
trap { break }

# Get children of a process
function Get-ChildProcess {
	param($pproc)
	$local:procs = @()
	if ($pproc) { # need to check process object
		$local:procs = Get-WmiObject win32_process -com $pproc.csname `
			| where { $_.ParentProcessID -eq $pproc.ProcessID }
	}
	return $local:procs
}


$wmiclass = [wmiclass]"win32_processstartup"
# if (-not $cred) { $cred = Get-Credential -cred kuhntucker\$user } 
$cred = Get-Credential -cred "$env:USERDOMAIN\$env:USERNAME"
$vgrids = F:\VGRIDS\Get-Vgrids.ps1 -v $vid
while ($true) {
	clear-host
	Get-Date |Out-Host
	$procs = @();
	foreach ($pn in $procnames) {
		$procs = $procs + (Get-WmiObject win32_process -com $vgrids -filt "name='$pn'" -cred $cred)
	}
	if ($procs) {
		$procs |
			Format-Table -auto -group csname `
				@{label='Instance';expression={$dum=$_.executablepath -match 'Current[1-9]'; $matches[0]}},
				@{label='SID';expression={$_.SessionID}},
				@{label='ProcID';expression={$_.processid}},
				@{label='PProcID';expression={$_.parentprocessid}},
				@{label='CreationDate';expression={$wmiclass.ConvertToDateTime($_.CreationDate)}},
				@{label='ElaspedHour';
					expression={'{0,9:f3}' -f ([DateTime]::now-$wmiclass.ConvertToDateTime($_.CreationDate)).TotalHours}},
				@{label='CPUMinute';
					expression={'{0,9:f3}' -f [single](([single]$_.usermodetime+[single]$_.kernelmodetime)/60/1e7)}},
				@{label='PeakVirtual';expression={[int]($_.PeakVirtualSize/1048576)}},
				@{label='PeakWorking';expression={[int]($_.PeakWorkingSetSize/1048576)}}

		# List processes with max elapsed time
		$tstr = $etime.tostring('0.0')
		Out-Host -input "`nProcesses with elapsed time > $tstr hours:"
		$temp = Sort-Object -prop CreationDate -input $procs -desc
		$temp |where {([DateTime]::now-$wmiclass.ConvertToDateTime($_.CreationDate)).TotalHours -gt $etime} |
			Format-Table -auto `
				@{label='ElaspedHour';
					expression={'{0,9:f3}' -f ([DateTime]::now-$wmiclass.ConvertToDateTime($_.CreationDate)).TotalHours}},
				ProcessID,CSName,
				@{label='Instance';expression={$dum=$_.executablepath -match 'Current[1-9]'; $matches[0]}}

		# terminate hung processes
		if ($ttime -gt $etime) {
			$tstr = $ttime.tostring('0.0')
			Out-Host -input "`nChild processes to be terminated for elapsed time > $tstr hours:"
			$kprocs = @()
			$temp = $temp |where {([DateTime]::now-$wmiclass.ConvertToDateTime($_.CreationDate)).TotalHours -gt $ttime}
			foreach ($p in $temp) {
				$k = F:\VGRIDS\Get-ProcessTree.ps1 -r $p
# 				$k = Get-ChildProcess($p)
				$kprocs = $kprocs + $k
			}
			$kprocs |
				Format-Table -auto `
					@{label='ElaspedHour';
						expression={'{0,9:f3}' -f ([DateTime]::now-$wmiclass.ConvertToDateTime($_.CreationDate)).TotalHours}},
					ProcessID,ParentProcessID,Name,CSName
			if ($kprocs) { $kprocs | %{ $_.Terminate(0) } }
		}
	}
	Start-Sleep -sec $interval
}
 
