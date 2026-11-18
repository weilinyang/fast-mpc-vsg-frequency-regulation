function plot_revision
root=fileparts(fileparts(mfilename('fullpath'))); set(groot,'defaultAxesFontName','Times New Roman','defaultAxesFontSize',10);
names={'VSG','AdaptiveVSG','FixedMPC','AdaptiveMPC','ReuseMPC'};
labels={'VSG','Adaptive VSG','Fixed MPC','Full adaptive MPC','Sequence reuse'};
colors=[.4 .4 .4;.9 .6 0;0 .6 .4;0 .45 .7;.8 .45 .65]; styles={'--','-.',':','-','--'};
fig=figure('Visible','off','Units','inches','Position',[1 1 7.1 5]); tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
ax1=nexttile; hold on; ax2=nexttile; hold on;
for i=1:numel(names)
 d=readtable(fullfile(root,'results',['nominal_' names{i} '.csv']));
 plot(ax1,1000*d.time_s,d.frequency_Hz-50,styles{i},'Color',colors(i,:),'LineWidth',1.3);
 plot(ax2,1000*d.time_s,d.power_W/1000,styles{i},'Color',colors(i,:),'LineWidth',1.3);
end
xlabel(ax1,'Time (ms)'); ylabel(ax1,'(a) Frequency error (Hz)'); legend(ax1,labels,'Location','southeast','FontSize',8);
xlabel(ax2,'Time (ms)'); ylabel(ax2,'(b) ESS power (kW)');
ax3=nexttile; yyaxis left; plot(1000*d.time_s,d.J_kgm2,'Color',colors(end,:)); ylabel('(c) J (kg m^2)');
yyaxis right; plot(1000*d.time_s,d.D_Nmsrad,':','Color',colors(4,:)); ylabel('D (N m s/rad)'); xlabel('Time (ms)');
ax4=nexttile; plot(1000*d.time_s,d.q/1000,'Color',colors(end,:)); xlabel('Time (ms)'); ylabel('(d) Frequency weight q / 1000');
for a=[ax1 ax2 ax3 ax4], grid(a,'on'); xline(a,20,':','Color',[.6 .6 .6]); box(a,'off'); end
exportgraphics(fig,fullfile(root,'manuscript','revision_nominal.png'),'Resolution',300); close(fig);
T=readtable(fullfile(root,'results','revision_metrics.csv'));
cases={'J_low','J_high','D_low','D_high','noise','delay','renewable','power_limit','energy_limit','dc_sag'};
cats={'J -20%','J +20%','D -20%','D +20%','Noise','Delay','Renewable','Power cap','Energy','DC cap'};
v=zeros(10,2); r=v;
for j=1:10
 for k=1:2
  methods={'AdaptiveMPC','ReuseMPC'}; row=T(strcmp(T.case_name,cases{j})&strcmp(T.method,methods{k}),:);
  v(j,k)=row.max_df_Hz; r(j,k)=row.max_rocof_Hzs;
 end
end
fig=figure('Visible','off','Units','inches','Position',[1 1 7.1 3]); tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for j=1:2
 nexttile; if j==1, h=bar(v); ylabel('(a) Maximum frequency error (Hz)'); else, h=bar(r); ylabel('(b) Maximum RoCoF (Hz/s)'); end
 h(1).FaceColor=colors(4,:); h(2).FaceColor=colors(5,:); xticks(1:10); xticklabels(cats); xtickangle(65); grid on; box off;
 if j==1, legend('Full adaptive MPC','Sequence reuse','Location','northwest','FontSize',8); end
end
exportgraphics(fig,fullfile(root,'manuscript','revision_robustness.png'),'Resolution',300); close(fig);
B=readtable(fullfile(root,'results','qp_benchmark.csv')); fig=figure('Visible','off','Units','inches','Position',[1 1 6.4 2.7]); hold on;
methods={'cold','warm','block','reuse'}; labels={'Full / cold','Full / shifted initial guess','Two-block','Sequence reuse'};
for i=1:4, q=B(strcmp(B.method,methods{i}),:); plot(q.N,q.median_us,'o-','Color',colors(i+1,:),'DisplayName',labels{i}); end
yline(50,':','50 us sampling interval','DisplayName','50 us interval'); xticks([5 10 20]); xlabel('Prediction horizon N'); ylabel('Median desktop QP time (us)'); legend('Location','best','NumColumns',2,'FontSize',8); grid on; box off;
exportgraphics(fig,fullfile(root,'manuscript','revision_timing.png'),'Resolution',300); close(fig);
end
