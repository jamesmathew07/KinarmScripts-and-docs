function c3d_out=KINARM_add_COP(c3d_in)
%KINARM_add_COP(c3d_in) - If the c3d data contains force plate information
%   this will calculate the COPx, COPy, COP_VelocityX, COP_VelocityY for each
%   force plate found.
%
%Usage:
% data = zip_load('exam_name.zip');
% data.c3d = KINARM_add_COP(data.c3d)
    c3d_out = c3d_in;

    %When the FZ value is above this we will not calculate the COP since it
    %will be too noisy and meaningless.
    SMALL_FZ_THRESHOLD = -40;
    
    plateCount = c3d_out(1).ACCESSORIES.FORCE_PLATE_COUNT;
    fprintf('Force plate count: %d\n', plateCount);
    
    for ii = 1:length(c3d_out)
        fprintf('.');
        
        for plateIdx=1:plateCount
            
            strPlateID = num2str(plateIdx);
            strFPName = ['FP' strPlateID '_'];
            strParamName = ['FORCE_PLATE_' strPlateID '_'];
            
            [COPx, COPy] = toCOP(getPlateOffset()); 
            c3d_out(ii).([strFPName 'COPx']) = COPx;
            c3d_out(ii).([strFPName 'COPy']) = COPy;
            c3d_out(ii).([strFPName 'COP_VelocityX']) = calcVelocity(COPx, c3d_out(ii).([strFPName 'TimeStamp']));
            c3d_out(ii).([strFPName 'COP_VelocityY']) = calcVelocity(COPy, c3d_out(ii).([strFPName 'TimeStamp']));
        end        
    end
    
    fprintf('\nForce plate channels added.');
    
    %The plate offset is stored in all exams files. This is a reference to
    %the center of the plate. By applying this offset to all COP values we
    %have moved the COP to its correct location in the global workspace.
    function offset=getPlateOffset()
        
        FORCE_PLATE_SEPARATION = 0.47; %the centers of the plates should be 47cm apart
        offset = [0, 0];
        
        if isfield(c3d_out(ii).ACCESSORIES, [strParamName 'CENTER_X'])
            offset = [c3d_out(ii).ACCESSORIES.([strParamName 'CENTER_X']), ...
                c3d_out(ii).ACCESSORIES.([strParamName 'CENTER_Y'])];
            
            %this is a work around for a bug where the second plate's X
            %value was recorded incorrectly. This moves the plate location.
            if plateIdx == 2
                if c3d_out(ii).ACCESSORIES.FORCE_PLATE_1_CENTER_X == c3d_out(ii).ACCESSORIES.FORCE_PLATE_2_CENTER_X && ...
                        c3d_out(ii).ACCESSORIES.FORCE_PLATE_1_CENTER_Y == c3d_out(ii).ACCESSORIES.FORCE_PLATE_2_CENTER_Y
                    
                    if offset(0) < 0
                         offset(0) =  offset(0) + FORCE_PLATE_SEPARATION;
                    else
                         offset(0) =  offset(0) - FORCE_PLATE_SEPARATION;
                    end
                end
            end
        end
    end

    function [COPx, COPy]=toCOP(offset)
        Fx = c3d_out(ii).([strFPName 'FX']);
        Fy = c3d_out(ii).([strFPName 'FY']);
        Fz = c3d_out(ii).([strFPName 'FZ']);
        Mx = c3d_out(ii).([strFPName 'MX']);
        My = c3d_out(ii).([strFPName 'MY']);
        
        zOffset = 0;
        if strncmpi(c3d_out(ii).ACCESSORIES.([strParamName 'TYPE']), 'NDI', 3)
            %constant from David McNiel at NDI to move the COP to the top
            %of the plate
            zOffset = 0.0471; 
        end
        
        mX = Mx - (Fy*zOffset);
        mY = My + (Fx*zOffset);
        COPx = offset(1) - mY ./ Fz;
        COPy = -offset(2) + mX ./ Fz;
        
        %for small force in Z values calculating the COP makes no sense 
        %since it can make the number jump around wildly. This finds those
        %low FZ values and just sets the COP to the center of the plate.
        smallFzIdx = find(Fz > SMALL_FZ_THRESHOLD);
        COPx(smallFzIdx) = offset(1);
        COPy(smallFzIdx) = -offset(2);
    end

    function velocityOut=calcVelocity(position, timestamp)
        [~, idxs, ~] = unique(timestamp);
        
        curIdxs = idxs(2:end);
        prevIdxs = idxs(1:end -1);
        
        %creates the diff of position over the diff of time for only the
        %values where time has changed.
        deltaP = position(curIdxs) - position(prevIdxs);
        deltaT = timestamp(curIdxs) - timestamp(prevIdxs);
        velocity = deltaP ./ deltaT;

        %This will fill in the velocities at unique time points, the rest
        %will be zeros
        velocityOut = zeros(length(position), 1);
        velocityOut(curIdxs) = velocity;
        
        Fz = c3d_out(ii).([strFPName 'FZ']);
        lowFzIdx = find(Fz > SMALL_FZ_THRESHOLD);
        if ~isempty(lowFzIdx)
            indexesOfChange = find(diff(lowFzIdx) > 1);
            %this SHOULD find all of the points of instantaneous change so we
            %can remove those points from the velocity calculations. Those
            %points need to be removed because instantaneous change causes huge
            %velocity changes that are not real.
            % (indexesOfChange + 1) = indexes where we got from 0 force to any
            % other value
            % lowFzIdx(indexesOfChange + 1) = indexes where we go from any
            % force to zero.
            % lowFzIdx(end) + 1 = this takes care of the case where there is
            % only one major inflection. 
            if isempty(indexesOfChange)
                instantaneousChangePoints = lowFzIdx(end) + 1;
            else
                instantaneousChangePoints = [(indexesOfChange + 1)', lowFzIdx(indexesOfChange + 1)', lowFzIdx(end) + 1];
            end
            velocityOut(instantaneousChangePoints) = 0;
        end
        
        
        %this fills in all of the zeros left by the last step by "dragging"
        %the last non-zero down to the next array entries until a new
        %non-zero value is found.
        curVal = velocityOut(curIdxs(1));
        for jj=curIdxs(1):length(velocityOut)
            if velocityOut(jj) ~= 0
                curVal =  velocityOut(jj);
            else
                velocityOut(jj) = curVal;
            end
        end        
    end
end