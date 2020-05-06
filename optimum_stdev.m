function opt_stdev = optimum_stdev(par_cov,f_mat)
load(f_mat,'jac');
%jac = jac(1:3000,:);
nrow = floor(size(jac,1)/numlabs);
if labindex == numlabs
  djac = jac((1+(labindex-1)*nrow):end,:);
else
  djac = jac((1:nrow)+(labindex-1)*nrow,:);
end
opt_stdev = sqrt(diag(djac*par_cov*djac',0));