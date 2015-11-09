function v = chili_startingvector(Basis,Potential,I)

Options.Tolerance = 1e-10; % for numerical integration

lambdaLK = Potential.lambda;
XLK = Potential.xlk;

switch numel(I)
  case 0, v = chili_sv0(Basis,lambdaLK,XLK,Options);
  case 1, v = chili_sv1(Basis,lambdaLK,XLK,I,Options);
  case 2, v = chili_sv2(Basis,lambdaLK,XLK,I,Options);
end

%=====================================================================
% Calculates starting vector for a system with S=1/2 without nuclei
function v = chili_sv0(Basis,lambdaLK,XLK,Options)

evenLmax = Basis.evenLmax;
oddLmax = Basis.oddLmax;
Kmax = Basis.Kmax;
Mmax = Basis.Mmax;
deltaK = Basis.deltaK;
jKmin = Basis.jKmin;
pSmin = Basis.pSmin;

MpSymm = Basis.MpSymm;
DirTilt = Basis.DirTilt;

Potential = any(lambdaLK);
if (Potential)
  %AxialPotential = all(lambda([2 4])==0);
  PotLmax = size(XLK,1)-1;
  PotKmax = PotLmax;
end

if isfield(Basis,'Size')
  maxVals = Basis.Size;
else
  maxVals = 10000;
end

Value = zeros(maxVals,1);
Col   = zeros(maxVals,1);
Row   = zeros(maxVals,1);

nRows = 0; % number of rows of the column vector v
nCols = 1;
idx = 0;

iseven = @(x)mod(x,2)==0;
isodd = @(x)mod(x,2)~=0;
for L = 0:evenLmax
  if isodd(L) && (L>oddLmax), continue; end
  for jK = jKmin:2:1
    Kmx = min(L,Kmax);
    for K = 0:deltaK:Kmx
      if (K==0) && (parity(L)~=jK), continue; end
      
      %==============================================
      thisValue = 0;
      if iseven(L) && iseven(K)
        if (~Potential)
          % Zero potential: non-zero values for L==K==0
          if (L==0) && (K==0), thisValue = 1; end
        elseif ((PotKmax==0) && (K~=0))
          % Axial potential (max K == 0): zero for K>0
          %thisValue = 0;
        else
          %
          % Axial potential K==0, nonaxial potential: numerical integration
          thisValue = quadl(@orifun,0,1,Options.Tolerance,0,L,K,lambdaLK);
          if (K~=0)
            thisValue = thisValue * sqrt((2*L+1)/prod(L-K+1:L+K));
          else
            thisValue = thisValue * sqrt((2*L+1)/2);
          end
        end
      end
      %==============================================
      
      Mmx = min(L,Mmax);
      for M = -Mmx:Mmx
        for pS = pSmin:1
          qSmx = 1 - abs(pS);
          for qS = -qSmx:2:qSmx
            if ((MpSymm)&&(~DirTilt)&&((0+pS-1)~=M)), continue; end % Meirovich Eq.(A47)
            
            nRows = nRows + 1;
            
            %==============================================
            NonZeroElement = (jK==1) && (M==0) && (pS~=0);
            if NonZeroElement && ...
                (((~DirTilt) && (pS==1)) || ...
                (( DirTilt) && (abs(pS)==1)))
              if (thisValue~=0)
                idx = idx + 1;
                Value(idx) = thisValue;
                Col(idx) = 1;
                Row(idx) = nRows;
              end
            end
            %==============================================
            
          end
        end
      end
    end
  end
end

Value = Value(1:idx);
Col = Col(1:idx);
Row = Row(1:idx);

v = full(sparse(Row,Col,Value,nRows,nCols));
v = sum(v,2);
v = v/norm(v);

return


%=====================================================================
% Calculates starting vector for a system with S=1/2 and 1 nucleus
function v = chili_sv1(Basis,lambdaLK,XLK,I,Options)

evenLmax = Basis.evenLmax;
oddLmax = Basis.oddLmax;
Kmax = Basis.Kmax;
Mmax = Basis.Mmax;
deltaK = Basis.deltaK;
jkmn = Basis.jKmin;
pSmin = Basis.pSmin;
pImax = Basis.pImax;

MpSymm = Basis.MpSymm;
DirTilt = Basis.DirTilt;

Potential = any(lambdaLK);
if (Potential)
  %AxialPotential = all(lambdaLK([2 4])==0);
  PotLmax = size(XLK,1)-1;
  PotKmax = PotLmax;
end

if isfield(Basis,'Size')
  maxVals = Basis.Size;
else
  maxVals = 10000;
end

Value = zeros(maxVals,1);
Row   = zeros(maxVals,1);
Col   = zeros(maxVals,1);

nRows = 0; % number of rows of the column vector v
nCols = 2*I+1;
idx = 0;

iseven = @(x)mod(x,2)==0;
isodd = @(x)mod(x,2)~=0;
for L = 0:evenLmax
  if isodd(L) && (L>oddLmax), continue; end    
  for jK = jkmn:2:1
    Kmx = min(L,Kmax);
    for K = 0:deltaK:Kmx
      if (K==0) && (parity(L)~=jK), continue; end
      
      %==============================================
      thisValue = 0;
      if iseven(L) && iseven(K)
        if (~Potential)
          % Zero potential: non-zero values for L==K==0
          if (L==0) && (K==0), thisValue = 1; end
        elseif ((PotKmax==0) && (K~=0))
          % Axial potential (max K == 0): zero for K>0
          %thisValue = 0;
        else
          %
          % Axial potential K==0, nonaxial potential: numerical integration
          thisValue = quadl(@orifun,0,1,Options.Tolerance,0,L,K,lambdaLK);
          if (K~=0)
            thisValue = thisValue * sqrt((2*L+1)/prod(L-K+1:L+K));
          else
            thisValue = thisValue * sqrt((2*L+1)/2);
          end
        end
      end
      %==============================================
      
      Mmx = min(L,Mmax);
      for M = -Mmx:Mmx
        
        
        for pS = pSmin:1
          qSmx = 1 - abs(pS);
          for qS = -qSmx:2:qSmx
            
            for pI = -pImax:pImax
              if (MpSymm && (~DirTilt)&&((pI+pS-1)~=M)), continue; end % Meirovich Eq.(A47)
              
              %==============================================
              NonZeroElement = (jK==1) & (M==0) & (pS~=0) & (pI==0);
              %==============================================
              
              qImax = 2*I - abs(pI);
              for qI = -qImax:2:qImax
                
                nRows = nRows + 1;
                
                %==============================================
                if NonZeroElement && ...
                    (((~DirTilt) && (pS==1)) || ...
                    (( DirTilt) && (abs(pS)==1)))
                  if (thisValue~=0)
                    mI = qI/2; % qI/2 gives mI of transition, since pI==0
                    idx = idx + 1;
                    Value(idx) = thisValue;
                    Row(idx) = nRows;
                    Col(idx) = mI + I + 1;
                  end
                end
                %==============================================
                
              end
            end
            
          end
        end
        
        
      end
    end
  end
end

Value = Value(1:idx);
Row = Row(1:idx);
Col = Col(1:idx);

v = full(sparse(Row,Col,Value,nRows,nCols));
v = sum(v,2);
v = v/norm(v);

return


%=====================================================================
% Calculates starting vector for a system with S=1/2 and 2 nuclei
function v = chili_sv2(Basis,lambdaLK,XLK,I,Options)

evenLmax = Basis.evenLmax;
oddLmax = Basis.oddLmax;
Kmax = Basis.Kmax;
Mmax = Basis.Mmax;
deltaK = Basis.deltaK;
jkmn = Basis.jKmin;
pSmin = Basis.pSmin;
pI1max = Basis.pI1max;
pI2max = Basis.pI2max;

MpSymm = Basis.MpSymm;
DirTilt = Basis.DirTilt;

I1 = I(1);
I2 = I(2);

Potential = any(lambdaLK);
if (Potential)
  %AxialPotential = all(lambdaLK([2 4])==0);
  PotLmax = size(XLK,1)-1;
  PotKmax = PotLmax;
end

if isfield(Basis,'Size')
  maxVals = Basis.Size;
else
  maxVals = 10000;
end

Value = zeros(maxVals,1);
Row   = zeros(maxVals,1);
Col   = zeros(maxVals,1);

nRows = 0; % number of rows of the column vector v
nCols = prod(2*I+1);
idx = 0;

iseven = @(x)mod(x,2)==0;
isodd = @(x)mod(x,2)~=0;
for L = 0:evenLmax
  if isodd(L) && (L>oddLmax), continue; end    
  for jK = jkmn:2:1
    Kmx = min(L,Kmax);
    for K = 0:deltaK:Kmx
      if (K==0) && (parity(L)~=jK), continue; end
      
      %==============================================
      thisValue = 0;
      if iseven(L) && iseven(K)
        if (~Potential)
          % Zero potential: non-zero values for L==K==0
          if (L==0) && (K==0), thisValue = 1; end
        elseif ((PotKmax==0) && (K~=0))
          % Axial potential (max K == 0): zero for K>0
          %thisValue = 0;
        else
          %
          % Axial potential K==0, nonaxial potential: numerical integration
          thisValue = quadl(@orifun,0,1,Options.Tolerance,0,L,K,lambdaLK);
          if (K~=0)
            thisValue = thisValue * sqrt((2*L+1)/prod(L-K+1:L+K));
          else
            thisValue = thisValue * sqrt((2*L+1)/2);
          end
        end
      end
      %==============================================
      
      Mmx = min(L,Mmax);
      for M = -Mmx:Mmx
        
        for pS = pSmin:1
          qSmx = 1 - abs(pS);
          for qS = -qSmx:2:qSmx
            for pI1 = -pI1max:pI1max
              %if ((MpSymm) && (~DirTilt)&&((pI1+pS-1)~=M)), continue; end % Meirovich Eq.(A47)
              
              qI1max = 2*I1 - abs(pI1);
              for qI1 = -qI1max:2:qI1max
                
                for pI2 = -pI2max:pI2max
                  qI2max = 2*I2 - abs(pI2);
                  %==============================================
                  NonZeroElement = (jK==1) && (M==0) && ...
                    (pS~=0) && (pI1==0) && (pI2==0);
                  %==============================================
                  for qI2 = -qI2max:2:qI2max
                    if ((MpSymm) && (~DirTilt)&&((pI1+pI2+pS-1)~=M)), continue; end % Meirovich Eq.(A47)
                    
                    nRows = nRows + 1;
                    
                    %==============================================
                    if NonZeroElement && ...
                        (((~DirTilt) && (pS==1)) || ...
                        (( DirTilt) && (abs(pS)==1)))
                      if (thisValue~=0)
                        mI = [qI1 qI2]/2; % gives [mI1 mI2] of transition
                        idx = idx + 1;
                        Value(idx) = thisValue;
                        Col(idx) = sum(mI+I+1);
                        Row(idx) = nRows;
                      end
                    end
                    %==============================================
                    
                  end
                end
                
              end
            end
          end
        end
      end
    end
  end
end

Value = Value(1:idx);
Col = Col(1:idx);
Row = Row(1:idx);


v = full(sparse(Row,Col,Value,nRows,nCols));
v = sum(v,2);
v = v/norm(v);

return


%=====================================================================
function p = parity(a)
if mod(a,2), p = -1; else p = +1; end
return


%=====================================================================
% orifun  Integrand of the orientational integral in the starting vector.
% see Schneider 1989, p.19
function val = orifun(z,L,K,lambda)

% based on the integral (valid for even K)
% \int_0^{2\pi} cos(K g) exp(B cos(2 g)) d g =
% 2 \pi besseli(K/2,B)

% Potential terms with K == 0
A = 0;
if lambda(1), A = A + lambda(1)/2*plegendre(2,0,z); end
if lambda(3), A = A + lambda(3)/2*plegendre(4,0,z); end

% Potential terms with K == 2
B = 0;
if lambda(2), B = B + lambda(2)/(2*sqrt( 6))*plegendre(2,2,z); end
if lambda(4), B = B + lambda(4)/(6*sqrt(10))*plegendre(4,2,z); end

val = plegendre(L,K,z).*exp(A).*besseli(K/2,B)*(2*pi);

return