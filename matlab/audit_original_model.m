function audit_original_model
base = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(base,'results');
modelFile = fullfile(base,'code','fangzheng.slx');
report = struct('version',version,'release',version('-release'),'model_file',modelFile);
try
    load_system(modelFile);
    name = 'fangzheng';
    report.loaded = true;
    report.solver = get_param(name,'Solver');
    report.simulation_mode = get_param(name,'SimulationMode');
    report.stop_time = get_param(name,'StopTime');
    report.init_callback = get_param(name,'InitFcn');
    functions = find_system(name,'LookUnderMasks','all','FollowLinks','on','SFBlockType','MATLAB Function');
    report.matlab_functions = functions;
    report.powergui = find_system(name,'LookUnderMasks','all','FollowLinks','on','MaskType','PSB option menu block');
    report.to_workspace = find_system(name,'LookUnderMasks','all','FollowLinks','on','BlockType','ToWorkspace');
    report.scope_count = length(find_system(name,'LookUnderMasks','all','BlockType','Scope'));
    fprintf('MODEL_LOADED=1\nSOLVER=%s\nMODE=%s\n',report.solver,report.simulation_mode);
    try
        set_param(name,'SimulationCommand','update');
        report.compiles = true;
        fprintf('MODEL_COMPILES=1\n');
    catch err
        report.compiles = false;
        report.compile_error = getReport(err,'extended','hyperlinks','off');
        fprintf('MODEL_COMPILES=0\n%s\n',report.compile_error);
    end
    close_system(name,0);
catch err
    report.loaded = false;
    report.load_error = getReport(err,'extended','hyperlinks','off');
    fprintf('MODEL_LOADED=0\n%s\n',report.load_error);
end
fid = fopen(fullfile(out,'original_model_audit.json'),'w');
fwrite(fid,jsonencode(report,PrettyPrint=true));
fclose(fid);
end
