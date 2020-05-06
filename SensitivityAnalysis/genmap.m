function genmap(d_runname,Spest)
% plot sensitivity map from Spest

  d_shapefile = 'F:\IHM\shapefiles';
  [d_scenario,runname] = fileparts(d_runname);
  if nargin<2
    load(fullfile(d_runname,'Spest.mat'));
  end
  par_cellarray = struct2cell(Spest.Parameter)';

  % compute second moment - stdev at current parameter space
  i_temp = cellfun(@(y) ~isempty(y),par_cellarray(:,11));
  par_cellarray(i_temp,14) = cellfun(@(x,y) sqrt(x*x+y*y),...
    par_cellarray(i_temp,11),par_cellarray(i_temp,12),'UniformOutput',false);

  % get a set of fixed parameters from database
  conn = database('KT_PPEST','','');
  sql = [...
      'SELECT PD.Name, PD.ParameterGroup, PD.Transformation, PD.TiedParameter, ',...
        'PD.Value, PD.LowerBound, PD.UpperBound, ',...
        'NULL D8, NULL D9, NULL D10, NULL D11, NULL D12, NULL D13, NULL D14 ',...
      'FROM ParameterData AS PD INNER JOIN ',...
          'RunDesc AS RD ON PD.RunID = RD.RunID ',...
      'WHERE (RD.Name = ''' runname ''') AND PD.Transformation like ''fixed'' ',...
      'ORDER BY PD.ParameterDataID'];
  par_cellarray = [par_cellarray; fetch(conn,sql)];
  close(conn);

  % assign sensitivity of parent to child parameters
  i_tie = cellfun(@(y) ~isempty(regexp(y,'tied','ONCE')),par_cellarray(:,3));
  i_parent = cellfun(@(y) strmatch(y,par_cellarray(:,1)),par_cellarray(i_tie,4));
  par_cellarray(i_tie,[9 10 14]) = par_cellarray(i_parent,[9 10 14]);

  % Read common shapefiles
  GEOcoastline = shaperead([d_shapefile '\INTBcoastline.shp']);
  GEOwellfield = shaperead([d_shapefile '\INTBwellfield.shp']);
  GEOcounty    = shaperead([d_shapefile '\INTBcounty.shp']);
  GEOextend    = shaperead([d_shapefile '\INTB_extend.shp']);

  % shape of parameter zones
  %params = {'lk','tm','us','cs','bl1','bl3','RCAcondconn','RCAconn','RCAroute','inf','sc'};
  params = {'lk','tm','sc'};
  GEO_ParZone = cell(size(params));
  for kk = 1:length(params)
    GEO_ParZone{kk} = shaperead([d_shapefile '\' params{kk} '_Zone.shp']);
  end
  par_title = {'Leakance';'Transmissivity';'Spring Conductance'};

%% sensitivity colormap
  h = figure;
  sen_cmap = colormap(jet(9));
  close(h);
%   senspec = cell(11,1);
%   senspec([1 2 3 4 7 8 10]) = {makesymbolspec('polygon',...
  senspec = cell(3,1);
  senspec([1 2]) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'PercSen',[1e-4 0.33],'FaceColor',sen_cmap(1,:),'LineWidth',0.1}, ...
    {'PercSen',[0.33 0.67],'FaceColor',sen_cmap(2,:),'LineWidth',0.1}, ...
    {'PercSen',[0.67 1.00],'FaceColor',sen_cmap(3,:),'LineWidth',0.1}, ...
    {'PercSen',[1.00 3.33],'FaceColor',sen_cmap(4,:),'LineWidth',0.1}, ...
    {'PercSen',[3.33 6.67],'FaceColor',sen_cmap(5,:),'LineWidth',0.1}, ...
    {'PercSen',[6.67 10.0],'FaceColor',sen_cmap(6,:),'LineWidth',0.1}, ...
    {'PercSen',[10.0 33.3],'FaceColor',sen_cmap(7,:),'LineWidth',0.1}, ...
    {'PercSen',[33.3 66.7],'FaceColor',sen_cmap(8,:),'LineWidth',0.1}, ...
    {'PercSen',[66.6 100.],'FaceColor',sen_cmap(9,:),'LineWidth',0.1})};
  % senspec([5 6 9 11]) = {makesymbolspec('polygon',...
  senspec(3) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'PercSen',[1e-4 0.33],'FaceColor',sen_cmap(1,:),'EdgeColor',sen_cmap(1,:),'LineWidth',0.1}, ...
    {'PercSen',[0.33 0.67],'FaceColor',sen_cmap(2,:),'EdgeColor',sen_cmap(2,:),'LineWidth',0.1}, ...
    {'PercSen',[0.67 1.00],'FaceColor',sen_cmap(3,:),'EdgeColor',sen_cmap(3,:),'LineWidth',0.1}, ...
    {'PercSen',[1.00 3.33],'FaceColor',sen_cmap(4,:),'EdgeColor',sen_cmap(4,:),'LineWidth',0.1}, ...
    {'PercSen',[3.33 6.67],'FaceColor',sen_cmap(5,:),'EdgeColor',sen_cmap(5,:),'LineWidth',0.1}, ...
    {'PercSen',[6.67 10.0],'FaceColor',sen_cmap(6,:),'EdgeColor',sen_cmap(6,:),'LineWidth',0.1}, ...
    {'PercSen',[10.0 33.3],'FaceColor',sen_cmap(7,:),'EdgeColor',sen_cmap(7,:),'LineWidth',0.1}, ...
    {'PercSen',[33.3 66.7],'FaceColor',sen_cmap(8,:),'EdgeColor',sen_cmap(8,:),'LineWidth',0.1}, ...
    {'PercSen',[66.6 100.],'FaceColor',sen_cmap(9,:),'EdgeColor',sen_cmap(9,:),'LineWidth',0.1})};

%% uncertainty colormap
  h = figure;
  std_cmap = colormap(jet(7));
  close(h);
%   stdspec = cell(11,1);
%   stdspec([1 2 3 4 7 8 10]) = {makesymbolspec('polygon',...
  stdspec = cell(3,1);
  stdspec([1 2]) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'Stdev',[0.00 0.01],'FaceColor',std_cmap(1,:),'LineWidth',0.1}, ...
    {'Stdev',[0.01 0.05],'FaceColor',std_cmap(2,:),'LineWidth',0.1}, ...
    {'Stdev',[0.05 0.10],'FaceColor',std_cmap(3,:),'LineWidth',0.1}, ...
    {'Stdev',[0.10 0.20],'FaceColor',std_cmap(4,:),'LineWidth',0.1}, ...
    {'Stdev',[0.20 0.30],'FaceColor',std_cmap(5,:),'LineWidth',0.1}, ...
    {'Stdev',[0.30 0.40],'FaceColor',std_cmap(6,:),'LineWidth',0.1}, ...
    {'Stdev',[0.40 0.50],'FaceColor',std_cmap(7,:),'LineWidth',0.1})};
% 	stdspec([5 6 9 11]) = {makesymbolspec('polygon',...
  stdspec(3) = {makesymbolspec('polygon',...
    {'Default', 'FaceColor',[.8 .8 .8],'LineWidth',0.1}, ...
    {'Stdev',[0.00 0.01],'FaceColor',std_cmap(1,:),'EdgeColor',std_cmap(1,:),'LineWidth',0.1}, ...
    {'Stdev',[0.01 0.05],'FaceColor',std_cmap(2,:),'EdgeColor',std_cmap(2,:),'LineWidth',0.1}, ...
    {'Stdev',[0.05 0.10],'FaceColor',std_cmap(3,:),'EdgeColor',std_cmap(3,:),'LineWidth',0.1}, ...
    {'Stdev',[0.10 0.20],'FaceColor',std_cmap(4,:),'EdgeColor',std_cmap(4,:),'LineWidth',0.1}, ...
    {'Stdev',[0.20 0.30],'FaceColor',std_cmap(5,:),'EdgeColor',std_cmap(5,:),'LineWidth',0.1}, ...
    {'Stdev',[0.30 0.40],'FaceColor',std_cmap(6,:),'EdgeColor',std_cmap(6,:),'LineWidth',0.1}, ...
    {'Stdev',[0.40 0.50],'FaceColor',std_cmap(7,:),'EdgeColor',std_cmap(7,:),'LineWidth',0.1})};

  % parameter loop
  for k = 1:length(params)
      param = params{k};
      GEO_Zone   = GEO_ParZone{k};

%       % percent to the max of parrameter group
%       carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%       csen = [carr{:,3}];
%       max_csen = max(par_csen);
%       carr = [...
%           str2num(char(regexprep(carr(:,1),'..([0-9]+) *','$1'))),...
%           par_csen',...
%           cell2mat(arrayfun(@(y) {par_csen(y)/max_par_csen*100},(1:length(par_csen))'))
%           ];
%       clear par_csen

      % percent to the overall max sensitivity
      switch param
        case {'lk','tm','us','cs'}
          carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'..([0-9]+) *','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
%         case {'RCAcondconn','RCAconn','RCAroute'}
%           carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%           carr = [...
%               str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
%               [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
%               ]; %#ok<ST2NM>
%         case {'bl1','bl3'}
%           carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
%           carr = [...
%               str2num(char(regexprep(carr(:,1),'BLeak(\d+)_','$1'))),...
%               [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
%               ]; %#ok<ST2NM>
        case 'RCAcondconn'
          i_temp = cellfun(@(y) ~isempty(y),...
              regexpi(par_cellarray(:,1),'RCA_(\d+)0 '));
          carr = par_cellarray(i_temp,:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
        case 'RCAconn'
          i_temp = cellfun(@(y) ~isempty(y),...
              regexpi(par_cellarray(:,1),'RCA_(\d+)1 '));
          carr = par_cellarray(i_temp,:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
        case 'RCAroute'
          i_temp = cellfun(@(y) ~isempty(y),...
              regexpi(par_cellarray(:,1),'RCA_(\d+)2 '));
          carr = par_cellarray(i_temp,:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'RCA_([0-9]+)','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
        case 'bl1'
          i_temp = cellfun(@(y) ~isempty(y),...
              regexpi(par_cellarray(:,1),'BLeak\d+_1'));
          carr = par_cellarray(i_temp,:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'BLeak(\d+)_1','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
        case 'bl3'
          i_temp = cellfun(@(y) ~isempty(y),...
              regexpi(par_cellarray(:,1),'BLeak\d+_3'));
          carr = par_cellarray(i_temp,:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'BLeak(\d+)_3','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
        case 'inf'
          carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'\D+(\d+)','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
        case 'sc'
          carr = par_cellarray(strmatch(param,par_cellarray(:,2)),:);
          carr = [...
              str2num(char(regexprep(carr(:,1),'\D+(\d+)_\d','$1'))),...
              [carr{:,9}]',[carr{:,10}]',[carr{:,14}]'
              ]; %#ok<ST2NM>
      end
      for i=1:length(GEO_Zone)
        i_temp = carr(:,1)==GEO_Zone(i).ZONEID;
        if any(i_temp)
          if isnan(carr(i_temp,2))
            GEO_Zone(i).Sensitivity = -99; 
            GEO_Zone(i).PercSen = -99; 
            GEO_Zone(i).Stdev = -99;
          else
            GEO_Zone(i).Sensitivity = carr(i_temp,2); 
            GEO_Zone(i).PercSen = carr(i_temp,3); 
            GEO_Zone(i).Stdev = carr(i_temp,4);
          end
        end
      end

      senmap;
      stdmap;
  end

%% Sensitivity
  function senmap
    ptitle = {'Composite Parameter Sensitivity (as percent of max sensitivity)',par_title{k}};
    h = figwindow(ptitle{1}); set(gca,'FontSize',7);
    colormap(sen_cmap);
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
    cbh = colorbar('North','FontSize',7,'Xtick',0:1/9:1,'XTickLabel',...
        {'0','0.33','0.67','1.00','3.33','6.67','10.0','33.3','66.7','100.'});
    pos = get(cbh,'Position');
    set(cbh,'Position',[pos(1),pos(2)*1.027,pos(3),0.012]);
    
    % title
    title(ptitle,'FontSize',10,'FontWeight','bold');
    figure(h);
    d_save = [d_scenario '/' runname '/CompositeSensitivity'];
    exportFig2PDF(d_save,[params{k} '_sensitivity']);
%     if ~exist(d_save,'dir'), mkdir(d_save); end
    shapewrite(GEO_Zone(temp),[d_save '/' params{k} '_sensitivity']);
  end

%% Uncertainty
  function stdmap
    ptitle = {'Parameter Uncertainty (Standard Deviation in Common Logarithmic Scale)',par_title{k}};
    h = figwindow(ptitle{1}); set(gca,'FontSize',7);
    colormap(std_cmap);
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
    cbh = colorbar('North','FontSize',7,'Xtick',0:1/7:1,'XTickLabel',...
        {'0','0.5','1.0','1.5','2.0','2.5','3.0','5.0'});
    pos = get(cbh,'Position');
    set(cbh,'Position',[pos(1),pos(2)*1.027,pos(3),0.012]);

    % title
    title(ptitle,'FontSize',10,'FontWeight','bold');
    figure(h);
    d_save = [d_scenario '/' runname '/Uncertainty'];
    exportFig2PDF(d_save,[params{k} '_uncertainty']);
%     if ~exist(d_save,'dir'), mkdir(d_save); end
    shapewrite(GEO_Zone(temp),[d_save '/' params{k} '_uncertainty']);

  end

end


