% check_dynord    Process dynamics and ordering potential.
%
%   (Could be) Implemented to simplify and maintain consistency in code across programs.
%

function varargout = check_dynord(program,Sys,FieldSweep)

assert(ischar(program), 'Program name must be a string.')

switch program
  case 'chili'
    if isfield(Sys,'psi')
      error('Sys.psi is obsolete. Remove it from your code. See the documentation for details.');
    end

    if ~isfield(Sys,'DiffFrame'), Sys.DiffFrame = [0 0 0]; end
    if ~isfield(Sys,'Exchange'), Sys.Exchange = 0; end
    if ~isfield(Sys,'lambda'), Sys.lambda = []; end

    if isfield(Sys,'tcorr'), Dynamics.tcorr = Sys.tcorr; end
    if isfield(Sys,'Diff'), Dynamics.Diff = Sys.Diff; end
    if isfield(Sys,'logtcorr'), Dynamics.logtcorr = Sys.logtcorr; end
    if isfield(Sys,'logDiff'), Dynamics.logDiff = Sys.logDiff; end
    if isfield(Sys,'lwpp'), Dynamics.lwpp = Sys.lwpp; end
    if isfield(Sys,'lw'), Dynamics.lw = Sys.lw; end

    Dynamics.Exchange = Sys.Exchange;
    Potential.lambda = Sys.lambda;
    usePotential = ~isempty(Potential.lambda) && ~all(Potential.lambda==0);
    
    [Dynamics,err] = processdynamics(Dynamics,FieldSweep);
    error(err);
    
    varargout = {Dynamics,Potential,usePotential};
    
  case 'cardamom'
    
%     if isfield(Sys,'psi')
%       error('Sys.psi is obsolete. Remove it from your code. See the documentation for details.');
%     end
% 
%     if ~isfield(Sys,'DiffFrame'), Sys.DiffFrame = [0 0 0]; end  % TODO implement in cardamom
%     if ~isfield(Sys,'Exchange'), Sys.Exchange = 0; end
%     if ~isfield(Sys,'lambda'), Sys.lambda = []; end

    if isfield(Sys,'tcorr'), Dynamics.tcorr = Sys.tcorr; end  % TODO process and feed to stochtraj?
    if isfield(Sys,'Diff'), Dynamics.Diff = Sys.Diff; end
    if isfield(Sys,'logtcorr'), Dynamics.logtcorr = Sys.logtcorr; end
    if isfield(Sys,'logDiff'), Dynamics.logDiff = Sys.logDiff; end
    if isfield(Sys,'lwpp'), Dynamics.lwpp = Sys.lwpp; end
    if isfield(Sys,'lw'), Dynamics.lw = Sys.lw; end

%     Dynamics.Exchange = Sys.Exchange;
%     Potential.lambda = Sys.lambda;
%     usePotential = ~isempty(Potential.lambda) && ~all(Potential.lambda==0);
    
    [Dynamics,err] = processdynamics(Dynamics,FieldSweep);
    error(err);
    
    varargout = {Dynamics};%,Potential,usePotential};

  case 'stochtraj'
    if isfield(Sys,'Coefs') && isfield(Sys,'LMK')
      if ~ismatrix(Sys.LMK) || size(Sys.LMK,2)~=3
        error('LMK must be an array of shape Nx3.')
      end
      if ~ismatrix(Sys.Coefs) || size(Sys.Coefs,2)~=2
        error('Coefs must be an array of shape Nx2.')
      end
      % Enforce indexing convention
      for j=1:size(Sys.LMK,1)
        L = Sys.LMK(j,1);
        M = Sys.LMK(j,2);
        K = Sys.LMK(j,3);
        assert(L>0,'For all sets of indices LMK, it is required that L>0.')
        if K==0
          assert((0<=M)&&(M<=L),'For all sets of indices LMK, if K=0, then it is required that 0<=M<=L.')
        else
          assert((0<K)&&(K<=L)&&abs(M)<=L,'For all sets of indices LMK, if K~=0, then it is required that 0<K<=L and |M|<=L.')
        end
      end
    elseif ~isfield(Sys,'Coefs') && ~isfield(Sys,'LMK')
      % if no ordering potential coefficient is given, initialize empty arrays
      Sys.Coefs = [];
      Sys.LMK = [];
    else
      error('Both ordering coefficients and LMK are required for an ordering potential.')
    end

    Sim.Coefs = Sys.Coefs;
    Sim.LMK = Sys.LMK;

    % parse the dynamics parameter input using private function
    if isfield(Sys,'tcorr'), Dynamics.tcorr = Sys.tcorr;
    elseif isfield(Sys,'Diff'), Dynamics.Diff = Sys.Diff;
    elseif isfield(Sys,'logtcorr'), Dynamics.logtcorr = Sys.logtcorr;
    elseif isfield(Sys,'logDiff'), Dynamics.logDiff = Sys.logDiff;
    else error('A rotational correlation time or diffusion rate is required.'); end
    
    % FieldSweep not implemented for stochtraj yet
    [Dynamics, err] = processdynamics(Dynamics,[]);
    error(err);

    varargout = {Dynamics,Sim};

  otherwise
    error('Program not recognized.')
    
end

end

%% Helper function
function [Dyn,err] = processdynamics(D,FieldSweep)

Dyn = D;
err = '';

% diffusion tensor, correlation time
%------------------------------------------------------------------------
% convert everything (tcorr, logcorr, logDiff) to Diff
if isfield(Dyn,'Diff')
  % Diff given
elseif isfield(Dyn,'logDiff')
  Dyn.Diff = 10.^Dyn.logDiff;
elseif isfield(Dyn,'tcorr')
  Dyn.Diff = 1/6./Dyn.tcorr;
elseif isfield(Dyn,'logtcorr')
  if Dyn.logtcorr>=0, error('Sys.logtcorr must be negative.'); end
  Dyn.Diff = 1/6./10.^Dyn.logtcorr;
else
  err = sprintf('You must specify a rotational correlation time or a diffusion tensor\n(Sys.tcorr, Sys.logtcorr, Sys.Diff or Sys.logDiff).');
  return
end

if any(Dyn.Diff<0)
  error('Negative diffusion rate or correlation times are not possible.');
elseif any(Dyn.Diff>1e12)
  fprintf('Diffusion rate very fast. Simulation might not converge.\n');
elseif any(Dyn.Diff<1e3)
  fprintf('Diffusion rate very slow. Simulation might not converge.\n');
end

% expand to rhombic tensor
switch numel(Dyn.Diff)
  case 1, Dyn.Diff = Dyn.Diff([1 1 1]);
  case 2, Dyn.Diff = Dyn.Diff([1 1 2]);
  case 3, % Diff already rhombic
  otherwise
    err = 'Sys.Diff must have 1, 2 or 3 elements (isotropic, axial, rhombic).';
    return
end

if isfield(Dyn,'lw')
  if numel(Dyn.lw)>1
    if FieldSweep
      LorentzFWHM = Dyn.lw(2)*28 * 1e6; % mT -> MHz -> Hz
    else
      LorentzFWHM = Dyn.lw(2)*1e6; % MHz -> Hz
    end
  else
    LorentzFWHM = 0;
  end
  if (LorentzFWHM~=0)
    % Lorentzian T2 from FWHM in freq domain 1/T2 = pi*FWHM
    Dyn.T2 = 1/LorentzFWHM/pi;
  else
    Dyn.T2 = inf;
  end
end

% Heisenberg exchange
%------------------------------------------------------------------
if ~isfield(Dyn,'Exchange'), Dyn.Exchange = 0; end
Dyn.Exchange = Dyn.Exchange*2*pi*1e6; % MHz -> angular frequency

end