 param([string]$server)
 $pids = gwmi win32_process -com $server
 $ihm_pid = $pids |where {$_.name -eq 'ihm.exe'}
 $del_procs = @();
 
 foreach ($i in $ihm_pid) {
   foreach ($p in $pids) {
     if ($p.parentprocessid -eq $i.processid) {
     	$del_procs = $del_procs + $p
     }
   }
   foreach ($p in $pids) {
     if ($i.parentprocessid -eq $p.processid) {
     	$del_procs = $del_procs + $p
     }
   }
 }
 
 foreach ($p in $ihm_pid) {
 $del_procs = $del_procs + $p
 }
 
 $r = @()
 foreach ($p in $del_procs) { $r = $r + $p.terminate(0) }
 return $r