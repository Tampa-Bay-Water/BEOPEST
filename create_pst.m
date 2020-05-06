function create_pst(d_current0,runname,wt_col,flag_parmtran)
% Script to create PPEST *.pst (version2)

if nargin < 1 || isempty(d_current0)
  d_current0 = 'F:\IHM\BEOPEST\Current0_IHMv4_20200222';
end
if nargin < 2, runname = 'bp_020'; end
if nargin < 3, wt_col = 5; end
if nargin < 4, flag_parmtran = true; end

%% path and files for creation of parameters data
d_root = fileparts(d_current0);
f_param = fullfile(d_root,runname,'parameters_3.xls'); % original:'parameters_2.xls'
f_weight = fullfile(d_root,'ObsWeightSchemes_2.xls'); %original:ObsWeightSchemes_2.xls
d_pestet = fullfile(d_root,'PEST_ET');
f_intb = fullfile(d_current0,'INTB2_input.mdf');
f_dbout = fullfile(d_current0,'INTB_output.mdf');

addpath(fullfile(d_root,'New_PotSurfaceTarget'),'-end');

%% paths and files for creation of observation targets
obs_group = {...
  '_wlyspr';...
  '_mlyspr';...
  '_wlystf';...
  '_mlystf';...
  '_wlygwl';...
  '_mlygwl';...
};
% obs_wt is use as observation inclusion selection
% this must be consistence with the file f_weight
obs_wt = [1,1,1,1,1,1];
obsname_tpl  = {...
  'spr%04d_wkly';...
  'spr%04d_mnly';...
  'stf%04d_wkly';...
  'stf%04d_mnly';...
  'gwl%04d_wkly';...
  'gwl%04d_mnly';...
};

% Observation target for ET by landuse class
d_etout = fullfile(d_pestet,'ET');
f_etout = {...
  'LandETData\Agric_Irrigated.csv';...
  'LandETData\Forested.csv';...
  'LandETData\Grass_Pasture.csv';...
  'LandETData\Mining_Other.csv';...
  'LandETData\Urban.csv';...
  'LandETData\LandETTotals.csv';...
  'ReachETData\ETByCategoryTotals.csv';...
  'ReachETData\LimitedMoisture.csv';...
  'ReachETData\UnlimitedMoisture.csv';...
  'MonthlyETData\MonthlyET.csv';...
  };
etobs_group = {...
  '%s_ETLUAg';...     1  8
  '%s_ETLUFo';...     2  9
  '%s_ETLUGr';...     3  10
  '%s_ETLUMi';...     4  11
  '%s_ETLUUr';...     5  12
  'zET_LUTotal ';...  6  13
  'zET_RchTotal';...  7  14
  '%s_ETRchL';...     8  15
  '%s_ETRchU';...     9  16
  'zET_MLYCoeff';... 10  17
};
% obs_wt is use as observation inclusion selection
% actual weight will be updated with the file f_weight
etobs_wt = [1,1,1,1,1,1,1,1,1,1]; % act as switch to turn on
% etobs_wt = [0,0,0,0,0,0,0,0,0,0];
etobsname_tpl  = {...
  'ET_LUAgrIrr_%04d';...
  'ET_LUForest_%04d';...
  'ET_LUGrass_%04d';...
  'ET_LUMining_%04d';...
  'ET_LUUrban_%04d';...
  'ET_LUTotal_%.3s';...
  'ET_RchCatTot_%.7s';...
  'ET_RchLimMoi_%04d';...
  'ET_RchUnlimM_%04d';...
  'ET_Coeff_%.5s%02d';...
};


%% Data for associating region to target
db_instance = 'v11.0';
sqllocaldb_exe = 'C:\Program Files\Microsoft SQL Server\110\Tools\Binn\SqlLocalDB.exe';
system(['"' sqllocaldb_exe '" create ' db_instance ' -s']);
sv = ['(localdb)\' db_instance];
dv = 'SQL Server Native Client 11.0';
conn = database(['Driver=' dv ';Server=' sv ';Database=' f_intb ...
    ';AttachDbFileName=' f_intb ...
	';Trusted_Connection=Yes;LoginTimeout=300;']);

scn_props = fetch(conn,['select * from [' f_intb '].dbo.Scenario where Name=''PEST_Run''']);
% sim_sdate = scn_props.SimulationStartDate{1}(1:10);
sim_edate = scn_props.SimulationEndDate{1}(1:10);
data_sdate = scn_props.IHMBinaryFileArchiveStartDate{1}(1:10);
data_edate = scn_props.IHMBinaryFileArchiveEndDate{1}(1:10);
if datenum(sim_edate)<datenum(data_edate)
    data_edate = sim_edate;
end

sql = [...
        'SELECT OW.ObservedWellID AS WID, RGN.Name AS Region, OW.LayerNumber ',...
        'FROM ObservedWell AS OW INNER JOIN ',...
        'Region AS RGN ON OW.RegionID = RGN.RegionID'...
    ];
curs = fetch(conn, sql, 'DataReturnFormat', 'cellarray');
wellrgn = struct('sid',curs(:,1),'Region',curs(:,2),'Layer',curs(:,3));
sql = [...
        'SELECT FS.FlowStationID AS SID, RGN.Name AS Region ',...
        'FROM FlowStation AS FS INNER JOIN ',...
        'Region AS RGN ON FS.RegionID = RGN.RegionID'...
    ];
curs = fetch(conn, sql, 'DataReturnFormat', 'cellarray');
strmrgn = struct('sid',curs(:,1),'Region',curs(:,2));
sql = [...
        'SELECT     SP.SpringID AS SID, RGN.Name ',...
        'FROM Spring AS SP INNER JOIN ',...
        'Region AS RGN ON SP.RegionID = RGN.RegionID'...
    ];
curs = fetch(conn, sql, 'DataReturnFormat', 'cellarray');
sprgrgn = struct('sid',curs(:,1),'Region',curs(:,2));
sql = [...
        'SELECT     RCH.ReachID AS RID, RGN.Name ',...
        'FROM Reach AS RCH INNER JOIN ',...
        'Region AS RGN ON RCH.RegionID = RGN.RegionID'...
    ];
curs = fetch(conn, sql, 'DataReturnFormat', 'cellarray');
rchrgn = struct('rid',curs(:,1),'Region',curs(:,2));
sql = [...
        'SELECT LS.LandSegmentID, RGN.Name ',...
        'FROM Region AS RGN INNER JOIN ',...
        '(Basin AS BS INNER JOIN LandSegment AS LS ON BS.BasinID = LS.BasinID) ',...
        'ON RGN.RegionID = BS.RegionID'...
    ];
curs = fetch(conn, sql, 'DataReturnFormat', 'cellarray');
lsegrgn = struct('lid',curs(:,1),'Region',curs(:,2));

exec(conn,['ALTER DATABASE [' f_intb '] SET OFFLINE WITH ROLLBACK IMMEDIATE']);
exec(conn,['exec sp_detach_db [' f_intb ']']);
close(conn);
grp_region = {sprgrgn,sprgrgn,strmrgn,strmrgn,wellrgn,wellrgn};

%% template files - corresponding to parameters
f_template = strrep({...
  ' pp_test.tp1  pp_test.dt1';... % leakance
  ' pp_test.tp2  pp_test.dt2';... % transmissivity
  ' pp_test.tp3  pp_test.dt3';... % unconfined storage
  ' pp_test.tp4  pp_test.dt4';... % confined storage
  ' pp_test.tp5  pp_test.dt5';... % hspf
  },'pp_test',runname);

%% instruction files - corresponding to observations
f_instruction = strrep({...
  ' pp_test.i01  pp_test.o01';... % weekly springflow
  ' pp_test.i02  pp_test.o02';... % monthly springflow
  ' pp_test.i03  pp_test.o03';... % weekly streamflow
  ' pp_test.i04  pp_test.o04';... % monthly streamflow
  ' pp_test.i05  pp_test.o05';... % weekly groundwater level
  ' pp_test.i06  pp_test.o06';... % monthly groundwater level
  ' pp_test.i07  pp_test.o07';... % URAS Potentiometric Surface
  ' pp_test.i08  pp_test.o08';... % ET_LUAgrIrr
  ' pp_test.i09  pp_test.o09';... % ET_LUForest
  ' pp_test.i10  pp_test.o10';... % ET_LUGrass
  ' pp_test.i11  pp_test.o11';... % ET_LUMining
  ' pp_test.i12  pp_test.o12';... % ET_LUUrban
  ' pp_test.i13  pp_test.o13';... % ET_LUTotal
  ' pp_test.i14  pp_test.o14';... % ET_RchCatTot
  ' pp_test.i15  pp_test.o15';... % ET_RchLimMoi
  ' pp_test.i16  pp_test.o16';... % ET_RchUnlimM
  ' pp_test.i17  pp_test.o17';... % ETMLY
%  ' pp_test.i18  pp_test.o18';... % Coastal Discharge
%  ' pp_test.i19  pp_test.o19';... % disconnected reach Discharge
%  ' pp_test.i20  pp_test.o20';... % disconnected reach Hydroperiod
  },'pp_test',runname);

%% process data
% parameter
par_grpdata = [];
par_data = [];
tied_par = []; % from parameters_x.xls, last part of spreadsheet
par_function;

% observation (target)
obs_data = [];
ins_line = {};
i_insfile = [];
obs_function;

% localDB Cleanup
system(['"' sqllocaldb_exe '" stop ' db_instance]);
% system(['"' sqllocaldb_exe '" delete ' db_instance]);

% prior information data
pinfo_data = [];

%% Extract weight columns from spreadsheet
% The only text column is parameter group, the first text row is heading
% The first numeric column is residual, the rest of the columns contain
% weight scheme
t_observ = readtable(f_weight,'Sheet','WeightTable');
i_observ = cellfun(@(y) ~isempty(y),t_observ.ObservationGroup); % remove rows of blank ObservationGroup
j_observ = ~strncmp(t_observ.Properties.VariableNames,'Var',3); % remove blank columns
t_observ = t_observ(i_observ,j_observ);
wt_irows = ~isnan(t_observ.Residual);
wt_cols = t_observ(wt_irows,3:end);
% wt_name = strrep(wt_cols.Properties.VariableNames,'_','-'); % avoid underscore
wt_name = wt_cols.Properties.VariableNames;
obs_group = table2cell(t_observ(wt_irows,1));
% cell array for tieing and fixing matrix
child_par = table2cell(t_observ(~wt_irows,1));
if ~isempty(child_par)
    parent_par = table2cell(t_observ(~wt_irows,3:end));
else
    parent_par = cell(0,width(t_observ)-2);
end
% Check for empty parent parameters
if all(cellfun(@(y) all(isnan(y)) | isempty(y),parent_par(:,wt_col)))
    parent_par = [];
else
    parent_par = strtrim(parent_par(:,wt_col));
end
temp = arrayfun(@(y) ~isempty(parent_par{y}),1:length(parent_par))';
tied_data = [];
if any(temp)
  child_par = strtrim(child_par(temp));
  parent_par = parent_par(temp);
  temp_par = cellfun(@(y) strtrim(y(1:12)),par_data,'UniformOutput',false);
  temp = cellfun(@(y) any(strcmp(child_par,y)),temp_par);
  par_data(temp) = strrep(par_data(temp),' log  ','  tied');
  par_data(temp) = strrep(par_data(temp),' none ','  tied');
  par_data(temp) = strrep(par_data(temp),' fixed','  tied');
  tied_data = cellfun(@(x,y) sprintf('%s  %s',x,y),child_par,parent_par,...
    'UniformOutput',false);
  % eliminate fixed parameters
  i_fix = strcmp(parent_par,'fixed');
  tied_data = tied_data(~i_fix);
  temp = cellfun(@(y) any(strcmp(y,child_par(i_fix))),temp_par);
  par_data(temp) = strrep(par_data(temp),'  tied',' fixed');
end

% Empty parent parameter case causes readtable to read weight as double
if isempty(parent_par)
    wt_cols = wt_cols.(wt_name{wt_col});
else
    wt_cols = cellfun(@(y) str2double(y),wt_cols.(wt_name{wt_col}));
end
i_wt = wt_cols>0;
% get rid of obs_data rows with weight <= 0
temp = textscan(strjoin(obs_data,'\n'),'%s%*s%*s%s');
i_delete = cellfun(@(y) any(strcmpi(y,obs_group(~i_wt))),temp{2});
temp = temp{1}(i_delete); % save deleted observations for instruction file
obs_data = obs_data(~i_delete);

wt_cols = wt_cols(i_wt);
obs_group = obs_group(i_wt);
for og = 1:length(obs_group)
  i_observ = cellfun(@(y) ~isempty(y),strfind(obs_data,obs_group{og}));
  obs_data(i_observ) = regexprep(obs_data(i_observ), ['1.00  ' obs_group{og}],...
    sprintf('%15.6e  %s',sqrt(wt_cols(og)),obs_group{og}));
end

%% update instruction files
for i=1:i_insfile
  ins_obs = cellfun(@(y) regexpi(y,'\!(.+)\!','tokens','once'),ins_line{i},...
      'UniformOutput',false);
  ins_line{i} = ins_line{i}(~cellfun(@(y) any(strcmpi(y,temp)),ins_obs));

  % write instruction files
  ins_line{i} = strjoin([{'pif @'} ins_line{i}'],'\n');
  fn = fullfile(d_root,runname,[runname sprintf('.i%02d',i)]);
  fid = fopen(fn,'wt');
  fprintf(fid,'%s',ins_line{i});
  fclose(fid);
  if i>7
    etobs_wt(i-7) = length(ins_line{i})>5;
  end
end
f_instruction = f_instruction(logical([obs_wt 1 etobs_wt])); % 1 for pot surface logical wt

%% dump file
write_file;
        
        
%% function to perpare parameter data
  function par_function
    t_param = readtable(f_param,'Sheet','pst_ManualCalibrMod');
    i_param = cellfun(@(y) ~isempty(y),t_param.PARNME); % remove rows of blank PARNME
    j_param = ~strncmp(t_param.Properties.VariableNames,'Var',3); % remove blank columns
    t_param = t_param(i_param,j_param);
    i_tied_par = isnan(t_param.PARVAL1);
    tied_par = table2cell(t_param(i_tied_par,1:2));
    t_param = t_param(~i_tied_par,:);
    i_tied_par = cellfun(@(y) ~isempty(y),tied_par(:,2));
    tied_par = tied_par(i_tied_par,:);
    fixed_par = tied_par(strcmpi(tied_par(:,2),'fixed'),1);
    tied_par = tied_par(~strcmpi(tied_par(:,2),'fixed'),:);
    if ~isempty(fixed_par)
        j = cellfun(@(y) strmatch(y,t_param.PARNME),fixed_par);
        t_param.PARTRANS(j) = {'fixed'};
    end
    if ~isempty(tied_par)
        j = cellfun(@(y) strmatch(y,t_param.PARNME),tied_par(:,1));
        t_param.PARTRANS(j) = {'tied'};
    end
        
    % check transformation
    if ~flag_parmtran
      i_temp = t_param.IHM_factor==1 & ~strncmpi(t_param.PARTRANS,'fixed',5);
      t_param.PARTRANS(i_temp) = cellstr(repmat('none',sum(i_temp),1));
    end 
        
    % parameter group
    par_group = unique(t_param.PARGP);
    for g = par_group'
        if strcmp(g,'intfw')>0
            temp = sprintf('%-13s absolute  0.01  0.0  always_3  0.5  parabolic',char(g));
        else
            temp = sprintf('%-13s relative  0.08  0.0  always_3  0.5  parabolic',char(g));
        end
      par_grpdata = [par_grpdata; {temp}];
    end 
        
    % parameter data - part1
    for i = 1:height(t_param)
      temp = sprintf('%-13s%-8s%-8s%15.5e%15.5e%15.5e%13s%5.2f%5.2f%3d',...
        strtrim(t_param.PARNME{i}),strtrim(t_param.PARTRANS{i}),strtrim(t_param.PARCHGLIM{i}),...
          t_param.PARVAL1(i),t_param.PARLBND(i),t_param.PARUBND(i),...
          strtrim(t_param.PARGP{i}),...
          t_param.SCALE(i),t_param.OFFSET(i),t_param.DERCOM(i));
      par_data = [par_data; {temp}];
    end
    
    % parameter data - part2 (tieing in parameter.xls)
    if ~isempty(tied_par)
      tied_par = arrayfun(@(y) sprintf('%-12s %-12s',tied_par{y,1},tied_par{y,2}),...
        (1:size(tied_par,1))','UniformOutput',false);
    end
  end

%% function to form observation targets
  function obs_function
    % weekly & monthly spring, stream flow, and Goundwater level
    typecode = [1,2;1,1;2,2;2,1;3,2;3,1];
    conn = database(['Driver=' dv ';Server=' sv ';Database=' f_dbout ...
        ';AttachDbFileName=' f_dbout ...
        ';Trusted_Connection=Yes;LoginTimeout=300;']);
    for i=1:6
      csv = fetch(conn,[...
        'SELECT LocationID',...
        '	,CAST(CONVERT(VARCHAR,IntervalStartDate,112) AS INT) DATE',...
        '	,ObservedIntervalMean',...
        '	,ObservedIntervalStandardDeviation',...
        '	,Residual',...
        '	,Weight ',...
        'FROM dbo.ObservedDataIntervalStats ',...
        sprintf('where DataTypeCode=%d and IntervalTypeCode=%d and ',typecode(i,1),typecode(i,2)),...
        '(IntervalStartDate between ''',data_sdate,''' and ''',data_edate,''') and ObservedIntervalStandardDeviation>0 ',...
        'ORDER BY LocationID,IntervalStartDate']);

      if obs_wt(i) <= 0, continue; end
      rgn = grp_region{i};
      form = [obsname_tpl{i} '%d  0.0 %5.2f  %s%s'];
      temp = arrayfun(@(x,y) ...
        sprintf(form,x,y,obs_wt(i),rgn([rgn.sid]==x).Region,obs_group{i}),...
        csv.LocationID,csv.DATE,'UniformOutput',false);
%         csv(:,1),csv(:,2),'UniformOutput',false);
      obs_data = [obs_data; temp];
        
      % write instruction files
      ins_line{i} = arrayfun(@(x,y) ...
        sprintf(['L1 @,@ @,@ !' obsname_tpl{i} '%d!'],x,y),...
        csv.LocationID,csv.DATE,'UniformOutput',false);
%         csv(:,1),csv(:,2),'UniformOutput',false);
    end
    
    exec(conn,['ALTER DATABASE [' f_dbout '] SET OFFLINE WITH ROLLBACK IMMEDIATE']);
    exec(conn,['exec sp_detach_db [' f_dbout ']']);
    close(conn);
    
    % add layernumber to groundwater group
    if (obs_wt(5) > 0 || obs_wt(6) > 0)
      temp = regexpi(obs_data,'gwl(\d+)_.*','tokens','once');
      i_temp = cellfun(@(y) ~isempty(y),temp);
      id_temp = cellfun(@(y) rgn([rgn.sid]==str2double(y)).Layer,temp(i_temp));
      obs_data(i_temp) = strrep(obs_data(i_temp),'lygwl',...
        arrayfun(@(x) sprintf('lygw%1d',x),id_temp,'UniformOutput',false));
    end
    
    % UFAS Potentiometric Surface
    t_potsurf = create_potsurfacetarget(d_current0,data_sdate,data_edate);
    temp = arrayfun(@(x) sprintf('POT_%-10s     %3.1f  %4.2f  %s',...
      t_potsurf.PSWellID{x},0,1,[t_potsurf.RegionName{x} '_potsur']),...
      (1:height(t_potsurf))','UniformOutput',false);
    obs_data = [obs_data; temp];
    
    % instruction file for pot surface
    i_insfile = i+1;
    ins_line{i_insfile} = cellfun(@(x) sprintf('L1 !POT_%s!',x),t_potsurf.PSWellID,...
        'UniformOutput',false);

    % ET
    for i=1:length(f_etout)
      if etobs_wt(i) <= 0, continue; end
      switch i
        case {1 2 3 4 5}
          fid = fopen(fullfile(d_etout,f_etout{i}),'r');
          csv = textscan(fid,'%d%f%f%f%f','HeaderLines',1,'Delimiter',',');
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  ' etobs_group{i}];
          temp = arrayfun(@(x) ...
            sprintf(form,x,etobs_wt(i),lsegrgn([lsegrgn.lid]==x).Region),...
            csv{1,1},'UniformOutput',false);
          obs_data = [obs_data; temp];

          % write instruction files
          i_insfile = i_insfile+1;
          ins_line{i_insfile} = arrayfun(@(x) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],x),...
            csv{1,1},'UniformOutput',false);
          
        case {6 7} % LU total & Category Total
          fid = fopen(fullfile(d_etout,f_etout{i}),'r');
          csv = textscan(fid,'%s%f%f%f%f','HeaderLines',1,'Delimiter',',');
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  ' etobs_group{i}];
          temp = arrayfun(@(x) sprintf(form,char(x),etobs_wt(i)),...
            csv{1,1},'UniformOutput',false);
          obs_data = [obs_data; temp];

          % write instruction files
          i_insfile = i_insfile+1;
          ins_line{i_insfile} = arrayfun(@(x) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],char(x)),...
            csv{1,1},'UniformOutput',false);
          
         case {8 9}
          fid = fopen(fullfile(d_etout,f_etout{i}),'r');
          csv = textscan(fid,'%d%f%f%f%f','HeaderLines',1,'Delimiter',',');
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  ' etobs_group{i}];
          temp = arrayfun(@(x) ...
            sprintf(form,x,etobs_wt(i),rchrgn([rchrgn.rid]==x).Region),...
            csv{1,1},'UniformOutput',false);
          obs_data = [obs_data; temp];

          % write instruction files
          i_insfile = i_insfile+1;
          ins_line{i_insfile} = arrayfun(@(x) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],x),...
            csv{1,1},'UniformOutput',false);

        case 10
          fid = fopen(fullfile(d_etout,f_etout{i}),'r');
          csv = textscan(fid,'%s%d%f%f%f%f',...
              'HeaderLines',1,'Delimiter',',');
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  ' etobs_group{i}];
          temp = arrayfun(@(x,y) sprintf(form,char(x),y,etobs_wt(i)),...
            csv{1,1},csv{1,2},'UniformOutput',false);
          obs_data = [obs_data; temp];

          % write instruction files
          i_insfile = i_insfile+1;
          ins_line{i_insfile} = arrayfun(@(x,y) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],char(x),y),...
            csv{1,1},csv{1,2},'UniformOutput',false);
            
      end % switch
    end % for loop
%{
    % Coastal Discharge
    obs_data = [obs_data; 'CoastalDischarge   0.0  1.00  SPRNG_CoastQ'];

    % write instruction file for Coastal Discharge
    i_insfile = i_insfile+1;
    ins_line{i_insfile} = {'L1 @,@ @,@ !CoastalDischarge!'};

    % Disconnected reach Discharge
    fid = fopen(fullfile(d_pestet,'Streamflow','DisconnectedReachDischarge.txt'),'r');
    csv = textscan(fid,'%d,%d,%f','HeaderLines',1);
    fclose(fid);
    form = 'DCReach_%d_%d  0.0  1.00  %5s_dcrDch';
    temp = arrayfun(@(x,y) sprintf(form,x,y,rchrgn([rchrgn.rid]==x).Region),...
      csv{1,1},csv{1,2},'UniformOutput',false);
    obs_data = [obs_data; temp];

    % write instruction file for Disconnected reach Discharge
    i_insfile = i_insfile+1;
    ins_line{i_insfile} = arrayfun(@(x,y) ...
      sprintf('L1 @,@ @,@ !DCReach_%d_%d!',x,y),csv{1,1},csv{1,2},...
      'UniformOutput',false);

    % skip this observation
    % Disconnected reach Hydroperiod
    fid = fopen(fullfile(d_graphicpest,'IntervalResiduals','HydroperiodIntervalResiduals_CalendarYear.txt'),'r');
    csv = textscan(fid,'%d,%d,%f,%f,%f,%f,%f','HeaderLines',1);
    fclose(fid);
    form = 'HPReach_%d_%d  0.0  1.00  %5s_dcrHyP';
    nnan = ~isnan(csv{1,7});
    temp = arrayfun(@(x,y) sprintf(form,x,y,rchrgn([rchrgn.rid]==x).Region),...
      csv{1,1}(nnan),csv{1,2}(nnan)/10000,'UniformOutput',false);
    obs_data = [obs_data; temp];

    % write instruction file for Disconnected reach Hydroperiod
    i_insfile = i_insfile+1;
    ins_line{i_insfile} = arrayfun(@(x,y) ...
      sprintf('L1 @,@ @,@ !HPReach_%d_%d!',x,y),csv{1,1}(nnan),csv{1,2}(nnan)/10000,...
      'UniformOutput',false);
%}
    
  end

%% write file out
  function write_file
    obs_grpdata = textscan(strjoin(obs_data,'\n'),'%*s%*f%*f%s');
    obs_grpdata = unique(obs_grpdata{1});

    fid = fopen(fullfile(d_root,runname,sprintf('%s.pst',runname)),'wt');

    % file signature
    fprintf(fid,'%s\n','pcf');

    % control data
    fprintf(fid,'%s\n','* control data');
    % RSTFLE PESTMODE
    fprintf(fid,'%s\n','restart  estimation');
    % NPAR NOBS NPARGP NPRIOR NOBSGP [MAXCOMDIM]
    fprintf(fid,'%6d%7d%6d%6d%6d\n',length(par_data),length(obs_data),...
      length(par_grpdata),length(pinfo_data),length(obs_grpdata));
    % NTPLFLE NINSFLE PRECIS DPOINT NUMCOM JACFILE MESSFILE
    fprintf(fid,'%5d%5d%s\n',length(f_template),length(f_instruction),...
      ' single  point  1   0   0');
    % RLAMBDA1 RLAMFAC PHIRATSUF PHIREDLAM NUMLAM [JACUPDATE]
%    fprintf(fid,'%s\n',' 50.0  2.0  0.2  0.01  10 999');
    fprintf(fid,'%s\n','  5.0  2.0  0.2  0.01  5 999 lamforgive');
    % RELPARMAX FACPARMAX FACORIG [IBOUNDSTICK] [UPVECBEND]
%    fprintf(fid,'%s\n',' 10.0  10.0  0.001 0 0');
    fprintf(fid,'%s\n',' 10.0  10.0  0.001 3 1');
    % PHIREDSWH [NOPTSWITCH] [[DOAUI] [DOSENREUSE]
    fprintf(fid,'%s\n',' 0.1  3 noaui');
    % NOPTMAX PHIREDSTP NPHISTP NPHINORED RELPARSTP NRELPAR
    fprintf(fid,'%s\n',' 2  0.005  4  4  0.005  4');
%    fprintf(fid,'%s\n','40  0.005  4  4  0.005  4');
    % ICOV ICOR IEIG
    fprintf(fid,'%s\n',' 1  1  1');
%    fprintf(fid,'%s\n',' 0  0  0');

    
    % parameter groups
    fprintf(fid,'%s\n','* parameter groups');
    % PARGPNME INCTYP DERINC DERINCLB FORCEN DERINCMUL DERMTHD
    % (one such line for each of the NPARGP parameter groups)
    for i=1:length(par_grpdata)
      fprintf(fid,'%s\n',par_grpdata{i});
    end

    
    % parameter data
    fprintf(fid,'%s\n','* parameter data');
    % PARNME PARTRANS PARCHGLIM PARVAL1 PARLBND PARUBND PARGP SCALE OFFSET DERCOM
    % (one such line for each of the NPAR parameters)
    % PARNME PARTIED
    % (one such line for each tied parameter)
    for i=1:length(par_data)
      fprintf(fid,'%s\n',par_data{i});
    end
    if ~isempty(tied_par)
      for i=1:length(tied_par)
        fprintf(fid,'%s\n',tied_par{i});
      end
    end

    % tied data (tied data in wt-scheme spreadsheet
    if ~isempty(tied_data)
      for i=1:length(tied_data)
        fprintf(fid,'%s\n',tied_data{i});
      end      
    end
    
    % observation groups
    fprintf(fid,'%s\n','* observation groups');
    % OBGNME
    % (one such line for each observation group)
    for i=1:length(obs_grpdata)
      fprintf(fid,'%s\n',obs_grpdata{i});
    end

    
    % observation data
    fprintf(fid,'%s\n','* observation data');
    % OBSNME OBSVAL WEIGHT OBGNME
    % (one such line for each of the NOBS observations)
    for i=1:length(obs_data)
      fprintf(fid,'%s\n',obs_data{i});
    end

    
    % model command line
    fprintf(fid,'%s\n','* model command line');
    % write the command which PEST must use to run the model
    fprintf(fid,'powershell -command "%s -r %s"\n','.\Invoke-Model.ps1',runname);

    
    % model input/output
    fprintf(fid,'%s\n','* model input/output');

    % TEMPFLE INFLE
    % (one such line for each model input file containing parameters)
    for i=1:length(f_template)
      fprintf(fid,'%s\n',f_template{i});
    end

    % INSFLE OUTFLE
    % (one such line for each model output file containing observations)
%     for i=1:length(f_instruction)
    for i=1:length(f_instruction)
      fprintf(fid,'%s\n',f_instruction{i});
    end


    % prior information
    fprintf(fid,'%s\n','* prior information');
    % PILBL PIFAC * PARNME + PIFAC * log(PARNME) ... = PIVAL WEIGHT OBGNME
    % (one such line for each of the NPRIOR articles of prior information)
    
    
    fclose(fid);
  end

end