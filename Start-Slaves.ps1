# .\Start-Slaves -r bp_004 -v @(8..8) -i @(1..5)
param(
	[int[]]$vid=@(1..82),
	[int[]]$inid=@(1..5),
	[string]$runname='bp_test'
	)
trap { break }

$cred = Import-Clixml -Path `
    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_$($env:USERNAME.Substring(0,4))_cred.xml")
#    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_mdce_cred.xml")

# RDP file template
$rdp_tpl = @"
screen mode id:i:1
desktopwidth:i:1920
desktopheight:i:1200
session bpp:i:32
winposstr:s:0,1,1,1,1500,1000
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:2
displayconnectionbar:i:1
disable wallpaper:i:1
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:`$v
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
redirectdirectx:i:1
autoreconnection enabled:i:1
authentication level:i:0
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:`powershell.exe -NoExit -Command "`$inid=Import-Clixml .\inid.xml;.\Activate-Slaves.ps1 `$p_args; `$title"
shell working directory:s:C:\IHM
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:1
use redirection server name:i:0
username:s:$env:USERDOMAIN\$env:USERNAME
drivestoredirect:s:
"@

#$pscmd = "C:\Windows\System32\WindowsPowershell\v1.0\powershell.exe -NoExit -Command"
$vgrids = F:\VGRIDS\Get-Vgrids -vid $vid

foreach ($v in $vgrids) {
	# check startup program
	$f_startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\powershell.lnk'
	$f_startup = $f_startup.Replace('C:',"\\$v\c$")
	if (Test-Path -PathType Leaf $f_startup) {Remove-Item $f_startup -Force}
	
	$title = "`$host.ui.RawUI.WindowTitle=`'Activate-Slaves`'"
	Copy-Item F:\VGRIDS\beopest\Activate-Slaves.ps1 -dest "\\$v\c`$\IHM" -verbose
    $inid |Export-Clixml "\\$v\c`$\IHM\inid.xml" -Force
	
	$p_args =  "`$inid $runname $env:COMPUTERNAME"
	$f_rdp = Join-Path $env:LOCALAPPDATA "\Temp\slave_$v.rdp"
	Set-Content $f_rdp -Value $rdp_tpl.Replace('$v',$v).Replace('$p_args',$p_args).Replace('$title',$title)
	
#
	# Auto start using alternate shell is not working in Windows 7, use startup file instead
	$WshShell = New-Object -comObject WScript.Shell
	$sc = $WshShell.CreateShortcut($f_startup)
	$sc.TargetPath = Join-Path $PSHOME 'powershell.exe'
	$sc.Arguments = "-NoExit -Command ""`$procs=`$inid=Import-Clixml .\inid.xml;.\Activate-Slaves.ps1 $p_args; $title;`$procs"""
	$sc.WorkingDirectory = 'C:\IHM'
	$sc.Save()
#>
	# spawn mstsc process and get system process
    cmdkey /generic:TERMSRV/$v /user:($cred.UserName) /pass:($cred.GetNetworkCredential().Password)
	mstsc "$f_rdp" -v:$v
}

# Cleanup startup file
<#
Sleep -Seconds 3600
foreach ($v in $vgrids) {
	$f_startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\powershell.lnk'
	$f_startup = $f_startup.Replace('C:',"\\$v\c$")
	if (Test-Path -PathType Leaf $f_startup) {Remove-Item $f_startup -Force}
}
#>

$jb = @()
$vgrids | %{
$jb += Invoke-Command -ComputerName "$_.vgrid.local" -ScriptBlock {
    param($f_startup)
    Sleep -Seconds 60
	$f_startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\powershell.lnk'
	if (Test-Path -PathType Leaf $f_startup) {Remove-Item $f_startup -Force}
} -Credential $cred -Authentication Credssp -AsJob
}
Wait-Job $jb
