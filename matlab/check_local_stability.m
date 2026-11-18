function check_local_stability
root=fileparts(fileparts(mfilename('fullpath'))); Ts=50e-6; N=5; w0=2*pi*50; wb=2*pi; Pb=30000;
M=zeros(N,2); M(1,1)=1; M(N,2)=1; C=zeros(N,N-2); C(2:N-1,:)=eye(N-2);
S=eye(N); S=S(3:N,:); I=eye(N); e1=I(1,:); records=[];
A0=matrix(.2,10,36000); P=dlyap(A0',eye(N-1));
for J=linspace(.2,1,9)
 for D=linspace(10,40,9)
  for q=linspace(36000,150000,9)
   A=matrix(J,D,q); records(end+1,:)=[J,D,q,max(abs(eig(A))),max(eig(A'*P*A-P)),norm(A-A0,2)]; %#ok<AGROW>
  end
 end
end
mu=norm(P*A0,2); pn=norm(P,2); epsilon=1/(sqrt(mu^2+pn)+mu);
result=struct('grid_points',size(records,1),'max_spectral_radius',max(records(:,4)), ...
    'common_P_grid_worst_eigenvalue',max(records(:,5)),'nominal_P',P, ...
    'certified_matrix_radius',epsilon,'grid_max_distance',max(records(:,6)));
fid=fopen(fullfile(root,'results','stability_check.json'),'w'); fprintf(fid,'%s',jsonencode(result,PrettyPrint=true)); fclose(fid);
writematrix(records,fullfile(root,'results','stability_grid.csv'));
fprintf('STABILITY_CHECK=%s\n',jsonencode(result));
 function A=matrix(J,D,q)
   a=exp(-D/J*Ts); b=Pb*(1-a)/(D*w0*wb); [F,G,~]=prediction_matrices(a,b,N);
   H=2*(q*(G'*G)+eye(N)); Kx=2*q*G'*F; Hr=M'*H*M;
   Lx=-M*(Hr\(M'*Kx)); Lh=(eye(N)-M*(Hr\(M'*H)))*C;
   A=[a+b*e1*Lx,b*e1*Lh;S*Lx,S*Lh];
 end
end
