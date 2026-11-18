function export_saved_original
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results');
load(fullfile(out,'original_baseline.mat'),'so','elapsed');
names={'frequency_Hz','active_power_W','mpc_power_W','inertia','damping','frequency_weight'};
grid=(0:20e-6:1.5)'; info=struct('simulation_completed',true,'simulation_elapsed_seconds',elapsed,'resampling_period_s',20e-6);
for i=1:numel(names)
 ts=so.logsout.getElement(names{i}).Values;
 [t,idx]=unique(ts.Time); y=squeeze(ts.Data); y=y(idx);
 value=interp1(t,y,grid,'linear');
 writetable(table(grid,value,'VariableNames',{'time_s','value'}),fullfile(out,['original_' names{i} '.csv']));
 if i==1
  info.initial_frequency_Hz=value(1); info.final_frequency_Hz=value(end);
  info.islanded_max_frequency_error_Hz=max(abs(value(grid>=1.2)-50));
  info.nonfinite_count=sum(~isfinite(value));
 end
end
fid=fopen(fullfile(out,'original_baseline_summary.json'),'w');fprintf(fid,'%s',jsonencode(info,PrettyPrint=true));fclose(fid);
fprintf('SAVED_ORIGINAL_EXPORT=%s\n',jsonencode(info));
end
