function S=plotComSen_dce(j,d_scenario,runname,par_cellarray,obs_cellarray,...
    wt_cols,wt_name,obs_group,child_par,parent_par)
% j : weight column number to be processed
% d_scenario : master's PPEST root directory
% runname : name of the current run
% par_cellarray : cell array of parameters attribute table
% obs_cellarray : cell array of observation attribute table
% wt_cols : matrix of weights
% wt_name : weight column header
% obs_group : list of observation groups
% child_par : list of tied child parameters (left most column in the
%   tied and fixed parameters part of the spreadsheet)
% parent_par : list of tied parent parameters

% check if executing under workers on MDCE
if isempty(regexpi(cd,'vgrid\d\d\_worker'))
  flag_nograph = true;
else
  flag_nograph = false;
end


%% run under the mfile directory - is this necessary?
cd(fileparts(mfilename('fullpath')));

par_value = par_cellarray(:,[1,3]);
par_trans = par_cellarray(:,[1,4]);
obs_resid = [obs_cellarray{:,4}]';


%% read jacobian
% runname may contain iteration number
t_runname = char(regexpi(runname,'(bp_\d+).*','tokens','once'));
f_jco = fullfile(d_scenario,runname,[t_runname '.jco']);
jac = get_jco(f_jco);

% check consistency of jac
[nr,nc] = size(jac);
nobs = size(obs_cellarray,1);
npar = size(par_cellarray,1);
if nr~=nobs | nc~=npar %#ok<OR2>
    error('Size of Jacobian matrix in conflict with existing data');
end

% set observation weight and reduce jacobian if wt elements contain zeros
% that is deliberately remove those rows of jac with wt==0
wt = set_obswt([obs_group num2cell(wt_cols(:,j))]);

i_jac_del = wt<=1e-2;
% 
% % Eliminate rows with Jacobian elements are all zeros
% i_jac_del = i_jac_del | arrayfun(@(y) sum(abs(jac(y,:)))<=1e-2,[1:nobs]');

nobs = sum(~i_jac_del);
wt = wt(~i_jac_del);
jac = jac(~i_jac_del,:);
obs_cellarray = obs_cellarray(~i_jac_del,:);
obs_resid = obs_resid(~i_jac_del);

%% plot by weight columns
% Create permutable matrix to modified jac according to tie and fix
if ~isempty(child_par) & any(cellfun(@(y) ~isempty(y),parent_par(:,j))) %#ok<AND2>
    permute_jac = eye(npar);
    % identifiers for log, fix, and tie elements
    i_fix = cellfun(@(y) ~isempty(y),regexpi(parent_par(:,j),'fixed'));
    i_tie = cellfun(@(y) ~isempty(y),parent_par(:,j));
    i_tie = i_tie & ~i_fix;
% the folowing code break in newer version MATLAB
%     temp = cellfun(@(y) par_trans{strmatch(y,par_trans(:,1)),2},...
%         child_par,'UniformOutput',false);
%     i_log = i_tie & cellfun(@(y) ~isempty(y),regexpi(temp,'log'));

    i_log = i_tie;
    i_temp = cellfun(@(y) any(cell2mat(regexp(child_par(i_tie),y))),...
      par_cellarray(:,1));
    i_log(i_tie) = strncmp(par_trans(i_temp,2),'log',3);
    
    % make sure parameter names are 12 chars wide
    parent_par(i_tie,j) = cellfun(@(y) sprintf('%-12s',y),parent_par(i_tie,j),...
      'UniformOutput',false);
    
    % check that no parent of tied parameters is a fixed parameter
    % fixed in weight-scheme spreadsheet
    temp = cellfun(@(y) strmatch(y,child_par(i_fix)),parent_par(i_tie,j),...
      'UniformOutput',false);
    temp = cellfun(@(y) ~isempty(y),temp);
    if any(temp)
      error('Can''t have a parent of tied parameters as a fixed parameter!');
    end
    % fixed in .pst file
    temp = cellfun(@(y) par_trans{strmatch(y,par_trans(:,1)),2},...
        parent_par(i_tie,j),'UniformOutput',false);
    temp = cellfun(@(y) ~isempty(y),regexpi(temp,'fixed'));
    if any(temp)
      error('Can''t have a parent of tied parameters as a fixed parameter!');
    end

    % determine deleting columns
    if any(i_fix)
        j_jac_del = cellfun(@(y) strmatch(y,par_cellarray(:,1)),child_par(i_fix));
    else
        j_jac_del = []; 
    end
    if any(i_tie)
        i_jac_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),child_par(i_tie));
        j_jac_del = [j_jac_del; i_jac_tie]; 
        % determine ratios, rows (i_jac_tie) and columns (j_jac_tie) to place the ratio
        j_jac_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),parent_par(i_tie,j));
        tied_ratio = arrayfun(@(y) par_value{y,2},i_jac_tie)...
            ./arrayfun(@(y) par_value{y,2},j_jac_tie);
%         log_ratio = log10(arrayfun(@(y) par_value{y,2},i_jac_tie))...
%             ./log10(arrayfun(@(y) par_value{y,2},j_jac_tie));
%         tied_ratio(i_log) = log_ratio(i_log);

        % set tied_ratio for log-pairs to one - see Chin Man's derivation 8/30/2007
        if length(tied_ratio)>sum(i_log)
          tied_ratio(i_log) = ones(size(tied_ratio(i_log)));
        else
          tied_ratio = ones(size(tied_ratio));
        end
        for it = 1:length(tied_ratio)
            permute_jac(i_jac_tie(it),j_jac_tie(it)) = tied_ratio(it);
        end
    end
    j_jac = setdiff(1:npar,j_jac_del);
    par_cellarray = par_cellarray(j_jac,:);
    permute_jac = permute_jac(:,j_jac);
    jac = jac*permute_jac;
    npar = size(jac,2);
    if any(i_tie)
      j_jac_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),parent_par(i_tie,j));
    end
    clear permute_jac j_jac_del i_jac_tie i_tie i_fix i_log log_ratio tied_ratio;
end

% parameter sensitivity
par_csen = spdiags(wt,0,nobs,nobs);
par_csen = full(diag(jac'*par_csen*jac,0));
% It seem impossible to have a negative element in the diagonal matrix.
% But I have seen one before, so I will trap it here.
par_csen(par_csen<0) = 0;
par_csen = sqrt(par_csen)/nobs;
par_cellarray(:,3) = num2cell(par_csen);

% percent to the overall max sensitivity
max_csen = max(par_csen);
par_cellarray(:,4) = num2cell(par_csen/max_csen*100);

% covariance, correlation matrices and eigen system
j_jac_del = par_csen < 1e-4;
%j_jac_del = par_csen < 5e-3;
% make sure the deleting columns are not one of tieing parents
temp = whos('j_jac_tie');
if ~isempty(temp) && temp.bytes>0
  temp = true(size(j_jac_del));
  temp(j_jac_tie) = false;
  j_jac_del = j_jac_del & temp;
end
npar = sum(~j_jac_del);
refvar = sum(obs_resid.*obs_resid.*wt)/(nobs-npar);
jac = jac(:,~j_jac_del);
% determine cofactor matrix
Q = spdiags(wt,0,nobs,nobs);
% par_cov = inv(jac'*par_cov*jac)*refvar;
par_cov = jac'*Q*jac;
par_cov = par_cov\eye(length(par_cov));
% update vector
par_cellarray(~j_jac_del,6) = num2cell(par_cov*jac'*Q*obs_resid);
par_cov = par_cov*refvar;

% observation and parameter stdevs
par_stdev = NaN(size(par_csen));
% if not enough small value elements eliminated, problem may arise when
% matrix is inverted above. Better trap the negative element here.
temp = full(diag(par_cov,0));
temp(temp<0) = 0;
% % stdev of target
% % the followng formular requires full obs_cov which can be time consuming
% % obs_cov = jac*par_cov*jac'; obs_std = sqrt(spdiags(obs_cov,0));
if size(obs_cellarray,2) > 5
  jacoffset = jac*[par_cellarray{~j_jac_del,6}]';
  obs_cellarray(:,9) = num2cell(abs(jacoffset));
%   obs_cellarray(:,6) = num2cell(...
%     arrayfun(@(y) sqrt(jac(y,:)*par_cov*jac(y,:)'+jacoffset(y)^2),1:size(jac,1))');
  %if optimum_stdev_dce(), return; end
  obs_cellarray(:,6) = num2cell(sqrt(...
    cell2mat(obs_cellarray(:,8)).^2 + cell2mat(obs_cellarray(:,9)).^2));
end
% observation sensitivity
obs_cellarray(:,5) = num2cell(sqrt(sum(jac.^2,2).*wt)/npar);
obs_cellarray(:,3) = num2cell(sqrt(wt));
% change in observation residuals
% obs_cellarray(:,5) = num2cell((jac*[par_cellarray{~j_jac_del,6}]').*sqrt(wt));

% stdev of parameter
par_stdev(~j_jac_del) = sqrt(temp); % so the NaN values will appear for the non-sensitive parameters
par_cellarray(:,5) = num2cell(par_stdev);
clear jac Q;

% % No observation related output
% S = struct(...
%   'Parameter',cell2struct(par_cellarray,...
%     {'Parameter','ParGroup','Sensitivity','PercentSens','Stdev','Update'},2),...
%     'Covariance',par_cov);

% Include observation output
if size(obs_cellarray,2) <= 5
  S = struct(...
    'Parameter',cell2struct(par_cellarray,...
      {'Parameter','ParGroup','Sensitivity','PercentSens','Stdev','Update'},2),...
    'Covariance',par_cov,...
    'Observation',cell2struct(obs_cellarray,...
        {'Observation','ObsGroup','Weight','Resid','Sensitivity'},2));
else
  S = struct(...
    'Parameter',cell2struct(par_cellarray,...
      {'Parameter','ParGroup','Sensitivity','PercentSens','Stdev','Update'},2),...
    'Covariance',par_cov,...
    'Observation',cell2struct(obs_cellarray,...
      {'Observation','ObsGroup','Weight','IterationResid','Sensitivity','SqrtM2',...
        'FinalResid','OptStdev','OffsetStdev'},2));
end
clear par_cov;

% assignin('base','Stemp',S);
if flag_nograph, return; end

%% Read common shapefiles
GEOcoastline = shaperead([d_scenario '\shapefiles\INTBcoastline.shp']);
GEOwellfield = shaperead([d_scenario '\shapefiles\INTBwellfield.shp']);
GEOcounty    = shaperead([d_scenario '\shapefiles\INTBcounty.shp']);
GEOextend    = shaperead([d_scenario '\shapefiles\INTB_extend.shp']);

%% shape of parameter zones
params = {'lk','tm','us','cs','bl1','bl3','RCAcondconn','RCAconn','RCAroute','inf','sc'};
GEO_ParZone = cell(size(params));
for kk = 1:length(params)
  GEO_ParZone{kk} = shaperead([d_scenario '\shapefiles\' params{kk} '_Zone.shp']);
end
par_title = {'Leakance';'Transmissivity';'Unconfined Storage';'Confined Storage';...
  'Bed Leakance Layer1';'Bed Leakance Layer3';...
  'RCA Conditionally Connected Reach';'RCA Connected Reach';'RCA Routing Reach';...
  'Infiltration';'Spring Conductance'};

%% plot maps of sensitivity
senmap1();
stdmap();


%% function to plot sensitivity map for each weight pair
function senmap1

% colormap
h = figure;
cmap = colormap(jet(9));
close(h);
senspec = cell(11,1);
senspec([1 2 3 4 7 8 10]) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'PercSen',[1e-4 0.33],'FaceColor',cmap(1,:),'LineWidth',0.1}, ...
    {'PercSen',[0.33 0.67],'FaceColor',cmap(2,:),'LineWidth',0.1}, ...
    {'PercSen',[0.67 1.00],'FaceColor',cmap(3,:),'LineWidth',0.1}, ...
    {'PercSen',[1.00 3.33],'FaceColor',cmap(4,:),'LineWidth',0.1}, ...
    {'PercSen',[3.33 6.67],'FaceColor',cmap(5,:),'LineWidth',0.1}, ...
    {'PercSen',[6.67 10.0],'FaceColor',cmap(6,:),'LineWidth',0.1}, ...
    {'PercSen',[10.0 33.3],'FaceColor',cmap(7,:),'LineWidth',0.1}, ...
    {'PercSen',[33.3 66.7],'FaceColor',cmap(8,:),'LineWidth',0.1}, ...
    {'PercSen',[66.6 100.],'FaceColor',cmap(9,:),'LineWidth',0.1})};
senspec([5 6 9 11]) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'PercSen',[1e-4 0.33],'FaceColor',cmap(1,:),'EdgeColor',cmap(1,:),'LineWidth',0.1}, ...
    {'PercSen',[0.33 0.67],'FaceColor',cmap(2,:),'EdgeColor',cmap(2,:),'LineWidth',0.1}, ...
    {'PercSen',[0.67 1.00],'FaceColor',cmap(3,:),'EdgeColor',cmap(3,:),'LineWidth',0.1}, ...
    {'PercSen',[1.00 3.33],'FaceColor',cmap(4,:),'EdgeColor',cmap(4,:),'LineWidth',0.1}, ...
    {'PercSen',[3.33 6.67],'FaceColor',cmap(5,:),'EdgeColor',cmap(5,:),'LineWidth',0.1}, ...
    {'PercSen',[6.67 10.0],'FaceColor',cmap(6,:),'EdgeColor',cmap(6,:),'LineWidth',0.1}, ...
    {'PercSen',[10.0 33.3],'FaceColor',cmap(7,:),'EdgeColor',cmap(7,:),'LineWidth',0.1}, ...
    {'PercSen',[33.3 66.7],'FaceColor',cmap(8,:),'EdgeColor',cmap(8,:),'LineWidth',0.1}, ...
    {'PercSen',[66.6 100.],'FaceColor',cmap(9,:),'EdgeColor',cmap(9,:),'LineWidth',0.1})};

for k = 1:length(params)
    param = params{k};
    if mod(k,2)==1
        [h,a] = create1x2Axes(...
            {'Composite Parameter Sensitivity (percent of max sensitivity)',...
            ['Weight Scheme: ' wt_name{j}]});
        colormap(cmap);
        subplot(a(1,1));
    else
        subplot(a(2,1));
    end

    GEO_Zone   = GEO_ParZone{k};

%     % percent to the max of parrameter group
%     carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%     csen = [carr{:,3}];
%     max_csen = max(par_csen);
%     carr = [...
%         str2num(char(regexprep(carr(:,1),'..([0-9]+) *','$1'))),...
%         par_csen',...
%         cell2mat(arrayfun(@(y) {par_csen(y)/max_par_csen*100},(1:length(par_csen))'))
%         ];
%     clear par_csen
    
    % percent to the overall max sensitivity
    switch param
      case {'lk','tm','us','cs'}
        carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'..([0-9]+) *','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
%       case {'RCAcondconn','RCAconn','RCAroute'}
%         carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%         carr = [...
%             str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
%             [carr{:,3}]',...
%             [carr{:,4}]'
%             ]; %#ok<ST2NM>
%       case {'bl1','bl3'}
%         carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%         carr = [...
%             str2num(char(regexprep(carr(:,1),'BLeak(\d+)_','$1'))),...
%             [carr{:,3}]',...
%             [carr{:,4}]'
%             ]; %#ok<ST2NM>
      case 'RCAcondconn'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'RCA_(\d+)0 '));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
      case 'RCAconn'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'RCA_(\d+)1 '));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
      case 'RCAroute'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'RCA_(\d+)2 '));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
      case 'bl1'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'BLeak\d+_1'));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'BLeak(\d+)_1','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
      case 'bl3'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'BLeak\d+_3'));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'BLeak(\d+)_3','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
      case 'inf'
        carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'\D+(\d+)','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
      case 'sc'
        carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'\D+(\d+)_\d','$1'))),...
            [carr{:,3}]',...
            [carr{:,4}]'
            ]; %#ok<ST2NM>
    end
    for i=1:length(GEO_Zone)
      i_temp = carr(:,1)==GEO_Zone(i).ZONEID;
      if any(i_temp)
        if isnan(carr(i_temp,2))
          GEO_Zone(i).Sensitivity = -99; 
          GEO_Zone(i).PercSen = -99; 
        else
          GEO_Zone(i).Sensitivity = carr(i_temp,2); 
          GEO_Zone(i).PercSen = carr(i_temp,3); 
        end
      end
    end

    temp = cellfun(@(y) ~isempty(y),{GEO_Zone.PercSen});
    mapshow(GEO_Zone(temp),'SymbolSpec',senspec{k});

    hold on
    mapshow(GEOcoastline,'Color',[.5 .75 1],'LineWidth',0.1);
    mapshow(GEOcounty,'Color',[.25 .25 .25],'LineWidth',0.5,'LineStyle','-.');
    mapshow(GEOwellfield,'EdgeColor',[0 0 1],'FaceColor','none','LineWidth',1.0);
    hold off

    daspect([1 1 1]);
    xlim(GEOextend.BoundingBox(:,1));
    ylim(GEOextend.BoundingBox(:,2));
    xlabel('UTM Easting, m');
    ylabel('UTM Northing, m');
    colorbar('NorthOutside','FontSize',7,'Xtick',0:1/9:1,'XTickLabel',...
        {'0','0.33','0.67','1.00','3.33','6.67','10.0','33.3','66.7','100.'});

    % title
    d_save = [d_scenario '/' runname '/CompositeSensitivity'];
    if ~exist(d_save,'dir'), mkdir(d_save); end
    title(par_title{k});
    shapewrite(GEO_Zone(temp),[d_save '/' wt_name{j} '_' params{k} '_sensitivity']);

    figure(h);
    if mod(k,2)==0 | k==length(params) %#ok<OR2>
        exportFig2PDF(d_save,sprintf('/%s(%d)',wt_name{j},ceil(k/2)));
    end  
end
end % senmap1 function


%% function to plot stdev map for each weight pair
function stdmap

% colormap
h = figure;
cmap = colormap(jet(7));
close(h);
stdspec = cell(11,1);
stdspec([1 2 3 4 7 8 10]) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'Stdev',[0.0 0.5],'FaceColor',cmap(1,:),'LineWidth',0.1}, ...
    {'Stdev',[0.5 1.0],'FaceColor',cmap(2,:),'LineWidth',0.1}, ...
    {'Stdev',[1.0 1.5],'FaceColor',cmap(3,:),'LineWidth',0.1}, ...
    {'Stdev',[1.5 2.0],'FaceColor',cmap(4,:),'LineWidth',0.1}, ...
    {'Stdev',[2.0 2.5],'FaceColor',cmap(5,:),'LineWidth',0.1}, ...
    {'Stdev',[2.5 3.0],'FaceColor',cmap(6,:),'LineWidth',0.1}, ...
    {'Stdev',[3.0 15.],'FaceColor',cmap(7,:),'LineWidth',0.1})};
stdspec([5 6 9 11]) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'Stdev',[0.0 0.5],'FaceColor',cmap(1,:),'EdgeColor',cmap(1,:),'LineWidth',0.1}, ...
    {'Stdev',[0.5 1.0],'FaceColor',cmap(2,:),'EdgeColor',cmap(2,:),'LineWidth',0.1}, ...
    {'Stdev',[1.0 1.5],'FaceColor',cmap(3,:),'EdgeColor',cmap(3,:),'LineWidth',0.1}, ...
    {'Stdev',[1.5 2.0],'FaceColor',cmap(4,:),'EdgeColor',cmap(4,:),'LineWidth',0.1}, ...
    {'Stdev',[2.0 2.5],'FaceColor',cmap(5,:),'EdgeColor',cmap(5,:),'LineWidth',0.1}, ...
    {'Stdev',[2.5 3.0],'FaceColor',cmap(6,:),'EdgeColor',cmap(6,:),'LineWidth',0.1}, ...
    {'Stdev',[3.0 15.],'FaceColor',cmap(7,:),'EdgeColor',cmap(7,:),'LineWidth',0.1})};

for k = 1:length(params)
    param = params{k};
    if mod(k,2)==1
        [h,a] = create1x2Axes(...
            {'Parameter Uncertainty - Standard Deviation',...
            ['Weight Scheme: ' wt_name{j}]});
        colormap(cmap);
        subplot(a(1,1));
    else
        subplot(a(2,1));
    end

    GEO_Zone   = GEO_ParZone{k};
    
    % extract stdev for particular parameter group
    switch param
      case {'lk','tm','us','cs'}
        carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'..([0-9]+) *','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
%       case {'RCAcondconn','RCAconn','RCAroute'}
%         carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%         carr = [...
%             str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
%             [carr{:,3}]',...
%             [carr{:,4}]'
%             ]; %#ok<ST2NM>
%       case {'bl1','bl3'}
%         carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%         carr = [...
%             str2num(char(regexprep(carr(:,1),'BLeak(\d+)_','$1'))),...
%             [carr{:,3}]',...
%             [carr{:,4}]'
%             ]; %#ok<ST2NM>
      case 'RCAcondconn'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'RCA_(\d+)0 '));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
      case 'RCAconn'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'RCA_(\d+)1 '));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
      case 'RCAroute'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'RCA_(\d+)2 '));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
      case 'bl1'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'BLeak\d+_1'));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'BLeak(\d+)_1','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
      case 'bl3'
        i_temp = cellfun(@(y) ~isempty(y),...
            regexpi(par_cellarray(:,1),'BLeak\d+_3'));
        carr = par_cellarray(i_temp,:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'BLeak(\d+)_3','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
      case 'inf'
        carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'\D+(\d+)','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
      case 'sc'
        carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
        carr = [...
            str2num(char(regexprep(carr(:,1),'\D+(\d+)_\d','$1'))),...
            [carr{:,5}]'
            ]; %#ok<ST2NM>
    end
    for i=1:length(GEO_Zone)
      i_temp = carr(:,1)==GEO_Zone(i).ZONEID;
      if any(i_temp)
        if ~isnan(carr(i_temp,2)) && ~isinf(carr(i_temp,2))
          GEO_Zone(i).Stdev = carr(i_temp,2);
        else
          GEO_Zone(i).Stdev = -99;
        end
      end
    end
    temp = cellfun(@(y) ~isempty(y),{GEO_Zone.Stdev});
    mapshow(GEO_Zone(temp),'SymbolSpec',stdspec{k});

    hold on
    mapshow(GEOcoastline,'Color',[.5 .75 1],'LineWidth',0.1);
    mapshow(GEOcounty,'Color',[.25 .25 .25],'LineWidth',0.5,'LineStyle','-.');
    mapshow(GEOwellfield,'EdgeColor',[0 0 1],'FaceColor','none','LineWidth',1.0);
    hold off

    daspect([1 1 1]);
    xlim(GEOextend.BoundingBox(:,1));
    ylim(GEOextend.BoundingBox(:,2));
    xlabel('UTM Easting, m');
    ylabel('UTM Northing, m');
    colorbar('NorthOutside','FontSize',7,'Xtick',0:1/7:1,'XTickLabel',...
        {'0','0.5','1.0','1.5','2.0','2.5','3.0','15'});

    % title
    d_save = [d_scenario '/' runname '/Uncertainty'];
    if ~exist(d_save,'dir'), mkdir(d_save); end
    title(par_title{k});
    shapewrite(GEO_Zone(temp),[d_save '/' wt_name{j} '_' params{k} '_uncertainty']);

    figure(h);
    if mod(k,2)==0 | k==length(params) %#ok<OR2>
        exportFig2PDF(d_save,sprintf('/%s(%d)',wt_name{j},ceil(k/2)));
    end  
end
end % stdmap function

%% function to get jacobian
function jac=get_jco(f_jco)
fid = fopen(f_jco);
fseek(fid,0,'bof');
npar = -fread(fid,1,'long')';
nobs = -fread(fid,1,'long')';
nonz =  fread(fid,1,'long')';

fseek(fid,12,'bof');
i_nonz = fread(fid,nonz,'*long',8);

fseek(fid,16,'bof');
v_nonz = fread(fid,nonz,'double',4);

jac = zeros(npar*nobs,1);
jac(i_nonz) = v_nonz;
jac = reshape(jac,nobs,npar);
end % get_jco function

%% function to set cellarray of observation
function wt_vec=set_obswt(wts)
% wt_vec: vector of weights by observation
% weight triplet
% wts: two columns cellarray with observation group and weight pairs

%wt = ones(size(obsnames));
for o = 1:size(wts,1)
    i = strmatch(wts{o,1},obs_cellarray(:,2));
    obs_cellarray(i,3) = arrayfun(@(y) wts(o,2),(1:length(i))');
end
wt_vec = cell2mat(obs_cellarray(:,3));
end % set_obswt function

%% function to compute jac*cov(p)*jac' using distributed array
function rtn_status=optimum_stdev_dce()
  d_runname = fullfile(d_scenario,runname);
  rtn_status = false;
  sched = findResource('scheduler','type','jobmanager','Name','JobManager2');
  pjob = createParallelJob(sched);
  set(pjob, 'FileDependencies', {'..\optimum_stdev.m','taskStartup.m'});
  % use UNC path
  f_jac = strrep(lower([d_runname '\jac.mat']),'e:','\\kuhntucker\e$');
  f_jac = strrep(lower([d_runname '\jac.mat']),'h:','\\kuhntucker\e$');
  save([d_runname '\jac.mat'],'jac');
  ptask = createTask(pjob, @optimum_stdev, 1, {par_cov,f_jac});
  submit(pjob);
  waitForState(pjob);
  results = getAllOutputArguments(pjob);
  if ptask.ErrorMessage
    disp(ptask.ErrorMessage);
    rtn_status = true;
  else
    obs_cellarray(:,8) = num2cell(cell2mat(results));
  end
  destroy(ptask);
  destroy(pjob);
end

end % plotComSen_dce function