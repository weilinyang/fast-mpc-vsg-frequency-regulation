function run_original_baseline
base = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(base,'results');
load_system(fullfile(base,'code','fangzheng.slx'));
mdl = 'fangzheng';
paths = {'VSG_1/转子机械方程/Gain', ...
    'VSG_1/转子机械方程/Pe', ...
    'VSG_1/转子机械方程/Subsystem2', ...
    'VSG_1/转子机械方程/自适应参数1', ...
    'VSG_1/转子机械方程/Subsystem2/Gain'};
names = {'frequency_Hz','active_power_W','mpc_power_W','inertia','frequency_weight'};
for i=1:numel(paths)
    ports=get_param([mdl '/' paths{i}],'PortHandles');
    set_param(ports.Outport(1),'DataLogging','on', ...
        'DataLoggingNameMode','Custom','DataLoggingName',names{i});
end
ports=get_param([mdl '/' paths{4}],'PortHandles');
set_param(ports.Outport(2),'DataLogging','on', ...
    'DataLoggingNameMode','Custom','DataLoggingName','damping');
si=Simulink.SimulationInput(mdl);
si=si.setModelParameter('SignalLogging','on','SignalLoggingName','logsout', ...
    'ReturnWorkspaceOutputs','on','StopTime','1.5','SimulationMode','normal');
tic;
try
    so=sim(si);
    elapsed=toc;
    save(fullfile(out,'original_baseline.mat'),'so','elapsed','-v7.3');
    for i=1:so.logsout.numElements
        el=so.logsout.getElement(i);
        ts=el.Values;
        data=squeeze(ts.Data);
        if isvector(data)
            writetable(table(ts.Time,data(:),'VariableNames',{'time_s','value'}), ...
                fullfile(out,['original_' regexprep(el.Name,'[^A-Za-z0-9_-]','_') '.csv']));
        end
    end
    fprintf('ORIGINAL_SIMULATION_COMPLETED=1\nELAPSED_SECONDS=%.3f\n',elapsed);
catch err
    elapsed=toc;
    msg=getReport(err,'extended','hyperlinks','off');
    fid=fopen(fullfile(out,'original_baseline_error.txt'),'w');fprintf(fid,'%s',msg);fclose(fid);
    fprintf('ORIGINAL_SIMULATION_COMPLETED=0\n%s\n',msg);
end
close_system(mdl,0);
end
