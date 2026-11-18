function [s,o,qp]=supp_controller_step(s,omega,pe,t,c)
% Reference implementation of the revised physical-unit incremental MPC.
% Absolute state prediction is algebraically identical to the incremental
% lift with its coefficient-change offset, without subtracting noisy histories.
k=min(numel(c.noiseHz),max(1,round(t/c.Ts)+1));
noisyOmega=omega+2*pi*c.noiseHz(k);
s.measurementBuffer=[s.measurementBuffer(:,2:3),[noisyOmega;pe]];
measurement=s.measurementBuffer(:,3-c.delaySamples);
wm=measurement(1);pem=measurement(2);e=wm-c.w0;
raw=(wm-s.previousOmega)/c.Ts;
af=exp(-2*pi*c.derivativeCutoffHz*c.Ts);
s.derivative=af*s.derivative+(1-af)*raw;
s.previousOmega=wm;
J=c.J0;D=c.D0;
adaptive=~strcmp(c.method,'fixed') && ~strcmp(c.method,'vsg');
if adaptive
 if e*s.derivative>0 && abs(s.derivative)>c.Tj
  J=c.J0+c.Kj*abs(s.derivative);
 end
 if abs(e)>c.Td, D=c.D0+c.Kd*abs(e); end
end
q=c.qfixed;
if adaptive,q=c.Kr*(c.ar*J+D);end
fallback=0;fail=0;iterations=0;qpSeconds=0;maxResidual=0;cost=0;
if strcmp(c.method,'vsg') || strcmp(c.method,'adaptive_vsg')
 s.pm=c.Pref;
else
 a=exp(-D/J*c.Ts);b=-expm1(-D/J*c.Ts)/(D*c.w0);
 N=c.N;G=zeros(N);free=zeros(N,1);
 for i=1:N
  free(i)=a^i*e+b*sum(a.^(0:i-1))*(s.pm-pem);
  for j=1:i,G(i,j)=b*sum(a.^(0:i-j));end
 end
 % Scale variables in kW and the entire objective by a positive constant.
 % This changes conditioning, not the physical cost or the minimizer.
 scale=1000;Gs=G*scale;L=tril(ones(N));
 H=2*(eye(N)+(q/c.r)*(G'*G));
 f=2*q/(c.r*scale)*G'*free;
 A=[Gs;-Gs;L;-L];
 rhs=[(2*pi*c.fmax-c.w0)*ones(N,1)-free;...
      -(2*pi*c.fmin-c.w0)*ones(N,1)+free;...
      (c.Pmax-s.pm)/scale*ones(N,1);...
      -(c.Pmin-s.pm)/scale*ones(N,1)];
 if nargout>2
  qp=struct('H',H,'f',f,'A',A,'rhs',rhs,'free',free,'G',G,'q',q,'r',c.r,'scale',scale);
 end
 method=c.method;if strcmp(method,'fixed'),method='full';end
 tic;
 [z,ok,info]=solve_sequence(H,f,A,rhs,s.previousU,method);
 qpSeconds=toc;fallback=double(info.fallback);iterations=info.iterations;
 if ok
  U=scale*z;
  s.pm=s.pm+U(1);s.previousU=z;
  maxResidual=max(A*z-rhs);
  cost=c.r*(U'*U)+q*sum((free+G*U).^2);
 else
  fail=1;s.previousU=[];
  % Explicit command-side protective hold after a failed complete solve.
  s.pm=min(c.Pmax,max(c.Pmin,s.pm));maxResidual=NaN;cost=NaN;
 end
end
assert(all(isfinite([s.pm,J,D,q])) && J>0 && D>0 && q>0);
o=[s.pm;J;D;q;wm;s.derivative;fallback;fail;iterations;qpSeconds;maxResidual;cost];
end
