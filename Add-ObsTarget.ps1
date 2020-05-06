param(
	[string[]]$path=@(),
	[string]$directory='F:\VGRIDS\ppest\Graphics_Pest_20070424\IntervalResiduals',
	[string[]]$groupname,[single[]]$wt
	)
	
if (-not $path) {
	$path = @(
	'SpringIntervalResiduals_7.txt',
	'SpringIntervalResiduals_30.txt',
	'StreamflowIntervalResiduals_7.txt',
	'StreamflowIntervalResiduals_30.txt',
	'WellIntervalResiduals_7.txt',
	'WellIntervalResiduals_30.txt'
	)
	$groupname = @(
	'wklysprgflow',
	'mnlysprgflow',
	'wklystrmflow',
	'mnlystrmflow',
	'wklygwlevel',
	'mnlygwlevel'
	)
	$wt = @(1,1,1,1,1,1)
	$nametpl  = @(
	'sp000wyymmdd',
	'sp000myymmdd',
	'fl000wyymmdd',
	'fl000myymmdd',
	'wl000wyymmdd',
	'wl000myymmdd'
	)
}

if (-not $directory) { $directory = '.' }
$lines = @()
foreach ($i in 0..($path.length-1)) {
	Join-Path $directory $path[$i] |Import-Csv |
		where {($_.Resdidual -ne 'NaN') -and 
			(($_.DateCode -like '1996????') -or ($_.DateCode -like '1997????'))} |
		%{
			$id = [int]$_.LocationID
			$WEIGHT = $wt[$i].ToString()
			$OBSNME = $id.ToString($nametpl[$i].SubString(0,6))
			$OBSNME += $_.DateCode.SubString(2)
			$OBSVAL = $_.Resdidual.ToString()
			$OBGNME = $groupname[$i]
			$lines += "$OBSNME`t$OBSVAL`t$WEIGHT`t$OBGNME"
		}
}
return ($lines |sort)