param(
	[int[]]$vid=@(1..14+16..37)
	)
trap { break }

# function kill_ihm_tree {
#   param([string]$server)
#   $pids = gwmi win32_process -com $server
#   $ihm_pid = $pids |where {$_.name -eq 'ihm.exe'}
#   $del_procs = @();
#   foreach ($i in $ihm_pid) {
#     foreach ($p in $pids) {
#       if ($p.parentprocessid -eq $i.processid) {
#       	$del_procs = $del_procs + $p
#       }
#     }
#     foreach ($p in $pids) {
#       if ($i.parentprocessid -eq $p.processid) {
#       	$del_procs = $del_procs + $p
#       }
#     }
#   }
#   foreach ($p in $ihm_pid) {
#   $del_procs = $del_procs + $p
#   }
#   foreach ($p in $del_procs) { $r = $p.terminate(0) }
# }

$vgrids = F:\VGRIDS\Get-Vgrids -vid $vid
foreach ($s in $vgrids) {
	$proc = [diagnostics.process]::start("powershell.exe","F:\VGRIDS\ppest\Kill-IHMTree.ps1 -s $s")
}
