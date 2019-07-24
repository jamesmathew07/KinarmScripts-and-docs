function data_out = KINARM_add_friction(data_in, u, B)
%KINARM_ADD_FRICTION Estimate KINARM robot friction.
%	DATA_OUT = KINARM_ADD_FRICTION(DATA_IN, u, B)
%	adds estimates of friction (including viscous damping) to the DATA_IN
%	structure. Friction ('u') and viscous damping ('B') coefficients must
%	be supplied as input arguments to this function, otherwise friction
%	will not be added.   
%
%	The input structure DATA_IN	should be of the form produced by 
%	DATA_IN = ZIP_LOAD. ex.
%
%   data = zip_load('183485624_2010-09-21_11-26-21.zip')
%   out = KINARM_add_friction(data.c3d(3), 0.06, 0.0025)
%
%   If the data is in Dexterit-E 2.3 or earlier format then the usage would
%   be:
%
%   data = c3d_load('Subject, Test_2879_1_N_tm_8_3_1.c3d')
%   out = KINARM_add_friction(data, 0.06, 0.0025)
%
%
%   The inputs u and B can be either scalars or vectors of length 2 or 4.
%   If they are scalar, then the values will be used for both joints on
%   both arms.  If they are vectors of length 2, then u(1) and B(1) will be
%   applied to motor 1 (M1) for each arm and u(2) and B(2) will be applied
%   to motor 2 (M2) for each arm (where M1 applies torque to L1 and M2
%   applied torque to L2).  If they are  vectors of length 4, then u(1)
%   through u(4) and B(1) through B(4)will be applied to Right_M1,
%   Right_M2, Left_M1 and Left_M2 respectively.   
%
%	u must be in units of Nm and B must be in units of
%	Nm/(rad/s).  Although every  robot has slightly different friction
%	coeffecients, typical values are:
%     KINARM Exoskeleton Classic - KINARM_ADD_FRICTION(DATA_IN, 0.12, 0.0009)
%     Human KINARM Exoskeleton   - KINARM_ADD_FRICTION(DATA_IN, 0.15, 0.0014)
%     KINARM End-Point           - KINARM_ADD_FRICTION(DATA_IN, 0.18, 0.0020)
%
%	The combined effects of friction plus viscosity are calculated for each
%	motor/segment (M1/L1 and M2/L2) of the KINARM robot and stored as new
%	fields in the DATA_OUT structure.  The new fields are in units of Nm,
%	in a global coordinate system (as per Right_M1TorCMD etc) and are: 
%		.Right_M1TorFRC
%		.Right_M2TorFRC
%		.Left_M1TorFRC
%		.Left_M2TorFRC
%

data_out = data_in;

if isempty(data_in)
	return
end

if ~exist('u', 'var') || ~exist('B', 'var')
	error('WARNING: friction and/or viscosity was not specified.  Friction and viscosity cannot be added');
end

if ~(length(u)==1 || length(u)==2 || length(u)==4 )
	error('WARNING: length of friction input incorrect.  Friction and viscosity cannot be added');
end

if ~(length(B)==1 || length(B)==2 || length(B)==4 )
	error('WARNING: length of viscosity input incorrect.  Friction and viscosity cannot be added');
end

%expand u and/or B to be 1x4 if needed
if length(u) == 1
	u = u * [1 1 1 1];
elseif length (u) == 2
	u = reshape([u u],1,4);
end

if length(B) == 1
	B = B * [1 1 1 1];
elseif length (B) == 2
	B = reshape([B B],1,4);
end

for ii = 1:length(data_in)
	%Right hand first.  Check to see if there is right hand data.
	if isfield(data_in(ii), 'Right_L1Vel');
		v = data_in(ii).Right_L1Vel;
		% tanh(100*v) is a reasonable model of friction
		data_out(ii).Right_M1TorFRC = -u(1)*tanh(100*v) - B(1)*v;
		v = data_in(ii).Right_L2Vel;
		% tanh(100*v) is a reasonable model of friction
		data_out(ii).Right_M2TorFRC = -u(2)*tanh(100*v) - B(2)*v;
	end
	if isfield(data_in(ii), 'Left_L1Vel');
		v = data_in(ii).Left_L1Vel;
		% tanh(100*v) is a reasonable model of friction
		data_out(ii).Left_M1TorFRC = -u(3)*tanh(100*v) - B(3)*v;
		v = data_in(ii).Left_L2Vel;
		% tanh(100*v) is a reasonable model of friction
		data_out(ii).Left_M2TorFRC = -u(4)*tanh(100*v) - B(4)*v;
	end
end

%re-order the fieldnames so that the friction forces are with the motor torques
orig_names = fieldnames(data_in);
right_hand_names = {'Right_M1TorFRC'; 'Right_M2TorFRC'};
left_hand_names = {'Left_M1TorFRC'; 'Left_M2TorFRC'};
%Before re-arranging them, check to see if they existed in the original
%data_in structure, in which case do NOT re-arrange
if ~isempty(strmatch('Right_L1Vel', orig_names, 'exact')) && isempty(strmatch(right_hand_names{1}, orig_names, 'exact'))
	index = max(strmatch('Right_M2TorCMD', orig_names));
	new_names = cat(1, orig_names(1:index), right_hand_names, orig_names(index+1:length(orig_names)));
else
	new_names = orig_names;
end
if ~isempty(strmatch('Left_L1Vel', orig_names, 'exact')) && isempty(strmatch(left_hand_names{1}, orig_names, 'exact'))
	index = max(strmatch('Left_M2TorCMD', new_names));
	new_names = cat(1, new_names(1:index), left_hand_names, new_names(index+1:length(new_names)));
end

data_out = orderfields(data_out, new_names);

disp('Finished adding KINARM robot friction');

