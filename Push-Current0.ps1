param(
    [parameter(Position = 0, Mandatory = $true)] [string]$src,
    [parameter(Position = 1)] [int[]]$vid = @(1..11),
    [parameter(Position = 2)] [int[]]$inid = @(1..50),
    [parameter(Position = 3)] [string[]]$vgrids = @()
)
trap { break }

# test if $src exist
if (-not (Test-Path $src -PathType Container)) {
    Write-Error 'Error: Specified current0 source folder not exist!'
    return
}

$cred = Import-Clixml -Path `
(Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_$($env:USERNAME.Substring(0,4))_cred.xml")
#    (Join-Path 'F:\VGRIDS\admin' "$($env:COMPUTERNAME)_mdce_cred.xml")
$full_domainname = $env:USERDNSDOMAIN

# Flush C:\IHM
Write-Host "Push-Current0: Spawning process to delete C:\IHM" -fore Yellow

if ($vgrids.Count -eq 0) {
    $vgrids = F:\VGRIDS\Get-Vgrids.ps1 -v $vid
}
$delete_job = @()
$vgrids | % {
    $delete_job += Invoke-Command -ComputerName "$_.$full_domainname" -ScriptBlock {
        $acl_obj = Get-Acl -Path C:\IHM
        Remove-Item C:\IHM -Recurse -Force | Out-Null
        New-Item -Path C:\ -Name IHM -ItemType Directory -Force | Out-Null
        #$acl_obj = Get-Acl -Path C:\IHM
        #$grp = New-Object `
        #    System.Security.Principal.NTAccount($full_domainname, "Domain Admins")
        #$ACL.SetOwner($grp)
        #$ar = New-Object  `
        #    system.security.accesscontrol.filesystemaccessrule($env:USERNAME,"FullControl","Allow")
        #$acl_obj.SetAccessRule($ar)
        Set-Acl $acl_obj.Path $acl_obj
    } -Credential $cred -Authentication Credssp -AsJob
}
Write-Host "Push-Current0: Wait for deleting process to complete ..." -fore Yellow
Wait-Job $delete_job

Write-Host "Push-Current0: Check for completion of deleting" -fore Yellow
$temp = $vgrids | % { 
    if ((dir \\$_\C`$\IHM) -ne $null) {
        Write-Warning "Push-Current0: Warning: Deleteing \\$_\C`$\IHM was incomplete on!"
        Write-Host "Enter debug mode, type `$host.ExitNestedPrompt() to continue." -fore Yellow

        ## break to fix
        $host.EnterNestedPrompt() #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    }
}

################################################################################
# supporting functions

#function Invoke-CopyTree {
$sc_copytree = {
    #### Copy-Tree
    param([string[]]$r, [string[]]$children, [int]$n_tree)
    $n = @(0..($n_tree - 1))
    $procs = @()
    $child = @()
    $r | % { foreach ($j in $n) {
            $d_dest, $children = $children
            if ($d_dest) {
                $child += $d_dest
                #Write-Host "Push-Current0: Spawning process for $v; copy $_ to $d_dest" -fore Yellow
                $procs += Invoke-Command -ScriptBlock {
                    param($d_src, $d_dest)
                    "Copy-Item $d_src $d_dest -Recurse -Force"
                } -ArgumentList $_, $d_dest -AsJob
            }
        } }
    Wait-Job $procs
    $child
    #### End Copy-Tree
}
################################################################################

# Number of tree branches
$n_tree = 2

# convert list of instances to folder names
$d_instances = $inid | % { Join-Path 'C:\IHM' $_.ToString('Current0') }

# First copy Current0 (on F:) to first instance
Write-Host "Push-Current0: Creating master currentX on $($d_instances[0]) ..." -fore Yellow
$copy_procs = @()
$vgrids | % {
    if ($_ -ieq $env:COMPUTERNAME) {
        $copy_procs += Start-Job -ScriptBlock {
            param($src, $d)
            Copy-Item $src $d -Recurse -Force -Verbose
        } -ArgumentList $src, $d_instances[0]
    }
    else {
        $v = "$_.$full_domainname"
        $copy_procs += Invoke-Command -ComputerName $v -ScriptBlock {
            param($src, $d)
            net use F: \\vgridfs\f_drive
            Copy-Item $src $d -Recurse -Force
        } -ArgumentList $src, $d_instances[0] -Credential $cred -Authentication Credssp -AsJob
    }
}
Wait-Job $copy_procs

# set up childred from $d_instances
# Use binary tree to make copy starting from root at child[0]
$procs = @()
foreach ($v in $vgrids) {
    $vgrid = "$v.$full_domainname"
    $children = $d_instances -join ',' 
    # F:\VGRIDS\beopest\Invoke-CopyTree.ps1 $children -r $vgrid
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo('powershell', `
            "-file F:\VGRIDS\beopest\Invoke-CopyTree.ps1 $children -r $vgrid")
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.WindowStyle = 'Normal'
    $procs += [Diagnostics.Process]::Start($pinfo)
}
Write-Host "Push-Current0: Wait for copying process to complete ..." -fore Yellow
if ($procs) { Wait-Process -InputObject $procs }

# Check for nested CurrentX folder 
# (not clean delete of CurrentX earlier due to locked .mdf)
$temp = $vgrids | ? { Test-Path \\$_\c$\IHM\Current?\Current? -PathType Container }
if ($temp -ne $null) {
    Write-Warning "Push-Current0: Warning: Nested CurrentX were detected on: `r`n$temp"
    Write-Host "Enter debug mode, type `$host.ExitNestedPrompt() to continue." -fore Yellow

    ## break to fix
    $host.EnterNestedPrompt() #<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
}
