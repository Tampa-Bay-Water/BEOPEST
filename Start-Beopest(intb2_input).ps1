param(
    [int[]]$vid = @(1..33),
    [int[]]$inid = @(1..16),
    [string]$runname = "bp_015",
    [string]$d_current0 = (Join-Path $pwd 'Current0_IHMv4_20191120'),
    [string]$user = "mdce_wanakule",
    [string]$wdm = 'bayesrain_ret.wdm', # 'gagedrain_ret.wdm' or 'bayesrain_ret.wdm'
    [int]$wtcolno = 1,
    [string]$sim_sdate = '1/1/1996',
    [string]$sim_edate = '12/31/1997',
    [string]$arc_sdate = '', # if need to skip first year to minimize hotstart effects
    [string]$arc_edate = '',
    [switch]$no_pst,
    [switch]$no_tpl,
    [switch]$no_push,
    [switch]$update,
    [switch]$no_slaves,
    [switch]$loadDB,
    [switch]$no_postprocessing,
    [string]$compare_hydrograph = ''
)
trap { break }

function Find-ChildProcess {
    param($p)
    if ($p -eq $null) { return }
    $id = $p.ProcessID
    if ($null -eq $srv) {$srv = '.'}
    $result = Get-WmiObject -Class Win32_Process -Filter "ParentProcessID=$id" -ComputerName $p.PSComputerName
    if ($null -eq $result) { return }
    $result
    $result |Where-Object { $_ -ne $null } | % { Find-ChildProcess $_  }
}

function Pause ($Message = "Press any key to continue...") {
    Write-Host -NoNewLine $Message
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

$start_time = Get-Date

# run this script from scenario root
$d_root = 'F:\IHM\BEOPEST';
$d_scenario = Join-Path $d_root $runname
$d_script = $PSScriptRoot;
if (-not (Test-Path $d_scenario -PathType Container)) {
    New-Item $d_root -Name $runname -ItemType directory
}

# set directory to scenario directory
if ($pwd.Path -ne $d_scenario) {
    Set-Location $d_scenario
}


# if need change permission
$d_mdf = Join-Path $d_current0 INTB2_input*.*df
$acl_objs = Get-Acl -Path $d_mdf
$ar = New-Object  system.security.accesscontrol.filesystemaccessrule("Domain Users","FullControl","Allow")
foreach ($o in $acl_objs) {
    $o.SetAccessRule($ar)
    Set-Acl $o.Path $o
}
# Get-Acl -Path $d_mdf |fl


# change simulation start and end dates in access database
if (-not $no_pst) {
    Write-Host "Start-Beopest: Changing simulation dates in database ..." -fore Yellow
    if ($arc_sdate -eq '') { $arc_sdate = $sim_sdate }
    if ($arc_edate -eq '') { $arc_edate = $sim_edate }
    &"$d_root\Set-INTBdate.ps1" $sim_sdate $sim_edate $arc_sdate $arc_edate `
    (Join-Path $d_current0 'INTB2_input.mdf')
}

$f_matlab = Join-Path (Join-Path $env:matlabroot 'bin') 'matlab.exe'

# Clearnup Current0
Remove-Item (@("*.tp?", "*.dt?", "*.i0?", "*.pst")| % {Join-Path $d_current0 $_}) -force 

# copy these files for record keeping
Copy-Item (Join-Path $d_root Invoke-Model.ps1) . -Force -Verbose
Copy-Item (Join-Path (Join-Path $d_root 'PEST_ET') 'clsETSummary_Bounds.ps1') . -Force -Verbose
Copy-Item (Join-Path (Join-Path $d_root 'New_PotSurfaceTarget') Measure-UFASPOT.ps1) . -Force -Verbose
Copy-Item (Join-Path $d_root 'ModflowZonations_11122019.xlsx') . -Force -Verbose
Copy-Item (Join-Path $d_root 'parameters_3.xls') . -Force -Verbose
Copy-Item Invoke-Model.ps1 $d_current0 -Force -Verbose # update script to run INTB and postprocessing output
Copy-Item clsETSummary_Bounds.ps1 $d_current0 -Force -Verbose # update script to run INTB-ET and postprocessing output
Copy-Item Measure-UFASPOT.ps1 $d_current0 -Force -Verbose # script to post processing POT SURFACE data

# Set rainfall wdm
Copy-Item (Join-Path $d_root $wdm) `
(Join-Path (Join-Path $d_current0 'HSPF') 'rain_ret.wdm') -Force -Verbose -ErrorAction Stop

# Update INTB_output database
Copy-Item (Join-Path $d_root 'INTB_output*.*df') $d_current0 -Verbose -ErrorAction Stop
<#
# if need change permission
$acl_objs = Get-Acl -Path .\INTB_output*.*df
$ar = New-Object  system.security.accesscontrol.filesystemaccessrule("Domain Users","FullControl","Allow")
foreach ($o in $acl_objs) {
    $o.SetAccessRule($ar)
    Set-Acl $o.Path $o
}
Get-Acl -Path .\INTB_output*.*df |fl
#>

### create pest control file .pst
if (-not $no_pst) {
    $f_pst = Join-Path $d_current0 "$runname`.pst"
    if (Test-Path $f_pst -PathType Leaf) { Remove-Item (Join-Path $d_current0 '*.pst') -Force }
    $f_int = Join-Path $d_current0 "$runname`.i01"
    if (Test-Path $f_int -PathType Leaf) { Remove-Item (Join-Path $d_current0 '*.i*') -Force }
    Write-Host "Start-Beopest: Creating PEST .pst and instruction files ..." -fore Yellow
	
    # override log transform on HSPF factor parameters
    #$ml_cmd = "-r ""cd $PSScriptRoot; create_pst('','$runname',$wtcolno,false); exit;""" 
	
    # use log transformation on HSPF factor parameters
    $ml_cmd = "-r ""cd $PSScriptRoot;create_pst('$d_current0','$runname',$wtcolno); exit;"" -automation"
    $p_pst = [Diagnostics.Process]::Start($f_matlab, $ml_cmd)
    Sleep -Seconds 5
    $p_pst = Get-Process -Id (gwmi win32_process -Filter "ParentProcessID=$($p_pst.Id)").ProcessID
}

### create pest template files
if (-not $no_tpl) {
    $f_tpl = Join-Path $d_current0 "$runname`.tp1"
    if (Test-Path $f_tpl -PathType Leaf) { Remove-Item (Join-Path $d_current0 '*.tp?') -Force }
    $f_dt1 = Join-Path $d_current0 "$runname`.dt1"
    if (Test-Path $f_dt1 -PathType Leaf) { Remove-Item (Join-Path $d_current0 '*.dt?') -Force }
    Write-Host "Start-Beopest: Creating PEST template files ..." -fore Yellow
    $f_mfzone = Join-Path $d_scenario 'ModflowZonations_11122019.xlsx'
    $ml_cmd = "-r ""cd $d_script;extract_gwpar('$f_mfzone','$runname'); exit;"" -automation"
    $p_mlab = [Diagnostics.Process]::Start($f_matlab, $ml_cmd)
    Sleep -Seconds 5
    $p_mlab = Get-Process -Id (gwmi win32_process -Filter "ParentProcessID=$($p_mlab.Id)").ProcessID
    Copy-Item "..\ihm_ctl_template.tp5" ".\$runname.tp5" -force -verbose
    Copy-Item "$d_current0\ihm.ctl" ".\$runname.dt5" -force -verbose #-------check on this
}

### cleanup slaves, detach all .mdf files from slave machines 
# $r_status = &$d_script\Clean-LocalDB -vid $vid

### create parallel pest management file .rmf
Write-Host "Start-Beopest: Creating PEST .rmf file ..." -fore Yellow
$nyear = [int]((New-TimeSpan -End $sim_edate -Start $sim_sdate).TotalDays / 365.25)
&(Join-Path $PSScriptRoot Create-RMF.ps1) -v $vid -i $inid -r $runname -n $nyear

### copy necessary pest files
Write-Host "Start-Beopest: Wait for writing process to finish ..." -fore Yellow
if (-not $no_tpl) { $p_mlab.WaitForExit() }
if (-not $no_pst) { $p_pst.WaitForExit() }
Start-Sleep -sec 1
Copy-Item "$runname.tp?", "$runname.dt?", "$runname.i??", "$runname.pst" $d_current0 -force

$elapsed_time = New-TimeSpan -End (Get-Date) -Start $start_time
Write-Host "`nStart-Beopest: Time since start = $($elapsed_time.TotalMinutes) minutes." -fore Green

### Push master across instances
if (-not $no_push) {
    $r_status = &$d_script\Push-Current0 -src $d_current0 -vid $vid -inid $inid
}
elseif ($update) {
    Write-Host "Start-Beopest: Updating $runname.`* ..." -fore Yellow
    $vid |%{ $v = $_.ToString('vgrid00'); $inid |%{ $c = $_.ToString('Current0')
        Copy-Item "$runname.tp?", "$runname.dt?", "$runname.i??", "$runname.pst" \\$v\C\IHM\$c -Force
        Copy-Item "$d_current0\*.ps1"  \\$v\C\IHM\$c -Force
        #Copy-Item "$d_current0\*.csv"  \\$v\C\IHM\$c -Force
        #Copy-Item "$d_current0\*.xml"  \\$v\C\IHM\$c -Force
        Copy-Item (Join-Path (Join-Path $d_current0 'HSPF') 'rain_ret.wdm') `
            \\$v\C\IHM\$c\HSPF -Force
    }}
}
# remove old stats file, if exists
$vid |%{
    $v = $_.ToString('vgrid00')
    Remove-Item "\\$v\c$\IHM\Current*\$runname.stats" -ErrorAction SilentlyContinue
}

$elapsed_time = New-TimeSpan -End (Get-Date) -Start $start_time
Write-Host "`nStart-Beopest: Time since start = $($elapsed_time.TotalMinutes) minutes." -fore Green

# DON'T DO CLEAN UP - CALLING Push-Current0.ps1 LATER WILL MISS THESE FILES 
# Remove-Item (Join-Path $d_current0 Invoke-Model.ps1) -force -verbose
# Remove-Item (Join-Path $d_current0 Measure-UFASPOT.ps1) -force -verbose
# Remove-Item (Join-Path $d_current0 PSPointsForPEST.xls) -force -verbose

### Start PEST first and specify port
$f_exe = Join-Path 'C:\PEST' -ChildPath beopest64.exe -Resolve
$p_arg = "$runname /H :4004"
Write-Host "Start-Beopest: Starting beopest ..." -fore Yellow
Write-Host "$f_exe $p_arg"

$pinfo = New-Object System.Diagnostics.ProcessStartInfo($f_exe, $p_arg)
$pinfo.WorkingDirectory = $d_scenario 
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$p = [Diagnostics.Process]::Start($pinfo)

### Start BEOPEST-SLAVE on available vgrid machines
if (-not $no_slaves) {
    Write-Host "Start-Beopest: Starting slaves ..." -fore Yellow
    &$d_script\Start-Slaves -vid $vid -inid $inid -r $runname
}

do {
    $p.StandardOutput.ReadToEnd() |Write-Host
    $p.StandardError.ReadToEnd() |Write-Host
    Sleep -Seconds 5
} until ($p.HasExited)
if ($p.ExitCode -lt 0) {
    "Exit Code: $('{1} (HResult:0x{0:x})' -f $p.ExitCode,$p.ExitCode)" |
        Write-Error -Category OperationStopped `
        -ErrorId $p.ExitCode -TargetObject 'IHM.clsScenario().Run' `
        -CategoryTargetName 'Invoke-Model.ps1' -CategoryReason 'Fatal Error' `
        -CategoryTargetType 'Powershell Script' -CategoryActivity 'Running IHM'
    exit $p.ExitCode
}
#>
### Stop IHM and kill slaves
Write-Host "Start-Beopest: Trying to shutdown IHM ..." -fore Yellow
$proc_im = $vid |
    % { Get-WmiObject win32_process `
        -com $_.ToString('vgrid00') -filt "Name='powershell.exe' and CommandLine like '%Invoke-Model%'" }
$procs = Find-ChildProcess $proc_im
@($proc_im, $procs) | % {$_} |select ProcessID, ParentProcessID, Name, CommandLine
@($procs, $proc_im) | % {if ($_ -ne $null) {$_.Terminate(0)}}

#### Stop beopest/slaves
Write-Host "Start-Beopest: Trying to shutdown beopest/slaves ..." -fore Yellow
$proc_beopest = $vid |
    % { Get-WmiObject win32_process `
        -com $_.ToString('vgrid00') -filt "Name='beopest64.exe'" |
        ? {$_ -ne $null} | % {$_.Terminate(0)} }

@("$runname.tp?", "$runname.dt?", "$runname.i??", "$runname.pst") |
    % {Remove-Item (Join-Path $d_current0 $_) -force -verbose}
     
#### Check for BeoPEST Error in .rmr file
$temp = gc -tail 500 "$runname.rmr"
if (($temp |? {$_ -imatch '.+error.+'}) -ne $null) {
    Write-Error -Message "Start-Beopest: Found error in PEST rmr file ..."
    $lineno = 1..500 |? {$temp[$_ - 1] -imatch '.+error.+'}
    $temp[($lineno[0] - 2)..($lineno[$lineno.length - 1])]
    return
}

#### copy stats files
Write-Host "Start-Beopest: Copying run statistics to stats.xml ..." -fore Yellow
$vid |%{
    $v = $_.ToString('vgrid00')
    $inid |%{
        $c = $_.ToString('Current0')
        gc "\\$v\c$\IHM\$c\$runname.stats"
    }
} |
ConvertFrom-Csv -Header @('cname','pwd','name','starttime','proctime','clocktime','vm','pm','ws') |
Export-Clixml '.\stats.xml' -Force -ErrorAction SilentlyContinue
if (Test-Path '.\stats.xml' -PathType Leaf) {
    Import-Clixml '.\stats.xml' |?{$_.name -eq 'powershell' -and $_.pwd -ieq 'c:\ihm\current1'} |
        select cname,pwd,starttime,clocktime,pm |ft -AutoSize
}

$elapsed_time = New-TimeSpan -End (Get-Date) -Start $start_time
Write-Host "`nStart-Beopest: Time since start = $($elapsed_time.TotalHours) hours." -fore Green

# ### Restart MATLAB DistComp
# Write-Host "Start-Beopest: Reviving MDCE ..." -fore Yellow
# & $d_script\..\distcomp\Start-MDCE.ps1 -v @(2) -w @(2) -j 2
# & $d_script\..\distcomp\Start-MDCE.ps1 -v @(1..32) -w @(2) -j 2

cd ..
### Copy the last currentX folder
Write-Host "Start-Beopest: Making a copy of the last run instance folder ..." -fore Yellow
$temp = Import-Csv (Join-Path $runname "\$runname.rmr") -Delimiter ' ' `
    -Header @('v1', 'v2', 'v3', 'v4', 'v5', 'v6', 'v7', 'v8', 'v9', 'v10', 'v11', 'v12', 'v13', 'v14', 'v15', 'v16')
$node = @{}
$temp |select -Property v9, v15, v16 |
    % {if ('directory' -contains $_.v15 -and $_.v16 -match '(.+)\\C\:(.+)\.') {
        $node[$_.v9] = '\\' + $matches[1] + 'C$' + $matches[2]
    }}
$run = @{}
$temp |select -Property v9, v10, v13 |
    % {if ('commencing' -contains $_.v10) { $run[$_.v9] = [int]$_.v13 }}

$comp = @{}
$temp |select -Property v9, v10, v13 |
    % {if ('completed' -contains $_.v10) {
        $comp[$_.v9] = $node[([int]$_.v13).ToString('0')]
        $last_comp = $comp[$_.v9]
    }}

$temp = $last_comp.replace('\', '') -match '\d+.\d+.\d+.(\d+).+(Current\d+)'
# last IP offset from VGRID ID by 200
$temp = "$(([int]$matches[1]-200).ToString('VGRID00'))_$($matches[2])"
Write-Host "Start-Beopest: Copying the last run 'Current' folder to $temp ..." `
    -fore Yellow
$temp = Join-Path $PWD (Join-Path $runname $temp)
Copy-Item -Path $last_comp $temp -Container -Recurse -Force

# Create database for PEST_Run output on the last run
F:\IHM\beopest\Create-LastRunDB.ps1 $runname $temp

# Compare hydrographs with previous run
if ($compare_hydrograph -ne '') {
    Write-Host "Generating hydrographs ..." -fore Yellow
    if ($compare_hydrograph -ieq 'none' -or `
        (Test-Path (Join-Path $d_root $compare_hydrograph) -PathType Container)) {
        $ml_cmd = "-r ""cd $d_root;compare_residue_all_hg1('$runname','$compare_hydrograph'); exit;"" -automation"
        $p = [Diagnostics.Process]::Start($f_matlab, $ml_cmd)
    }
    else {
        Write-Warning "No runname '$compare_hydrograph'!"
    }
}

### Load results to database
if ($loadDB) {
    Write-Host "Start-Beopest: Spawn a process to load all PEST output to database ..." -fore Yellow
    $runid = ([int32]($runname.Split('_'))[1]).tostring('0')
    $ml_cmd = "-r ""cd $d_root; loaddbf_all_output($runid,[],$wtcolno); exit;"""
    $p_mlab = [diagnostics.process]::start($f_matlab, "$ml_cmd -automation")
    #    $p_mlab.WaitForExit()
    Write-Warning "The background process can take more than an hour to finish. `
         Check MATLAB console for progress or error!"
}

### Post processing
# if (-not $no_postprocessing) {
# 	Write-Host "Start-Beopest: Post-processing PEST results ..." -fore Yellow
# 	& $d_script\PostProcess-Pest -r $runname -d $d_scenario -sens '1:47' -corr '47'
# }

Write-Host "Start-Beopest: Finished" -fore Yellow
