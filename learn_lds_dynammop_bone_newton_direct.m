function [model, Xhat, LL] = learn_lds_dynammop_bone_newton(X, varargin)
% learning model parameters for Linear Dynamical Systems (LDS), also known
% as Kalman Filters. 
% Recover missing values using DynaMMo+ algorithm. 
% an improved version of the algorithm in 
% Lei Li, Jim McCann, Nancy Pollard, Christos Faloutsos. DynaMMo: Mining 
% and Summarization of Coevolving Sequences with Missing Values. 
% KDD '09, Paris, France.function [model, Xhat, LL] = learn_lds_dynammop_bone_newton(X, varargin)
%
% Linear Dynamical Systems are described by the following equations:
% z_1 = mu0 + w_1function [model, Xhat, LL] = learn_lds_dynammop_bone_newton(X, varargin)
% z_n = A z_{n-1} + w_n
% x_n = C x_n + v_n
% w_1 ~ N(0, Q0)
% w_n ~ N(0, Q)
% v_n ~ N(0, R)
%
% Args:
%   X: M * N matrix, M is number of sequences, N is the time duration.
%
% Optional Args:
%   'Bone', followed by a matrix indicating the bone contraints
%      .. * 3 matrix: each row with 
%      <bone 1, bone 2, bone length>
%      assume bone is symmetric. i.e. <bone 2, bone 1, bone length> will
%      also be in bone matrix.
%   'Hidden', followed by an integer indicating the number of hidden
%   variables.
%   'MaxIter', followed by an integer indicating the number of max
%   iterations.
%   'Model', followed by a struct denoting a model to start with (see
%   below).
%   'Observed', followed by a matrix with the same size as X, with binary
%   values denoting whether X(i,j) is observed(1) or missing (0). If not
%   provided, will automatically treat 0's in X as missing values.
%  covariance options:
%   'DiagQ0', if presented, will learn a diagonal covariance Q0
%   'DiagQ', if presented, will learn a diagonal covariance Q
%   'DiagR', if presented, will learn a diagonal covariance R
%   'IsotropicQ0', if presented, will learn a diagonal and isotropic Q0
%   'IsotropicQ', if presented, will learn a diagonal and isotropic Q
%   'IsotropicR', if presented, will learn a diagonal and isotropic R
%   'FullQ0', if presented, will learn any possible Q0
%   'FullQ', if presented, will learn any possible Q
%   'FullR', if presented, will learn any possible R
%  Note these options could not coexist for the same covariance matrix.
%  Default (no args given) the algorithm will learn with H=M, MaxIter=10,
%  diagonal Q0, Q, R.
%   'Plotfun', followed by a function handle (should take in X), for plotting purpose.
%
% Returns:
%   model: a struct with the following attributes:
%     A: transition matrix (also named as F in papers), H * H
%     C: transmission  matrix(also called projection matrix, named as G
% in papers), M * H
%     Q: transition covariance, H * H 
%     R: transmission covariance, M * M
%     mu0: initial states (also named as z_0 sometimes), H * 1
%     Q0: initial covariance, H * H
%
% Example:
% t = 1:100;
% x1 = sin(2 * pi * t / 50);
% x2 = sin(2 * pi * t / 50 + pi / 4);
% X = [x1; x2];
% [model, Xhat, LL] = learn_lds_dynammop(X, 'Hidden', 2, 'MaxIter', 100, 'PlotFun', @(X)plot(X'));
%
% derived from old function 
% function [A, Gamma, C, Sigma, u0, V0, LL] = learn_kalman(x, H, maxIter)
%
% $Author: leili $@cs.cmu.edu
% $Date: 2010-01-21 17:42:41 -0500 (Thu, 21 Jan 2010) $
% $Rev: 219 $
%

X_original = X;
N = size(X, 2);
M = size(X, 1);

% get number of hidden variables
a = find(strcmp('MaxIter', varargin), 1);
if (isempty(a))
  maxIter = 10;
else
  maxIter = varargin{a+1};
end

% get number of hidden variables
a = find(strcmp('Hidden', varargin), 1);
if (isempty(a))
  H = M;
else
  H = varargin{a+1};
end

% get the bone
a = find(strcmp('Bone', varargin), 1);
if (isempty(a))
  % no bone contraints
  bone = [];
else
  bone = varargin{a+1};
end

% get the initial model
a = find(strcmp('Model', varargin), 1);
if (isempty(a))
  model.A = eye(H, H) + randn(H, H);
  model.C = eye(M, H) + randn(M, H);
  model.Q = eye(H, H);
  model.R = eye(M, M);
  model.mu0 = randn(H, 1);
  model.Q0 = model.Q;
else
  model = varargin{a+1};
end

% get the observed
a = find(strcmp('Observed', varargin), 1);
if (isempty(a))
  observed = ~isnan(X);
  if (~any(~observed))
    % if there is no NAN in the matrix,
    % try to regard the 0 as missing
    observed = (abs(X) > eps);
  end
else
  observed = varargin{a+1};
  %Dim = 3; % default
  % observed can be on bone joints or on marker coordinates
  
  Dim = int32(M / size(observed, 1));
  observed = (reshape(repmat(observed', Dim, 1), N, M))';
end

% get plot function 
a = find(strcmp('PlotFun', varargin), 1);
if (~isempty(a))
  plotFun = varargin{a+1};
end

% use linear interpolation as an initialization
Y = linear_interp(X, observed);
X(~observed) = Y(~observed);

CONV_BOUND = 1e-5;
ratio = 1;
diff = 1;
iter = 0;
oldLogli = -inf;

ET = cell(N, 5);
for t = 1:N
  k = 0; 
  ET{t, 2} = [];
  ET{t, 3} = [];  
  ET{t, 4} = find(~observed(:, t));
  ET{t, 5} = sum(~observed(:, t));
  ET{t, 6} = ceil(cumsum(~observed(:, t)) / Dim);
  for i = 1:size(bone, 1)
    u = bone(i, 1);
    v = bone(i, 2);
    if ((u < v) && (~observed(Dim * u, t) && ~observed(Dim * v, t)))      
      ET{t, 2} = [ET{t, 2} [ET{t, 6}(Dim * u); ET{t, 6}(Dim * v); bone(i, 3)]];
    end    
    if ((u < v) && (~observed(Dim * u, t) && observed(Dim * v, t)))
      ET{t, 3} = [ET{t, 3} [ET{t, 6}(Dim * u); v; bone(i, 3)]];
    end
  end
  ET{t, 1} = size(ET{t, 2}, 2) + size(ET{t, 2}, 3);  
end

ALPHA = 0.2;
while ((ratio > CONV_BOUND || diff > CONV_BOUND) && (iter < maxIter) && (~ (isTiny(model.Q0) || isTiny(model.Q) || isTiny(model.R))))
  oldmodel = model;
  iter = iter + 1;
  if (iter > 1)
    [mu, V, P, X, logli] = forward_fly(X, model, observed, varargin{:});
  else
    [mu, V, P, logli] = forward(X, model, varargin{:});
  end
  [Ez, Ezz, Ez1z] = backward(mu, V, P, model);  
  Y = estimate_missing(X, Ez, model, observed);
  X(~observed) = Y(~observed);
  
  % make the bone contraints
  %if (((iter > 20) && (rem(floor(iter / 4), 25) ~= 0)) || (iter > 500))
  if (iter > 0)
    % do bone length constraint
    %[u, V, P, logli] = forward(X, A, Gamma, C, Sigma, u0, V0);
    
    %ucap is the estimated E[z_n]
    %[ucap, Vcap, J] = backward(u, V, P, A);
    % sq = randperm(size(bone, 1));
    % estimate the missing values and lagrangian multiplier
    invSigma = inv(model.R);
    for t = 1 : N
      % for i = 1 : size(bone, 1)
      % use random optimization order
      if (ET{t, 1} > 0) % there are active bone constraints for this time tick
        invSm = invSigma(observed(:, t), observed(:, t));
        k = ET{t, 1};
        y = [X(~observed(:, t), t); zeros(k, 1)];
        xtilde = X(~observed(:, t), t);
        deltachange = 1;
        iter_y = 0;
        while (deltachange > 0.001 && iter_y < 10000)
          A = invSm;
          B = zeros(M, k);
          D = zeros(M+k, 1);
          for i = 1 : size(ET{t, 2})
          for i = 1 : k
            %A = A + ET{t, 1}{i} * y(M + i);
            A()
            B(:, i) = 2 * ET{t, 1}{i} * y(1:M);
            
            % compute the difference in distance
            u = bone(ET{t, 3}(i), 1);
            v = bone(ET{t, 3}(i), 2);
            dist = bone(ET{t, 3}(i), 3);
            D(M+i) = norm(y((u*Dim - Dim + 1) : (u * Dim)) - y((v*Dim - Dim + 1) : (v * Dim))) ^ 2 - dist ^ 2;
          end
          D(1:M) = 2 * (invSigma * (y(1:M) - xtilde) + B * y((M+1) : end));
          C = [A, B; B', zeros(k, k)];
          deltay = - pinv(C) * D * ALPHA;
          y = y + deltay; 
          deltachange = sum(abs(deltay));
          iter_y = iter_y + 1;
          y(observed(:, t)) = xtilde(observed(:, t));
        end
        X(~observed(:, t), t) = y(~observed(:, t)); 
      end
      
    end
    
    [mu, V, P, logli] = forward(X, model, varargin{:});
    
    %ucap is the estimated E[z_n]
    [Ez, Ezz, Ez1z] = backward(mu, V, P, model);  
  end

  model = MLE_lds(X, Ez, Ezz, Ez1z, varargin{:});  
  logli = real(logli);
  diff = (logli - oldLogli);
  if (logli < oldLogli)
    warning('Loglikelihood decreases!');
  end
  ratio = abs(diff/logli) ;
  LL(iter) = logli;
  oldLogli = logli;
  fprintf('iteration = %d, logli = %d\n', iter, logli);
  if (exist('plotFun'))
    plotFun(X);
    drawnow;
  end
end
model = oldmodel;
Xhat = X;




