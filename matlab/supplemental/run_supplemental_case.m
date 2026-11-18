function record=run_supplemental_case(c,rebuild)
if nargin<2,rebuild=false;end
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
addpath(here,fileparts(here));out=fullfile(root,'results','supplemental');
if ~exist(out,'dir'),mkdir(out);end
% Shared, band-limited measurement noise with exact seed and RMS.
rng(c.seed,'twister');n=round(c.stop/c.Ts)+1;
raw=randn(n,1);af=exp(-2*pi*100*c.Ts);
noise=filter(1-af,[1 -af],raw);noise=noise-mean(noise);
c.noiseHz=noise/std(noise)*c.noiseRmsHz;
dc=[0 800; c.stop 800];
if c.dcSag,dc=[0 800;1.20 640;1.25 800;c.stop 800];end
assignin('base','sup_cfg',c);assignin('base','sup_dc',dc);
mdl='supplemental_network';
if rebuild
 mdl=build_supplemental_network;
elseif ~bdIsLoaded(mdl)
 load_system(fullfile(root,'code',[mdl '.slx']));
end
wallTimer=tic;
try
 set_param(mdl,'SimulationCommand','update');
 so=sim(mdl);
 elapsed=toc(wallTimer);
 global SUPP_TRACE
 trace=SUPP_TRACE;trace=trace(all(isfinite(trace(:,1:10)),2),:);
 assert(size(trace,1)==n,'Missing controller samples: %d/%d',size(trace,1),n);
 assert(max(abs(trace(:,1)-(0:n-1)'*c.Ts))<1e-10,'Nonuniform control sample times.');
 names={'time_s','omega_rad_s','Pe_W','Pm_W','J','D','q',...
 'measured_omega_rad_s','filtered_acceleration_rad_s2','full_fallback',...
 'qp_fail','qp_iterations','qp_seconds','constraint_residual','predicted_cost'};
 name=[c.caseName '_' c.method];
 writetable(array2table(trace,'VariableNames',names),fullfile(out,[name '.csv']));
 network=[so.sup_voltage.time,so.sup_voltage.signals.values,...
  so.sup_gridCurrent.signals.values,so.sup_storageCurrent.signals.values];
 assert(size(network,1)==n && all(isfinite(network(:))),'Invalid electrical traces.');
 writetable(array2table(network,'VariableNames',{'time_s','va_V','vb_V','vc_V',...
  'iga_A','igb_A','igc_A','isa_A','isb_A','isc_A'}),fullfile(out,[name '_network.csv']));
 % Preserve the common-rate raw data used in the analysis in both MAT/CSV.
 % Avoid serializing unused legacy scopes at every electrical solver step.
 save(fullfile(out,[name '.mat']),'network','trace','c','elapsed','-v7.3');
 record=struct('caseName',c.caseName,'method',c.method,'completed',true,...
 'elapsedSeconds',elapsed,'samples',size(trace,1),'configuration',rmfield(c,'noiseHz'),...
 'matlabVersion',version,'minFrequencyHz',min(trace(:,2)/(2*pi)),...
 'maxFrequencyHz',max(trace(:,2)/(2*pi)),'qpFailures',sum(trace(:,11)),...
 'fullFallbacks',sum(trace(:,10)),'Jrange',[min(trace(:,5)),max(trace(:,5))],...
 'Drange',[min(trace(:,6)),max(trace(:,6))],'qrange',[min(trace(:,7)),max(trace(:,7))]);
 fprintf('COMPLETED %s elapsed=%.2fs frequency=[%.5f,%.5f] failures=%d fallback=%d\n',...
 name,elapsed,record.minFrequencyHz,record.maxFrequencyHz,record.qpFailures,record.fullFallbacks);
catch err
 record=struct('caseName',c.caseName,'method',c.method,'completed',false,...
 'elapsedSeconds',toc(wallTimer),'error',getReport(err,'extended','hyperlinks','off'),...
 'configuration',rmfield(c,'noiseHz'));
 fprintf('FAILED %s_%s\n%s\n',c.caseName,c.method,record.error);
end
fid=fopen(fullfile(out,[c.caseName '_' c.method '_run.json']),'w');
fwrite(fid,jsonencode(record,PrettyPrint=true));fclose(fid);
assert(record.completed,'Supplemental simulation failed; see run record.');
end
