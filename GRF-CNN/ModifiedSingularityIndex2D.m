function [orientation, scaleMap, pos_psi, centerline] = ...
    ModifiedSingularityIndex2D(I1,nrScales, min_scale)
%Inputs:
% I1: Input Image, Must be 2-D and of type Double.
% nrScales: scalar, number of scales over which to compute the index
% min_scale: minimum scale for computation. Should be > 1 for meaningful
% results. Default value is 1.5 pixels.

%Outputs:
% orientation: Dominant channel orientation estimated at each pixel.
% scaleMap: Estimated width.
% pos_psi: Positive polarity signal index response.
% centerline: Estimated centerline.

% If you use this code in your research, then please cite the following
% papers:

%1. F. Isikdogan, A.C. Bovik, and P. Passalacqua. Automatic analysis of 
%channel networks on remotely sensed images by singularity analysis,
%IEEE Geosci. Remote Sens. Lett., in review.

%2. G. S. Muralidhar, A. C. Bovik, and M. K Markey. A steerable, multi-
%scale singularity index. IEEE Signal Process. Lett., To Appear, 2012.

%3. G. S. Muralidhar, A. C. Bovik, and M. K. Markey. A new singularity
%index. In IEEE Intl. Conf. Image Proc. IEEE, 2012.


if (ndims(I1) == 3)
    error('Input Image Must Be 2-D');
end

if (~isa(I1,'double'))
    error('Input Image Must Be Of Type Double');
end

if (~exist('nrScales','var'))
    nrScales = 5;
end

if (~exist('min_scale','var'))
    min_scale = 1.5;
end

preservePolarity = 1;

t = min_scale;

[R,C] = size(I1);
polarity = [];

scaleHistograms = zeros(R,C,nrScales);
orientationHistograms = zeros(R,C,nrScales);

for scale = nrScales : -1 : 1
    
    largest_scale = t*((sqrt(2))^(scale-1));
    sigmabig = ceil(sqrt((1-(0.2)^2)/(0.2^2))*largest_scale);
    siz = round(sigmabig*6) + 1;
    
    if (rem(siz,2) == 0)
        siz = siz + 1;
    end
    
    gbig = fspecial('gaussian',siz,sigmabig);
    mu = conv2d_fft(I1,gbig);
    I = I1-mu;
    
    sprintf('Processing scale %d', scale)
    sigma = t*((sqrt(2))^(scale-1));
    
    siz = round(sigma*4)+1;
    if (rem(siz,2) == 0)
        siz = siz + 1;
    end
    [X, Y] = meshgrid(-siz:siz,-siz:siz);
    
    theta1 = 0;
    theta2 = pi/3;
    theta3 = 2*pi/3;
    
    u = X*cos(theta1) - Y*sin(theta1);
    v = X*sin(theta1) + Y*cos(theta1);
    G0 = (1/(2*pi*(sigma^2))).*exp(-(((u.^2) + (v.^2))/(2*(sigma^2)))); % This is the mother Gaussian.
    % Since the isotropic Gaussian is rotationally symmetric, all derivatives
    % are defined in terms of this G0.
    
    G20 = (((u.^2)./(sigma^4)) - (1/(sigma^2))).*G0; %Second partial derivative along u
    
    u = X*cos(theta2) - Y*sin(theta2);
    G260 = (((u.^2)./(sigma^4)) - (1/(sigma^2))).*G0; %Second partial derivative along u
    
    u = X*cos(theta3) - Y*sin(theta3);
    G2120 = (((u.^2)./(sigma^4)) - (1/(sigma^2))).*G0; %Second partial derivative along u
    
    G20 = G20 - mean(G20(:));
    G260 = G260 - mean(G260(:));
    G2120 = G2120 - mean(G2120(:));
    
    J20 = conv2d_fft(I,G20);
    J260 = conv2d_fft(I,G260);
    J2120 = conv2d_fft(I,G2120);
    
    Nr = (2/9) * sqrt(3) * ( (J260.^2) - (J2120.^2) + (J20.*J260) - (J20.*J2120) );
    Dr = (2/9) * ( 2*(J20.^2) - (J260.^2) - (J2120.^2) + (J20.*J260) - 2*(J260.*J2120) + (J20.*J2120) );
    
    % The implementation below is for atan2 from wiki
    angles = atan2(Nr, Dr);
        
    angles = 0.5*angles;
    
    sigma1 = 1.7754*sigma;
    
    siz = round(sigma1*4) + 1;
    if (rem(siz,2) == 0)
        siz = siz + 1;
    end
    [X, Y] = meshgrid(-siz:siz,-siz:siz);
    
    theta1 = 0;
    u = X*cos(theta1) - Y*sin(theta1);
    v = X*sin(theta1) + Y*cos(theta1);
    G0_half = (1/(2*pi*(sigma1^2)))*exp(-(((u.^2) + (v.^2))/(2*(sigma1^2))));
    G0u = -((1/sigma1).^2).*u.*G0_half; % First partial derivative along u
    
    theta1 = pi/2;
    u = X*cos(theta1) - Y*sin(theta1);
    G90u = -((1/sigma1).^2).*u.*G0_half; % First partial derivative along u
    
    G0u = G0u - mean(G0u(:));
    G90u = G90u - mean(G90u(:));
    
    J0u = conv2d_fft(I,G0u);
    J90u = conv2d_fft(I,G90u);
    
    J2 = ((1/3).*(1+(2*cos(2*angles))).*J20) + ((1/3).*(1-cos(2*angles)+(sqrt(3)*sin(2*angles))).*J260) + ...
        ((1/3).*(1-cos(2*angles)-(sqrt(3)*sin(2*angles))).*J2120); % J2 is the second order derivative along the direction specified by angles
    
    J1 = (J0u.*cos(angles)) + (J90u.*sin(angles)); % J1 is the first order derivative along the direction specified by angles
    
    if (sum(G0(:)) ~= 0)
        G0 = G0./sum(G0(:));
    end
    
    J = conv2d_fft(I,G0);
    
    psi_scale = (sigma^2)*(((abs(J).*J2))./(1+((abs(J1)).^2)));
       
    if (scale == nrScales)
        polarity = sign(psi_scale);
        
        %suppress island response
        negIdx = polarity > 0;
        psi_scale(negIdx) = 0;
    
        psi = psi_scale;
        orient = angles;
        scaleMapIdx = scale * ones(R,C);
    else
        polarity_scale = sign(psi_scale);
        idx = (polarity_scale .* psi_scale) > (polarity .* psi);
        polarity(idx) = polarity_scale(idx);
        
        %suppress island response
        negIdx = polarity > 0;
        psi_scale(negIdx) = 0;
        
        psi(idx) = psi_scale(idx);
        scaleMapIdx(idx) = scale;
        orient(idx) = angles(idx);
    end
    
    orientationHistograms(:,:,scale) = angles;
    scaleHistograms(:,:,scale) = abs(psi_scale);
end

%interpolate the width
scaleMap = zeros(R,C);
for scale = 1:nrScales
    interpolated =  t*((sqrt(2))^(scale-2)) * scaleHistograms(:,:,max(scale-1,1))...
                  + t*((sqrt(2))^(scale-1)) * scaleHistograms(:,:,scale)...
                  + t*((sqrt(2))^(scale)) * scaleHistograms(:,:,min(scale+1,nrScales));
    scaleMap(scaleMapIdx == scale) = interpolated(scaleMapIdx == scale);
    normalizer = scaleHistograms(:,:,max(scale-1,1)) + scaleHistograms(:,:,scale) + scaleHistograms(:,:,min(scale+1,nrScales));
    scaleMap(scaleMapIdx == scale) = scaleMap(scaleMapIdx == scale)./normalizer(scaleMapIdx == scale);
    scaleMap(isnan(scaleMap)) = 0;
end

% remove ripples (variable-size box filter that approximates gaussian in 3 iterations)
level = graythresh(I1);
scaleMap(I1<level) = 0; %fix the scale map
psi = varSizeBoxFilter(psi, scaleMap/8);
psi = varSizeBoxFilter(psi, scaleMap/8);
psi = varSizeBoxFilter(psi, scaleMap/8);
scaleMap = varSizeBoxFilter(scaleMap, scaleMap/8);
scaleMap = varSizeBoxFilter(scaleMap, scaleMap/8);
scaleMap = varSizeBoxFilter(scaleMap, scaleMap/8);

orientation = orient;
% Simple NMS implementation
orient = orient .* 180/pi;
idx = orient < 0;
orient(idx) = orient(idx) + 180;

Q = zeros(R,C);
idx = (orient >=0 & orient <= 22.5) | (orient >=157.5 & orient <= 180);
Q(idx) = 0; % suppress in east-west

idx = (orient >22.5 & orient <= 67.5);
Q(idx) = 1;%suppress in north east, south west

idx = (orient >67.5 & orient <= 112.5);
Q(idx) = 2; % supppress in north south

idx = (orient >112.5 & orient <= 157.5);
Q(idx) = 3; % supppress in north west south east

pos_psi = zeros(R,C);
posNMS = zeros(R,C);

if (preservePolarity == 0)
    NMS = psi;
    for i = 2 : R-1
        for j = 2 : C-1
            if (Q(i,j) == 0)
                if ((psi(i,j) <= psi(i,j-1)) || (psi(i,j) <= psi(i,j+1)))
                    NMS(i,j) = 0;
                end
            elseif (Q(i,j) == 1)
                if ((psi(i,j) <= psi(i-1,j+1)) || (psi(i,j) <= psi(i+1,j-1)))
                    NMS(i,j) = 0;
                end
            elseif (Q(i,j) == 2)
                if ((psi(i,j) <= psi(i-1,j)) || (psi(i,j) <= psi(i+1,j)))
                    NMS(i,j) = 0;
                end
            elseif (Q(i,j) == 3)
                if ((psi(i,j) <= psi(i-1,j-1)) || (psi(i,j) <= psi(i+1,j+1)))
                    NMS(i,j) = 0;
                end
            end
        end
    end
else
    
    K_temp = polarity .* psi;
    NMS = K_temp;
    
    for i = 2 : R-1
        for j = 2 : C-1
            if (Q(i,j) == 0)
                if ((K_temp(i,j) <= K_temp(i,j-1)) || (K_temp(i,j) <= K_temp(i,j+1)))
                    NMS(i,j) = 0;
                end
            elseif (Q(i,j) == 1)
                if ((K_temp(i,j) <= K_temp(i-1,j+1)) || (K_temp(i,j) <= K_temp(i+1,j-1)))
                    NMS(i,j) = 0;
                end
            elseif (Q(i,j) == 2)
                if ((K_temp(i,j) <= K_temp(i-1,j)) || (K_temp(i,j) <= K_temp(i+1,j)))
                    NMS(i,j) = 0;
                end
            elseif (Q(i,j) == 3)
                if ((K_temp(i,j) <= K_temp(i-1,j-1)) || (K_temp(i,j) <= K_temp(i+1,j+1)))
                    NMS(i,j) = 0;
                end
            end
        end
    end
        
    idx = polarity == -1; % Positive going impulses have negative polarity
    pos_psi(idx) = -psi(idx);
    posNMS(idx) = NMS(idx);
    centerline = posNMS;
end