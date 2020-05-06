param(
	[int[]]$vid=@(21..82),
	[string]$runname,
	[switch]$noCSV
	)

$f_csv = Join-Path (Get-Location) "$runname.csv"
$f_temp = 'C:\Temp\temp.csv'
$vgrids = F:\VGRIDS\Get-Vgrids.ps1 -v $vid

# CSV file heading 
if (-not $noCSV) {
	Write-Output "ServerName,Instance,StartTime,ExecHour,PkVirtualMemSize,PkPagedMemSize,PeakWorkingSet" |
		Out-File $f_csv -en ASCII
	foreach ($v in $vgrids) {
		get-content "\\$v\c`$\ihm\$runname`.stats" |
			Out-File $f_csv -en ASCII -append
	}

	# Add runname to csv file for bulk insert
	$temp = Import-Csv $f_csv
	1..$temp.length |%{Add-Member -MemberType NoteProperty -Name RunName -In $temp[$_-1] -Value $runname}
	$temp |
		Select RunName,ServerName,Instance,StartTime,ExecHour,PkVirtualMemSize,PkPagedMemSize,PeakWorkingSet |
		where {$_.ServerName -like 'VGRID*'} |
		Export-Csv $f_csv -en ASCII -noTypeInformation
}

# bulk insert does not like quotes
Get-Content $f_csv |%{$_.replace('"','')} |Set-Content $f_temp
<#
# load csv into database
$svr = "KUHNTUCKER"
$db = "PPEST"
$tab = "RunStatistics"
$cn = New-Object System.Data.SqlClient.SqlConnection `
	"server=$svr;database=$db;Integrated Security=sspi"
$cn.Open()
$sql = $cn.CreateCommand()
$sql.CommandText = "DELETE $tab WHERE RunName='$runname'"
$rdr = $sql.ExecuteNonQuery()

$sql = $cn.CreateCommand()
$sql.CommandText = "BULK INSERT $tab FROM '$f_temp' " +
	"WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', MAXERRORS = 1)"
$rdr = $sql.ExecuteNonQuery()

# summarize statistics
$sql = $cn.CreateCommand()
$sql.CommandText = "SELECT ServerName" +
	",avg(ExecHour) AvgExecHour,stdev(ExecHour) StdevExecHour" +
	",avg(WorkingSetMB) AvgWS_MB,avg(VirtualMB) AvgVM_MB" +
	",CASE WHEN cast(right(servername,2) as int)>=27 then 24/avg(ExecHour)*7 else 24/avg(ExecHour)*4 end Efficiency" +
	" FROM $tab WHERE RunName='$runname'" +
	" GROUP BY ServerName ORDER BY Efficiency Desc"
$rdr = $sql.ExecuteReader()
$dt = New-Object "System.Data.DataTable"
$dt.Load($rdr)
$cn.Close()
#>
$f_xls = Join-Path (Get-Location) "$runname.xls"
$dt |select-object ServerName,AvgExecHour,StdevExecHour,AvgWS_MB,AvgVM_MB,Efficiency |
	export-csv $f_xls -en ASCII -noTypeInformation
#$dt | Format-Table

return $dt