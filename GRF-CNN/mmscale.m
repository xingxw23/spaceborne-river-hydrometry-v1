function [ img ] = mmscale( img )
%Performs simple contrast stretching

if(size(img,3) == 1)
    img = (img - min(img(:)))/(max(img(:)) - min(img(:)));
elseif(size(img,3) == 3)
    img(:,:,1) = mmscale( img(:,:,1) );
    img(:,:,2) = mmscale( img(:,:,2) );
    img(:,:,3) = mmscale( img(:,:,3) );
else
    error('Invalid image');
end

end

