function [M64] = compress_hypervectors(M)
%
% DESCRIPTION   : to compress a matrix/vector into a matrix/vector composed
%                 by 64-bit unsigned integer variables  
%
% INPUTS:
%   M           : input matrix/vector
% OUTPUTS:
%   M64         : compressed matrix/vector
%    
    [r_M,c_M] = size(M);
    
    dim = floor(c_M/64);
    if (mod(dim, 64)) 
        dim=dim+1;
    end
    
    M64 = [];
 
    temp = uint64(0); 
  
    for z = 1 : r_M
        for j = 1 : dim - 1
            for i = 1 : 64
                temp = uint64(temp + uint64(bitsll(M(z, (i + (64 * (j - 1)))), (64 - i))));
            end  
            M64(z, j) = temp;
            temp = 0; 
        end   
        for i = 1 : rem(c_M, 64)
            temp = temp + uint64(bitsll(M(z, ((i + (64 * (dim - 1))))), (64 - i)));
        end
        M64(z, dim) = temp;
        temp = 0; 
    end
    
end
