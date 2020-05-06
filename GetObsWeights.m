function [Swt,child_par,parent_par]=GetObsWeights(f_weight,colspec,tieflag)
% function to extract weight columns from spreadsheet
% The only text column is parameter group, the first text row is heading
% The first numeric column is residual, the rest of the columns contain
% weight scheme
if nargin < 2
  colspec = 48;
end
if nargin < 3
  tieflag = false; % use tie information from pest input file
end
[xlsnum,xlstxt] = xlsread(f_weight,'WeightTable');
wt_cols = xlsnum(:,2:end);
% wt_name = strrep(xlstxt(1,3:end),'_','-'); % avoid underscore
wt_name = xlstxt(1,3:end);
wt_irows = (1:size(xlsnum))+1;
obs_group = xlstxt(wt_irows,1);
obs_group = [obs_group num2cell(wt_cols(:,colspec))];
Swt = cell2struct(obs_group,{'obs_group',wt_name{1,colspec}},2);

% cell array for tieing and fixing matrix
child_par = xlstxt(wt_irows(end)+1:end,1);

if tieflag
  if ~isempty(child_par)
      parent_par = xlstxt(wt_irows(end)+1:end,3:end);
  end
else
  parent_par = cell(size(xlstxt(wt_irows(end)+1:end,3:end)));
end
