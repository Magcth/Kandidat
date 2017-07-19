function [X,E_opt] = OptimizeM1(Efield_objects,weight_denom,weight_nom, nbrEfields, particle_settings)
% Function that optimizes over function M1.
% Optimization is done by expressing M1 as a polynomial and finding
% complex amplitudes that gives the minimum value using particle swarm.
%
% ------INPUTS--------------------------------------------------------------
% Efield_objects:    Cell vector with efields of one frequency in SF-Efield format 
%                    (length=number of antennas).
% weight_denom:      weight in denomenator of M1. Default: matrix with 
%                    true/false for the position of the tumor, in octree format.
% weight_nom:        weight in the nomenator of M1. Default: matrix with true/false 
%                    for the position of healthy tissue, in octree format.
% nbrEfields:        the number of Efields that are put in to the optimization.
% particle_settings: vector with [swarmsize, max_iterations, stall_iterations] 
%                    for particleswarm.
% ------OUTPUTS--------------------------------------------------------------
% X:                 solver argument for polynomial M1
% E_opt:             optimized Efield.
% --------------------------------------------------------------------------
    
    % Cut off antennas with low power contribution in select_best
    Efield_objects = select_best(Efield_objects, nbrEfields, weight_denom);
    
    % Create the two square matrices for the gen. eigenvalue representation
    % of M1
    A = zeros(length(Efield_objects));
    B = A;

    % Calculate all integral values
    for i = 1:length(Efield_objects) % pick first Efield
        for j = 1:length(Efield_objects) % pick second Efield
            if i > j % Symmetry case
                A(i,j) = conj(A(j,i));
                B(i,j) = conj(B(j,i));
                continue
            end
            e_i = Efield_objects{i};
            e_j = Efield_objects{j};
            P = scalar_prod(e_i,e_j);

            A(i,j) = scalar_prod_integral(P,weight_denom)/1e9;
            B(i,j) = scalar_prod_integral(P,weight_nom)/1e9;
        end
    end
    
    P_nom = CPoly(0);
    P_den = CPoly(0);
    n = length(Efield_objects);
    % Create the polynomials
    for i = 1:n % pick first Efield
        for j = 1:n % pick second Efield
            P_nom = P_nom + CPoly(B(i,j),[-i;j]);
            P_den = P_den + CPoly(A(i,j),[-i;j]);
        end
    end
    
    [numer_realP, mapp1_real_to_Cpoly, mapp1_imag_to_Cpoly] = to_real(P_nom );
[denom_realP, mapp2_real_to_Cpoly, mapp2_imag_to_Cpoly] = to_real(P_den);

mapp_real_to_Cpoly = containers.Map('KeyType','int64','ValueType','int64');
mapp_imag_to_Cpoly = containers.Map('KeyType','int64','ValueType','int64');
mapp_CPoly_to_real = containers.Map('KeyType','int64','ValueType','int64');
mapp_CPoly_to_imag = containers.Map('KeyType','int64','ValueType','int64');

KEYS = keys(mapp1_real_to_Cpoly);
for i = 1:length(KEYS)
    k = KEYS{i};
    mapp_real_to_Cpoly(k) = mapp1_real_to_Cpoly(k);
end
KEYS = keys(mapp2_real_to_Cpoly);
for i = 1:length(KEYS)
    k = KEYS{i};
    mapp_real_to_Cpoly(k) = mapp2_real_to_Cpoly(k);
end

KEYS = keys(mapp1_imag_to_Cpoly);
for i = 1:length(KEYS)
    k = KEYS{i};
    mapp_imag_to_Cpoly(k) = mapp1_imag_to_Cpoly(k);
end
KEYS = keys(mapp2_imag_to_Cpoly);
for i = 1:length(KEYS)
    k = KEYS{i};
    mapp_imag_to_Cpoly(k) = mapp2_imag_to_Cpoly(k);
end

KEYS = keys(mapp_real_to_Cpoly);
for i = 1:length(KEYS)
    key = KEYS{i};
    mapp_CPoly_to_real(mapp_real_to_Cpoly(key)) = key;
end
KEYS = keys(mapp_imag_to_Cpoly);
for i = 1:length(KEYS)
    key = KEYS{i};
    mapp_CPoly_to_imag(mapp_imag_to_Cpoly(key)) = key;
end

[mapp_realvar_to_fvar, mapp_fvar_to_realvar, n] ...
    = CPoly.real_to_fmap({numer_realP, denom_realP});

% Express M1 as a function of X
f = @(X)M_1(X,weight_denom,weight_nom,Efield_objects,mapp_real_to_Cpoly,mapp_imag_to_Cpoly,mapp_fvar_to_realvar,n);

%  options = optimset('Plotfcn',@gaplotbestf,'MaxTime',60);
% X = fminsearch(f,ones(n,1),options);
% X = ga(f,n,options)

% Find minimum value to M1(X) with particleswarm
lb = -ones(n,1);
ub = ones(n,1);
initialSwarmMat=[ones(1,n);rand(particle_settings(1)-1,n)];
options = optimoptions('particleswarm','SwarmSize',particle_settings(1),...
    'PlotFcn',@pswplotbestf, 'MaxIterations', particle_settings(2), ...
    'MaxStallIterations', particle_settings(3), ...
    'InitialSwarmMatrix', initialSwarmMat); 
[X,~,~,~] = particleswarm(f,n,lb,ub,options);

% Compute M1 value and Efield with the optimal complex amplitudes
% corresponding to solver argument X
[M1_val,E_opt] = M_1(X,weight_denom,weight_nom, Efield_objects,mapp_real_to_Cpoly,mapp_imag_to_Cpoly,mapp_fvar_to_realvar,n);

disp(strcat('M1-value post-optimization: ', num2str(M1_val)))

end

