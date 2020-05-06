for grp=obs_wts(:,1)'
  i_temp = strncmp(obs_cellarray(:,2),grp,length(char(grp)));
  v_temp = sqrt(obs_wts{strcmp(obs_wts(:,1),grp),2});
  obs_cellarray(i_temp,7) = num2cell(repmat(v_temp,sum(i_temp),1));
  obs_cellarray(i_temp,7) = num2cell(([obs_cellarray{i_temp,7}].*[obs_cellarray{i_temp,4}]).^2);
end

obs_grps(:,3) = num2cell(cellfun(@(y) sum([obs_cellarray{strcmp(obs_cellarray(:,2),y),7}])...
  /sum(strcmp(obs_cellarray(:,2),y)),obs_grps(:,1)));