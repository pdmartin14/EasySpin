function ok = test(opt)

% Assure that esfit runs using multiple systems.

Sys1.g = [2 2.1];
Sys1.lw = 10;
Sys2.g = [1.98 2.03];
Sys2.lw = 5;

Exp.Field = 350;
Exp.mwRange = [9.5 10.5];

[nu,spc] = pepper({Sys1,Sys2},Exp);
rng(1)
spc = addnoise(spc,80,'u');

Vary1.g = [0.02 0.02]; 
Vary2.g = [0.02 0.02]; 
Opt = struct;
FitOpt.PrintLevel = 0;
FitOpt.Method = 'levmar fcn';
[~,spcfit,resid] = esfit(@pepper,spc,{Sys1,Sys2},{Vary1,Vary2},Exp,Opt,FitOpt);

rmsd = sqrt(mean(resid.^2));

ok = rmsd<3e-2;

if opt.Display
  plot(nu,spc,nu,spcfit);
  legend('exp','fit');
end

data = [];
