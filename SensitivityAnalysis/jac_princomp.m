function [eigvec,jac,eigval,par_cellarray,obs_cellarray]=jac_princomp(f_weight,d_runname,j,use_distcomp)
% f_weight : path of the spreadsheet for the weight scheme
% d_runname : directory for the jacobian matrix file
% colspec : specify list of columns of weight schemes
% use_distcomp : flag for usign DISTCOMP

%% run under the mfile directory - is this necessary?
cd(fileparts(mfilename('fullpath')));
if nargin < 2
    runname = 'pp_012';
    d_scenario = 'E:\ihm\ppest_20070420';
else
    [d_scenario,runname] = fileparts(d_runname);
end
if nargin < 4, use_distcomp = false; end

%% parameter info from database
conn = database('KT_PPEST','','');
sql = [...
    'SELECT PD.Name, PD.ParameterGroup, PD.Value, PD.Transformation, NULL as Dummy ',...
    'FROM ParameterData AS PD INNER JOIN ',...
        'RunDesc AS RD ON PD.RunID = RD.RunID ',...
    'WHERE (RD.Name = ''' runname ''') AND (PD.Transformation <> ''fixed'') ',...
    'ORDER BY PD.ParameterDataID'];
par_cellarray = fetch(conn,sql);

sql = [...
    'SELECT OBR.Observation, OD.ObservationGroup, OBR.Residual ',...
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

par_value = par_cellarray(:,[1,3]);
par_trans = par_cellarray(:,[1,4]);
obs_resid = [obs_cellarray{:,3}]';  % this column will be modified by set_obswt function


%% read jacobian
f_jco = fullfile(d_scenario,runname,[runname '.jco']);
jac = get_jco(f_jco);
% modified_jac = false;

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
i_jac_del = wt<=0.01;
nobs = sum(~i_jac_del);
wt = wt(~i_jac_del);
jac = jac(~i_jac_del,:);
obs_cellarray = obs_cellarray(~i_jac_del,:);
obs_resid = obs_resid(~i_jac_del);

%% plot by weight columns
% Create permutable matrix to modified jac according to tie and fix
if ~isempty(child_par) & sum(cellfun(@(y) ~isempty(y),parent_par(:,j)))>0 %#ok<AND2>
    permute_jac = eye(npar);
    % identifiers for log, fix, and tie elements
    i_fix = cellfun(@(y) ~isempty(y),regexpi(parent_par(:,j),'fixed'));
    i_tie = cellfun(@(y) ~isempty(y),parent_par(:,j));
    i_tie = i_tie & ~i_fix;
    temp = cellfun(@(y) par_trans{strmatch(y,par_trans(:,1)),2},...
        child_par,'UniformOutput',false);
    i_log = i_tie & cellfun(@(y) ~isempty(y),regexpi(temp,'log'));
    
    % make sure parameter names are 12 chars wide
    parent_par(i_tie,j) = cellfun(@(y) sprintf('%-12s',y),parent_par(i_tie,j),...
      'UniformOutput',false);
    
    % check that no parent of tied parameters is a fixed parameter
    % fixed in weight-scheme spreadsheet
    temp = cellfun(@(y) strmatch(y,child_par(i_fix)),parent_par(i_tie,j),...
      'UniformOutput',false);
    temp = cellfun(@(y) ~isempty(y),temp);
    if sum(temp)>0
      error('Can''t have a parent of tied parameters as a fixed parameter!');
    end
    % fixed in .pst file
    temp = cellfun(@(y) par_trans{strmatch(y,par_trans(:,1)),2},...
        parent_par(i_tie,j),'UniformOutput',false);
    temp = cellfun(@(y) ~isempty(y),regexpi(temp,'fixed'));
    if sum(temp)>0
      error('Can''t have a parent of tied parameters as a fixed parameter!');
    end

    % determine deleting columns
    if sum(i_fix)>0
        j_jac_del = cellfun(@(y) strmatch(y,par_cellarray(:,1)),child_par(i_fix));
    else
        j_jac_del = []; 
    end
    if sum(i_tie)>0
        i_jac_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),child_par(i_tie));
        j_jac_del = [j_jac_del; i_jac_tie]; %#ok<AGROW>
        % determine ratios, rows (i_jac_tie) and columns (j_jac_tie) to place the ratio
        j_jac_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),parent_par(i_tie,j));
        tied_ratio = arrayfun(@(y) par_value{y,2},i_jac_tie)...
            ./arrayfun(@(y) par_value{y,2},j_jac_tie);
%         log_ratio = log10(arrayfun(@(y) par_value{y,2},i_jac_tie))...
%             ./log10(arrayfun(@(y) par_value{y,2},j_jac_tie));
%         tied_ratio(i_log) = log_ratio(i_log);

        % set tied_ration for log-pairs to one - see Chin Man's derivation 8/30/2007
        tied_ratio(i_log) = ones(size(tied_ratio(i_log)));
        for it = 1:length(tied_ratio)
            permute_jac(i_jac_tie(it),j_jac_tie(it)) = tied_ratio(it);
        end
    end
    j_jac = setdiff(1:npar,j_jac_del);
    par_cellarray = par_cellarray(j_jac,:);
    permute_jac = sparse(permute_jac(:,j_jac));
    jac = jac*permute_jac;
    npar = size(jac,2);
%     if sum(i_tie)>0
%       j_jac_tie = cellfun(@(y) strmatch(y,par_cellarray(:,1)),parent_par(i_tie,j));
%     end
    clear permute_jac j_jac_del i_jac_tie i_tie i_fix i_log log_ratio tied_ratio;
end

% limit PCA to tm, lk, cs, and us
i_TLS = strncmpi(par_cellarray(:,2),'tm',2) ...
  | strncmpi(par_cellarray(:,2),'lk',2) ...
  | strncmpi(par_cellarray(:,2),'cs',2) ...
  | strncmpi(par_cellarray(:,2),'us',2);

par_cellarray = par_cellarray(i_TLS,:);
jac = jac(:,i_TLS);
jac = spdiags(sqrt(wt),0,nobs,nobs)*jac;
f_save = [d_runname '\jac_' wt_name{j} '.mat'];
% [coeff,score,latent,tsquare]=s_princomp(jac);
% perc_variance = 100*latent/sum(latent);
% pareto(perc_variance);
refvar = sum(obs_resid.*obs_resid.*wt)/(nobs-npar);
%refvar = 1/(nobs-1);
par_cov = spdiags(wt,0,nobs,nobs);
par_cov = jac'*par_cov*jac;
par_cov = par_cov\eye(length(par_cov))*refvar;
[eigvec eigval] = eig(full(par_cov));
eigval = diag(eigval,0);
[eigval,IX] = sort(eigval,'descend');
eigvec = eigvec(:,IX);
par_stdev = sqrt(full(diag(par_cov,0)));
save(f_save,'jac','eigval','eigvec','par_cellarray','obs_cellarray');
jac = jac*eigvec;
for jj=1:size(jac,2), jac(:,jj)=jac(:,jj)/par_stdev(jj); end
perc_variance = 100*eigval/sum(eigval);
pareto(perc_variance); xlim([1 50]); set(gca,'fontsize',7);
biplot(eigvec(:,1:2),'scores',jac(:,1:2),'varlabels',par_cellarray(:,1));
for i=get(gca,'children')'
  if strcmp(get(i,'tag'),'varlabel'), set(i,'fontsize',7); end
end

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
jac = sparse(reshape(jac,nobs,npar));
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

end