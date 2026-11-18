function run_revision_experiments
root=fileparts(fileparts(mfilename('fullpath'))); outdir=fullfile(root,'results');
rng(260981,'twister'); Ts=50e-6; t=(0:Ts:.10)'; n=numel(t); N=5;
Pbase=30000; Pref=15000; wb=2*pi; w0=2*pi*50;
net=15000*(t>=.02); noise=.005*randn(n,1);
methods={'VSG','AdaptiveVSG','FixedMPC','AdaptiveMPC','WarmMPC','BlockMPC','ReuseMPC'};
cases={'nominal','J_low','J_high','D_low','D_high','noise','delay','renewable','power_limit','energy_limit','dc_sag'};
metrics={}; allcurves=struct; opts=struct;
for ic=1:numel(cases)
    cn=cases{ic}; opts.Jmult=1; opts.Dmult=1; opts.Pmax=45000;
    opts.noise=zeros(n,1); opts.delay=0; opts.E0=.5*3.6e7;
    dm=net;
    switch cn
        case 'J_low', opts.Jmult=.8;
        case 'J_high', opts.Jmult=1.2;
        case 'D_low', opts.Dmult=.8;
        case 'D_high', opts.Dmult=1.2;
        case 'noise', opts.noise=noise;
        case 'delay', opts.delay=1;
        case 'renewable', dm=net+3000*sin(2*pi*5*t).*(t>=.02);
        case 'power_limit', opts.Pmax=24000;
        case 'energy_limit', opts.E0=.1*3.6e7+1800;
        case 'dc_sag', opts.Pmax=36000;
    end
    use=methods; if ic>1, use={'AdaptiveMPC','ReuseMPC'}; end
    for im=1:numel(use)
        name=use{im}; [curve,m]=simulate(name,dm,opts);
        writetable(array2table(curve,'VariableNames',{'time_s','frequency_Hz','power_W','J_kgm2','D_Nmsrad','q','net_disturbance_W','energy_J'}), ...
            fullfile(outdir,[cn '_' name '.csv']));
        metrics(end+1,:)=[{cn,name},num2cell(m)]; %#ok<AGROW>
        if ic==1, allcurves.(name)=curve; end
        fprintf('CASE=%s METHOD=%s MAX_DF=%.6g MAX_ROCOF=%.6g QP_FAIL=%d REUSE_FALLBACK=%d\n',cn,name,m(1),m(2),m(5),m(6));
    end
end
T=cell2table(metrics,'VariableNames',{'case_name','method','max_df_Hz','max_rocof_Hzs','IAE_Hzs','final_df_Hz','qp_failures','full_fallbacks','power_violation_W','frequency_violation_Hz','energy_violation_J','slew_violation_Ws'});
writetable(T,fullfile(outdir,'revision_metrics.csv'));
benchmark(); save(fullfile(outdir,'revision_experiments.mat'),'T','allcurves','Ts','N','opts');
    function [curve,m]=simulate(name,dm,o)
        freq=zeros(n,1); power=Pref*ones(n,1); Js=.2*ones(n,1); Ds=10*ones(n,1); qs=40000*ones(n,1); energies=zeros(n,1); energies(1)=o.E0;
        prev=[]; uprev=0; J=.2; D=10; q=36000; deriv=0; fail=0; fb=0;
        adapt=any(strcmp(name,{'AdaptiveVSG','AdaptiveMPC','WarmMPC','BlockMPC','ReuseMPC'}));
        QP=~any(strcmp(name,{'VSG','AdaptiveVSG'})); mode='cold';
        if strcmp(name,'WarmMPC'), mode='warm'; elseif strcmp(name,'BlockMPC'), mode='block'; elseif strcmp(name,'ReuseMPC'), mode='reuse'; end
        measured=freq+o.noise;
        for k=1:n-1
            idx=max(1,k-o.delay); xmeas=freq(idx)+o.noise(idx);
            if k>1, raw=(xmeas-measured(k-1))*wb/Ts; else, raw=0; end
            deriv=exp(-2*pi*25*Ts)*deriv+(1-exp(-2*pi*25*Ts))*raw; measured(k)=xmeas;
            if adapt && mod(k-1,20)==0
                jt=.2;
                if xmeas*deriv>0, jt=min(1,.2+.2*max(abs(deriv)-2.5,0)); end
                dt=min(40,10+10*max(abs(wb*xmeas)-.1,0));
                J=J+min(max(jt-J,-.01),.01); D=D+min(max(dt-D,-1),1);
                qt=min(150000,max(36000,3000*(10*J+D))); q=q+min(max(qt-q,-1000),1000);
            elseif ~adapt, J=.2; D=10; q=40000; end
            a=exp(-D/J*Ts); b=Pbase*(1-a)/(D*w0*wb);
            [F,G,g]=prediction_matrices(a,b,N); free=F*xmeas+g*(dm(idx)/Pbase);
            Emax=.9*3.6e7; Emin=.1*3.6e7;
            umax=(o.Pmax-Pref)/Pbase; umin=-Pref/Pbase; dr=1e6*Ts/Pbase;
            L=eye(N)-diag(ones(N-1,1),-1); l0=[uprev;zeros(N-1,1)]; C=tril(ones(N));
            A=[G;-G;eye(N);-eye(N);L;-L;Ts*Pbase*C;-Ts*Pbase*C];
            rhs=[1.5*ones(N,1)-free;1.5*ones(N,1)+free;umax*ones(N,1);-umin*ones(N,1);dr*ones(N,1)+l0;dr*ones(N,1)-l0; ...
                (energies(k)-Emin)*ones(N,1)-Ts*Pref*(1:N)';(Emax-energies(k))*ones(N,1)+Ts*Pref*(1:N)'];
            if QP
                H=2*(q*(G'*G)+eye(N)); f=2*q*G'*free;
                [U,ok,inf]=solve_sequence(H,f,A,rhs,prev,mode); fb=fb+inf.fallback;
                if ok, u=U(1); prev=U; else, fail=fail+1; u=uprev; prev=[]; end
            else, u=0; end
            % Explicit actuator/energy safeguard, including full-QP failure.
            total=min(o.Pmax,max(0,Pref+Pbase*u));
            total=min(total,max(0,(energies(k)-Emin)/Ts)); u=(total-Pref)/Pbase;
            ap=exp(-(D*o.Dmult)/(J*o.Jmult)*Ts);
            bp=Pbase*(1-ap)/(D*o.Dmult*w0*wb);
            freq(k+1)=ap*freq(k)+bp*(u-dm(k)/Pbase);
            power(k)=total; energies(k+1)=energies(k)-Ts*total;
            uprev=u; Js(k)=J; Ds(k)=D; qs(k)=q;
        end
        power(end)=power(end-1); Js(end)=J; Ds(end)=D; qs(end)=q;
        win=t>=.02; rocof=diff(freq)/Ts;
        m=[max(abs(freq(win))),max(abs(rocof)),trapz(t(win),abs(freq(win))),abs(freq(end)),fail,fb, ...
            max(0,max(power)-o.Pmax),max(0,max(abs(freq))-1.5),max(0,.1*3.6e7-min(energies)),max(0,max(abs(diff(power)))/Ts-1e6)];
        curve=[t,50+freq,power,Js,Ds,qs,dm,energies];
    end
    function benchmark
        rows={}; sizes=[5,10,20]; rep=200;
        for nh=sizes
            [F,G,g]=prediction_matrices(exp(-10/.2*Ts),Pbase*(1-exp(-10/.2*Ts))/(10*w0*wb),nh);
            H=2*(40000*(G'*G)+eye(nh)); A=[eye(nh);-eye(nh);G;-G]; rhs=[ones(nh,1);.5*ones(nh,1);1.5*ones(2*nh,1)];
            for meth={'cold','warm','block','reuse'}
                mode=meth{1}; last=[]; elapsed=zeros(rep,1); gaps=zeros(rep,1); fbs=0;
                for j=1:rep+10
                    f=2*40000*G'*(F*(-.001-.0001*sin(j)) +g*.05);
                    [uf,ok]=solve_sequence(H,f,A,rhs,[],'cold'); assert(ok);
                    tic; [ur,ok,inf]=solve_sequence(H,f,A,rhs,last,mode); seconds=toc; assert(ok);
                    if j>10
                        elapsed(j-10)=1e6*seconds;
                        gaps(j-10)=max(0,(.5*ur'*H*ur+f'*ur)-(.5*uf'*H*uf+f'*uf));
                        fbs=fbs+inf.fallback;
                    end
                    last=ur;
                end
                rows(end+1,:)={nh,mode,mean(elapsed),median(elapsed),prctile(elapsed,95),max(elapsed),mean(gaps),max(gaps),fbs}; %#ok<AGROW>
            end
        end
        writetable(cell2table(rows,'VariableNames',{'N','method','mean_us','median_us','p95_us','max_us','mean_cost_gap','max_cost_gap','full_fallbacks'}),fullfile(outdir,'qp_benchmark.csv'));
    end
end
