function extract_gwpar(f_xlsfile,runname)

if nargin < 1 || isempty(f_xlsfile)
  d_xlsfile = fileparts(mfilename('fullpath'));
  f_xlsfile = 'ModflowZonations_11032006.xlsx';
else
  [d_xlsfile,f_xlsfile] = fileparts(f_xlsfile);
  f_xlsfile = [f_xlsfile '.xlsx'];
end
if nargin < 2, runname = 'pp_test'; end

[xlsnum,xlstxt] = xlsread(fullfile(d_xlsfile,f_xlsfile),'ModflowProperties');
for i=1:length(xlstxt)
  eval([char(xlstxt(i)) '=xlsnum(:,' num2str(i) ');']);
end
% f_xlsfile
%  t = readtable(fullfile(d_xlsfile,f_xlsfile),'Sheet','ModflowProperties');

%% write data for MODFLOW
for i = 1:4, fid(i) = fopen(fullfile(d_xlsfile,sprintf('%s.dt%d',runname,i)),'wt'); end
for i = 1:length(CellID)
  irow = floor(CellID(i)/1000);
  icol = mod(CellID(i),1000);
  fprintf(fid(1),'%5d%5d%15.6e\n',irow,icol,Leakance(i));
  fprintf(fid(2),'%5d%5d%15.6e\n',irow,icol,Transmissivity3(i));
  fprintf(fid(3),'%5d%5d%15.6e\n',irow,icol,UnconfinedStorage3(i));
  fprintf(fid(4),'%5d%5d%15.6e\n',irow,icol,ConfinedStorage3(i));
end
for i = 1:4, fclose(fid(i)); end

%% write PEST template for MODFLOW
for i = 1:4
  fid(i) = fopen(fullfile(d_xlsfile,sprintf('%s.tp%d',runname,i)),'wt');
  % first line
  fprintf(fid(i),'%s\n','ptf !');
end
for i = 1:length(CellID)
  irow = floor(CellID(i)/1000);
  icol = mod(CellID(i),1000);  
  fprintf(fid(1),'%5d%5d!lk%03d        !\n',irow,icol,LeakanceZoneID(i));
  fprintf(fid(2),'%5d%5d!tm%03d        !\n',irow,icol,Transmissivity3ZoneID(i));
  fprintf(fid(3),'%5d%5d!us%02d        !\n',irow,icol,UnconfinedStorage3ZoneID(i));
  fprintf(fid(4),'%5d%5d!cs%02d        !\n',irow,icol,ConfinedStorage3ZoneID(i));
end
for i = 1:4, fclose(fid(i)); end


%% define variables by headers
lkzone=unique(LeakanceZoneID)';
tmzone=unique(Transmissivity3ZoneID)';
cszone=unique(ConfinedStorage3)';
uszone=unique(UnconfinedStorage3ZoneID)';

%% save data to verify with parameter file
outstr = [];
for i=lkzone
  temp = Leakance(LeakanceZoneID==i);
  outstr = [outstr; {sprintf('lk%03d,%e',i,temp(1))}];
end
for i=tmzone
  temp = Transmissivity3(Transmissivity3ZoneID==i);
  outstr = [outstr; {sprintf('tm%03d,%e',i,temp(1))}];
end
for i=cszone
  temp = ConfinedStorage3(ConfinedStorage3==i);
  outstr = [outstr; {sprintf('cs%02d,%e',i,temp(1))}];
end
for i=uszone
  temp = UnconfinedStorage3(UnconfinedStorage3ZoneID==i);
  outstr = [outstr; {sprintf('us%02d,%e',i,temp(1))}];
end
disp(char(outstr));