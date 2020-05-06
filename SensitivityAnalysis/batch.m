function batch(d_runname,f_weight,colspec,corr_wtcol,use_distcomp)
maxcol = 87;
if nargin <1, d_runname = 'F:\IHM\BEOPEST\bp_004'; end
if nargin <2, f_weight = 'F:\IHM\BEOPEST\bp_004\ObsWeightScheme_2.xls'; end
if nargin <3, colspec = 1:maxcol; end
if nargin <4, corr_wtcol = 87; end
if nargin <5, use_distcomp = true; end

Spest = struct('WtScheme',cell(maxcol,1),'Results',cell(maxcol,1));

while ~isempty(colspec)
  Stemp=plotComSen(f_weight,d_runname,colspec,use_distcomp);
  Spest(colspec) = Stemp(colspec);
  save([d_runname '\Spest.mat'],'Spest');

  % find incomplet run -- problem with some workers
  temp = {Spest.Results};
  temp = find(arrayfun(@(y) isempty(temp{y}),1:44));
  if length(temp)==length(colspec), colspec = [];
  else colspec = temp; end
end

[cor_pair,par_insens,par_eig]=par_correlation(Spest(corr_wtcol),d_runname);
save([d_runname '\Spest.mat'],'cor_pair','par_insens','par_eig','-append');

loadOfflineResults(d_runname);
