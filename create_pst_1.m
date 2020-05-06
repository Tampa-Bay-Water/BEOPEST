function create_pst(d_master,runname,wt_col,flag_parmtran)
% Script to create PPEST *.pst

if nargin < 1 || isempty(d_master)
  d_master = '\\kuhntucker\e$\ihm\ppest_20070420';
end
if nargin < 2, runname = 'pp_test'; end
if nargin < 3, wt_col = 49; end
if nargin < 4, flag_parmtran = true; end

%% path and files for creation of parameters data
f_param = 'parameters_1.xls';
f_weight = fullfile(d_master,'ObsWeightSchemes_1.xls');
d_graphicpest = fullfile(d_master,'Graphics_Pest_20070707');

%% paths and files for creation of observation targets
d_output = fullfile(d_graphicpest,'IntervalResiduals');
f_output = {...
  'SpringIntervalResiduals_CalendarWeek.txt';...
  'SpringIntervalResiduals_CalendarMonths.txt';...
  'StreamflowIntervalResiduals_CalendarWeek.txt';...
  'StreamflowIntervalResiduals_CalendarMonths.txt';...
  'WellIntervalResiduals_CalendarWeek.txt';...
  'WellIntervalResiduals_CalendarMonths.txt';...
  };
obs_group = {...
  '_wlyspr';...
  '_mlyspr';...
  '_wlystf';...
  '_mlystf';...
  '_wlygwl';...
  '_mlygwl';...
};
obs_wt = [1,1,1,1,1,1];
obsname_tpl  = {...
  'spr%03d_wkly';...
  'spr%03d_mnly';...
  'stf%03d_wkly';...
  'stf%03d_mnly';...
  'gwl%03d_wkly';...
  'gwl%03d_mnly';...
};

% Observation target for ET by landuse class
d_etout = fullfile(d_graphicpest,'ET');
f_etout = {...
  'ETByLandUseData\Agric_Irrigated.txt';...
  'ETByLandUseData\Forested.txt';...
  'ETByLandUseData\Grass_Pasture.txt';...
  'ETByLandUseData\Mining_Other.txt';...
  'ETByLandUseData\Urban.txt';...
  'ETByLandUseData\ETByLandUseTotals.txt';...
  'ETByReachData\ETByCategoryTotals.txt';...
  'ETByReachData\LimitedMoisture.txt';...
  'ETByReachData\UnlimitedMoisture.txt';...
  'MonthlyETData\MonthlyET.txt';...
  };
etobs_group = {...
  'ET_LUAgrIrr';... 1  8
  'ET_LUForest';... 2  9
  'ET_LUGrass';...  3  10
  'ET_LUMining';... 4  11
  'ET_LUUrban';...  5  12
  'ET_LUTotal';...  6  13
  'ET_RchCatTot';...7  14
  'ET_RchLimMoi';...8  15
  'ET_RchUnlimM';...9  16
  'ET_MLYCoeff';... 10 17
};
etobs_wt = [1,1,1,1,1,1,1,1,1,1];
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
conn = database('KT_INTB2','lagrange_remote','password');
sql = [...
        'SELECT OW.ObservedWellID AS WID, RGN.Name AS Region ',...
        'FROM ObservedWell AS OW INNER JOIN ',...
        'INTB_2_MDB...Region AS RGN ON OW.RegionID = RGN.RegionID'...
    ];
curs = exec(conn, sql);
curs = fetch(curs);
wellrgn = struct('sid',curs.Data(:,1),'Region',curs.Data(:,2));
sql = [...
        'SELECT FS.FlowStationID AS SID, RGN.Name AS Region ',...
        'FROM FlowStation AS FS INNER JOIN ',...
        'INTB_2_MDB...Region AS RGN ON FS.RegionID = RGN.RegionID'...
    ];
curs = exec(conn, sql);
curs = fetch(curs);
strmrgn = struct('sid',curs.Data(:,1),'Region',curs.Data(:,2));
sql = [...
        'SELECT     SP.SpringID AS SID, RGN.Name ',...
        'FROM Spring AS SP INNER JOIN ',...
        'INTB_2_MDB...Region AS RGN ON SP.RegionID = RGN.RegionID'...
    ];
curs = exec(conn, sql);
curs = fetch(curs);
sprgrgn = struct('sid',curs.Data(:,1),'Region',curs.Data(:,2));
close(curs);
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
  ' pp_test.i18  pp_test.o18';... % Coastal Discharge
  ' pp_test.i19  pp_test.o19';... % disconnected reach Discharge
  ' pp_test.i20  pp_test.o20';... % disconnected reach Hydroperiod
  },'pp_test',runname);
f_inst = arrayfun(@(x) sprintf('%s.i%02d',runname,x),...
  (1:length(f_instruction))','UniformOutput',false);


%% process data
% parameter
par_grpdata = [];
par_data = [];
tie_data = [];
par_function;

% observation (target)
obs_grpdata = [];
obs_data = [];
obs_function;
obs_grpdata = unique(obs_grpdata);

% prior information data
pinfo_data = [];

%% insensitive parameters
param_insens = {
	'BLeak1010_3 ',...
	'BLeak1020_3 ',...
	'BLeak1030_3 ',...
	'BLeak110_3  ',...
	'BLeak120_3  ',...
	'BLeak1210_3 ',...
	'BLeak1220_3 ',...
	'BLeak130_3  ',...
	'BLeak1320_3 ',...
	'BLeak1330_3 ',...
	'BLeak220_3  ',...
	'BLeak310_3  ',...
	'BLeak320_3  ',...
	'BLeak330_3  ',...
	'BLeak410_3  ',...
	'BLeak430_3  ',...
	'BLeak450_3  ',...
	'BLeak480_3  ',...
	'BLeak610_3  ',...
	'BLeak620_3  ',...
	'BLeak630_3  ',...
	'BLeak640_3  ',...
	'BLeak710_3  ',...
	'BLeak720_3  ',...
	'BLeak740_3  ',...
	'BLeak830_3  ',...
	'BLeak840_3  ',...
	'BLeak860_3  ',...
	'BLeak920_3  ',...
	'BLeak930_3  ',...
	'DSChannel   ',...
	'DSOpenWater ',...
	'EIAFMOther  ',...
	'GCond       ',...
	'MPETCWBPMDL ',...
	'MPETCWLVeep ',...
	'MPETCWLake  ',...
	'MPETCWSC    ',...
	'RCA_10102   ',...
	'RCA_11102   ',...
	'RCA_11202   ',...
	'RCA_11302   ',...
	'RCA_12102   ',...
	'RCA_13202   ',...
	'RCA_1500    ',...
	'RCA_2302    ',...
	'RCA_4102    ',...
	'RCA_4502    ',...
	'RCA_4802    ',...
	'RCA_6102    ',...
	'RCA_6202    ',...
	'RCA_8302    ',...
	'RCA_8602    ',...
	'RCA_8700    ',...
	'RCA_9202    ',...
	'RCA_9302    ',...
	'RZDWBPMDL   ',...
	'RZDWLVDeep  ',...
	'RZDWLake    ',...
	'RZDWSC      ',...
	'cs00        ',...
	'cs03        ',...
	'cs05        ',...
	'cs06        ',...
	'cs07        ',...
	'cs08        ',...
	'cs10        ',...
	'cs11        ',...
	'cs13        ',...
	'cs14        ',...
	'cs17        ',...
	'cs19        ',...
	'cs20        ',...
	'cs21        ',...
	'lk000       ',...
	'lk029       ',...
	'lk059       ',...
	'lk060       ',...
	'lk066       ',...
	'lk077       ',...
	'lk106       ',...
	'lk152       ',...
	'tm000       ',...
	'us00        ',...
	'us03        ',...
	'us05        ',...
	'us06        ',...
	'us07        ',...
	'us08        ',...
	'us10        ',...
	'us11        ',...
	'us13        ',...
	'us14        ',...
	'us17        ',...
	'us19        ',...
	'us20        ',...
	'us21        '};
	
        
temp = cellfun(@(y) sum(strncmpi(param_insens,y,12))>0,par_data);
par_data(temp) = strrep(par_data(temp),' log  ',' fixed');
par_data(temp) = strrep(par_data(temp),' none ',' fixed');


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
parent_par = parent_par(:,wt_col);
temp = arrayfun(@(y) ~isempty(parent_par{y}),1:length(parent_par))';
tied_data = [];
if sum(temp)>0
  child_par = child_par(temp);
  parent_par = parent_par(temp);
  temp = cellfun(@(y) sum(strncmpi(child_par,y,12))>0,par_data);
  par_data(temp) = strrep(par_data(temp),' log  ','  tied');
  par_data(temp) = strrep(par_data(temp),' none ','  tied');
  tied_data = cellfun(@(x,y) sprintf('%s  %s',x,y),child_par,parent_par,...
    'UniformOutput',false);
end
wt_cols = wt_cols(:,wt_col);
for og = 1:length(obs_group)
  temp = cellfun(@(y) ~isempty(y),strfind(obs_data,obs_group{og}));
  obs_data(temp) = regexprep(obs_data(temp), ['1.00  ' obs_group{og}],...
    sprintf('%15.6e  %s',sqrt(wt_cols(og)),obs_group{og}));
end


%% dump file
write_file;
        
        
%% function to perpare parameter data
  function par_function
    [xlsnum,xlstxt] = xlsread(fullfile(d_master,f_param));
    %heading = xlstxt(1,:);
    rows = size(xlsnum,1);
    tie_data = xlstxt((rows+2):end,1:2);
    xlstxt = xlstxt((1:rows)+1,:);
        
    % check transformation
    if ~flag_parmtran
      i_temp = xlsnum(:,9)==1 & ~strncmpi(xlstxt(:,2),'fixed',5);
      xlstxt(i_temp,2) = cellstr(repmat('none',sum(i_temp),1));
    end 
        
    % parameter group
    par_group = unique(xlstxt(:,7));
    for g = par_group'
      temp = sprintf('%-13s relative  0.05  0.0  always_2  2.0  parabolic',char(g));
      par_grpdata = [par_grpdata; {temp}];
    end 
        
    % parameter data - part1
    for i = 1:size(xlsnum,1)
      % check for tied paramter and update
      if (~isempty(tie_data)) && (strmatch(xlstxt(i,1),tie_data(:,1),'exact')>0)
          xlstxt{i,2} = 'tied';
      end
      temp = sprintf('%-13s%-8s%-8s%15.5e%15.5e%15.5e%13s%5.2f%5.2f%3d',...
        xlstxt{i,1},xlstxt{i,2},xlstxt{i,3},xlsnum(i,1:3),xlstxt{i,7},xlsnum(i,5:7));
      par_data = [par_data; {temp}];
    end
    
    % parameter data - part2 (tieing in parameter.xls)
    if ~isempty(tie_data)
      tie_data = arrayfun(@(y) sprintf('%-12s %-12s',tie_data{y,1},tie_data{y,2}),...
        (1:size(tie_data,1))','UniformOutput',false);
    end
  end

%% function to form observation targets
  function obs_function
    % weekly & monthly spring, stream flow, and Goundwater level
    for i=1:length(f_output)
      fid = fopen(fullfile(d_output,char(f_output{i})),'r');
      csv = textscan(fid,'%d,%d,%f,%f,%f,%f,%f','headerlines',1);
      fclose(fid);
      temp_i = csv{1,2}>19960000 & csv{1,2} < 19980000 & ~isnan(csv{1,6});
      rgn = grp_region{i};
      form = [obsname_tpl{i} '%d  0.0 %5.2f  %s%s'];
      temp = arrayfun(@(x,y) ...
        sprintf(form,x,y,obs_wt(i),rgn([rgn.sid]==x).Region,obs_group{i}),...
        csv{1,1}(temp_i),csv{1,2}(temp_i),'UniformOutput',false);
      obs_data = [obs_data; temp];
      obs_grpdata = [obs_grpdata; arrayfun(@(x) [rgn([rgn.sid]==x).Region,obs_group{i}],...
          csv{1,1}(temp_i),'UniformOutput',false)];
        
      % write instruction files
      line = arrayfun(@(x,y) ...
        sprintf(['L1 @,@ @,@ !' obsname_tpl{i} '%d!'],x,y),...
        csv{1,1}(temp_i),csv{1,2}(temp_i),'UniformOutput',false);
      fid = fopen(fullfile(d_master,char(f_inst{i})),'wt');
      fprintf(fid,'%s\n','pif @');
      line{1} = strrep(line{1},'L1','L3');
      for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
      fclose(fid);
      
      % % Create from Swt structure
      % locids = [Swt_weeklySPRG.StaID];
      % datestart = cellfun(@(y) datestr(datenum(y,23),'yyyymmdd'),[Swt_weeklySPRG.WeekStart],...
      %   'UniformOutput',false);
      % %datestart = reshape(datestart,size(datestart,1)*size(datestart,2),1);
      % temp = isnan([Swt_weeklySPRG.AvgValue]) | isnan([Swt_weeklySPRG.Weight]) | isnan([Swt_weeklySPRG.Stdev]);
      % locids = num2cell(repmat(locids,size(temp,1),1));
      % temp = reshape(~temp,size(temp,1)*size(temp,2),1);
      % 
      % res = cellfun(@(x,y) sprintf('!spr%03d_wkly%s!',x,y),locids(temp),datestart(temp),...
      %   'UniformOutput',false);
    end
    
    % UFAS Potentiometric Surface
    [xlsnum,xlstxt] = xlsread(fullfile(d_master,'PSPointsForPEST.xls'),'Data');
    wellid = xlstxt(2:end,1); % get rid of heading    
    temp = cellfun(@(x) sprintf('POT_%-10s     %3.1f  %4.2f  %s',...
      x,0,1,'POTSURFACE'),wellid,'UniformOutput',false);
    obs_data = [obs_data; temp];
    obs_grpdata = [obs_grpdata; {'PotSurface'}];
    
    % instruction file for pot surface
    line = cellfun(@(x) sprintf('L1 !POT_%s!',x),wellid,'UniformOutput',false);
    fid = fopen(fullfile(d_master,char(f_inst{i+1})),'wt');
    fprintf(fid,'%s\n','pif @');
    for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
    fclose(fid);

    % Coastal Discharge
    obs_data = [obs_data; 'CoastalDischarge  0.0  1.00  CoastalDisch'];
    obs_grpdata = [obs_grpdata; 'CoastalDisch'];

    % write instruction file for Coastal Discharge
    line = 'L1 @,@ @,@ !CoastalDischarge!';
    fid = fopen(fullfile(d_master,char(f_inst{18})),'wt');
    fprintf(fid,'%s\n','pif @');
    fprintf(fid,'%s\n',line);
    fclose(fid);

    % Disconnected reach Discharge
    fid = fopen(fullfile(d_graphicpest,'Streamflow','DisconnectedReachDischarge.txt'),'r');
    csv = textscan(fid,'%d,%d,%f','headerlines',1);
    fclose(fid);
    form = 'DCReach_%d_%d  0.0  1.00  DConnReachQ';
    temp = arrayfun(@(x,y) sprintf(form,x,y),csv{1,1},csv{1,2},...
      'UniformOutput',false);
    obs_data = [obs_data; temp];
    obs_grpdata = [obs_grpdata; 'DConnReachQ'];

    % write instruction file for Disconnected reach Discharge
    line = arrayfun(@(x,y) ...
      sprintf('L1 @,@ @,@ !DCReach_%d_%d!',x,y),csv{1,1},csv{1,2},...
      'UniformOutput',false);
    fid = fopen(fullfile(d_master,char(f_inst{19})),'wt');
    fprintf(fid,'%s\n','pif @');
    for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
    fclose(fid);

    % Disconnected reach Hydroperiod
    fid = fopen(fullfile(d_graphicpest,'IntervalResiduals','HydroperiodIntervalResiduals_CalendarYear.txt'),'r');
    csv = textscan(fid,'%d,%d,%f,%f,%f,%f,%f','headerlines',1);
    fclose(fid);
    form = 'HPReach_%d_%d  0.0  1.00  DConnReachHP';
    nnan = ~isnan(csv{1,7});
    temp = arrayfun(@(x,y) sprintf(form,x,y),csv{1,1}(nnan),csv{1,2}(nnan)/10000,...
      'UniformOutput',false);
    obs_data = [obs_data; temp];
    obs_grpdata = [obs_grpdata; 'DConnReachHP'];

    % write instruction file for Disconnected reach Hydroperiod
    line = arrayfun(@(x,y) ...
      sprintf('L1 @,@ @,@ !HPReach_%d_%d!',x,y),csv{1,1}(nnan),csv{1,2}(nnan)/10000,...
      'UniformOutput',false);
    fid = fopen(fullfile(d_master,char(f_inst{20})),'wt');
    fprintf(fid,'%s\n','pif @');
    for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
    fclose(fid);

    % ET
    for i=1:length(f_etout)
      switch i
        case {1 2 3 4 5 8 9}
          fid = fopen(fullfile(d_etout,char(f_etout{i})),'r');
          csv = textscan(fid,'%d,%f,%f,%f,%f','headerlines',1);
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  %s'];
          temp = arrayfun(@(x) ...
            sprintf(form,x,etobs_wt(i),etobs_group{i}),...
            csv{1,1},'UniformOutput',false);
          obs_data = [obs_data; temp];
          obs_grpdata = [obs_grpdata; etobs_group{i}];

          % write instruction files
          line = arrayfun(@(x) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],x),...
            csv{1,1},'UniformOutput',false);
          fid = fopen(fullfile(d_master,char(f_inst{i+7})),'wt');
          fprintf(fid,'%s\n','pif @');
          for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
          fclose(fid);
          
        case {6 7} % LU total & Category Total
          fid = fopen(fullfile(d_etout,char(f_etout{i})),'r');
          csv = textscan(fid,'%s,%f,%f,%f,%f',...
              'headerlines',1,'Whitespace',',');
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  %s'];
          temp = arrayfun(@(x) ...
            sprintf(form,char(x),etobs_wt(i),etobs_group{i}),...
            csv{1,1},'UniformOutput',false);
          obs_data = [obs_data; temp];
          obs_grpdata = [obs_grpdata; etobs_group{i}];

          % write instruction files
          line = arrayfun(@(x) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],char(x)),...
            csv{1,1},'UniformOutput',false);
          fid = fopen(fullfile(d_master,char(f_inst{i+7})),'wt');
          fprintf(fid,'%s\n','pif @');
          for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
          fclose(fid);
          
        case 10
          fid = fopen(fullfile(d_etout,char(f_etout{i})),'r');
          csv = textscan(fid,'%s,%f,%f,%f,%f,%f',...
              'headerlines',1,'Whitespace',',');
          fclose(fid);
          form = [etobsname_tpl{i} '  0.0 %5.2f  %s'];
          temp = arrayfun(@(x,y) ...
            sprintf(form,char(x),y,etobs_wt(i),etobs_group{i}),...
            csv{1,1},csv{1,2},'UniformOutput',false);
          obs_data = [obs_data; temp];
          obs_grpdata = [obs_grpdata; etobs_group{i}];

          % write instruction files
          line = arrayfun(@(x,y) ...
            sprintf(['L1 @,@ @,@ !' etobsname_tpl{i} '!'],char(x),y),...
            csv{1,1},csv{1,2},'UniformOutput',false);
          fid = fopen(fullfile(d_master,char(f_inst{i+7})),'wt');
          fprintf(fid,'%s\n','pif @');
          for j = 1:length(line), fprintf(fid,'%s\n',char(line{j})); end
          fclose(fid);
            
      end % switch
      
    end
  end

%% write file out
  function write_file
    fid = fopen(fullfile(d_master,sprintf('%s.pst',runname)),'wt');

    % file signature
    fprintf(fid,'%s\n','pcf');

    % control data
    fprintf(fid,'%s\n','* control data');
    % RSTFLE PESTMODE
    fprintf(fid,'%s\n','restart  estimation');
    % NPAR NOBS NPARGP NPRIOR NOBSGP [MAXCOMDIM]
    fprintf(fid,'%6d%6d%6d%6d%6d\n',length(par_data),length(obs_data),...
      length(par_grpdata),length(pinfo_data),length(obs_grpdata));
    % NTPLFLE NINSFLE PRECIS DPOINT NUMCOM JACFILE MESSFILE
    fprintf(fid,'%5d%5d%s\n',length(f_template),length(f_instruction),...
      ' single  point  1   0   0');
    % RLAMBDA1 RLAMFAC PHIRATSUF PHIREDLAM NUMLAM [JACUPDATE]
    fprintf(fid,'%s\n',' 50.0  2.0  0.2  0.01  10 999');
%    fprintf(fid,'%s\n','  0.0  2.0  0.2  0.01  10 999');
    % RELPARMAX FACPARMAX FACORIG [IBOUNDSTICK] [UPVECBEND]
%    fprintf(fid,'%s\n',' 10.0  10.0  0.001 0 0');
    fprintf(fid,'%s\n',' 10.0  10.0  0.001 3 1');
    % PHIREDSWH [NOPTSWITCH] [[DOAUI] [DOSENREUSE]
    fprintf(fid,'%s\n',' 0.1  3 noaui');
    % NOPTMAX PHIREDSTP NPHISTP NPHINORED RELPARSTP NRELPAR
    fprintf(fid,'%s\n','-1  0.005  4  4  0.005  4');
%    fprintf(fid,'%s\n','10  0.005  4  4  0.005  4');
    % ICOV ICOR IEIG
%    fprintf(fid,'%s\n',' 1  1  1');
    fprintf(fid,'%s\n',' 0  0  0');

    
    % parameter groups
    fprintf(fid,'%s\n','* parameter groups');
    % PARGPNME INCTYP DERINC DERINCLB FORCEN DERINCMUL DERMTHD
    % (one such line for each of the NPARGP parameter groups)
    for i=1:length(par_grpdata)
      fprintf(fid,'%s\n',char(par_grpdata{i}));
    end

    
    % parameter data
    fprintf(fid,'%s\n','* parameter data');
    % PARNME PARTRANS PARCHGLIM PARVAL1 PARLBND PARUBND PARGP SCALE OFFSET DERCOM
    % (one such line for each of the NPAR parameters)
    % PARNME PARTIED
    % (one such line for each tied parameter)
    for i=1:length(par_data)
      fprintf(fid,'%s\n',char(par_data{i}));
    end
    if ~isempty(tie_data)
      for i=1:length(tie_data)
        fprintf(fid,'%s\n',tie_data{i});
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
      fprintf(fid,'%s\n',char(obs_grpdata{i}));
    end

    
    % observation data
    fprintf(fid,'%s\n','* observation data');
    % OBSNME OBSVAL WEIGHT OBGNME
    % (one such line for each of the NOBS observations)
    for i=1:length(obs_data)
      fprintf(fid,'%s\n',char(obs_data{i}));
    end

    
    % model command line
    fprintf(fid,'%s\n','* model command line');
    % write the command which PEST must use to run the model
    fprintf(fid,'powershell -command "&{%s -r %s}"\n','.\Invoke-Model.ps1',runname);

    
    % model input/output
    fprintf(fid,'%s\n','* model input/output');

    % TEMPFLE INFLE
    % (one such line for each model input file containing parameters)
    for i=1:length(f_template)
      fprintf(fid,'%s\n',char(f_template{i}));
    end

    % INSFLE OUTFLE
    % (one such line for each model output file containing observations)
    for i=1:length(f_instruction)
      fprintf(fid,'%s\n',char(f_instruction{i}));
    end


    % prior information
    fprintf(fid,'%s\n','* prior information');
    % PILBL PIFAC * PARNME + PIFAC * log(PARNME) ... = PIVAL WEIGHT OBGNME
    % (one such line for each of the NPRIOR articles of prior information)
    
    
    fclose(fid);
  end

end