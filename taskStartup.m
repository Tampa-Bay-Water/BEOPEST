function taskStartup(task)
!echo on
!hostname > c:\windows\temp\netuse.txt
!cd >> c:\windows\temp\netuse.txt
% !tasklist /v >> c:\windows\temp\netuse.txt
% !for /F %a in ('hostname') do set hn=%a
% !perl -e "foreach (keys(%ENV)) {print $_,q( ),$ENV{$_},qq(\n)}" >> c:\windows\temp\netuse.txt 2>&1

!net use /P:Y
% MATLAB ghostscript won't work if cwd name is UNC
!net use E: /delete >> c:\windows\temp\netuse.txt 2>&1
!net use E: \\kuhntucker\E$ password111 /user:kuhntucker\chinman >> c:\windows\temp\netuse.txt 2>&1
!net use F: /delete >> c:\windows\temp\netuse.txt 2>&1
!net use F: \\vgridfs\vgridfs_e password111 /user:vgridfs\chinman >> c:\windows\temp\netuse.txt 2>&1
%!net use F: \\vgridfs\E$ password111 /user:vgridfs\chinman >> c:\windows\temp\netuse.txt 2>&1

!for %I in (01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27) do net use \\vgrid%I\c$ /delete >> c:\windows\temp\netuse.txt 2>&1
!for %I in (01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27) do net use \\vgrid%I\c$ password111 /user:vgrid%I\chinman >> c:\windows\temp\netuse.txt 2>&1
!net use >> c:\windows\temp\netuse.txt 2>&1
addpath(...
	'E:\MATLAB_R2007a\work',...
	'F:\VGRIDS\ppest\SensitivityAnalysis'...
  );