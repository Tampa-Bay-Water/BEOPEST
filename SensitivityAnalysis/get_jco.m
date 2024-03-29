function [jac nobs npar]=get_jco(f_jco)
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
[nobs,npar] = size(jac);
