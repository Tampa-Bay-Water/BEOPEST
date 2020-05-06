# F:\VGRIDS\beopest\Add-Slaves.ps1 
param(
    [parameter(Position = 0, Mandatory = $true)] [string]$Current0,
    [parameter(Position = 1, Mandatory = $true)] [string]$runname,
    [parameter(Position = 2)] [string]$server='KUHNTUCKER1',
    [parameter(Position = 3)] [int[]]$inid = @(1..50),
    [parameter(Position = 4)] [string[]]$vgrids = @()
)
trap { break }

# push out Current0
F:\VGRIDS\beopest\Push-Current0.ps1 "$Current0" -inid @(1..40) -vgrids @('kuhntucker7')

function Start-BeoPestSlave {
	param([int]$i,[string]$r,[string]$s) # instance number, runname and master computername
	$d_instance = $i.ToString("Current0")
	$cwd = Join-Path 'C:\IHM' $d_instance

	# initiate slave beopest64.exe
	$wtitle = "$env:COMPUTERNAME.$d_instance"
	[Environment]::SetEnvironmentVariable('WorkingDirectory',$cwd,'user')
    Start-Sleep -Seconds 3
    $tprocs = Start-Process -FilePath 'C:\PEST\beopest64.exe' -ArgumentList " $r /h $s`:4004" -WorkingDirectory "$cwd"
	return $tprocs
}

$sqllocaldb = 'C:\Program Files\Microsoft SQL Server\150\Tools\Binn\SqlLocalDB.exe'
$inid |ForEach-Object{
    $db_inst = $_.ToString('Current0')
    $status = Invoke-Expression "& '$sqllocaldb' i $db_inst" |?{$_ -imatch 'State: +(.+)'} |%{$Matches[1]}
    if ($status -ieq 'Stopped') {
        $rtnval = Invoke-Expression "& '$sqllocaldb' delete $db_inst"
    }
}

$msprocs = @()
foreach ($i in $inid) {
	Start-BeoPestSlave $i $runname $server
	$msprocs = $msprocs + $tproc
}
Start-Sleep -Seconds 3
$sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
Add-Type -MemberDefinition $sig -name NativeMethods -namespace Win32

Invoke-Command -ScriptBlock {
	do {
		Start-Sleep -Seconds 15
		$procs = Get-Process -Name "HspfEngine" -ErrorAction SilentlyContinue |
			ForEach-Object{ If ($_ -ne $NULL) { [Win32.NativeMethods]::ShowWindowAsync($_.MainWindowHandle,2)} }
		$p = Get-WmiObject -Class Win32_Process -Filter "Name='beopest64.exe'"
	} until ($p -eq $null)
	shutdown -l
}
return $msprocs

