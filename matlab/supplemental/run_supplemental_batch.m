function run_supplemental_batch(indices)
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
addpath(here,fileparts(here));cases={};
c=supp_config;c.caseName='nominal';
for m={'full','warm','block','reuse'},d=c;d.method=m{1};cases{end+1}=d;end
for j=[.8 1.2]
 for damp=[.8 1.2]
  c=supp_config;c.Jplant=j;c.Dplant=damp;
  c.caseName=sprintf('mismatch_J%03d_D%03d',round(j*100),round(damp*100));
  cases=pair(c,cases);
 end
end
for seed=[260108 260109 260110]
 c=supp_config;c.noiseRmsHz=.005;c.seed=seed;
 c.caseName=sprintf('noise_seed%d',seed);cases=pair(c,cases);
end
for delay=[1 2]
 c=supp_config;c.delaySamples=delay;c.caseName=sprintf('delay%d',delay);
 cases=pair(c,cases);
end
c=supp_config;c.renewable=true;c.caseName='renewable';cases=pair(c,cases);
c=supp_config;c.dcSag=true;c.caseName='dc_sag';cases=pair(c,cases);
c=supp_config;c.Pmax=18000;c.caseName='command_cap';
for m={'full','warm','block','reuse'},d=c;d.method=m{1};cases{end+1}=d;end
c=supp_config;c.Jplant=1.2;c.Dplant=.8;c.noiseRmsHz=.005;
c.delaySamples=2;c.renewable=true;c.dcSag=true;c.caseName='combined';cases=pair(c,cases);
c=supp_config;c.electricalStep=1e-6;c.caseName='step_1us';cases=pair(c,cases);
if nargin<1,indices=1:numel(cases);end
records=cell(size(indices));
for ii=1:numel(indices)
 k=indices(ii);
 fprintf('RUN %d/%d: %s_%s\n',k,numel(cases),cases{k}.caseName,cases{k}.method);
 records{ii}=run_supplemental_case(cases{k},k==1);
end
fid=fopen(fullfile(root,'results','supplemental',sprintf('batch_runs_%02d.json',indices(1))),'w');
fwrite(fid,jsonencode(records,PrettyPrint=true));fclose(fid);
fprintf('BATCH_COMPLETE runs=%d\n',numel(cases));
end
function cases=pair(c,cases)
for m={'full','reuse'},d=c;d.method=m{1};cases{end+1}=d;end
end
