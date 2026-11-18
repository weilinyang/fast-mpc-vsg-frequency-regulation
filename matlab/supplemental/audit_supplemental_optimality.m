function audit_supplemental_optimality
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
addpath(here,fileparts(here));out=fullfile(root,'results','supplemental');
names={'nominal','command_cap','combined'};results=struct([]);
for j=1:numel(names)
 name=[names{j} '_reuse'];x=load(fullfile(out,[name '.mat']),'c','trace');
 c=x.c;T=x.trace;s=supp_initial_state(c);gap=[];replayError=0;
 for k=1:size(T,1)
  [s,o,qp]=supp_controller_step(s,T(k,2),T(k,3),T(k,1),c);
  replayError=max(replayError,abs(o(1)-T(k,4)));
  if mod(k-1,20)==0 && T(k,1)>=1
   [z,ok]=solve_sequence(qp.H,qp.f,qp.A,qp.rhs,[],'full');
   assert(ok);u=qp.scale*z;
   fullCost=qp.r*(u'*u)+qp.q*sum((qp.free+qp.G*u).^2);
   actualCost=o(12);diff=actualCost-fullCost;
   assert(diff>=-1e-7*(1+fullCost));
   assert(fullCost>eps,'Relative gap undefined for zero full-QP cost.');
   gap(end+1,:)=[T(k,1),actualCost,fullCost,diff,max(0,diff)/fullCost]; %#ok<AGROW>
  end
 end
 assert(replayError<1e-6,'Reference replay mismatch: %.9g',replayError);
 writetable(array2table(gap,'VariableNames',{'time_s','reuse_cost','full_cost',...
 'cost_difference','relative_gap'}),fullfile(out,[name '_cost_audit.csv']));
 results(j).caseName=names{j};results(j).samples=size(gap,1);
 results(j).maxRelativeGap=max(gap(:,5));results(j).maxAbsoluteGap=max(gap(:,4));
 results(j).commandReplayMaxErrorW=replayError;
 fprintf('AUDIT %s points=%d max_relative_gap=%.8g replay=%.3g W\n',name,size(gap,1),max(gap(:,5)),replayError);
end
fid=fopen(fullfile(out,'optimality_audit.json'),'w');
fwrite(fid,jsonencode(results,PrettyPrint=true));fclose(fid);
end
