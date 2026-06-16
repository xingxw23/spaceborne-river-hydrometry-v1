% If you use this code in your research, then please cite the following
% paper:

%F. Isikdogan, A.C. Bovik, and P. Passalacqua. Automatic analysis of 
%channel networks on remotely sensed images by singularity analysis,
%IEEE Geosci. Remote Sens. Lett., in review.

[orientation, scaleMap, pos_psi, centerline] =  ModifiedSingularityIndex2D(I, 16, 1.5);

%Quiver plot (illustrates channel orientation)
figure;
imshow(I, []);  
hold on;
[Nx, Ny] = size(I);
xidx = 1:20:Nx;
yidx = 1:20:Ny;
[X,Y] = meshgrid(xidx,yidx);
u = (pos_psi.*cos(orientation));
u = u(xidx, yidx);
v = (pos_psi.*sin(orientation));
v = v(xidx, yidx);
quiver(Y',X',v,u, 'ShowArrowHead','on', 'LineWidth', 1, 'AutoScaleFactor', 2);

%Threshold centerlines
centerline = mmscale(centerline);
level = graythresh(centerline);
[gtT1r, gtT1c] = find(centerline > level*0.1); 
gtT2 = centerline > level;
bw = bwselect(gtT2, gtT1c, gtT1r, 8);
imtool(bw);

% Regrow channels (as a figure)
[row,col] = find(bw);
llen = scaleMap(bw) * 1.25;
lthe = orientation(bw);

x_off = -llen .* cos(lthe);
y_off = llen .* sin(lthe);
lines = [col-x_off col+x_off row-y_off row+y_off];
imshow(I)
hold on
for i = 1:length(lines)
    line(lines(i,1:2), lines(i,3:4));
end

% Regrow channels (as a raster image - runs faster) 
[row,col] = find(bw);
I_regrown = bw;
llen = scaleMap(bw) * 1.5;
lthe = orientation(bw);

x_off = -llen .* cos(lthe);
y_off = llen .* sin(lthe);
lines = [col-x_off row-y_off col+x_off row+y_off];

for i = 1:length(lines)
    [xsn, ysn] = bresenham(lines(i,1), lines(i,2), lines(i,3), lines(i,4));
    linearInd = sub2ind(size(I_regrown), max(min(ysn,size(I_regrown,1)),1), max(min(xsn,size(I_regrown,2)),1));
    I_regrown(linearInd) = 1;
end
imtool(I_regrown)

%Optional: remove small connected components (e.g. ponds)
[Nx, Ny] = size(I_regrown);
CC = bwconncomp(I_regrown);
BW = false(Nx,Ny);
minlength = Nx*Ny*0.001;
for i = 1:length(CC.PixelIdxList)
    if(length(CC.PixelIdxList{i})>minlength)
        BW(CC.PixelIdxList{i}) = true;
    end
end
imtool(BW);
