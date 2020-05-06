function Spest=plotComSen(f_weight,d_runname,colspec,use_distcomp)
% f_weight : path of the spreadsheet for the weight scheme
% d_runname : directory for the jacobian matrix file
% colspec : specify list of columns of weight schemes
% use_distcomp : flag for usign DISTCOMP

%% run under the mfile directory - is this necessary?
cd(fileparts(mfilename('fullpath')));
if nargin < 2
    runname = 'pp_003';
    d_scenario = 'E:\ihm\ppest_20070420';
else
    [d_scenario,runname] = fileparts(d_runname);
end
if nargin < 4, use_distcomp = true; end

%% parameter info from database
conn = database('BeoPEST_output','','');
sql = [...
    'SELECT PD.Name, PD.ParameterGroup, PD.Value, PD.Transformation, NULL D1, NULL D2 ',...
    'FROM ParameterData AS PD INNER JOIN ',...
        'RunDesc AS RD ON PD.RunID = RD.RunID ',...
    'WHERE (RD.Name = ''' runname ''') AND (PD.Transformation <> ''fixed'') ',...
    'ORDER BY PD.ParameterDataID'];
par_cellarray = fetch(conn,sql);

sql = [...
    'SELECT OBR.Observation, OD.ObservationGroup, NULL D1, OBR.Residual, NULL D2 ',...
    'FROM ObservationData AS OD INNER JOIN ',...
      'ObservationResidual AS OBR ON OD.Name = OBR.Observation AND OD.RunID = OBR.RunID ',...
    'WHERE (OD.RunID = (SELECT RunID FROM RunDesc WHERE (Name = ''' runname '''))) ',...
    'ORDER BY OD.ObservationDataID '];
obs_cellarray = fetch(conn,sql);

close(conn)

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
if ~isempty(child_par)
    parent_par = xlstxt(wt_irows(end)+1:end,3:end);
end
if nargin < 3
  colspec = 1:size(wt_cols,2);
end

Spest = cell(length(wt_name),2);
Spest(:,1) = wt_name;
if use_distcomp
    % Create job and task for distcomp
    jm = findResource('scheduler','type','jobmanager','Name','JobManager2');
    jb = createJob(jm);
    set(jb,'RestartWorker',true);
    set(jb,'FileDependencies',{'taskStartup.m'});
    %set(jb, 'PathDependencies',{'E:/MATLAB_R2006a/work','F:\VGRIDS\ppest\SensitivityAnalysis'});
    for j = colspec
      createTask(jb,@plotComSen_dce,1,{j,d_scenario,runname,...
          par_cellarray,obs_cellarray,...
          wt_cols,wt_name,obs_group,child_par,parent_par});
    end
    submit(jb);
    waitForState(jb);
    temp = getAllOutputArguments(jb);
    if length(jb.Tasks) > 1
      errindex = cellfun(@(y) ~isempty(y),get(get(jb,'Tasks'),'ErrorMessage'));
    else
      errindex = cellfun(@(y) ~isempty(y),{get(get(jb,'Tasks'),'ErrorMessage')});
    end
    if sum(errindex)>0 
      tasks = findTask(jb);
      disp('There are errors at the following workers:\n');
      for i = 1:length(errindex)
          if errindex(i)
              disp(sprintf('While evaluating at weight column %d,',colspec(i)));
              disp([tasks(i).Worker.Hostname ':\n' tasks(i).ErrorMessage]);
          else
              Spest(colspec(i),2) = temp(i);
          end
      end
    else
      Spest(colspec,2) = temp;
    end
    destroy(jb);
else
    % Non MDCE should be used for debuging only
    for j = colspec
      Spest{j,2} = plotComSen_dce(j,d_scenario,runname,par_cellarray,obs_cellarray,...
          wt_cols,wt_name,obs_group,child_par,parent_par);
    end
end

Spest = cell2struct(Spest,{'WtScheme','Results'},2);
