function [U,ok,info]=solve_sequence(H,f,A,rhs,previous,method)
% Exact affine restriction of .5*U'*H*U+f'*U, retaining cross terms.
% Desktop reference implementation; quadprog is not an embedded deployment.
persistent options
if isempty(options)
    options=optimoptions('quadprog','Algorithm','active-set','Display','off', ...
        'OptimalityTolerance',1e-9,'ConstraintTolerance',1e-8,'MaxIterations',200);
end
N=numel(f); H=(H+H')/2; info.fallback=false; info.iterations=0;
if strcmp(method,'reuse') && ~isempty(previous)
    M=zeros(N,2); M(1,1)=1; M(N,2)=1;
    c=[0;previous(3:N);0]; z0=[previous(2);previous(N)];
elseif strcmp(method,'block')
    M=zeros(N,2); M(1,1)=1; M(2:N,2)=1; c=zeros(N,1); z0=zeros(2,1);
else
    M=eye(N); c=zeros(N,1); z0=zeros(N,1);
    if strcmp(method,'warm') && ~isempty(previous)
        z0=[previous(2:N);previous(N)];
    end
end
[z,ef,iterations]=solve_qp(M'*H*M,M'*(H*c+f),A*M,rhs-A*c,z0,options);
info.iterations=iterations;
ok=ef>0 && ~isempty(z);
if ok, U=M*z+c; ok=all(isfinite(U)) && max(A*U-rhs)<=1e-7; else, U=[]; end
if ~ok && size(M,2)<N
    info.fallback=true;
    [U,ef,iterations]=solve_qp(H,f,A,rhs,zeros(N,1),options);
    info.iterations=info.iterations+iterations;
    ok=ef>0 && ~isempty(U) && all(isfinite(U)) && max(A*U-rhs)<=1e-7;
end
end
function [z,ef,iterations]=solve_qp(H,f,A,rhs,z0,options)
% Exact interior solution for all variants. Active-set quadprog can cycle
% near zero gradients despite a strictly feasible unconstrained minimizer.
% Check both feasibility and stationarity; otherwise solve the constrained QP.
z=-H\f;iterations=0;
if all(isfinite(z)) && max(A*z-rhs)<=0 && ...
 norm(H*z+f,inf)<=1e-10*(1+norm(f,inf))
 ef=1;return;
end
[z,~,ef,out]=quadprog(H,f,A,rhs,[],[],[],[],z0,options);
iterations=out.iterations;
end
