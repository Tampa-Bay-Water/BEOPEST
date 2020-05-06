param ([int[]] $vid=1..82)
$db_inst = 'v11.0'

$jb = $vid |%{
    $v = $_.ToString('vgrid00')
    Invoke-Command -ComputerName $v -Sc {
        Invoke-Sqlcmd -ServerInstance "(localdb)\$db_inst" -Database master `
        -Query "select name from sysdatabases where name like 'C:\IHM\Current%'"
    } -AsJob
}

$temp = Receive-Job (Wait-Job $jb)
if ($temp -eq $null) { return }
$jb = 0..($temp.Length-1) |%{
    Invoke-Command -ComputerName $temp.PSComputerName[$_] -Sc {
        param($dbn)
        Invoke-Sqlcmd -ServerInstance "(localdb)\$db_inst" -Database master `
        -Query "ALTER DATABASE [$dbn] SET OFFLINE WITH ROLLBACK IMMEDIATE;exec sp_detach_db [$dbn]"
    } -ArgumentList $temp.Name[$_] -AsJob   
}
return (Wait-Job $jb)
