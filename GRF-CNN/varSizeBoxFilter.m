function I_smoothed = varSizeBoxFilter(I, sizeMat)

[R, C] = size(I);
J = cumsum(cumsum(I,1),2);
I_smoothed = zeros(size(I));

for r = 1:R
    for c = 1:C
        boxsize = round(sizeMat(r,c));
        if(boxsize == 0)
            I_smoothed(r,c) = I(r,c);
            continue;
        end
        I_smoothed(r,c) = J(min(r + boxsize, R), min(c + boxsize, C)) +...
                       J(max(r - boxsize, 1), max(c - boxsize, 1)) -...
                       J(max(r - boxsize, 1), min(c + boxsize, C)) -...
                       J(min(r + boxsize, R), max(c - boxsize, 1));
        I_smoothed(r,c) = I_smoothed(r,c)/(4*boxsize*boxsize);
    end
end