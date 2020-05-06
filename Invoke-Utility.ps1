param(
    [Parameter(Mandatory=$True,Position=1)]
    [ValidateSet('StartBeoPEST', 'RestartVgrids', 'RestartSlaves', 'KillIHMProcess', 'LogoffRDs', 
                 'CreateStartupShortcut','RemoveStartupShortcut', 
                 'RemoveStatiscsFiles', 'MinimizeWindows',
                 'PostprocessingIHM','TerminateBeoSlaves','FindIncomplete')]
    [string]$Prog = 'MinimizeWindows',
    
    [Parameter()]
    $VgridIDs=1..82,
    
    [Parameter()]
    $InstanceIDs=1..6,
    
    [Parameter()]
    $runname='bp_test',
    
    [Parameter()]
    $Options=''
)

function Find-ChildProcess {
	param($p)
	if ($p -eq $null) { return }
	$id = $p.ProcessID
	$result = Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$id" -ComputerName $p.PSComputerName
	if ($result -eq $null) { return }
	$result
	$result |Where-Object { $_ -ne $null } |%{ Find-ChildProcess $_  }
}

$d_script = 'F:\VGRIDS\beopest'
$options = $options -replace "`r`n",''

Switch ($Prog) {


'StartBeoPEST' {
# StartBeoPEST
$vid = '@('+([string]$VgridIDs).replace(' ',',')+')'
$inid = '@('+([string]$InstanceIDs).replace(' ',',')+')'
Invoke-Expression -Command "$d_script\Start-Beopest.ps1 -vid $vid -inid $inid -runname $runname $options"
}


'RestartVgrids' {
# Restart all vgrid computers
$VgridIDs | %{Restart-Computer -ComputerName $_.ToString('vgrid00') -Force -AsJob}
}


'RestartSlaves' {
# Restart slaves
& $d_script\Start-Slaves -vid $VgridIDs -inid $InstanceIDs -r $runname
}


'KillIHMProcess' {
# Kill IHM process tree
$currents = $InstanceIDs |%{$_.ToString('Current0')}
$proc_im = $VgridIDs |
	%{ Get-WmiObject win32_process `
		-com $_.ToString('vgrid00') -filt "Name='powershell.exe' and CommandLine like '%Invoke-Model%'" } |
			?{$_ -ne $null} |?{($_.Path -imatch '.+(Current\d+).+') -and ($matches[1] -icontains $currents)}
$procs = Find-ChildProcess $proc_im 
@($proc_im,$procs) |%{$_} |?{$_ -ne $null} |%{$_.Terminate()}
}


'TerminateBeoSlaves' {
Write-Host "Only worked inside slave's rdp window!"
$currents = $InstanceIDs |%{$_.ToString('Current0')}
$VgridIDs |
	%{Invoke-Command -ComputerName $_.ToString('vgrid00') -ScriptBlock {
		$temp = Get-Process -name beopest64 -ErrorAction SilentlyContinue
        if ($temp) {
            $temp|
		        ?{($_.StartInfo.EnvironmentVariables.Item('WorkingDirectory') -imatch '.+(current\d)') 
			    -and ($matches[1] -icontains $currents)} |
		        %{$_.kill()}
            }
		}
	}
& $PSCommandPath -Prog KillIHMProcess -VgridIDs $VgridIDs -InstanceIDs $InstanceIDs
}


'LogoffRDs' {
# Log-off from RDP
& $PSCommandPath -Prog TerminateBeoSlaves -VgridIDs $VgridIDs -InstanceIDs $InstanceIDs
$VgridIDs |%{$_;
    Invoke-Command -ComputerName $_.ToString('vgrid00') -ScriptBlock {
        $tss = ((quser | ? { $_ -imatch $env:USERNAME }) -split ' +')[2]
        if ($tss) { logoff $tss }
	    } -AsJob
	}
}


'CreateStartupShortcut' {
# Create Startup Shortcut
#$f = "$PSScriptRoot\Activate-Slaves.ps1 @(1..7) '$runname' 'kuhntucker1'"
$j = @()
$VgridIDs |%{
    $j += Invoke-Command -ComputerName "$($_.ToString('vgrid00')).vgrid.net" -ScriptBlock {
        param($cmd,$create_shortcut)
        $f_startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup" |
			Join-Path -ChildPath "powershell.lnk"
        if (Test-Path -PathType Leaf -Path "$f_startup") {
            Remove-Item -Force -Path "$f_startup"
        }
    
        if ($create_shortcut) {
            $Wsh = New-Object -comObject WScript.Shell
			$sc = $Wsh.CreateShortcut($f_startup)
			$sc.TargetPath = Join-Path $PSHOME 'powershell.exe'
			$sc.Arguments = "-NoExit -Command ""`$procs=.\Activate-Slaves.ps1 $p_args; $title;`$procs"""
			$sc.WorkingDirectory = 'C:\IHM'
			$sc.Save()
        }
    } -ArgumentList $f,$true -AsJob -Authentication Credssp -Credential $global:cred
}
return $j
}


'RemoveStartupShortcut' {
# Remove Startup Shortcut
$j = @()
$VgridIDs |%{
    $j += Invoke-Command -ComputerName $_.ToString('vgrid00') -ScriptBlock {
        $f_startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup" |
			Join-Path -ChildPath "powershell.lnk"
        if (Test-Path -PathType Leaf -Path "$f_startup") {
            Remove-Item -Force -Path "$f_startup"
        }
    } -AsJob
}
}


'RemoveStatiscsFiles' {
# Remove run statistics collector files
$VgridIDs |%{
    $v = $_.ToString('vgrid00');
    $temp = Get-ChildItem "\\$v\C$\IHM\*.stats"
    if ($temp.Count -gt 0) {
        Remove-Item -Path $temp
    }}
}

'MinimizeWindows' {
# Minimize HSPF window
$VgridIDs | %{
    if ($_ -eq 0) { $v = "."}
    elseif ($_ -lt 0) {$v = abs($_).ToString('kuhntucker0')}
    else {$_.ToString('vgrid00')}
    Invoke-Command -ComputerName $v -ScriptBlock {
        param($ProcNames)
        $temp = Get-Process -Name $ProcNames;
$Win32ShowWindowAsync = Add-Type –memberDefinition @” 
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); 
“@ -name “Win32ShowWindowAsync” -namespace Win32Functions –passThru  
        foreach ($i in $temp) {
            $Win32ShowWindowAsync::ShowWindowAsync($i.MainWindowHandle,11) | Out-Null
        }
    } -ArgumentList $ProcNames }
}

<#
function Minimize-Wondows {
param(
    [Parameter()]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $State = 'FORCEMINIMIZE',
    
    [Parameter()]
    $ProcName = @('HSPFEngine','powershell')
)
    $WindowStates = @{
        'FORCEMINIMIZE'   = 11
        'HIDE'            = 0
        'MAXIMIZE'        = 3
        'MINIMIZE'        = 6
        'RESTORE'         = 9
        'SHOW'            = 5
        'SHOWDEFAULT'     = 10
        'SHOWMAXIMIZED'   = 3
        'SHOWMINIMIZED'   = 2
        'SHOWMINNOACTIVE' = 7
        'SHOWNA'          = 8
        'SHOWNOACTIVATE'  = 4
        'SHOWNORMAL'      = 1
    }
$Win32ShowWindowAsync = Add-Type –memberDefinition @” 
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); 
“@ -name “Win32ShowWindowAsync” -namespace Win32Functions –passThru  

    Get-Process -Name $ProcName |
    %{$Win32ShowWindowAsync::ShowWindowAsync($_.MainWindowHandle,$WindowStates[$State])} |Out-Null
}
Minimize-Wondows -State FORCEMINIMIZE -ProcName "mstsc"

#>


'PostprocessingIHM' {
# Post processing IHM output on vgrid
& $PSCommandPath -Prog ListVgridSuccessRuns -IHMScenario $ihm_sc -VgridIDs $VgridIDs
$j = $global:d_success |?{$_ -imatch '(vgrid\d\d)'} |%{
    $v = $Matches[1];
    Invoke-Command -ComputerName "$v.vgrid.net" -ScriptBlock {
    param($d)
    Set-Location $d
    # check if preprocessing has already done on this instance
    $d_inout = ((Get-Content (Join-Path $pwd 'param.txt'))[1] -ireplace 'F:','\\vgridfs\f_drive').split('|')
    $d_real = $d_inout[2]
    $ihm_sc = Split-Path (Split-Path $d_real) -Leaf
    $f_log = "$d_real\$ihm_sc*.log"
    if (!(Test-Path $f_log -PathType Leaf) -or ((Test-Path $f_log -PathType Leaf) -and 
        ((gc -Tail 1 $f_log) -inotlike '*Simulation completed successfully*'))) {
        if (Test-Path "$d\model.err" -PathType Leaf) { Remove-Item "$d\model.err" }
        Copy-Item param.txt param.rdy
        Invoke-Expression "\\vgridfs\f_drive\MonteCarlo\$ihm_sc\Invoke-Model.ps1 -no_ihm"
    }} -ArgumentList $_ -AsJob -Authentication Credssp -Credential $global:cred }
return $j
}

'FindIncomplete' {
$temp = Import-Csv "F:\IHM\BEOPEST\$runname\$runname.rmr" -Delimiter ' ' `
    -Header @('v1','v2','v3','v4','v5','v6','v7','v8','v9','v10','v11','v12','v13','v14','v15','v16','v17')
$global:node = @{}
$temp |select -Property v9,v15,v16 |
    %{if ('directory' -contains $_.v15 -and $_.v16 -match '(.+)\\C\:(.+)\.') {
        $node[$_.v9]='\\'+$matches[1]+'C$'+$matches[2]
    }}
$global:run = @{}
$temp |select -Property v9,v10,v13 |
    %{if ('commencing' -contains $_.v10) { $run[$_.v9]=[int]$_.v13 }}

$global:comp = @{}
$temp |select -Property v9,v10,v13 |
    %{if ('completed' -contains $_.v10) {
        $comp[$_.v9]=$node[([int]$_.v13).ToString('0')]
        $last_comp = $comp[$_.v9]
    }}

$global:fail = @{}
$temp |select -Property v9,v12,v17 |
    %{if ('failure' -contains $_.v9) {
        $fail[$_.v17]=$node[([int]$_.v12.Replace(';','')).ToString('0')]
    }}

$rtnval = @{}
$run.Keys |?{$comp.$_-eq $null} |
    %{ $rtnval[$_] = $node[[string]$run.$_] }
#    %{'{0} {1}' -f $_,$node[[string]$run.$_]}
$rtnval
}

} # end of switch


