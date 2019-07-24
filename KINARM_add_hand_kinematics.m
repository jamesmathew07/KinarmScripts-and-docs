function data_out = KINARM_add_hand_kinematics(data_in)
%KINARM_ADD_HAND_KINEMATICS Calculate hand velocity and accelerations.
%	DATA_OUT = KINARM_ADD_HAND_KINEMATICS(DATA_IN) calculates the hand
%	velocities, accelerations and commanded forces from the joint
%	velocities, accelerations and motor torques for the KINARM robot.
%	These data are added to the DATA_IN structure. 
%
%	The input structure DATA_IN	should be of the form produced by 
%	DATA_IN = ZIP_LOAD. ex.
%
%   data = zip_load('183485624_2010-09-21_11-26-21.zip')
%   out = KINARM_add_hand_kinematics(data.c3d(3))
% 
%   or
%
%   data.c3d = KINARM_add_hand_kinematics(data.c3d)
%
%   If the data is in Dexterit-E 2.3 or earlier format then the usage would
%   be:
%
%   data = c3d_load('Subject, Test_2879_1_N_tm_8_3_1.c3d')
%   out = KINARM_add_hand_kinematics(data)
%
%	The hand kinematics are calculated from joint kinematics rather than
%	just differentiating the hand position because the original joint
%	kinematics are all calculated in real-time at a 1.129 kHz and then
%	re-sampled to 1 kHz.  See the BKIN Dexterity User Guide for more
%	information.  Differentiating the hand position will be produce
%	significant noise.
%
%   The hand forces calculated here are the commanded hand forces as would
%   have been 'commanded' to the KINARM robot and are based on the torques
%   applied to the robot.  These forces do NOT include the effects robot
%   inertia, which is typically not compensated for when commanded a
%   particular force or torque.  The actual force applied at the hand can
%   be either estimated using the equations of motion or measured using a
%   Force/Torque sensor at the hand.
%
%	The new fields are in units of m/s, m/s^2 and N, and are in a global
%	coordinate system (as per Right_HandX, Left_HandY etc) and are:  
% 		.Right_HandXVel
% 		.Right_HandYVel
% 		.Right_HandXAcc
% 		.Right_HandYAcc
%		.Right_Hand_ForceCMD_X
%		.Right_Hand_ForceCMD_Y
% 		.Left_HandXVel
% 		.Left_HandYVel
% 		.Left_HandXAcc
% 		.Left_HandYAcc
%		.Left_Hand_ForceCMD_X
%		.Left_Hand_ForceCMD_X

%default output
data_out = data_in;

if isempty(data_in)
	return;
end

for ii = 1:length(data_out)
	for jj = 1:2
		if jj == 1;
			side = 'RIGHT';
			side2 = 'Right';
		else 
			side = 'LEFT';
			side2 = 'Left';
        end
        
        if ~isfield(data_out(ii), [side '_KINARM']) || ~isfield(data_out(ii).([side '_KINARM']), 'VERSION')
            continue
        end
        
		if isfield(data_in(ii), [side2 '_HandX']) && (~isfield(data_in(ii), [side2 '_KINARM']) || data_out(ii).([side '_KINARM']).IS_PRESENT)
			% Check the version of the KINARM
			version = data_out(ii).([side '_KINARM']).VERSION;
			if strncmp('KINARM_EP', version, 9)
				% KINARM End-Point robot
				L1 = data_out(ii).([side '_KINARM']).L1_L;
				L2 = data_out(ii).([side '_KINARM']).L2_L;
				L2PtrOffset = 0;
			elseif strncmp('KINARM_H', version, 8) || strncmp('KINARM_M', version, 8)
				% KINARM Exoskeleton robot
				L1 = data_out(ii).CALIBRATION.([side '_L1']);
				L2 = data_out(ii).CALIBRATION.([side '_L2']);
				L2PtrOffset = data_out(ii).CALIBRATION.([side '_PTR_ANTERIOR']);
				if strcmp(side, 'LEFT')
					% L2PtrOffset is in global coordinates, not local, so change sign
					% as compared to the right hand.
					L2PtrOffset = -L2PtrOffset;
				end
			else
				% unidentified robot
				error(['unidentified ' side ' KINARM robot type']);
			end
			L1Ang = data_out(ii).([side2 '_L1Ang']);
			L2Ang = data_out(ii).([side2 '_L2Ang']);
			L1Vel = data_out(ii).([side2 '_L1Vel']);
			L2Vel = data_out(ii).([side2 '_L2Vel']);
			L1Acc = data_out(ii).([side2 '_L1Acc']);
			L2Acc = data_out(ii).([side2 '_L2Acc']);
			M1TorApp = data_in(ii).([side2 '_M1TorCMD']);
			M2TorApp = data_in(ii).([side2 '_M2TorCMD']);
			[hvx, hvy, hax, hay, Fx, Fy] = calc_hand_kinematics(L1, L2, L2PtrOffset, L1Ang, L2Ang, L1Vel, L2Vel, L1Acc, L2Acc, M1TorApp, M2TorApp);
			data_out(ii).([side2 '_HandXVel']) = hvx;
			data_out(ii).([side2 '_HandYVel']) = hvy;
			data_out(ii).([side2 '_HandXAcc']) = hax;
			data_out(ii).([side2 '_HandYAcc']) = hay;
			data_out(ii).([side2 '_Hand_ForceCMD_X']) = Fx;
			data_out(ii).([side2 '_Hand_ForceCMD_Y']) = Fy;

		end
	end
end

%re-order the fieldnames so that the hand velocity, acceleration and
%commanded forces are with the hand position at the beginning of the field
%list 
orig_names = fieldnames(data_in);
temp_names = fieldnames(data_out);
right_names = {'Right_HandXVel'; 'Right_HandYVel'; 'Right_HandXAcc'; 'Right_HandYAcc'; 'Right_Hand_ForceCMD_X'; 'Right_Hand_ForceCMD_Y'};
left_names = {'Left_HandXVel'; 'Left_HandYVel'; 'Left_HandXAcc'; 'Left_HandYAcc'; 'Left_Hand_ForceCMD_X'; 'Left_Hand_ForceCMD_Y'};

%check to see if any right-handed or left-handed fields were added to the
%output data structure
added_right_to_output = false;
added_left_to_output = false;
for ii = 1:length(right_names)
	if isempty( strmatch(right_names{ii}, orig_names, 'exact') ) && ~isempty( strmatch(right_names{ii}, temp_names, 'exact') )
		added_right_to_output = true;
	end
	if isempty( strmatch(left_names{ii}, orig_names, 'exact') ) && ~isempty( strmatch(left_names{ii}, temp_names, 'exact') )
		added_left_to_output = true;
	end
end

if added_right_to_output
	% remove all of the new fields from the original list
	for ii = 1:length(right_names)
		index = strmatch(right_names{ii}, orig_names, 'exact');
		if ~isempty(index)
			orig_names(index) = [];
		end
	end
	% place the new fields right after the HandY field
	index = strmatch('Right_HandY', orig_names, 'exact');
	new_names = cat(1, orig_names(1:index), right_names, orig_names(index+1:length(orig_names)));
else
	new_names = orig_names;
end
if added_left_to_output
	% remove all of the new fields from the original list
	for ii = 1:length(left_names)
		index = strmatch(left_names{ii}, orig_names, 'exact');
		if ~isempty(index)
			orig_names(index) = [];
		end
	end
	% place the new fields right after the HandY field
	index = strmatch('Left_HandY', new_names, 'exact');
	new_names = cat(1, new_names(1:index), left_names, new_names(index+1:length(new_names)));
end
data_out = orderfields(data_out, new_names);

disp('Finished adding KINARM robot hand kinematics');



%function which calculates hand velocity and acceleration from the angular
%velocities and accelerations 
function [hvx, hvy, hax, hay, Fx, Fy] = calc_hand_kinematics(L1, L2, L2PtrOffset, L1Ang, L2Ang, L1Vel, L2Vel, L1Acc, L2Acc, T1, T2);

sinL1 = sin(L1Ang);
cosL1 = cos(L1Ang);
sinL2 = sin(L2Ang);
cosL2 = cos(L2Ang);
sinL2ptr = cosL2;
cosL2ptr = -sinL2;

%hand velocities and accelerations
hvx = -L1*sinL1.*L1Vel - L2*sinL2.*L2Vel - L2PtrOffset*sinL2ptr.*L2Vel;
hvy = L1*cosL1.*L1Vel + L2*cosL2.*L2Vel + L2PtrOffset*cosL2ptr.*L2Vel;
hax = -L1 * (cosL1.*L1Vel.^2 + sinL1.*L1Acc) - L2 * ( cosL2.*L2Vel.^2 + sinL2.*L2Acc) - L2PtrOffset * ( cosL2ptr.*L2Vel.^2 + sinL2ptr.*L2Acc);
hay = L1 * (-sinL1.*L1Vel.^2 + cosL1.*L1Acc) + L2 * (-sinL2.*L2Vel.^2 + cosL2.*L2Acc) + L2PtrOffset * (-sinL2ptr.*L2Vel.^2 + cosL2ptr.*L2Acc);

%hand forces
A1 = -L1*sinL1;
A2 = L1*cosL1;
A3 = -(L2*sinL2+L2PtrOffset*sinL2ptr);
A4 = (L2*cosL2+L2PtrOffset*cosL2ptr);
%pre-allocate the memory for the _Hand_FX and _Hand_FY vectors
%for enhanced speed
Fx = L1Ang;
Fy = L1Ang;
for k = 1:length(L1Ang)
	F = [A1(k) A2(k); A3(k) A4(k)] \ [T1(k); T2(k)];
	Fx(k) = F(1);
	Fy(k) = F(2);
end