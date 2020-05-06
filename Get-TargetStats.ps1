param(
	[string]$runname='pp_test',
	[string]$d_graphpest='Graphics_Pest',
	[string]$d_scenario=$pwd
)

$f_outfile = Join-Path $d_scenario "$runname\target_stats.csv"
"Mean,Stdev,Location,Tstamp" |Out-File $f_outfile -Encoding ASCII

# Define Output files
$h_ihmout = @(
	@{field='Residual'; #0
		file='dummy'}, # dummy file to make array base 1 aligned with MATLAB
	@{field='Residual'; #1
		file="$d_graphpest\IntervalResiduals\SpringIntervalResiduals_CalendarWeek.txt"},
	@{field='Residual';
		file="$d_graphpest\IntervalResiduals\SpringIntervalResiduals_CalendarMonths.txt"},
	@{field='Residual';
		file="$d_graphpest\IntervalResiduals\StreamflowIntervalResiduals_CalendarWeek.txt"},
	@{field='Residual';
		file="$d_graphpest\IntervalResiduals\StreamflowIntervalResiduals_CalendarMonths.txt"},
	@{field='Residual'; #5
		file="$d_graphpest\IntervalResiduals\WellIntervalResiduals_CalendarWeek.txt"},
	@{field='Residual';
		file="$d_graphpest\IntervalResiduals\WellIntervalResiduals_CalendarMonths.txt"}
	@{field='Residual';
		file='dummy'}, # dummy file to make array aligned with MATLAB - pot surface
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByLandUseData\Agric_Irrigated.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByLandUseData\Forested.txt"}
	@{field='StandardizedResidual'; #10
		file="$d_graphpest\ET\ETByLandUseData\Grass_Pasture.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByLandUseData\Mining_Other.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByLandUseData\Urban.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByLandUseData\ETByLandUseTotals.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByReachData\ETByCategoryTotals.txt"}
	@{field='StandardizedResidual'; #15
		file="$d_graphpest\ET\ETByReachData\LimitedMoisture.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\ETByReachData\UnlimitedMoisture.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\ET\MonthlyETData\MonthlyET.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\Springs\CoastalDischarge.txt"}
	@{field='StandardizedResidual';
		file="$d_graphpest\Streamflow\DisconnectedReachDischarge.txt"}
	@{field='Residual'; #20
		file="$d_graphpest\IntervalResiduals\HydroperiodIntervalResiduals_CalendarYear.txt"}
		)

# Write outputs for Spring, Streamflow, Waterlevel - Weekly and Monthly
foreach ($i in 1..6) {
	$f_infile = Join-Path $d_scenario $h_ihmout[$i].file
	# remove line with NaN
	Import-Csv $f_infile |where {$_.($h_ihmout[$i].field) -ne 'NaN'} |
		Select-Object LocationID,DateCode,ObservedIntervalMean,ObservedIntervalStandardDeviation |
		%{'{0},{1},{2},{3}' -f $_.ObservedIntervalMean,$_.ObservedIntervalStandardDeviation,$_.LocationID,$_.DateCode} |
		Out-File $f_outfile -Encoding ASCII -Append
}

# Pot surface residual output
$f_potin = Join-Path $d_scenario 'PSPointsForPEST.xls'
&F:\VGRIDS\Import-Excel.ps1 -f $f_potin -s data |Select-Object ObsHead,Std,PSWellID,Date |
	%{foreach ($i in 0..($_.PSWellID.length-1)){
		'{0,5:G4},{1,5:G4},{2,12},{3,10:d},' -f $_.ObsHead[$i],$_.Std[$i],$_.PSWellID[$i],$_.Date[$i]
		}
	} |Out-File $f_outfile -Encoding ASCII -Append

# Write outputs for ET, coastal discharge, disconnected reach discharge
foreach ($i in 8..$h_ihmout.length) {
	$f_infile = Join-Path $d_scenario $h_ihmout[$i].file
	
	switch ($i) {
		{$i -le 12} { # ET by landuse class
			Import-Csv $f_infile |
				Select-Object LandSegmentID,TargetAverageAnnualET |
				%{'{0},{1},{2},' -f $_.TargetAverageAnnualET,([double]$_.TargetAverageAnnualET*0.15),$_.LandSegmentID} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{$i -eq 13} { # ET for land total
			Import-Csv $f_infile |
				Select-Object LandUse,TargetAverageAnnualET |
				%{'{0},{1},{2},' -f $_.TargetAverageAnnualET,([double]$_.TargetAverageAnnualET*0.1),$_.LandUse} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{$i -eq 14} { # ET for reach total
# $host.EnterNestedPrompt()
			Import-Csv $f_infile |
				Select-Object Category,TargetAverageAnnualET |
				%{'{0},{1},{2},' -f $_.TargetAverageAnnualET,([double]$_.TargetAverageAnnualET*0.1),$_.Category} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{($i -eq 15) -or ($i -eq 16)} {
			Import-Csv $f_infile |
				Select-Object ReachID,TargetAverageAnnualET |
				%{'{0},{1},{2},' -f $_.TargetAverageAnnualET,([double]$_.TargetAverageAnnualET*.15),$_.ReachID} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{$i -eq 17} {
			Import-Csv $f_infile |
				Select-Object LandUse,Month,ObservedCoefficient,ObservedStandardDeviation |
				%{'{0},{1},{2},{3}' -f $_.ObservedCoefficient,$_.ObservedStandardDeviation,$_.LandUse,$_.Month} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{$i -eq 18} { # coastal discharge
			Import-Csv $f_infile |
				Select-Object Target,SimulatedMinusTarget,StandardizedResidual |
				%{'9.5,2.162,{0},' -f $_.Target} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{$i -eq 19} { # disconnected reach discharge
			Import-Csv $f_infile |
				Select-Object ReachID,DateCode |
				%{'0,1.5,{0},{1}' -f $_.ReachID,$_.DateCode} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
		{$i -eq 20} { # hydro period
			Import-Csv $f_infile |
				Select-Object LocationID,DateCode,ObservedIntervalMean,ObservedIntervalStandardDeviation,Residual |
				Where {$_.Residual -ne 'NaN'} |
				%{'{0},{1},{2},{3}' -f $_.ObservedIntervalMean,$_.ObservedIntervalStandardDeviation,$_.LocationID,$_.DateCode} |
				Out-File $f_outfile -Encoding ASCII -Append
				break
			}
	}
}
