function Spest=UpdateVector(f_weight,d_runname,colspec,tieflag,optflag)
% f_weight : path of the spreadsheet for the weight scheme
% d_runname : directory for the jacobian matrix file
% colspec : specify the column of weight schemes
% tieflag : use tie information in weight scheme spreadsheet

%% run under the mfile directory - is this necessary?
cd(fileparts(mfilename('fullpath')));
if nargin < 2
    runname = 'pp_031';
    d_scenario = '\\kuhntucker\e$\ihm\ppest_20070420';
else
    [d_scenario,runname] = fileparts(d_runname);
end
if nargin < 3
  colspec = 61;
end
if nargin < 4
  tieflag = false; % use tie information from pest input file
end
if nargin < 5
  optflag = true; % Results from optimal is reached (vs. intermediate iteration results)
end

%% parameter info from database
% use runname without iteration id to retrieve data from DB
t_runname = char(regexpi(runname,'(pp_\d+).*','tokens','once'));
conn = database('KT_PPEST','','');
sql = [...
    'SELECT PD.Name, PD.ParameterGroup, PD.Value, PD.Transformation, NULL D5, NULL D6 ',...
    'FROM ParameterData AS PD INNER JOIN ',...
        'RunDesc AS RD ON PD.RunID = RD.RunID ',...
    'WHERE (RD.Name = ''' t_runname ''') AND (PD.Transformation <> ''fixed'') ',...
    'ORDER BY PD.ParameterDataID'];
par_cellarray = fetch(conn,sql);

%% Observation data
if optflag
  sql = [...
      'SELECT Name, ObservationGroup, NULL D3, NULL D4, NULL D5, NULL D6, NULL D7, NULL D8, NULL D9 ',...
      'FROM ObservationData ',...
      'WHERE (RunID = (SELECT RunID FROM RunDesc WHERE (Name = ''' runname '''))) ',...
      'ORDER BY ObservationDataID '];
else
  sql = [...
      'SELECT Name, ObservationGroup, NULL D3, NULL D4, NULL D5 ',...
      'FROM ObservationData ',...
      'WHERE (RunID = (SELECT RunID FROM RunDesc WHERE (Name = ''' t_runname '''))) ',...
      'ORDER BY ObservationDataID '];
end
obs_cellarray = fetch(conn,sql);
close(conn)

%% get current iteration residual
fid = fopen(fullfile(d_scenario,runname,[t_runname '.rei']),'rt');
fgetl(fid);   % ignor header
iobs = 0;
while feof(fid) == 0
  tline = fgetl(fid);
  if isempty(tline), continue; end
  [temp V2 V3 V4 V5] = regexp(tline,'OPTIMISATION ITERATION NO.+([0-9]+)\:\-','once');
  if ~isempty(temp)
    iterno = str2double(V5);
    continue;
  end
  if ~isempty(regexp(tline,'Name                 Group','once'))
    continue;
  end
  iobs = iobs +1;
  temp = textscan(tline,'%s%*s%*f64%*f64%f64%*f64');
  if strncmpi(temp{1},obs_cellarray(iobs,1),length(char(temp{1})))
    obs_cellarray{iobs,4} = temp{2};
  else
    error('Observation name not match; %s != %s',temp{1},obs_cellarray{iobs,1});
  end
end
fclose(fid);

%% get final residual
% if size(obs_cellarray,2) > 5
if optflag
  fid = fopen(fullfile(d_scenario,runname,[t_runname '.res']),'rt');
  fgetl(fid);   % ignor header
  iobs = 0;
  while feof(fid) == 0
    tline = fgetl(fid);
    if isempty(tline), continue; end
    temp = textscan(tline,'%s%*s%*f32%*f32%f32%*f32%*f32%*f32%*f32%*f32%*f32');
    iobs = iobs +1;
    if strncmpi(temp{1},obs_cellarray(iobs,1),length(char(temp{1})))
      obs_cellarray{iobs,7} = temp{2};
    else
      error('Observation name not match; %s != %s',temp{1},obs_cellarray{iobs,1});
    end
  end
  fclose(fid);
end
  
%% Extract weight columns from spreadsheet
% The only text column is parameter group, the first text row is heading
% The first numeric column is residual, the rest of the columns contain
% weight scheme
[xlsnum,xlstxt] = xlsread(f_weight,'WeightTable');
wt_cols = xlsnum(:,2:end);
wt_name = strrep(xlstxt(1,3:end),'_','-'); % avoid underscore
wt_irows = (1:size(xlsnum))+1;
obs_group = xlstxt(wt_irows,1);
% cell array for tieing and fixing matrix
child_par = xlstxt(wt_irows(end)+1:end,1);
if tieflag
  if ~isempty(child_par)
      parent_par = xlstxt(wt_irows(end)+1:end,3:end);
  end
else
  parent_par = cell(size(xlstxt(wt_irows(end)+1:end,3:end)));
end

i_tie = strncmp(par_cellarray(:,4),'tied',4);
Spest = plotComSen_dce(colspec,d_scenario,runname,...
  par_cellarray(~i_tie,:),obs_cellarray,...
  wt_cols,wt_name,obs_group,child_par,parent_par);

%% Get complete parameter info
conn = database('KT_PPEST','','');
sql = [...
    'SELECT PD.Name, PD.ParameterGroup, PD.Transformation, PD.TiedParameter, ',...
      'PD.Value, PD.LowerBound, PD.UpperBound, ',...
      'NULL D8, NULL D9, NULL D10, NULL D11, NULL D12, NULL D13 ',...
    'FROM ParameterData AS PD INNER JOIN ',...
        'RunDesc AS RD ON PD.RunID = RD.RunID ',...
    'WHERE (RD.Name = ''' t_runname ''') AND (PD.Transformation <> ''fixed'') ',...
    'ORDER BY PD.ParameterDataID'];
par_cellarray = fetch(conn,sql);
close(conn);
par_cellarray(~i_tie,9) = {Spest.Parameter.Sensitivity}';
par_cellarray(~i_tie,10) = {Spest.Parameter.PercentSens}';
par_cellarray(~i_tie,11) = {Spest.Parameter.Stdev}';
par_cellarray(~i_tie,12) = {Spest.Parameter.Update}';

%% Get current iteration parameter value
fid = fopen(fullfile(d_scenario,runname,[t_runname '.par']),'rt');
fgetl(fid);   % ignor header
while feof(fid) == 0
  tline = fgetl(fid);
  if isempty(tline), continue; end
  temp = textscan(tline,'%s%f64%*f64%*f64');
  i_row = strcmpi(par_cellarray(:,1),sprintf('%-12s',char(temp{1})));
  if sum(i_row)==0, continue; end
  par_cellarray{i_row,8} = temp{2};
end
fclose(fid);
i_log = strncmp(par_cellarray(:,3),'log',3);
i_none = strncmp(par_cellarray(:,3),'none',4);
if sum(i_log) > 0
  par_cellarray(i_log,13) = ...
    num2cell([par_cellarray{i_log,8}].*10.^[par_cellarray{i_log,12}])';
end
if sum(i_none) > 0
  par_cellarray(i_none,13) = ...
    num2cell([par_cellarray{i_none,8}]+[par_cellarray{i_none,12}])';
end

%% update for tied parameter
j_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),par_cellarray(i_tie,4));
i_log = false(size(par_cellarray(:,1)));
if sum(i_tie) > 0
  par_cellarray(i_tie,11) = ...
    num2cell([par_cellarray{i_tie,8}]./[par_cellarray{j_tie,8}].*[par_cellarray{j_tie,11}])';
  par_cellarray(i_tie,12) = ...
    num2cell([par_cellarray{i_tie,8}]./[par_cellarray{j_tie,8}].*[par_cellarray{j_tie,12}])';
  i_log(i_tie) = strncmp(par_cellarray(j_tie,3),'log',3);
end

j_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),par_cellarray(i_log,4));
if sum(i_log) > 0
  par_cellarray(i_log,12) = par_cellarray(j_tie,12);
  par_cellarray(i_log,13) = ...
    num2cell([par_cellarray{i_log,8}].*10.^[par_cellarray{i_log,12}])';
  i_none = i_tie & ~i_log;
  if sum(i_none)>0
    par_cellarray(i_none,13) = ...
      num2cell([par_cellarray{i_none,8}]+[par_cellarray{i_none,12}])';
  end
  % stdev
  par_cellarray(i_log,11) = par_cellarray(j_tie,11);
end

%% update staructure
Spest.Parameter = cell2struct(par_cellarray,...
    {'Parameter','ParGroup','Transformation','TiedParameter',...
    'StartValue','LowerBound','UpperBound','IteraionValue',...
    'Sensitivity','PercentSens','Stdev','Update','NewValue'},2);
  
% new format of Spest (noResults and wt_schemes fields)
writeOfflineResults(Spest,d_runname);
