%  mdload     Load data generated by molecular dynamics simulations.
%
%   MD = mdload(TrajFile,TopFile);
%   MD = mdload(TrajFile,TopFile,Info);
%   MD = mdload(TrajFile,TopFile,Info,Opt);
%
%   Input:
%     TrajFile  Name of trajectory output file from the MD simulation.
%               Supported formats are identified via the extension
%               in 'TrajFile' and 'TopFile'. Extensions:
%
%                    NAMD, X-PLOR, CHARMM:   .DCD, .PSF
%
%     TopFile   Name of topology input file used for the MD simulation.
%
%     Info      structure array containing the following fields
%
%                    SegName    character array
%                               Name of segment in the topology file
%                               assigned to the spin-labeled protein.
%                               If empty, the first segment name is chosen.
%
%                    ResName    character array
%                               Name of residue assigned to spin label side 
%                               chain. If not give, 'CYR1' is assumed, which is
%                               the default used by CHARMM-GUI for R1.
%
%                    LabelName  spin label name, 'R1' or 'TOAC'
%                               If not given, it will be inferred from ResName
%
%                    AtomNames  structure array (optional)
%                               Contains the atom names used in the PSF to 
%                               refer to the following atoms in the 
%                               nitroxide spin label molecule model. The
%                               defaults for R1 and TOAC are:
%
%                      R1:
%                                              ON (ONname)
%                                              |
%                                              NN (NNname)
%                                            /   \
%                                  (C1name) C1    C2 (C2name)
%                                           |     |
%                                 (C1Rname) C1R = C2R (C2Rname)
%                                           |
%                                 (C1Lname) C1L
%                                           |
%                                 (S1Lname) S1L
%                                          /
%                                (SGname) SG
%                                         |
%                                (CBname) CB
%                                         |
%                             (Nname) N - CA (CAname)
%
%                      TOAC:
%                                         ON (ONname)
%                                         |
%                                         NN (NNname)
%                                        /   \
%                             (CGRname) CGR  CGS (CGSname)
%                                       |    |
%                             (CBRname) CBR  CBS (CBSname)
%                                        \  /
%                             (Nname) N - CA (CAname)
%
%
%     Op  t    structure array containing the following fields
%
%               Verbosity 0: no display, 1: (default) show info
%
%               keepProtCA  0: (default) delete protein alpha carbon coordinates
%                           1: keep them
%
%   Output:
%     MD        structure array containing the following fields:
%
%       .nSteps  total number of steps in trajectory
%
%       .dt      size of time step (in s)
%
%       .FrameTraj   numeric array, size = (3,3,nTraj,nSteps)
%                    xyz coordinates of coordinate frame axis
%                    vectors, x-axis corresponds to
%                    FrameTraj(:,1,nTraj,:), y-axis corresponds to
%                    FrameTraj(:,2,nTraj,:), etc.
%
%       .FrameTrajwrtProt   numeric array, size = (3,3,nTraj,nSteps)
%                           same as FrameTraj, but with global
%                           rotational diffusion of protein removed
%
%       .RProtDiff   numeric array, size = (3,3,nTraj,nSteps)
%                    trajectories of protein global rotational
%                    diffusion represented by rotation matrices
%
%       .dihedrals   numeric array, size = (nDihedrals,nTraj,nSteps)
%                    dihedral angles of spin label side chain;
%                    nDihedrals=5 for R1, nDihedrals=2 for TOAC
%

function MD = mdload(TrajFile,TopFile,Info,Opt)

switch nargin
  case 0
    help(mfilename); return;
  case 1
    error('At least two input arguments (trajecory file and structure file) are needed.');
  case 2
    Info = struct;
    Opt = struct;
  case 3
    Opt = struct;
  case 4
  otherwise
    error('No more than 4 input arguments are possible.')
end

if ~isfield(Opt,'Verbosity'), Opt.Verbosity = 1; end
if ~isfield(Opt,'keepProtCA'), Opt.keepProtCA = false; end

global EasySpinLogLevel;
EasySpinLogLevel = Opt.Verbosity;

if ~isfield(Info,'ResName')
  Info.ResName = 'CYR1';
end
ResName = Info.ResName;

% Supplement LabelName if it can be inferred from ResName
if ~isfield(Info,'LabelName')
  switch ResName
    case 'TOC'
      Info.LabelName = 'TOAC';
    case 'CYR1'
      Info.LabelName = 'R1';
    otherwise
      error('Info.LabelName is missing and cannot be inferred from Info.LabelName.');
  end
end
LabelName = Info.LabelName;
if ~any(strcmp(LabelName,{'R1','TOAC'}))
  error('Label ''%s'' (given in Info.LabelName) is not supported.',LabelName);
end

% Supplement default atom names if not given
if ~isfield(Info,'AtomNames')
  switch LabelName
    case 'R1'
      logmsg(1,'Using default atom names for label R1.');
      Info.AtomNames.ONname = 'ON';
      Info.AtomNames.NNname = 'NN';
      Info.AtomNames.C1name = 'C1';
      Info.AtomNames.C2name = 'C2';
      Info.AtomNames.C1Rname = 'C1R';
      Info.AtomNames.C2Rname = 'C2R';
      Info.AtomNames.C1Lname = 'C1L';
      Info.AtomNames.S1Lname = 'S1L';
      Info.AtomNames.SGname = 'SG';
      Info.AtomNames.CBname = 'CB';
      Info.AtomNames.CAname = 'CA';
      Info.AtomNames.Nname = 'N';
    case 'TOAC'
      logmsg(1,'Using default atom names for label TOAC.');
      Info.AtomNames.ONname = 'OE';
      Info.AtomNames.NNname = 'ND';
      Info.AtomNames.CGSname = 'CG2';
      Info.AtomNames.CGRname = 'CG1';
      Info.AtomNames.CBSname = 'CB2';
      Info.AtomNames.CBRname = 'CB1';
      Info.AtomNames.CAname = 'CA';
      Info.AtomNames.Nname = 'N';
    otherwise
      error('Info.AtomNames is missing.')
  end
end
AtomNames = Info.AtomNames;

if ~isfield(Info,'SegName')
  Info.SegName = '';
end
SegName = Info.SegName;

if ~ischar(TopFile)||regexp(TopFile,'\w+\.\w+','once')<1
  error('TopFile must be given as a character array, including the filename extension.')
end

if exist(TopFile,'file')
  [TopFilePath, TopFileName, TopFileExt] = fileparts(TopFile);
  TopFile = fullfile(TopFilePath, [TopFileName, TopFileExt]);
else
  error('TopFile "%s" could not be found.', TopFile)
end

if ischar(TrajFile)
  % single trajectory file
  TrajFile = {TrajFile};
end
  
if ~iscell(TrajFile)
  error(['Please provide ''TrajFile'' as a single character array ',...
         '(single trajectory file) or a cell array whose elements are ',...
         'character arrays (multiple trajectory files).'])
end
if ~all(cellfun(@ischar, TrajFile))
  error('TrajFile must be a cell array of character arrays.')
end

% Process trajectory file names
nTrajFiles = numel(TrajFile);
TrajFilePath = cell(nTrajFiles,1);
TrajFileName = cell(nTrajFiles,1);
TrajFileExt = cell(nTrajFiles,1);
for k = 1:nTrajFiles
  if ~exist(TrajFile{k},'File')
    error('TrajFile "%s" could not be found.', TrajFile{k})
  end
  [TrajFilePath{k}, TrajFileName{k}, TrajFileExt{k}] = fileparts(TrajFile{k});
  TrajFile{k} = fullfile(TrajFilePath{k}, [TrajFileName{k}, TrajFileExt{k}]);
end

% make sure that all file extensions are identical
if ~all(strcmp(TrajFileExt,TrajFileExt{1}))
  error('At least two of the TrajFile file extensions are not identical.')
end
if ~all(strcmp(TrajFilePath,TrajFilePath{1}))
  error('At least two of the TrajFilePath locations are not identical.')
end

TrajFileExt = upper(TrajFileExt{1});
TopFileExt = upper(TopFileExt);

% check if file extensions are supported
supportedTrajFileExts = {'.DCD','.TRR'};
supportedTopFileExts = {'.PSF','.GRO'};
if ~any(strcmp(TrajFileExt,supportedTrajFileExts))
  error('The trajectory file extension "%s" is not supported.', TrajFileExt);
end
if ~any(strcmp(TopFileExt,supportedTopFileExts))
  error('The topology file extension "%s" is not supported.', TopFileExt);
end


% Importing data from MD trajectory files
%-------------------------------------------------------------------------------
logmsg(1,'-- extracting data from MD trajectory files -----------------------------------------');

if Opt.Verbosity==1, tic; end

MD.nSteps = 0;
MD.ProtCAxyz = [];
MD.Labelxyz = [];
MD.dt = [];

% parse through list of trajectory output files
ExtCombo = [TrajFileExt, ',', TopFileExt];
updateuser(0);
for iTrajFile = 1:nTrajFiles
  logmsg(1,'trajectory %d',iTrajFile);
  
  [Traj_,psf] = processMDfiles(TrajFile{iTrajFile}, TopFile, SegName, ResName, ...
    LabelName, AtomNames, ExtCombo);
  
  if ~isempty(MD.dt)
    if MD.dt~=Traj_.dt
      error('Time steps of trajectory files %s and %s are not equal.',TrajFile{iTrajFile},TrajFile{iTrajFile-1})
    end
  end
  MD.dt = Traj_.dt;
  
  % combine trajectories through array concatenation
  MD.ProtCAxyz = cat(1,MD.ProtCAxyz,Traj_.ProtCAxyz);
  MD.Labelxyz = cat(1,MD.Labelxyz,Traj_.Labelxyz);
  MD.nSteps = MD.nSteps + Traj_.nSteps;
  
  % this could take a long time, so notify the user of progress
  if Opt.Verbosity
    updateuser(iTrajFile,nTrajFiles)
  end
end

clear temp

% Extract spin label atomic coordinates
%-------------------------------------------------------------------------------
switch LabelName
  case 'R1'
    v.ON = MD.Labelxyz(:,:,psf.idx_ON);
    v.NN = MD.Labelxyz(:,:,psf.idx_NN);
    v.C1 = MD.Labelxyz(:,:,psf.idx_C1);
    v.C2 = MD.Labelxyz(:,:,psf.idx_C2);
    v.C1R = MD.Labelxyz(:,:,psf.idx_C1R);
    v.C2R = MD.Labelxyz(:,:,psf.idx_C2R);
    v.C1L = MD.Labelxyz(:,:,psf.idx_C1L);
    v.S1L = MD.Labelxyz(:,:,psf.idx_S1L);
    v.SG = MD.Labelxyz(:,:,psf.idx_SG);
    v.CB = MD.Labelxyz(:,:,psf.idx_CB);
    v.CA = MD.Labelxyz(:,:,psf.idx_CA);
    v.N = MD.Labelxyz(:,:,psf.idx_N);
  case 'TOAC'
    v.ON = MD.Labelxyz(:,:,psf.idx_ON);
    v.NN = MD.Labelxyz(:,:,psf.idx_NN);
    v.CGS = MD.Labelxyz(:,:,psf.idx_CGS);
    v.CGR = MD.Labelxyz(:,:,psf.idx_CGR);
    v.CBS = MD.Labelxyz(:,:,psf.idx_CBS);
    v.CBR = MD.Labelxyz(:,:,psf.idx_CBR);
    v.CA = MD.Labelxyz(:,:,psf.idx_CA);
    v.N = MD.Labelxyz(:,:,psf.idx_N);
end

MD = rmfield(MD,'Labelxyz');

% Calculate label frame vectors
%-------------------------------------------------------------------------------
logmsg(1,'Calculating label frames...');
% Initialize big arrays here for efficient memory usage
MD.FrameTraj = zeros(MD.nSteps,3,3,1);

normalize = @(v)bsxfun(@rdivide,v,sqrt(sum(v.*v,2)));

switch LabelName
  case 'R1'
    
    v.NNNO = normalize(v.ON - v.NN);  % N-O bond vector
    v.NNC1 = normalize(v.C1 - v.NN); % N-C1 bond vector
    v.NNC2 = normalize(v.C2 - v.NN); % N-C2 bond vector
    
    % z-axis
    MD.FrameTraj(:,:,3) = normalize(cross(v.NNC1,v.NNNO,2) + cross(v.NNNO,v.NNC2,2));
    
    % x-axis
    MD.FrameTraj(:,:,1) = v.NNNO;
    
    % y-axis
    MD.FrameTraj(:,:,2) = cross(MD.FrameTraj(:,:,3), MD.FrameTraj(:,:,1), 2);
    
  case 'TOAC'
    
    v.NNNO = normalize(v.ON - v.NN);    % N-O bond vector
    v.NNCGR = normalize(v.CGR - v.NN); % N-CGR bond vector
    v.NNCGS = normalize(v.CGS - v.NN); % N-CGS bond vector
    
    % z-axis
    MD.FrameTraj(:,:,3) = normalize(cross(v.NNCGR,v.NNNO,2) + cross(v.NNNO,v.NNCGS,2));
    
    % x-axis
    MD.FrameTraj(:,:,1) = v.NNNO;
    
    % y-axis
    MD.FrameTraj(:,:,2) = cross(MD.FrameTraj(:,:,3), MD.FrameTraj(:,:,1), 2);
end

% Calculate side chain dihedral angles
%-------------------------------------------------------------------------------
logmsg(1,'Calculating side chain dihedral angles...');
switch LabelName
  case 'R1'
    MD.dihedrals = zeros(MD.nSteps,5);
    MD.dihedrals(:,1) = dihedral(v.N,v.CA,v.CB,v.SG);
    MD.dihedrals(:,2) = dihedral(v.CA,v.CB,v.SG,v.S1L);
    MD.dihedrals(:,3) = dihedral(v.CB,v.SG,v.S1L,v.C1L);
    MD.dihedrals(:,4) = dihedral(v.SG,v.S1L,v.C1L,v.C1R);
    MD.dihedrals(:,5) = dihedral(v.S1L,v.C1L,v.C1R,v.C2R);
  case 'TOAC'
    MD.dihedrals = zeros(MD.nSteps,2);
    MD.dihedrals(:,1) = dihedral(v.CA,v.CBS,v.CGS,v.NN);
    MD.dihedrals(:,2) = dihedral(v.CA,v.CBR,v.CGR,v.NN);
end

% Reorder dimensions
MD.FrameTraj = permute(MD.FrameTraj, [2,3,4,1]);
MD.dihedrals = permute(MD.dihedrals, [2,3,1]); % (iStep,ichi,iTraj) -> (ichi,iTraj,iStep)

% Clear large arrays
clear v

% Remove global diffusion of protein
%-------------------------------------------------------------------------------
logmsg(1,'-- removing protein global diffusion -----------------------------------------');

% Align protein alpha carbons with inertia tensor frame in first snapshot
MD.ProtCAxyz = orientproteintraj(MD.ProtCAxyz);
MD.ProtCAxyz = permute(MD.ProtCAxyz,[2,3,1]); % reorder (step,iAtom,iTraj) to (iAtom,iTraj,step)

% Initializations
%RRot = zeros(3,3,MD.nSteps-1);
%qRot = zeros(4,MD.nSteps-1);
MD.RProtDiff = zeros(3,3,MD.nSteps);
MD.RProtDiff(:,:,1) = eye(3);
qTraj = zeros(4,MD.nSteps);
qTraj(:,1) = [1;0;0;0];
nAtoms = size(MD.ProtCAxyz,2);
mass = ones(1,nAtoms);
ProtCAxyzInt = zeros(3, nAtoms, MD.nSteps);
ProtCAxyzInt(:,:,1) = MD.ProtCAxyz(:,:,1);
MD.FrameTrajwrtProt = zeros(3,3,1,MD.nSteps);
MD.FrameTrajwrtProt(:,:,:,1) = MD.FrameTraj(:,:,:,1);

% LabelFrameInt = zeros(3, nAtoms, MD.nSteps);
% LabelFrameInt(:,:,:,1) = MD.FrameTraj(:,:,:,1);


% Find optimal rotation matrices and quaternions
tic % toc is used in updateuser()
firstFrameReference = true;
if firstFrameReference
  refFrame = MD.ProtCAxyz(:,:,1);
  updateuser(0);
  for iStep = 2:MD.nSteps
    
    thisFrame = MD.ProtCAxyz(:,:,iStep);
    
    q = calcbestq(refFrame, thisFrame, mass);
    R = quat2rotmat(q);
    
    MD.ProtCAxyz(:,:,iStep) = R.'*thisFrame;
    MD.FrameTrajwrtProt(:,:,:,iStep) = R.'*MD.FrameTraj(:,:,:,iStep);
    
    MD.RProtDiff(:,:,iStep) = R*MD.RProtDiff(:,:,iStep-1);
    qTraj(:,iStep) = quatmult(q, qTraj(:,iStep-1));
    
    if Opt.Verbosity
      updateuser(iStep, MD.nSteps);
    end
  end
else
% % Determine frame-to-frame rotations
% for iStep = 2:MD.nSteps
%   LastProtFrameInt = squeeze(ProtCAxyzInt(:,:,iStep-1));
%   ThisProtFrame = MD.ProtCAxyz(:,:,iStep);
% 
%   q = calcbestq(LastProtFrameInt, ThisProtFrame, mass.');
%   R = quat2rotmat(q);
% 
%   ProtCAxyzInt(:,:,iStep) = R.'*ThisProtFrame;  % "internal" Eckart frame
%   MD.FrameTrajwrtProt(:,:,:,iStep) = R.'*MD.FrameTraj(:,:,:,iStep);
% 
%   qRot(:,iStep-1) = q;
%   RRot(:,:,iStep-1) = R;
% 
%   MD.RProtDiff(:,:,iStep) = R*MD.RProtDiff(:,:,iStep-1);
%   qTraj(:,iStep) = quatmult(q, qTraj(:,iStep-1));
% 
%   updateuser(iStep, MD.nSteps)
% end
end

if ~Opt.keepProtCA
  % Remove field if not needed anymore, since it could be huge
  MD = rmfield(MD,'ProtCAxyz');
end


% Estimate global diffusion tensor of protein
%-------------------------------------------------------------------------------
calcProtDiffTensor = false;
if calcProtDiffTensor
% logmsg(1,'-- estimating protein global diffusion tensor -----------------------------------------');
% 
% dt = 2.5*MD.dt;  % NOTE: this assumes a solvent-exposed labeling site with 
%                  % a TIP3P water model
% 
% % calculate Cartesian angular velocity components in molecular frame
% wp = q2wp(qRot, dt);
% 
% % cumulative angular displacement
% Deltawp = integral(wp, dt);
% 
% % mean square angular displacement
% msadp = msd_fft(Deltawp);
% msadp = msadp(:, 1:round(end/2));
% 
% tLag = linspace(0, length(msadp)*dt, length(msadp))/1e-12;
% 
% endFit = min(ceil(100e-9/dt), length(msadp));
% 
% pxp = polyfit(tLag(1:endFit), msadp(1,1:endFit), 1);
% pyp = polyfit(tLag(1:endFit), msadp(2,1:endFit), 1);
% pzp = polyfit(tLag(1:endFit), msadp(3,1:endFit), 1);
% 
% MD.DiffGlobal = [pxp(1), pyp(1), pzp(1)]*1e12;

% % find frame trajectory without protein's rotational diffusion
% for iStep = 2:MD.nSteps
%   R = RRot(:,:,iStep);
%   thisStep = MD.FrameTraj(:,:,1,iStep);
%   MD.FrameTrajwrtProt(:,1,1,iStep) = thisStep(:,1).'*R;
%   MD.FrameTrajwrtProt(:,2,1,iStep) = thisStep(:,2).'*R;
%   MD.FrameTrajwrtProt(:,3,1,iStep) = thisStep(:,3).'*R;
% end
end

if Opt.Verbosity
  logmsg(1,'Summary:');
  logmsg(1,'  Label: %s',LabelName);
  logmsg(1,'  Number of trajectories: %d',nTrajFiles);
  logmsg(1,'  Number of time steps: %d',MD.nSteps);
  logmsg(1,'  Size of time step: %g fs',MD.dt/1e-12);
end

end
%===============================================================================


function [Traj,structure] = processMDfiles(TrajFile, TopFile, SegName, ResName, LabelName, AtomNames, ExtCombo)

switch ExtCombo
  case '.DCD,.PSF'
    % obtain atom indices of nitroxide coordinate atoms
    structure = md_readpsf(TopFile,SegName,ResName,LabelName,AtomNames); 
    Traj = md_readdcd(TrajFile,structure.idx_ProteinLabel);
    % TODO perform consistency checks between topology and trajectory files
    
    Traj.ProtCAxyz = Traj.xyz(:,:,structure.idx_ProteinCA);  % protein alpha carbon atoms
    Traj.Labelxyz = Traj.xyz(:,:,structure.idx_SpinLabel);   % spin label atoms
    Traj = rmfield(Traj,'xyz');     % remove the rest

  case '.TRR,.GRO'
    structure = md_readgro(TopFile,ResName,LabelName,AtomNames); 
    Traj = md_readtrr(TrajFile);
    
    Traj.ProtCAxyz = Traj.xyz(:,:,structure.idx_ProteinCA);  % protein alpha carbon atoms
    Traj.Labelxyz = Traj.xyz(:,:,structure.idx_SpinLabel);   % spin label atoms
    Traj = rmfield(Traj,'xyz');     % remove the rest
    
  otherwise
    error(['Trajectory and structure file type combination %s is either ',...
          'not supported or not properly entered.'], ...
          ExtCombo)
end

end

%-------------------------------------------------------------------------------
function updateuser(iter,totN)
% Update user on progress

persistent reverseStr

if iter==0, reverseStr = ''; return; end

avg_time = toc/iter;
secs_left = (totN - iter)*avg_time;
mins_left = floor(secs_left/60);

msg1 = sprintf('Iteration %d/%d  ', iter, totN);
if avg_time<1.0
  msg2 = sprintf('%2.1f it/s  ', 1/avg_time);
else
  msg2 = sprintf('%2.1f s/it   ', avg_time);
end
msg3 = sprintf('estimated time left: %02d:%02d\n', mins_left, round(mod(secs_left,60)));
msg = [msg1, msg2, msg3];

fprintf([reverseStr, msg]);
reverseStr = repmat(sprintf('\b'), 1, length(msg));

end

%-------------------------------------------------------------------------------
function chi = dihedral(a1Traj,a2Traj,a3Traj,a4Traj)
% calculate dihedral angle given 4 different atom indices and a trajectory

normalize = @(v) bsxfun(@rdivide,v,sqrt(sum(v.*v, 2)));
a1 = normalize(a1Traj - a2Traj);
a2 = normalize(a3Traj - a2Traj);
a3 = normalize(a3Traj - a4Traj);

b1 = cross(a2, a3, 2);
b2 = cross(a1, a2, 2);

vec1 = dot(a1, b1, 2).*sqrt(sum(a2.*a2, 2));
vec2 = dot(b1, b2, 2);

chi = atan2(vec1, vec2);

end

%-------------------------------------------------------------------------------
function traj = orientproteintraj(traj)
% Orient protein along the principal axes of inertia from the first snapshot

nAtoms = size(traj, 3);
mass = 1;

% recenter - subtract by the geometric center
traj = bsxfun(@minus,traj,mean(traj,3));

% calculate the principal axes of inertia for first snapshot
firstStep = squeeze(traj(1,:,:));
x = firstStep(1,:);
y = firstStep(2,:);
z = firstStep(3,:);

I = zeros(3,3);

I(1,1) = sum(mass.*(y.^2 + z.^2));
I(2,2) = sum(mass.*(x.^2 + z.^2));
I(3,3) = sum(mass.*(x.^2 + y.^2));

I(1,2) = -sum(mass.*(x.*y));
I(2,1) = I(1,2);

I(1,3) = -sum(mass.*(x.*z));
I(3,1) = I(1,3);

I(2,3) = -sum(mass.*(y.*z));
I(3,2) = I(2,3);

% scale I for better performance
I = I./norm(I);

[~, ~, a] = svd(I); % a is sorted by descending order of singular value
principal_axes = a(:, end:-1:1); % reorder such that 3rd axis has the largest moment

% Make sure axis system is right-handed
if det(principal_axes) < 0
  principal_axes(:,1) = -principal_axes(:,1);
end

RAlign = principal_axes;

% Rotate into principal axis frame of inertia tensor
for k = 1:nAtoms
  traj(:,:,k) = traj(:,:,k)*RAlign;
end

end

%-------------------------------------------------------------------------------
function q = calcbestq(rOld, rNew, mass)
% find the quaternion that best approximates the rotation of the Eckart 
% coordinate frame for a molecule between configurations
%
% Minimizes the following quantity:
%  1/M \sum_\alpha m_\alpha || R(q(n+1))*r_\alpha^int (n) - r_\alpha (n+1) ||^2
%

nAtoms = size(rOld, 2);

if size(rOld,1)~=3 || size(rNew,1)~=3 || nAtoms~=size(rNew,2)
  error('rOld and rNew both must have size (3,nAtoms).')
end

if ~isrow(mass) || size(mass,2)~=nAtoms
  error('mass must be a row vector with length equal to nAtoms.')
end

% Weighting of coordinates

massTot = sum(mass);

weights = mass/massTot;

left  = rOld.*sqrt(weights);
right = rNew.*sqrt(weights);

M = left*right.';

% Compute optimal quaternion
M = num2cell(M(:));

[Sxx,Syx,Szx,  Sxy,Syy,Szy,   Sxz,Syz,Szz] = M{:};

N=[(Sxx+Syy+Szz), (Syz-Szy),     (Szx-Sxz),      (Sxy-Syx);...
   (Syz-Szy),     (Sxx-Syy-Szz), (Sxy+Syx),      (Szx+Sxz);...
   (Szx-Sxz),     (Sxy+Syx),     (-Sxx+Syy-Szz), (Syz+Szy);...
   (Sxy-Syx),     (Szx+Sxz),     (Syz+Szy),      (-Sxx-Syy+Szz)];

[V,D] = eig(N);

[~, emax] = max(real(diag(D)));
emax = emax(1);

q = real(V(:, emax));  % eigenvector corresponding to maximum eigenvalue

[~,ii] = max(abs(q));
sgn = sign(q(ii(1)));
q = q*sgn;  %Sign ambiguity

% quat = q(:);
% nrm = norm(quat);
% if ~nrm
%  disp 'Quaternion distribution is 0'    
% end
% 
% quat = quat./norm(quat);
% 
% R = quat2rotmat(q);

end

%-------------------------------------------------------------------------------
function dy = derivative(y, dt)
  dy = zeros(size(y));
  dy(:,2:end-1) = (y(:,3:end) - y(:,1:end-2));
  dy(:,1) = 4*y(:,2) - 3*y(:,1) - y(:,3);
  dy(:,end) = 3*y(:,end) + y(:,end-2) - 4*y(:,end-1);
  dy = dy./(2*dt);
end

%-------------------------------------------------------------------------------
function iy = integral(y, dt)
  iy = zeros(size(y));
  iy(:,1) = 0;
  iy(:,2:end-1) = 5*y(:,1:end-2) + 8*y(:,2:end-1) - y(:,3:end);
  iy(:,end) = -y(:,end-2) + 8*y(:,end-1) + 5*y(:,end);
  iy = cumsum(iy, 2)*dt/12;
end

%-------------------------------------------------------------------------------
function w = q2w(qTraj, dt)

dq = derivative(qTraj, dt);

q0 = qTraj(1,:,:);
q1 = qTraj(2,:,:);
q2 = qTraj(3,:,:);
q3 = qTraj(4,:,:);

dq0 = dq(1,:,:);
dq1 = dq(2,:,:);
dq2 = dq(3,:,:);
dq3 = dq(4,:,:);

wx = 2*(-q1.*dq0 + q0.*dq1 - q3.*dq2 + q2.*dq3);
wy = 2*(-q2.*dq0 + q3.*dq1 + q0.*dq2 - q1.*dq3);
wz = 2*(-q3.*dq0 - q2.*dq1 + q1.*dq2 + q0.*dq3);

w = [wx; wy; wz];

end

%-------------------------------------------------------------------------------
function wp = q2wp(qTraj, dt)

dq = derivative(qTraj, dt);

q0 = qTraj(1,:,:);
q1 = qTraj(2,:,:);
q2 = qTraj(3,:,:);
q3 = qTraj(4,:,:);

dq0 = dq(1,:,:);
dq1 = dq(2,:,:);
dq2 = dq(3,:,:);
dq3 = dq(4,:,:);

wxp = 2*(-q1.*dq0 + q0.*dq1 + q3.*dq2 - q2.*dq3);
wyp = 2*(-q2.*dq0 - q3.*dq1 + q0.*dq2 + q1.*dq3);
wzp = 2*(-q3.*dq0 + q2.*dq1 - q1.*dq2 + q0.*dq3);

wp = [wxp; wyp; wzp];

end

%-------------------------------------------------------------------------------
function msd = msd_fft(x)

if iscolumn(x)
  x = x.';
end

nComps = size(x, 1);
N = length(x);

D = zeros(nComps, N+1);
D(:,2:end) = x.^2;


% D = D.sum(axis=1)
% D = np.append(D,0)
S2 = runprivate('autocorrfft',x, 2, 0, 0, 0);

Q = 2*sum(D, 2);
S1 = zeros(nComps, N);

for m = 1:N
    Q = Q - D(:, m) - D(:, end-m);
    S1(:, m) = Q/((N+1)-m);
end

msd = S1 - 2*S2;

end
