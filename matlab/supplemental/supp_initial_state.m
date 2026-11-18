function s=supp_initial_state(c)
s=struct('pm',c.Pref,'previousU',[],'previousOmega',c.w0,'derivative',0,...
 'measurementBuffer',repmat([c.w0;0],1,3));
end
