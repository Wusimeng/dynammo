function [bone, bone_var, bone_length_series] = get_bones(data, varargin)
% input the motion capture data in marker positions
% extract the bones using thresholding on variance of pairwise bone distance
% assume the position in 3d space.
% Args:
%   data: M * N matrix
% Optional Args:
%   'Threshold', followed by a number denoting the threshold used to
%   determine the bone
%   'Skeleton', using skeleton.mat file denoting the human body
%   skeleton
%   'Bonenames', followed by a cell array of strings for the bone names
%   'Dim', followed by a number denoting the dimension of space, default=3
% Returns:
%
%
% Example:
%   [bone, bone_var, bone_length_series] = get_bones(data, 'Bonenames',
%   textheader);
%   
%
%
%
% modified by leili, 2010/4/6

a = find(strcmp('Dim', varargin));
if (~isempty(a))
  Dim = varargin{a+1};
else
  Dim = 3;
end

N = size(data, 2);
M = size(data, 1);
k = M/Dim;
dist = zeros(k, k);
bone_length_series = zeros(N, k, k);
variance = zeros(k, k);
for i = 1:k
  for j = 1:k
    bone_length_series(:, i, j) = sqrt(sum((data((i*Dim - Dim + 1) : (i*Dim), :) - data((j*Dim - Dim + 1):(j*Dim), :)).^2));
    dist(i,j) = mean(bone_length_series(:, i, j));
    %variance(i, j) = var(bone_length_series(:, i, j));    
    variance(i, j) = max(bone_length_series(:, i, j)) - min(bone_length_series(:, i, j));
  end
end

bone_var = variance;

a = find(strcmp('Threshold', varargin));
b = find(strcmp('Bonenames', varargin));
if (any(strcmp('Skeleton', varargin)))
  skeleton_file = 'skeleton.mat';
  load(skeleton_file);
  bone = zeros(size(skeleton, 1), 3);
  for i = 1 : size(bone, 1)
    bone(i, 1:2) = skeleton(i, 1:2);
    bone(i, 3) = dist(bone(i, 1), bone(i, 2));
  end
elseif (~isempty(b))
  names = varargin{b+1};
 	new_names = regexprep(names, '^.*:(.*-[xyz])$', '$1');
	base_names = regexprep(new_names(1:3:end), '^(.*)-[xyz]$', '$1');
	%Make sure markers are layed out in an order we approve of:
	assert(min(strcmp(new_names(1:3:end), strcat(base_names, '-x'))) == 1);
	assert(min(strcmp(new_names(2:3:end), strcat(base_names, '-y'))) == 1);
	assert(min(strcmp(new_names(3:3:end), strcat(base_names, '-z'))) == 1);
	clear new_names;

  hier = { ...
    ... %stuff on the left:
    'LANK' 'LSHN'  ...
    'LBHD' 'C7' ...
    'LBWT' 'LBAC' ...
    'LBWT' 'NEWLBAC' ...    
    'LELB' 'LUPA'  ...
    'LELB' 'LSHO'  ...
    'LELB' 'NEWLSHO'  ...    
    'LFHD' 'LBHD'  ...
    'LFRM' 'LELB'  ...
    'LFWT' 'LBWT'  ...
    'LFWT' 'STRN'  ...
    'LHEE' 'LANK'  ...
    'LKNE' 'LTHI'  ...
    'LMT1' 'LANK'  ...
    'LMT1' 'LMT5'  ...
    'LMT5' 'LANK'  ...
    'LRSTBEEF' 'LMT5'  ...
    'LRSTBEEF' 'LTOE'  ...
    'LTOE' 'LMT1'  ...
    'LSHN' 'LKNE'  ...
    'LSHO' 'C7'  ...
    'LSHO' 'CLAV'  ...
    'LTHI' 'LFWT'  ...
    'LTHI' 'LBWT'  ...
    'LFIN' 'LWRB'  ...
    'LFIN' 'LTHMB'  ...
    'LTHMB' 'LWRA'  ...
    'LUPA' 'NEWLSHO'  ...
    'LUPA' 'LSHO'  ...
    'LWRA' 'LFRM'  ...
    'LWRA' 'LWRB'  ...
    'LWRB' 'LFRM'  ...
    'NEWLBAC' 'T10'  ...
    'NEWLSHO' 'LSHO'  ...
    'LBAC' 'T10'  ...
    'LSHO' 'LSHO'  ...    
    ... %stuff on the right:
    'RANK' 'RSHN'  ...
    'RBHD' 'C7'  ...
    'RBWT' 'NEWRBAC'  ...
    'RBWT' 'RBAC'  ...    
    'RELB' 'RUPA'  ...
    'RELB' 'NEWRSHO'  ...
    'RELB' 'RSHO'  ...    
    'RFHD' 'RBHD'  ...
    'RFRM' 'RELB'  ...
    'RFWT' 'RBWT'  ...
    'RFWT' 'STRN'  ...
    'RHEE' 'RANK'  ...
    'RKNE' 'RTHI'  ...
    'RMT1' 'RANK'  ...
    'RMT1' 'RMT5'  ...
    'RMT5' 'RANK'  ...
    'RRSTBEEF' 'RMT5'  ...
    'RRSTBEEF' 'RTOE'  ...
    'RTOE' 'RMT1'  ...
    'RSHN' 'RKNE'  ...
    'RSHO' 'C7'  ...
    'RSHO' 'CLAV'  ...
    'RTHI' 'RFWT'  ...
    'RTHI' 'RBWT'  ...
    'RFIN' 'RWRB'  ...
    'RFIN' 'RTHMB'  ...
    'RTHMB' 'RWRA'  ...
    'RUPA' 'NEWRSHO'  ...    
    'RUPA' 'RSHO'  ...
    'RWRA' 'RFRM'  ...
    'RWRA' 'RWRB'  ...
    'RWRB' 'RFRM'  ...
    'NEWRBAC' 'T10'  ...
    'NEWRSHO' 'RSHO'  ...
    'RBAC' 'C7'  ...
    'RBAC' 'T8'  ...
    ... %The centered stuff:
    'C7' 'T8'  ...
    'T8' 'T10'  ...
    'LBHD' 'RBHD'  ...
    'LFHD' 'RFHD'  ...
    'CLAV' 'STRN'  ...
    };  
  bone = [];    
  for i = 1 : 2 : length(hier)
  	a = find(strcmp(hier(i), base_names));
	b = find(strcmp(hier(i+1), base_names));
    if (~isempty(a) && ~isempty(b))
      bone = [bone; a, b, dist(a,b)];
      bone = [bone; b, a, dist(a,b)];
    end
  end
else
  if (~isempty(a))
    THRESHOLD = varargin{a+1};
  else 
    THRESHOLD = 0.001;
  end
  dist(variance > THRESHOLD) = 0;
  [x, y, d] = find(dist);
  %idx = x < y;
  %bone = [x(idx), y(idx), d(idx)];
  bone = [x, y, d];

end


