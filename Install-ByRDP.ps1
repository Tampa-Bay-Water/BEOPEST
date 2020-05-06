# .\Install-ByRDP.ps1 -v @(31..31)
param(
	[int[]]$vid=@(1..82),
	[string]$install_proc='F:\VGRIDS\admin\install.ps1'
	)
trap { break }

$path = Split-Path $install_proc -Parent
$f_proc = Split-Path $install_proc -Leaf

# RDP file template
$rdp_tpl = @"
screen mode id:i:1
desktopwidth:i:1920
desktopheight:i:1200
session bpp:i:32
winposstr:s:0,1,1,1,1200,800
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
alternate shell:s:`powershell.exe -NoExit -Command "$install_proc; `$title"
shell working directory:s:$path
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:1
use redirection server name:i:0
username:s:vgrid\wanakule
drivestoredirect:s:
"@

$vgrids = F:\VGRIDS\Get-Vgrids -vid $vid

foreach ($v in $vgrids) {
	# check startup program
	$f_startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\powershell.lnk'
	$f_startup = $f_startup.Replace('C:',"\\$v\c$")
	if (Test-Path -PathType Leaf $f_startup) {Remove-Item $f_startup -Force}
	
	$title = "`$host.ui.RawUI.WindowTitle=`'$f_proc`'"
	
	$p_args =  "$inid_str $runname $env:COMPUTERNAME"
	$f_rdp = "C:\windows\temp\install_$v.rdp"
	Set-Content $f_rdp -Value $rdp_tpl.Replace('$v',$v).Replace('$title',$title)
	
	# Auto start using alternate shell is not working in Windows 7, use startup file instead
	$WshShell = New-Object -comObject WScript.Shell
	$sc = $WshShell.CreateShortcut($f_startup)
	$sc.TargetPath = Join-Path $PSHOME 'powershell.exe'
	$sc.Arguments = "-NoExit -Command ""$title;.\install.ps1"""
	$sc.WorkingDirectory = 'F:\VGRIDS\admin'
	$sc.Save()

	# spawn mstsc process and get system process
	mstsc "$f_rdp" -v:$v
}

# Cleanup startup file
Sleep -Seconds 60
foreach ($v in $vgrids) {
	$f_startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\powershell.lnk'
	$f_startup = $f_startup.Replace('C:',"\\$v\c$")
	if (Test-Path -PathType Leaf $f_startup) {Remove-Item $f_startup -Force}
}
