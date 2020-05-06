function [cor_pair,par_insens,par_eig]=par_correlation(S,d_runname,cutoff)
% post processing parameter covariance

if nargin < 2
    runname = 'pp_003';
    d_scenario = 'E:\ihm\ppest_20070420';
else
    [d_scenario,runname] = fileparts(d_runname);
end
if nargin<3, cutoff=0.7; end

%% parameter zone info from database
conn = database('KT_PPEST','','');
sql = [...
    'select Parameter,ZoneID from dbo.ParameterDesc ',...
    'order by parameter'];
par_zoneid = fetch(conn,sql);
close(conn)

%% Get list of parameters that show some sensitivity
par_grp = [{S.Results.Parameter.Parameter}; {S.Results.Parameter.ParGroup}]';
% potential problem with hardcode 1e-4 in two piece of code
% i_sens = cell2mat([{S.Results.Parameter.Sensitivity}])>=1e-4; %#ok<NBRAK>
% A better way to id insensitive parameter is to check NaN in Stdev.
i_sens = ~isnan([S.Results.Parameter.Stdev]);
par_insens = par_grp(~i_sens,1);
par_name = par_grp(i_sens,1);

%% Determine eigen values
par_cov = S.Results.Covariance;
par_eig = eig(full(par_cov));

%% Compute correlation
n = length(par_cov);
% ill-conditon matrix may create a negative element in diagonal
% will have to elimiate these rows and columns
par_stdev = full(diag(par_cov,0));
temp = par_stdev<0;
par_cov(:,temp) = 0;
par_cov(temp,:) = 0;
par_stdev = sqrt(diag(par_cov,0));

% get upper triangular matrix of covariance
upar_cov = spdiags(par_cov,-(1:n)+1);
upar_cov = spdiags(upar_cov,-(1:n)+1,n,n)';

% calculate correlation
upar_cor = cell2mat(arrayfun(@(y) upar_cov(y,:)./par_stdev'/par_stdev(y),1:n,...
  'UniformOutput',false)');

% find pair of correlated parameter, first eliminate the diagonal (=1)
temp = spdiags(repmat(0,n,1),0,upar_cor);
j_cor = find(abs(temp)>=cutoff);
i_cor = mod(j_cor,n);
j_cor = ceil(j_cor/n);
cor_pair = [par_name(i_cor), par_name(j_cor),...
  num2cell(arrayfun(@(x,y) upar_cor(x,y),i_cor,j_cor))];

% make sure that parents are from primary parameter groups
pgrp = cellfun(@(y) deblank(par_grp(strmatch(y,par_grp(:,1)),2)),cor_pair(:,2),...
  'UniformOutput',false);
params = {'tm','lk','us','cs','inf','bl','rca'};
pgrp = cellfun(@(y) isempty(strmatch(y,params)),pgrp);
temp = cor_pair(pgrp,2);
cor_pair(pgrp,2) = cor_pair(pgrp,1);
cor_pair(pgrp,1) = temp;
% if parent-child from primary, determine parent from group ranking
pgrp = cellfun(@(y) deblank(par_grp(strmatch(y,par_grp(:,1)),2)),cor_pair(:,2),...
  'UniformOutput',false);
cgrp = cellfun(@(y) deblank(par_grp(strmatch(y,par_grp(:,1)),2)),cor_pair(:,1),...
  'UniformOutput',false);
pgrp = cellfun(@(y) strmatch(y,params),pgrp,'UniformOutput',false);
cgrp = cellfun(@(y) strmatch(y,params),cgrp,'UniformOutput',false);
pgrp = cell2mat(cellfun(@(x,y) ~isempty(y) && x>y,pgrp,cgrp,'UniformOutput',false));
temp = cor_pair(pgrp,2);
cor_pair(pgrp,2) = cor_pair(pgrp,1);
cor_pair(pgrp,1) = temp;

% swap if a child is in parent list
nswap = 1;
while nswap
  [nswap,cor_pair] = child_swap(cor_pair);
end

%% Read common shapefiles
GEOcoastline = shaperead([d_scenario '\shapefiles\INTBcoastline.shp']);
GEOwellfield = shaperead([d_scenario '\shapefiles\INTBwellfield.shp']);
GEOcounty    = shaperead([d_scenario '\shapefiles\INTBcounty.shp']);
GEOextend    = shaperead([d_scenario '\shapefiles\INTB_extend.shp']);

%% shape of parameter zones
% need lower case here because of strmatch(exact) function
params = {'lk','tm','us','cs','bl1','bl3','rcacondconn','rcaconn','rcaroute','inf','sc'};
GEO_ParZone = cell(size(params));
for k = 1:length(params)
  GEO_ParZone{k} = shaperead([d_scenario '\shapefiles\' params{k} '_Zone.shp']);
end

%% prepare to plot pairs of parameter
d_save = [d_scenario '/' runname '/Correlation'];
if ~exist(d_save,'dir'), mkdir(d_save); end

par_parent = unique(cor_pair(:,2));
for i = 1:length(par_parent)
    ppar = par_parent(i);
    pgrp = deblank(par_grp{strmatch(ppar,par_grp(:,1),'exact'),2});
    cpar = cor_pair(strmatch(ppar,cor_pair(:,2),'exact'),1);
    ccor = [cor_pair{strmatch(ppar,cor_pair(:,2),'exact'),3}];
    cgrp = cellfun(@(y) deblank(par_grp{strmatch(y,par_grp(:,1),'exact'),2}),...
      cpar,'UniformOutput',false);

%% Select parameter zone shapefile from parent parameter
    k = strmatch(pgrp,params,'exact');
%     switch pgrp
%       case {'lk','tm','us','cs','inf'}
%         k = strmatch(pgrp,params,'exact');
%       case {'bl1','bl3'}
%         if ~isempty(cell2mat(regexpi(ppar,'BLeak\d+_1'))),k = 5; end
%         if ~isempty(cell2mat(regexpi(ppar,'BLeak\d+_3'))), k = 6; end        
%       case 'rca'
%         if ~isempty(cell2mat(regexpi(ppar,'RCA_(\d+)0 '))), k = 7; end
%         if ~isempty(cell2mat(regexpi(ppar,'RCA_(\d+)1 '))), k = 8; end
%         if ~isempty(cell2mat(regexpi(ppar,'RCA_(\d+)2 '))), k = 9; end
%       otherwise
%         continue;
%     end
    
    k_child = num2cell(zeros(1,length(cgrp)));
    for kk = 1:length(cgrp)
        k_child{kk} = strmatch(cgrp{kk},params,'exact');
    end
    k_child = cell2mat(k_child);
    if sum(k_child)==0, continue; end

    ptitle = {['Correlated Parameter for Weight Scheme: ' S.WtScheme],...
        ['Independent Parameter: ' strrep(char(deblank(ppar)),'_','\_')]};
    [h,a] = figwindow(ptitle);
    set(a,'outerposition',[0 0 1 0.925]);
    
    % shape and zone for parent
    zonemap(k,ppar,GEO_ParZone,par_zoneid,[.49 1 .63]);
    hold on;

    % shape and zone for children
    for kk = 1:length(k_child)
      if k_child(kk)<=0, continue; end
      zonemap(k_child(kk),cpar{kk},GEO_ParZone,par_zoneid,'m');
    end

    mapshow(GEOcoastline,'Color',[.5 .75 1],'LineWidth',0.1);
    mapshow(GEOcounty,'Color',[.25 .25 .25],'LineWidth',0.5,'LineStyle','-.');
    mapshow(GEOwellfield,'EdgeColor',[0 0 1],'FaceColor','none','LineWidth',1.0);
    hold off

    daspect([1 1 1]);
    xlim(GEOextend.BoundingBox(:,1));
    ylim(GEOextend.BoundingBox(:,2));
    xlabel('UTM Easting, m');
    ylabel('UTM Northing, m');
    box on;
%     colorbar('NorthOutside','FontSize',7,'Xtick',0:1/9:1,'XTickLabel',...
%         {'0','0.33','0.67','1.00','3.33','6.67','10.0','33.3','66.7','100.'});

    % title
    title([strrep(deblank(char(ppar)),'_','\_') ' (green)']);
    if length(cpar)>1
      temp = cellfun(@(x,y) sprintf('%s (%6.3f)',strrep(char(deblank(x)),'_','\_'),y),...
        cpar,num2cell(ccor'),'UniformOutput',false);
    else
      temp = {sprintf('%s (%6.3f)',strrep(char(deblank(cpar)),'_','\_'),ccor)};
    end
    text(4.22e5,3.19e6,['Dependent:'; temp],'BackgroundColor',[.8 .8 .8],'margin',10,...
      'HorizontalAlignment','right','VerticalAlignment','top','FontSize',9);
%     shapewrite(GEO_Zone(temp),[d_save '/' S.WtScheme '_' params{k} '_correlation']);

    figure(h);
    axes('position',[0 0.95 1 .05],'XTick',[],'YTick',[],...
      'XColor','w','YColor','y');
    text(0.5,0.5,ptitle,'FontSize',9,'FontWeight','bold','HorizontalAlignment','center');
    exportFig2PDF(d_save,sprintf('/%s',char(deblank(ppar))));
end

% reorder cor_pair in descending order of correlation values
[temp,IX]=sort(abs([cor_pair{:,3}]),'descend');
cor_pair = cor_pair(IX,:);

% alos write output to Excel file
f_xls = [d_save '\' S.WtScheme '.xls'];
if ~isempty(par_insens), xlswrite(f_xls,par_insens,'Insensitive'); end
xlswrite(f_xls,cor_pair,'Correlated Pairs');
xlswrite(f_xls,par_eig,'Eigen');

%%
function [nswap,cor_pair] = child_swap(cor_pair)
% swap if a child is in parent list
par_parent = unique(cor_pair(:,2));
% rows of child in parent list, expressed in number of occurences
temp = cellfun(@(y) ~isempty(strmatch(y,par_parent)),cor_pair(:,1));
ccount = int16(temp);
ccount(temp) = cellfun(@(y) sum(cell2mat(regexp(cor_pair(:,2),y))),cor_pair(temp,1));
pcount = int16(temp);
pcount(temp) = cellfun(@(y) sum(cell2mat(regexp(cor_pair(:,2),y))),cor_pair(temp,2));
% swap only if number occurences is equal or more
temp(temp) = ccount(temp)>=pcount(temp);
nswap = sum(temp);
if nswap>0
  par_parent = cor_pair(temp,2);
  cor_pair(temp,2) = cor_pair(temp,1);
  cor_pair(temp,1) = par_parent;
end

%%
function zonemap(k,p,GEO_ParZone,par_zoneid,cspec)
GEO_Zone = GEO_ParZone{k};
ppar_zoneid = par_zoneid{strmatch(p,par_zoneid(:,1)),2};
zoneid = [GEO_Zone.ZONEID];
ppar_zoneid = zoneid==ppar_zoneid;
if k==5 | k==6 | k==9 %#ok<OR2>
    mapshow(GEO_Zone(ppar_zoneid),...
      'FaceColor',cspec,'EdgeColor',cspec,'FaceAlpha',.5,'LineWidth',0.1);
else
    mapshow(GEO_Zone(ppar_zoneid),'FaceColor',cspec,'FaceAlpha',.5,'LineWidth',0.1);
end
