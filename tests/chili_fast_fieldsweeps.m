function [err,data] = test(opt,olddata)

%==============================================================
% Compare approximate and explicit field-swept spectra (fast)
%==============================================================

Sys.g = [2.01 2.003];
Sys.lw = 0.1;
Sys.tcorr = 1e-9;

Exp.mwFreq = 9.5;
Exp.Harmonic = 0;
Exp.nPoints = 200;
Exp.Range = [337 339];

Opt.LiouvMethod = 'fast';

[x,y1] = chili(Sys,Exp,Opt);

Opt.ExplicitFieldSweep = true;
[x,y2] = chili(Sys,Exp,Opt);

if opt.Display
  plot(x,y1,x,y2);
  legend('approximate','explicit');
end

err = ~areequal(y1,y2,1e-3*max(y1));

data = [];