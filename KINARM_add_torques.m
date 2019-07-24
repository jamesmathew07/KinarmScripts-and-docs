
function data_out = KINARM_add_torques(data_in)
%KINARM_ADD_TORQUES Calculate intramuscular and applied torques for KINARM 
%	Exoskeleton robot and applied forces at the hand for KINARM EP robots.
%
%	DATA_OUT = KINARM_ADD_TORQUES(DATA_IN).  Calculations are based on the
%	kinematics in DATA_IN, the inertia of the KINARM robot, the inertia of
%	KINARM arm troughs (or anything else attached the KINARM robot), and
%	the inertia of the subject.  This function also calculates the torques
%	applied to the subject at the joints and end-point (i.e. hand).  
%
%	The new fields are:
%		[Right|Left]_Hand_[FX|FY]		(forces applied to subject's hand)
%		[Right|Left]_[ELB|SHO]TorIM		(intramuscule torques at joints)
%		[Right|Left]_[ELB|SHO]TorAPP	(torques applied to subject's joints)
%
%	If subject inertial parameters are not present in the DATA_IN
%	structure, then intramuscular torques will not be calculated (only the
%	applied torques will be calculated).  Subject inertial parameters are
%	usually added to the DATA_IN structure by calling
%	KINARM_ADD_SUBJECT_INERTIA.
%
%	If arm troughs, handles or other masses were added the KINARM robot
%	during data collection, then the inertial properties of those extra
%	links must be added to the DATA_IN structure prior to calling this
%	function by calling KINARM_ADD_TROUGH_INERTIA.
%
%	Note: if the input DATA_IN structure does not have motor friction
%	estimates in it (e.g. DATA_IN(ii).Right_M1TorFRC), torques and forces
%	are still calculated, but a warning is provided.  Customers can add
%	their own friction values using KINARM_ADD_FRICTION.m 
%
%	The input structure DATA_IN	should be of the form produced by 
%	DATA_IN = ZIP_LOAD. ex.
%
%   data = zip_load('183485624_2010-09-21_11-26-21.zip')
%   out = KINARM_add_torques(data.c3d(3))
%
%   If the data is in Dexterit-E 2.3 or earlier format then the usage would
%   be:
%
%   data = c3d_load('Subject, Test_2879_1_N_tm_8_3_1.c3d')
%   out = KINARM_add_torques(data)
%
%	The equations of motion for the KINARM robot were derived and provided by:
%	Dr. Gregory W Ojakangas
%	Associate professor of physics
%	Drury University
%	900 N Benton
%	Springfield, MO  65802

data_out = data_in;

if isempty(data_in)
	return
end

for ii = 1:length(data_in)
	for jj = 1:2
		if jj == 1;
			side = 'RIGHT';
			side2 = 'Right';
		else 
			side = 'LEFT';
			side2 = 'Left';
		end
		if isfield(data_in(ii), [side2 '_HandX']) && data_out(ii).([side '_KINARM']).IS_PRESENT;
			version = data_in(ii).([side '_KINARM']).VERSION;
			KINARM_inertia = data_in(ii).([side '_KINARM']);
			if isfield(data_in(ii), [side '_KINARM_TROUGHS'])
				% Add inertia from auxillary objects (e.g. arm troughs)
				KINARM_inertia = KINARM_combine_inertias(KINARM_inertia, data_in(ii).([side '_KINARM_TROUGHS']));
			else
				disp(['WARNING - no inertias found for ' side ' KINARM arm troughs parts for trial ' data_in(ii).FILE_NAME '.']);
			end
			% ***********************************
			%calculate total torques applied to arm segments (global coordinates)
			[T1, T2] = calc_torques(KINARM_inertia, data_out(ii), side, side2);

			%include the effects of friction to the Torques applied by the
			%motors if the frictions exist
			if isfield(data_in(ii), [side2 '_M1TorFRC']) && isfield(data_in(ii), [side2 '_M2TorFRC'])
				M1TorApp = data_in(ii).([side2 '_M1TorCMD']) + data_in(ii).([side2 '_M1TorFRC']);
				M2TorApp = data_in(ii).([side2 '_M2TorCMD']) + data_in(ii).([side2 '_M2TorFRC']);
			else
				disp(['WARNING - no motor friction estimates found for trial ' data_in(ii).FILE_NAME '.']);
				M1TorApp = data_in(ii).([side2 '_M1TorCMD']);
				M2TorApp = data_in(ii).([side2 '_M2TorCMD']);
			end
			
			%subtract the torques applied by the motors
			T1 = T1 - M1TorApp;
			T2 = T2 - M2TorApp;
			%convert to local joint coordinates
			[TELB, TSHO] = convert_torques(T1, T2, side2);
			data_out(ii).([side2 '_ELBTorAPP']) = TELB;
			data_out(ii).([side2 '_SHOTorAPP']) = TSHO;
						
			% ***********************************
			% Calculate applied endpoint forces _Hand_FX and _Hand_FY
			if strncmp('KINARM_EP', version, 9)
				L1 = data_in(ii).([side '_KINARM']).L1_L;
				L2 = data_in(ii).([side '_KINARM']).L2_L;
				L2_ptr = 0;
			else
				% assume that it is an Exoskeleton robot.
				L1 = data_in(ii).CALIBRATION.([side '_L1']);
				L2 = data_in(ii).CALIBRATION.([side '_L2']);
				L2_ptr = data_in(ii).CALIBRATION.([side '_PTR_ANTERIOR']);
			end
			L1Ang = data_in(ii).([side2 '_L1Ang']);
			L2Ang = data_in(ii).([side2 '_L2Ang']);
			if strmatch(side2, 'Right')
				L2ptr_Ang = L2Ang + pi;
			else
				L2ptr_Ang = L2Ang - pi;
			end

			A1 = -L1*sin(L1Ang);
			A2 = L1*cos(L1Ang);
			A3 = -(L2*sin(L2Ang)+L2_ptr*sin(L2ptr_Ang));
			A4 = (L2*cos(L2Ang)+L2_ptr*cos(L2ptr_Ang));
			%pre-allocate the memory for the _Hand_FX and _Hand_FY vectors
			%for enhanced speed
			data_out(ii).([side2 '_Hand_FX']) = L1Ang;
			data_out(ii).([side2 '_Hand_FY']) = L1Ang;
			for k = 1:length(L1Ang)
				F = [A1(k) A2(k); A3(k) A4(k)] \ [T1(k); T2(k)];
				data_out(ii).([side2 '_Hand_FX'])(k) = F(1);
				data_out(ii).([side2 '_Hand_FY'])(k) = F(2);
			end
			
			% ***********************************
			% calculate intramuscular torques _ELBTorIM and _SHOTorIM
			% But only if subject inertia exists.
			if isfield(data_in(ii), [side '_ARM'])
				KINARM_subj_inertia = KINARM_combine_inertias(KINARM_inertia, data_in(ii).([side '_ARM']));

				[T1, T2] = calc_torques(KINARM_subj_inertia, data_out(ii), side, side2);
				% subtract the torques applied by the motors
				T1 = T1 - M1TorApp;
				T2 = T2 - M2TorApp;
				% convert to local joint coordinates
				[TELB, TSHO] = convert_torques(T1, T2, side2);
				data_out(ii).([side2 '_ELBTorIM']) = TELB;
				data_out(ii).([side2 '_SHOTorIM']) = TSHO;
			else
				disp(['WARNING - no subject inertial parameters found for trial ' data_in(ii).FILE_NAME '.  Intramuscular torques not calculated']);
				data_out(ii).([side2 '_ELBTorIM']) = [];
				data_out(ii).([side2 '_SHOTorIM']) = [];
			end
		end
	end
end

% re-order the fieldnames so that the hand forces are with the hand
% kinematics and the joint torques are with motor torques
orig_names = fieldnames(data_in);
temp_names = fieldnames(data_out);
right_hand_names = {'Right_Hand_FX'; 'Right_Hand_FY'};
left_hand_names = {'Left_Hand_FX'; 'Left_Hand_FY'};
right_joint_names = {'Right_ELBTorIM'; 'Right_SHOTorIM'; 'Right_ELBTorAPP'; 'Right_SHOTorAPP'};
left_joint_names = {'Left_ELBTorIM'; 'Left_SHOTorIM'; 'Left_ELBTorAPP'; 'Left_SHOTorAPP'};
right_names = [right_hand_names; right_hand_names];
left_names = [left_hand_names; left_joint_names];

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
	% place the new fields right after the HandY field and the M2Tor field
	index = max(strmatch('Right_HandY', orig_names));		%Find last field beginning with 'Right_HandY'
	new_names = cat(1, orig_names(1:index), right_hand_names, orig_names(index+1:length(orig_names)));
	index = max(strmatch('Right_M2Tor', new_names));
	new_names = cat(1, new_names(1:index), right_joint_names, new_names(index+1:length(new_names)));
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
	% place the new fields right after the HandY field and the M2Tor field
	index = max(strmatch('Left_HandY', new_names));
	new_names = cat(1, new_names(1:index), left_hand_names, new_names(index+1:length(new_names)));
	index = max(strmatch('Left_M2Tor', new_names));
	new_names = cat(1, new_names(1:index), left_joint_names, new_names(index+1:length(new_names)));
end
data_out = orderfields(data_out, new_names);

disp('Finished adding KINARM robot applied and intramuscular torques');





function [TELB, TSHO] = convert_torques(T1, T2, side2)
% Convert torques from global to local coordinates
Telbow_global = T2;
Tshoulder_global = T1 + Telbow_global;
if strmatch(side2, 'Right', 'exact')
	TELB = Telbow_global;
	TSHO = Tshoulder_global;
else
	TELB = -Telbow_global;
	TSHO = -Tshoulder_global;
end



function [T1, T2] = calc_torques(inertia, data_in, side, side2)
% This function calculates the total torques applied to each
% segment (i.e. motor torques are NOT subtracted by this function)

% Ix is the inertia at the center of mass of segment x
% mx is the mass of segment x
% cxx is the location of the CofM WRT proximal joint in the axial direction
% cyx is the location of the CofM WRT proximal joint in the perpendicular
% direction (Right-handed coordinate system)
I1 = inertia.L1_I;
I2 = inertia.L2_I;
I3 = inertia.L3_I;
I4 = inertia.L4_I;
M1 = inertia.L1_M;
M2 = inertia.L2_M;
M3 = inertia.L3_M;
M4 = inertia.L4_M;
cx1 = inertia.L1_C_AXIAL;
cx2 = inertia.L2_C_AXIAL;
cx3 = inertia.L3_C_AXIAL;
cx4 = inertia.L4_C_AXIAL;
cy1 = inertia.L1_C_ANTERIOR;
cy2 = inertia.L2_C_ANTERIOR;
cy3 = inertia.L3_C_ANTERIOR;
cy4 = inertia.L4_C_ANTERIOR;
% convert to right-handed coordinate system
if strmatch('LEFT', side, 'exact')
	cy1 = -cy1;
	cy2 = -cy2;
	cy3 = -cy3;
	cy4 = -cy4;
end

Im1 = data_in.([side '_KINARM']).MOTOR1_I;			%inertia of motor 1, after gear ratio, kg-m^2
Im2 = data_in.([side '_KINARM']).MOTOR2_I;			%inertia of motor 2, after gear ratio, kg-m^2
version = data_in.([side '_KINARM']).VERSION;
if strncmp('KINARM_EP', version, 9)
	L1 = data_in.([side '_KINARM']).L1_L;
	delta = 0;											%angle between segments 2 and 5
else
	% assume that it is an Exoskeleton robot.
	L1 = data_in.CALIBRATION.([side '_L1']);
	delta = data_in.([side '_KINARM']).L2_L5_ANGLE;		%angle between segments 2 and 5
end
L3 = data_in.([side '_KINARM']).L3_L;				%crank length (m)
% convert to global coordinate system
if strmatch('LEFT', side, 'exact')
	delta = - delta;
end

%calculate KINARM inertias relative to proximal joint
I1_prox = I1 + M1*(cx1^2 + cy1^2);
I2_prox = I2 + M2*(cx2^2 + cy2^2);
I3_prox = I3 + M3*(cx3^2 + cy3^2);
I4_prox = I4 + M4*(cx4^2 + cy4^2);

L1Ang = data_in.([side2 '_L1Ang']);
L2Ang = data_in.([side2 '_L2Ang']);
L1Vel = data_in.([side2 '_L1Vel']);
L2Vel = data_in.([side2 '_L2Vel']);
L1Acc = data_in.([side2 '_L1Acc']);
L2Acc = data_in.([side2 '_L2Acc']);


theta2_1 = L2Ang - L1Ang;
theta5_1 = theta2_1 - delta;
sin21 = sin(theta2_1);
cos21 = cos(theta2_1);
sin51 = sin(theta5_1);
cos51 = cos(theta5_1);

A = I1_prox + I4_prox + Im1 + M2*L1^2;
B = M2*L1*(cx2*cos21 - cy2*sin21) + M4*L3*(cx4*cos51 + cy4*sin51);
C = M2*L1*(cx2*sin21 + cy2*cos21) + M4*L3*(cx4*sin51 - cy4*cos51);
D = I2_prox + I3_prox + Im2 + M4*L3^2;

% 	M = [A B; B D];	%inertial matrix
% 	CC = [0 -C; C 0];	%coriolis and centripetal forces
T1 = A * L1Acc + B .* L2Acc - C .* L2Vel.^2;
T2 = B .* L1Acc + D * L2Acc + C .* L1Vel.^2;



