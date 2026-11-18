function supp_sfcn(block)
block.NumDialogPrms=1;block.DialogPrmsTunable={'Nontunable'};
block.NumInputPorts=2;block.NumOutputPorts=1;
block.SetPreCompInpPortInfoToDynamic;block.SetPreCompOutPortInfoToDynamic;
for i=1:2
 block.InputPort(i).Dimensions=1;block.InputPort(i).DatatypeID=0;
 block.InputPort(i).Complexity='Real';block.InputPort(i).DirectFeedthrough=true;
end
block.OutputPort(1).Dimensions=4;block.OutputPort(1).DatatypeID=0;
block.OutputPort(1).Complexity='Real';
c=block.DialogPrm(1).Data;block.SampleTimes=[c.Ts 0];
block.SimStateCompliance='DefaultSimState';
block.RegBlockMethod('Start',@start);
block.RegBlockMethod('Outputs',@outputs);
end
function start(block)
global SUPP_STATE SUPP_TRACE SUPP_LAST_TIME SUPP_OUTPUT
c=block.DialogPrm(1).Data;SUPP_STATE=supp_initial_state(c);
SUPP_TRACE=nan(round(c.stop/c.Ts)+1,15);
SUPP_LAST_TIME=-inf;SUPP_OUTPUT=[c.Pref;c.J0;c.D0;c.Kr*(c.ar*c.J0+c.D0)];
end
function outputs(block)
global SUPP_STATE SUPP_TRACE SUPP_LAST_TIME SUPP_OUTPUT
t=block.CurrentTime;c=block.DialogPrm(1).Data;
if t>SUPP_LAST_TIME+c.Ts/10
 omega=block.InputPort(1).Data;pe=block.InputPort(2).Data;
 [SUPP_STATE,o]=supp_controller_step(SUPP_STATE,omega,pe,t,c);
 SUPP_OUTPUT=o(1:4);SUPP_LAST_TIME=t;
 k=round(t/c.Ts)+1;
 if k<=size(SUPP_TRACE,1),SUPP_TRACE(k,:)=[t,omega,pe,o'];end
end
block.OutputPort(1).Data=SUPP_OUTPUT;
end
