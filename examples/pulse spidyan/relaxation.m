% relaxation (spidyan)
%==========================================================================
% demonstration of how to switch relaxation on for specific events and how
% to set a userdefined equilibrium state
% relaxation types can be switched off, by removing them from Sys, or by
% setting to zero, e.g. to use only T1: Sys.T1 = 2; Sys.T2 = 0;

clear

% Spin System
Sys.ZeemanFreq = 9.500; % GHz
Sys.T1 = 1; % us
Sys.T2 = 0.5; % us

% Pulse Definitions
Rectangular.tp = 0.02; % us
Rectangular.Flip = pi; % rad

% A default Experiment/Sequence
Exp.mwFreq = 9.5; % GHz
Exp.Sequence = {Rectangular 2};
Exp.DetOperator = {'z1'};

Opt.Relaxation = [0 1]; % switches relaxation on only during the free evolution period 

spidyan(Sys,Exp,Opt);
