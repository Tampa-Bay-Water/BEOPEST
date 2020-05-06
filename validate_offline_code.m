%% Validation Test 1
% run pp_050 - all calibrated parameters have no fix and tie
% run pp_051 - add fix and tie to wtcol 80
% the following run produce 'trial_offline_results.xls' in pp_050
% compare the result with 'offline_results.xls' in pp_051 (which use PEST to
% compute stdev)
f_weight = '\\kuhntucker\e$\ihm\ppest_20070420\ObsWeightSchemes_trial.xls';
d_runname = '\\kuhntucker\e$\ihm\ppest_20070420\pp_050';
[d_scenario,runname] = fileparts(d_runname);
colspec = 80;
Spest=UpdateVector(f_weight,d_runname,colspec,true);


%% Validation Test 2
% generate 'offline_results.xls' from PEST result
f_weight = '\\kuhntucker\e$\ihm\ppest_20070420\ObsWeightSchemes_2.xls';
d_runname = '\\kuhntucker\e$\ihm\ppest_20070420\pp_051';
[d_scenario,runname] = fileparts(d_runname);
colspec = 80;
Spest=UpdateVector(f_weight,d_runname,colspec,false);


%% Validation Test 3
% additional tie and fix - spreadsheet must contain only additional tie & fix
% run pp_052 adds two more tied parameters, compare 'offline_results.xls'
% under pp_052 with 'trial_offline_results.xls' in pp_051 created by the 
% following code
f_weight = '\\kuhntucker\e$\ihm\ppest_20070420\ObsWeightSchemes_trial.xls';
d_runname = '\\kuhntucker\e$\ihm\ppest_20070420\pp_051';
[d_scenario,runname] = fileparts(d_runname);
colspec = 81;
Spest=UpdateVector(f_weight,d_runname,colspec,true);


%% Validation Test 4
% Same as Test 3, except that pp_051 was reran with 1% perturbation for 
% Jacobian calculation
% run pp_052 adds two more tied parameters, compare 'offline_results.xls'
% under pp_052 with 'trial_offline_results.xls' in pp_053 created by the 
% following code
f_weight = '\\kuhntucker\e$\ihm\ppest_20070420\ObsWeightSchemes_trial.xls';
d_runname = '\\kuhntucker\e$\ihm\ppest_20070420\pp_053';
[d_scenario,runname] = fileparts(d_runname);
colspec = 81;
Spest=UpdateVector(f_weight,d_runname,colspec,true);

