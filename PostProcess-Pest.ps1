param(
	[string]$runname="bp_004",
	[string]$d_scenario=$pwd,
	[string]$sens_wtcols='1:44',
	[string]$corr_wtcols='21'
	)
trap { break }

$d_script = "F:\VGRIDS\beopest"

### Load output to PPEST database
Write-Host "PostProcess-Pest: Load .pst to PPEST database ..." -fore Yellow
#$ml_cmd = "-r ""cd $d_script; loaddb_pst('$d_scenario','$runname'); exit;"""
#$p_pst = [diagnostics.process]::start("C:\MATLAB\R2015a\bin\matlab.exe","$ml_cmd -automation")
#$p_pst.WaitForExit()

#$d_runname = "$d_scenario\$runname"
Write-Host "PostProcess-Pest: Load ppest residual output to PPEST database ..." -fore Yellow
#$ml_cmd = "-r ""cd $d_script; loaddb_pestoutput('$d_runname','obsres'); loaddb_pestoutput('$d_runname','parsen'); exit;"""
#$p_out = [diagnostics.process]::start("C:\MATLAB\R2015a\bin\matlab.exe","$ml_cmd -automation")
#$p_out.WaitForExit()


### Run Offline Sensitivity Analysis using MATLAB
$d_SensAna = "$d_script\SensitivityAnalysis"
$f_weight = "$d_scenario\ObsWeightSchemes.xls"

 $run_batch = "batch('$d_runname','$f_weight',$sens_wtcols,$corr_wtcols,true)"
 Write-Host "PostProcess-Pest: Run offline sensitivity analysis ..." -fore Yellow
 $ml_cmd = "-r ""cd $d_SensAna; $run_batch; exit;"""

$run_batch = "Spest=UpdateVector('$f_weight','$d_runname',48)"
Write-Host "PostProcess-Pest: Run offline UpdateVector ..." -fore Yellow
$ml_cmd = "-r ""cd $d_script; $run_batch; save(['$d_runname' '\Spest.mat'],'Spest'); exit;"""

$p_senc = [diagnostics.process]::start("C:\MATLAB\R2015a\bin\matlab.exe","$ml_cmd -automation")
$p_senc.WaitForExit()

Write-Host "PostProcess-Pest: Finished" -fore Yellow