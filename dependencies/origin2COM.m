function com = origin2COM(Pin)
%   set origin to the centre-of-mass of the first image
%   Pin: cell arrays of character vectors containing the file names
%
%   ATTENTION: The first image is the reference, the remaining images are kept 
%   aligned with the first one
%

if (nargin < 1)
    Pin = spm_select([1 Inf],'image','select images(first image is the reference)');
    Pin = cellstr(Pin);
end

num_images = length(Pin);

% pre-estimated COM of MNI template
com_reference = [0 -5 -8];
    
P = Pin{1}; % last image as reference
V = spm_vol(P);
Y = spm_read_vols(V);
avg = mean(Y(:));
avg = mean(Y(Y>avg));  % don't use background values
[x,y,z] = ind2sub(size(Y),find(Y>avg));
com = V.mat(1:3,:)*[mean(x) mean(y) mean(z) 1]';
com = com';

for i = 1:num_images
    
    P = Pin{i};    
    Affine = eye(4);
    V = spm_vol(P);
    M = spm_get_space(V.fname);
	Affine(1:3,4) = (com - com_reference)';
	spm_get_space(V.fname,Affine\M);
    
end

end


