%This script creates files "data.h" and "mems_<early/late>.h".

% set this variable before you run this script
% fusion_point = 'early'; % early or late only

modalities = ["GSR", "ECG", "EEG"];

DID = fopen ( 'data.h', 'w');
MID = fopen ( sprintf('mems_%s.h', fusion_point) , 'w');
fprintf(DID, '#ifndef DATA_H_\n#define DATA_H_\n\n#include <stdio.h>\n#include "init.h"\n\n');
fprintf(MID, sprintf('#ifndef MEM_%s_H_\n#define MEM_%s_H_\n\n#include <stdio.h>\n#include "init.h"\n\n', upper(fusion_point), upper(fusion_point)));

for imod = 1:length(modalities)
    mod = modalities(imod)

    test_set = eval(sprintf('features_%s', mod));
    fprintf(DID, '//%s signals\n', mod);
    [r,c]=size(test_set);
    fprintf(DID, 'const float TEST_SET_%s[%d][%d] = {\n', mod, r, c);
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

    IM = eval(sprintf('iMch%d', 2*imod));
    IM = IM.values;
    IM = cell2mat(IM');
    IM = compress_hypervectors(IM);
    [r,c]=size(IM);
    fprintf(MID, '\n\n//%s Item Memory\nuint64_t iM_%s[%d][%d] = {\n', mod, mod, r, c);
     
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%d',(IM(i, j)));
            else 
                fprintf(MID, '%d, ',(IM(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    fprintf(MID, '};\n');
    
    CIM = eval(sprintf('chAM%d', 2*imod));
    CIM = CIM.values;
    CIM = cell2mat(CIM');
    CIM = compress_hypervectors(CIM);
    [r,c]=size(CIM);
    fprintf(MID, '\n\n//%s Continuous Item Memory\nuint64_t ciM_%s[%d][%d] = {\n', mod, mod, r, c);
     
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%d',(CIM(i, j)));
            else 
                fprintf(MID, '%d, ',(CIM(i, j)));  
            end
        end
        
        fprintf(MID, '},\n');
    end
    fprintf(MID, '};\n');
    
    % separate AMs if late fusion
    if strcmp(fusion_point, 'late')
        AM = eval(sprintf('hdc_model_%d', 2*imod));
        AM = AM.values;
        AM = cell2mat(AM');
        AM = compress_hypervectors(AM);
        [r,c]=size(AM);
        fprintf(MID, '\n\n//%s Associative Memory\nuint64_t aM_%s[%d][%d] = {\n', mod, mod, r, c);
         
        for i = 1 : r
            fprintf(MID, '{');
            for j = 1 : c
                if j == c
                    fprintf(MID, '%d',(AM(i, j)));
                else 
                    fprintf(MID, '%d, ',(AM(i, j)));  
                end
            end
            
            fprintf(MID, '},\n');
        end
        
        fprintf(MID, '};');
        
    end

end

% single AM if early fusion
if strcmp(fusion_point, 'early')
    AM = hdc_model;
    AM = AM.values;
    AM = cell2mat(AM');
    AM = compress_hypervectors(AM);
    [r,c]=size(AM);
    fprintf(MID, '\n\n//Associative Memory\nuint64_t aM[%d][%d] = {\n', r, c);
     
    for i = 1 : r
        fprintf(MID, '{');
        for j = 1 : c
            if j == c
                fprintf(MID, '%d',(AM(i, j)));
            else 
                fprintf(MID, '%d, ',(AM(i, j)));  
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
