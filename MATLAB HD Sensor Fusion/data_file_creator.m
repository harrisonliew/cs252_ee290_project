% DESCRIPTION: This script creates files "data.h" and "mems_<early/late>.h".
% INPUTS (set these before you run this script):
%   fusion_point: 'early' or 'late'
%   emotion: 'valence' or 'arousal'

modalities = ["GSR", "ECG", "EEG"];

DID = fopen ( 'data.h', 'w');
MID = fopen ( sprintf('mems_%s.h', fusion_point) , 'w');
fprintf(DID, '#ifndef DATA_H_\n#define DATA_H_\n\n#include <stdio.h>\n#include "init.h"\n\n');
fprintf(MID, sprintf('#ifndef MEM_%s_H_\n#define MEM_%s_H_\n\n#include <stdio.h>\n#include "init.h"\n\n', upper(fusion_point), upper(fusion_point)));

if (strcmp(emotion, 'valence'))
    e = -1;
else
    e = 0;
end

for imod = 1:length(modalities)
    mod = modalities(imod)

    % data
    test_set = eval(sprintf('TS_COMPLETE_%d', 2*imod+e));
    fprintf(DID, '//%s signals\n', mod);
    [r,c]=size(test_set);
    fprintf(DID, 'static const float TEST_SET_%s[%d][%d] = {\n', mod, r, c);
     for i = 1 : r
        fprintf(DID, '{');
        for j = 1 : c
            if j == c
                fprintf(DID, '%f',(test_set(i, j)));
            else 
                fprintf(DID, '%f, ',(test_set(i, j)));  
            end
        end
        
        fprintf(DID, '},\n');
    end
    fprintf(DID, '};\n');

    % sparse hypervectors
    projM_pos = eval(sprintf('projM%d_pos', 2*imod+e));
    projM_pos = compress_hypervectors(projM_pos);
    [r,c]=size(projM_pos);
    fprintf(MID, '\n\n//%s Embedding Vector (pos)\nstatic uint64_t projM_pos_%s[%d][%d] = {\n', mod, mod, r, c);
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%uULL',(projM_pos(i, j)));
            else 
                fprintf(MID, '%uULL, ',(projM_pos(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    fprintf(MID, '};\n');

    projM_neg = eval(sprintf('projM%d_neg', 2*imod+e));
    projM_neg = compress_hypervectors(projM_neg);
    [r,c]=size(projM_neg);
    fprintf(MID, '\n\n//%s Embedding Vector (neg)\nstatic uint64_t projM_neg_%s[%d][%d] = {\n', mod, mod, r, c);
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%uULL',(projM_neg(i, j)));
            else 
                fprintf(MID, '%uULL, ',(projM_neg(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    fprintf(MID, '};\n');

    % item memories
    IM = eval(sprintf('iMch%d', 2*imod+e));
    IM = IM.values;
    IM = cell2mat(IM');
    IM = compress_hypervectors(IM);
    [r,c]=size(IM);
    fprintf(MID, '\n\n//%s Item Memory\nstatic uint64_t iM_%s[%d][%d] = {\n', mod, mod, r, c);
     
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%uULL',(IM(i, j)));
            else 
                fprintf(MID, '%uULL, ',(IM(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    fprintf(MID, '};\n');
    
    % continuous item memories
    CIM = eval(sprintf('chAM%d', 2*imod+e));
    CIM = CIM.values;
    CIM = cell2mat(CIM');
    CIM = compress_hypervectors(CIM);
    [r,c]=size(CIM);
    fprintf(MID, '\n\n//%s Continuous Item Memory\nstatic uint64_t ciM_%s[%d][%d] = {\n', mod, mod, r, c);
     
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%uULL',(CIM(i, j)));
            else 
                fprintf(MID, '%uULL, ',(CIM(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    fprintf(MID, '};\n');
    
    % separate AMs if late fusion
    if strcmp(fusion_point, 'late')
        AM = eval(sprintf('hdc_model_%d', 2*imod+e));
        AM = AM.values;
        AM = cell2mat(AM');
        AM = compress_hypervectors(AM);
        [r,c]=size(AM);
        fprintf(MID, '\n\n//%s Associative Memory\nstatic uint64_t aM_%s[%d][%d] = {\n', mod, mod, r, c);
         
        for i = 1 : r
            fprintf(MID, '{');
            for j = 1 : c
                if j == c
                    fprintf(MID, '%uULL',(AM(i, j)));
                else 
                    fprintf(MID, '%uULL, ',(AM(i, j)));  
                end
            end
            
            fprintf(MID, '},\n');
        end
        
        fprintf(MID, '};');
        
    end

end

% golden labels
labels = eval(sprintf('L_TS_COMPLETE_%d - 1', 2+e));
fprintf(DID, '\n\n//golden labels\n');
[r,c]=size(labels);
fprintf(DID, 'static const int labels[%d] = {', r);
fprintf(DID, '%d, ', labels(1:end-1));
fprintf(DID, '%d', labels(end));
fprintf(DID, '};\n');

% single AM if early fusion
if strcmp(fusion_point, 'early')
    AM = hdc_model;
    AM = AM.values;
    AM = cell2mat(AM');
    AM = compress_hypervectors(AM);
    [r,c]=size(AM);
    fprintf(MID, '\n\n//Associative Memory\nstatic uint64_t aM[%d][%d] = {\n', r, c);
     
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%uULL',(AM(i, j)));
            else 
                fprintf(MID, '%uULL, ',(AM(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    
    fprintf(MID, '};');

end

fprintf(DID, '\n\n#endif');
fprintf(MID, '\n\n#endif');
fclose(DID);
fclose(MID);
