function [F,G,g]=prediction_matrices(a,b,N)
% Absolute normalized frequency error and absolute power correction.
F=(a.^(1:N))'; G=zeros(N); g=zeros(N,1);
for i=1:N
    G(i,1:i)=b*a.^((i-1):-1:0);
    g(i)=-sum(G(i,1:i));
end
end
