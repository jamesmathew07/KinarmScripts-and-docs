% correctXTorque - Correct the TorqueX data from the Force/Torque sensors in 
% an EP robot.  
%
% From the time Force/Torque sensors were introduced until Dexterit-E 3.4.2
% there was a bug in the calculation of TorqueX data of the Force/Torque 
% sensor. This code corrects those errors. If TorqueX data are not 
% found in the given data file then nothing is done. If the build TDK for the 
% given data file is >=3.4.2 then nothing is done.
%
% NOTE: The TorqueY and TorqueZ data and all of the Force data from the 
% Force/Torque sensors are correct, only TorqueX needs correction. 
%
% data_out = correctXTorque(data_in) Looks at the given data and attempts to
% correct it if required. data_in is either a single trial's data, or an
% entire exam as loaded by zip_load.
%
% ex. 
% exam = zip_load('exam_file.zip')
% correctedTrial = correctXTorque(exam.c3d(1))
% correctedExam = correctXTorque(exam)
%
% Written by Duncan McLean, 2014, for BKIN Technologies.
function data_out = correctXTorque(data_in)

    data_out = data_in;
    
    if isfield(data_in, 'c3d')
        for n=1:length(data_in.c3d)
            [bCorrected, R,L] = correctTorqueInTrial(data_in.c3d(n));
            if bCorrected
                data_out.c3d(n).Right_FS_TorqueX = R;
                data_out.c3d(n).Left_FS_TorqueX = L;
                data_out.c3d(n).torqueCorrected = 1;
            end
        end
    else
        [bCorrected, R,L] = correctTorqueInTrial(data_in);
        if bCorrected
            data_out.Right_FS_TorqueX = R;
            data_out.Left_FS_TorqueX = L;
            data_out.torqueCorrected = 1;
        end
    end
    
    function [bRequiresFix, R_TX, L_TX] = correctTorqueInTrial(trial)
        bRequiresFix = (isfield(trial, 'Right_FS_TorqueX') || isfield(trial, 'Left_FS_TorqueX')) && ~isfield(trial, 'torqueCorrected');
        
        %The bug was fixed in 3.4.2. Any version before 3.4.0 does not have
        %the build tdk, so we can assume it's wrong. 
        if bRequiresFix && isfield(trial.EXPERIMENT, 'TASK_PROGRAM_BUILD_TDK')
            parts = sscanf(trial.EXPERIMENT.TASK_PROGRAM_BUILD_TDK, '%d.%d.%d');
            
            if parts(1) > 3
                bRequiresFix = 0;
            elseif parts(1) == 3
                if parts(2) > 4
                    bRequiresFix = 0;
                elseif parts(2) == 4
                    if parts(3) >= 2
                        bRequiresFix = 0;
                    end
                end
            end
        end
        
        R_TX = [];
        L_TX = [];
        
        if bRequiresFix == 0
			% if no correction required, then use the original, uncorrected data
            if isfield(trial, 'Right_FS_TorqueX')
                R_TX = trial.Right_FS_TorqueX;
            end
            
            if isfield(trial, 'Left_FS_TorqueX')
                L_TX = trial.Left_FS_TorqueX;
            end
            return
        end
        
        if isfield(trial, 'Right_FS_TorqueX')
            R_TX = correctTorque(trial.Right_L2Ang, trial.Right_FS_TorqueX, trial.Right_FS_TorqueY);
        end

        if isfield(trial, 'Left_FS_TorqueX')
            L_TX = correctTorque(trial.Left_L2Ang, trial.Left_FS_TorqueX, trial.Left_FS_TorqueY);
        end

    end

    function torqueX = correctTorque(L2_angle, FS_TorqueX, FS_TorqueY)
        force_sensor_angle_offset = 29.0 * pi/180.0;  %angle offset is always 29 degrees in this older data
        
		% calculate the angles of F/T sensor local coordinate system relative the global coordinate frame
        sensor_u_angle = L2_angle - force_sensor_angle_offset;
        sensor_v_angle = L2_angle - force_sensor_angle_offset - pi/2;
        
		% calculate what the torques were in the original F/T sensor local coordinate frame
        force_sensor_torque_u = (FS_TorqueY.*cos(sensor_v_angle) - FS_TorqueX.*sin(sensor_v_angle)) ./ (sin(sensor_u_angle).*(cos(sensor_v_angle)-sin(sensor_v_angle)));
        force_sensor_torque_v = (FS_TorqueX - FS_TorqueY) ./ (cos(sensor_v_angle)-sin(sensor_v_angle));
        
		% re-calculate what TorqueX is in the global coordinate frame
        torqueX = force_sensor_torque_u .* cos(sensor_u_angle) + force_sensor_torque_v .* cos(sensor_v_angle);
    end
end
