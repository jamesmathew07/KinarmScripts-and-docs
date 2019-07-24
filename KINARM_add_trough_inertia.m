function data_out = KINARM_add_trough_inertia(data_in, varargin)

%KINARM_ADD_TROUGH_INERTIA Add trough inertia to KINARM robot inertia.
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN...) adds two new fields
%	(.RIGHT_KINARM_TROUGHS and .LEFT_KINARM_TROUGHS) to the DATA_IN
%	structure.  These two new fields contain an estimate of the inertial
%	properties of the arm troughs  (or anything else added to the KINARM
%	robot, such as a handle).  These fields are used by	KINARM_ADD_TORQUES
%	to estimate applied and intramuscular torques.   
% 
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN..., 'trough_db', TROUGH_DB, ...)
% 	Use TROUGH_DB as a database containing the inertial parameters of the arm
% 	troughs, such as mass, CofM.  TROUGH_DB should be created by calling
% 	KINARM_CREATE_TROUGH_DATABASE, which can be modified to create custom
% 	databases (e.g. if a custom handle was used with the KINARM robot).  
% 
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN..., 'trough_size', TROUGH_SIZE, ...)
% 	TROUGH_SIZE should either the string 'estimate' or a structure
% 	whose fields are identical to the fields of TROUGH_DB and whose values
% 	are equal to one of the sub-fields for each of TROUGH_DB's fields.  For
% 	example, if TROUGH_DB had the fields: .UA, .FA and .H, each of which had
% 	subfield .SML and .LRG, then TROUGH_SIZE must have the fields .UA, .FA and
% 	.H. and values 'SML' or 'LRG', such as:
% 
% 	TROUGH_SIZE = 
% 			UA: 'SML'
% 			FA: 'LRG'
% 			 H: 'SML'
% 
% 	If TROUGH_SIZE == 'estimate', then an estimate of trough size is made
% 	based on information in TROUGH_DB and the subject's mass and height.  See
% 	KINARM_CREATE_TROUGH_DATABASE for the required information in TROUGH_DB.
% 	Subject mass and height are either extracted on a per-trial basis from
% 	DATA_IN, or are provided via optional 'mass' and 'height' inputs (see
% 	below). 
% 
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN..., 'trough_location', TROUGH_LOCATION, ...)
% 	TROUGH_LOCATION should either the string 'estimate' or a structure whose
% 	fields are identical to the fields of TROUGH_DB and whose values are
% 	equal to location of the trough-index mark relative to the proximal joint
% 	(units of meters).  For example, if TROUGH_DB had the fields: .UA, .FA and .H, then
% 	TROUGH_LOCATION must have the fields .UA, .FA and .H. as well, containing
% 	numeric values, such as:   
% 
% 	TROUGH_LOCATION = 
% 			UA: 0.01
% 			FA: 0.15
% 			 H: 0.25
% 
% 	If TROUGH_LOCATION == 'estimate', then the input ESTIMATE_L2 can be
% 	provided, as per: 
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN..., 'trough_location', 
%   TROUGH_LOCATION, 'estimate_L2', ESTIMATE_L2 ...)  If ESTIMATE_L2 == true, 
%   then the length of L2 is estimated from the	length of L1, which is 
%   extracted on a per-trial basis from DATA_IN. If ESTIMATE_L2 == false or
% 	is not provided then L2 is extracted from DATA_IN.  L1 and L2 are then 
%   used with information in TROUGH_DB to estimate trough location.  See
% 	KINARM_CREATE_TROUGH_DATABASE for the required information in TROUGH_DB.
% 
% 	Differences between the anatomical length of L2 and the calibrated length
% 	can arise, for example,  if a subject chose to use their knuckle as
% 	feedback cursor position rather than their fingertip, or if a handle was
% 	grasped rather than arm troughs. 
% 
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN..., 'mass', MASS, ...)
% 	If TROUGH_SIZE == 'estimate', then an optional 'mass' input can be
% 	provided such that MASS is used to estimate trough_size rather than the
% 	mass stored in DATA_IN.  MASS should be in kg.
% 
% 	DATA_OUT = KINARM_ADD_TROUGH_INERTIA(DATA_IN..., 'height', HEIGHT, ...)
% 	If TROUGH_SIZE == 'estimate', then the optional 'height' input can be
% 	provided such that HEIGHT is used to estimate trough_size rather than the
% 	height stored in DATA_IN.  HEIGHT should be meters.
%
%	The input structure DATA_IN	should be of the form produced by 
%	DATA_IN = ZIP_LOAD. ex.
%
%   data = zip_load('183485624_2010-09-21_11-26-21.zip')
%   out = KINARM_add_trough_inertia(data.c3d(3), ...)
%
%   If the data is in Dexterit-E 2.3 or earlier format then the usage would
%   be:
%
%   data = c3d_load('Subject, Test_2879_1_N_tm_8_3_1.c3d')
%   out = KINARM_add_trough_inertia(data, ...)
%

data_out = data_in;			%default

if isempty(data_in)
	return
end

%check out varargin to ensure that they are valid
x = 1;
input_mass = [];		%default, indicating the input_mass 
input_height = [];		%default
estimate_L2 = false;	%default

while x <= length(varargin)
	if strncmpi(varargin{x}, 'trough_db', 9)
		x = x + 1;
		if length(varargin) >= x && isstruct(varargin{x})
			trough_db = varargin{x};
		else
			error('---> The value of trough_db was either not provided or is not a structure.');
		end
	elseif strncmpi(varargin{x}, 'trough_size', 11)
		x = x + 1;
		if length(varargin) >= x
			trough_size = varargin{x};
		else
			error('---> The value of trough_size was not provided.');
		end
	elseif strncmpi(varargin{x}, 'trough_location', 15)
		x = x + 1;
		if length(varargin) >= x
			trough_location = varargin{x};
		else
			error('---> The value of trough_location was not provided.');
		end
	elseif strncmpi(varargin{x}, 'mass', 4)
		x = x + 1;
		if length(varargin) >= x && isnumeric(varargin{x})
			input_mass = varargin{x};
		else
			error('---> The value of the mass was either not provided or was not numeric.');
		end
	elseif strncmpi(varargin{x}, 'height', 6)
		x = x + 1;
		if length(varargin) >= x && isnumeric(varargin{x})
			input_height = varargin{x};
		else
			error('---> The value of the height was either not provided or was not numeric.');
		end
	elseif strncmpi(varargin{x}, 'estimate_L2', 11)
		x = x + 1;
		if length(varargin) >= x && islogical(varargin{x})
			estimate_L2 = varargin{x};
		else
			error('---> The value of estimate_L2 was either not provided or was not logical (i.e. do not use quotes around true or false).');
		end
	end
	x = x + 1;
end

if ~exist('trough_db', 'var')
	error('---> The required input trough_db was not provided');
end
if ~exist('trough_size', 'var')
	error('---> The required input trough_size was not provided');
end
if ~exist('trough_location', 'var')
	error('---> The required input trough_location was not provided');
end

% Once all of the varargin are collected, ensure that trough_size and
% trough_location are valid.  
% get the trough types listed in the database.
trough_types = fieldnames(trough_db);

% determine if trough_size was provided or is to be guessed
guess_size = false;		%default value
if ischar(trough_size) && strcmp(trough_size, 'estimate')
	guess_size = true;		%Trough size is to be guessed
elseif isstruct(trough_size)
	%if trough_size is provided, ensure that it is a structure containing
	%the required fields (i.e. the trough_types)
	size_fields = fieldnames(trough_size);
	for ii = 1:length(trough_types)
		if isempty(strmatch(trough_types{ii}, size_fields, 'exact'))
			error(['---> TROUGH_SIZE input structure is missing trough_type field ''.' trough_types{ii} '''.']);
		end
	end
else 
		error('---> TROUGH_SIZE input must be the string ''estimate'' or a structure.');
end



% determine if trough_location was provided or is to be estimated
estimate_location = false;		%default value
if ischar(trough_location) && strcmp(trough_location, 'estimate')
	estimate_location = true;		%trough location is to be estimated
elseif isstruct(trough_location)
	% if a structure was passed for trough_location, check to see that it
	% has the correct fields and valid values for those fields.	location_fields = fieldnames(trough_location);
	location_fields = fieldnames(trough_location);
	for ii = 1:length(trough_types)
		if isempty(strmatch(trough_types{ii}, location_fields, 'exact'))
			error(['---> TROUGH_LOCATION input structure is missing trough_type field ''.' trough_types{ii} '''.']);
		end
	end
else 
	error('---> TROUGH_LOCATION input must be the string ''estimate'' or a structure.');
end


% check trough_db to ensure that each trough_type has the
% necessary fields (i.e, .segment).  Then check each
% trough_type for the necessary sub-fields (.M, .I, etc).
for ii = 1:length(trough_types)
	if ~isfield(trough_db.(trough_types{ii}), 'segment')  
		error(['---> Error in input parameter TROUGH_DB.  Trough type .' trough_types{ii} ' is missing subfield .segment.  Trough inertias cannot be added. ']);
	end
	segment = trough_db.(trough_types{ii}).segment;
	if isempty(segment) || isempty(strmatch(segment, {'L1', 'L2', 'L3', 'L4'}, 'exact'))
		error(['---> Error in input parameter TROUGH_DB.  Value of trough_db.' trough_types{ii} '.segment is not valid.  Must be ''L1'', ''L2'', ''L3'' or ''L4''.  Trough inertias cannot be added.']);
	end

	% get the names of all trough sizes, which is assumed to be all fields
	% other than .segment and .location_est
	trough_sizes = fieldnames(trough_db.(trough_types{ii}));
	trough_sizes(strmatch('segment', trough_sizes, 'exact')) = [];
	trough_sizes(strmatch('location_est', trough_sizes, 'exact')) = [];
	
	% make sure that all trough sizes have valid .M, .I, .C_AXIAL and
	% .C_ANTERIOR subfields
	for jj = 1:length(trough_sizes)
		if sum( ~isfield(trough_db.(trough_types{ii}).(trough_sizes{jj}),{'M', 'I', 'C_AXIAL', 'C_ANTERIOR'}) )
			error(['---> Error in input parameter TROUGH_DB.  troughdb.' trough_types{ii} '.' trough_sizes{jj} ' is missing one of the required subfields: .M, .I, .C_AXIAL and/or .C_ANTERIOR.  Trough inertias cannot be added.']);
		end
		M = trough_db.(trough_types{ii}).(trough_sizes{jj}).M;
		I = trough_db.(trough_types{ii}).(trough_sizes{jj}).I;
		C_AXIAL = trough_db.(trough_types{ii}).(trough_sizes{jj}).C_AXIAL;
		C_ANTERIOR = trough_db.(trough_types{ii}).(trough_sizes{jj}).C_ANTERIOR;
		if isempty(M) || ~isnumeric(M) || length(M) > 1
			error(['---> Error in input parameter TROUGH_DB.  Value of trough_db.' trough_types{ii} '.' trough_sizes{jj} '.M is not valid.  Trough inertias cannot be added.']);
		end
		if isempty(I) || ~isnumeric(I) || length(I) > 1
			error(['---> Error in input parameter TROUGH_DB.  Value of trough_db.' trough_types{ii} '.' trough_sizes{jj} '.I is not valid.  Trough inertias cannot be added.']);
		end
		if isempty(C_AXIAL) || ~isnumeric(C_AXIAL) || length(C_AXIAL) > 1
			error(['---> Error in input parameter TROUGH_DB.  Value of trough_db.' trough_types{ii} '.' trough_sizes{jj} '.C_AXIAL is not valid.  Trough inertias cannot be added.']);
		end
		if isempty(C_ANTERIOR) || ~isnumeric(C_ANTERIOR) || length(C_ANTERIOR) > 1
			error(['---> Error in input parameter TROUGH_DB.  Value of trough_db.' trough_types{ii} '.' trough_sizes{jj} '.C_ANTERIOR is not valid.  Trough inertias cannot be  added.']);
		end
	end
end					%end for loop 



%for each trial, add the trough_inertia
for ii = 1:length(data_in)
	if guess_size
		trough_size = guess_trough_size(data_in(ii), trough_db, input_mass, input_height);
	end
	%add inertias for right KINARM robot
	if isfield(data_in(ii), 'RIGHT_KINARM');
		if estimate_location && isfield(data_in(ii).CALIBRATION, 'RIGHT_L1')
			% Only KINARM Exoskeletons have the 'RIGHT_L1' field, and it is necessary for estimating trough location
			trough_location = estimate_trough_location(data_in(ii), trough_db, 'RIGHT', estimate_L2);
		else
				error( '---> Estimate trough location is only valid for KINARM Exoskeleton.' );
		end
		inertias = estimate_trough_inertias(trough_db, trough_size, trough_location);
		data_out(ii).RIGHT_KINARM_TROUGHS = inertias;
	end
	%add inertias for left KINARM  robot
	if isfield(data_in(ii), 'LEFT_KINARM');
		if estimate_location && isfield(data_in(ii).CALIBRATION, 'LEFT_L1');
			% Only KINARM Exoskeletons have the 'LEFT_L1' field, and it is necessary for estimating trough location
			trough_location = estimate_trough_location(data_in(ii), trough_db, 'LEFT', estimate_L2);
		else
			error( '---> Estimate trough location is only valid for KINARM Exoskeleton.' );
		end
		inertias = estimate_trough_inertias(trough_db, trough_size, trough_location);
		data_out(ii).LEFT_KINARM_TROUGHS = inertias;
	end
end
%re-order the fieldnames so that the hand velocity and acceleration are
%with the hand position at the beginning of the field list
orig_names = fieldnames(data_in);
right_names = {'RIGHT_KINARM_TROUGHS'};
left_names = {'LEFT_KINARM_TROUGHS'};
%Before re-arranging them, check to see if they existed in the original
%data structure, in which case do NOT re-arrange
if ~isempty(strmatch('RIGHT_KINARM', orig_names, 'exact')) && isempty(strmatch(right_names{1}, orig_names, 'exact'))
	index = strmatch('RIGHT_KINARM', orig_names, 'exact');
	new_names = cat(1, orig_names(1:index), right_names, orig_names(index+1:length(orig_names)));
else
	new_names = orig_names;
end
if ~isempty(strmatch('LEFT_KINARM', orig_names, 'exact')) && isempty(strmatch(left_names{1}, orig_names, 'exact'))
	index = strmatch('LEFT_KINARM', new_names, 'exact');
	new_names = cat(1, new_names(1:index), left_names, new_names(index+1:length(new_names)));
end
whos data_out new_names
data_out = orderfields(data_out, new_names);

disp('Finished adding KINARM robot arm trough inertias');



%%
% Guess which trough size to use, based on subject  mass and height
function trough_size_out = guess_trough_size(data_trial_in, trough_db, input_mass, input_height)
	% Guess which trough Add the trough inertia 
	if isempty(input_mass)
		subject_mass = data_trial_in.EXPERIMENT.WEIGHT;			%kg
	else
		subject_mass = input_mass;							%kg
	end
	if subject_mass <= 0
		error('---> Subject mass was <=0, therefore cannot guess which arm trough was used from body index.  Trough inertia not estimated.');
	end
	if isempty(input_height) 
		subject_height = data_trial_in.EXPERIMENT.HEIGHT;			%m
        if subject_height > 100
            subject_height = subject_height / 100; %convert to m
        end
	else
		subject_height = input_height;							%kg
	end
	if subject_height <= 0
		error('---> Subject_height was <=0, therefore cannot guess which arm trough was used from body index.  Trough inertia not estimated.');
	end
	body_index = subject_mass / subject_height;
	trough_types = fieldnames(trough_db);
	% for each trough_type, guess the size and store it in the output structure
	for ii = 1:length(trough_types)
		% get the names of all trough sizes, which is assumed to be all fields
		% other than .segment and .location_est
		trough_sizes = fieldnames(trough_db.(trough_types{ii}));
		trough_sizes(strmatch('segment', trough_sizes, 'exact')) = [];
		trough_sizes(strmatch('location_est', trough_sizes, 'exact')) = [];

		%the following guesses which size to use based on the 'body_index'
		min_body_indices = zeros(size(trough_sizes));
		for jj = 1:length(trough_sizes)
			min_body_indices(jj) = trough_db.(trough_types{ii}).(trough_sizes{jj}).body_index_min;
		end
		possible_sizes = min_body_indices( body_index >= min_body_indices );
		if ~isempty(possible_sizes)
			trough_size_out.(trough_types{ii}) = trough_sizes{ max(possible_sizes) == min_body_indices  };
		else
			error(['No trough sizes are specified for the body_index from subject mass ' num2str(subject_mass) 'kg and subject height ' num2str(subject_height) 'm.'])
		end		%end testing for which size
	end
	

%%
% Estimate trough location based on L2 and L1.
function trough_location_out = estimate_trough_location(data_trial_in, trough_db, side, estimate_L2)
	% estimate trough locations
	L1 = data_trial_in.CALIBRATION.([side '_L1']);
	if estimate_L2
		L2 = 1.37 * L1;				%Estimate forearm+hand length (L2) from upper arm length (L1).  From Winters, page 48
	else
		L2 = data_trial_in.CALIBRATION.([side '_L2']);
	end
	% trough_db must have a .location_est that contains a 1x4 vector for
	% estimating trough location based on L1 and L2 lengths
	trough_types = fieldnames(trough_db);
	for ii = 1:length(trough_types)
		if ~isfield(trough_db.(trough_types{ii}), 'location_est')  
			error(['---> Error in input parameter TROUGH_DB.  Trough type .' trough_types{ii} ' is missing subfields .segment and/or .location_est.  Trough inertias cannot be added. ']);
		end
		location_est = trough_db.(trough_types{ii}).location_est;
		if isempty(location_est) || ~isnumeric(location_est) || length(location_est)~= 4
			error(['---> Error in input parameter TROUGH_DB.  Value of trough_db.' trough_types{ii} '.location_est is not valid.  Must be a 1x4 numeric vector.  Trough inertias cannot be added.']);
		else
			trough_location_out.(trough_types{ii}) = dot(location_est, [L1 1 L2 1]);
		end
	end


	
%%
% Estimate the trough inertia (total for all trough types) 
function total_inertia = estimate_trough_inertias(trough_db, trough_size, trough_location)
trough_types = fieldnames(trough_db);
total_inertia.L1_M = 0;				%for KINARM_combine_inertias to function correctly, total_inertia cannot be empty
for ii = 1:length(trough_types)
	clear inertia;					%clear inertia so that it starts out empty
	inertia.L1_M = 0;				%for KINARM_combine_inertias to function correctly, inertia cannot be empty
	segment = trough_db.(trough_types{ii}).segment;
	size = trough_size.(trough_types{ii});  
	if ~isfield(trough_db.(trough_types{ii}), size)
		error(['---> Error.  The specified trough size ''' size ''' was not found in the trough database for ''trough_db.' trough_types{ii} '''.']);
	end
	inertia.([segment '_M']) = trough_db.(trough_types{ii}).(size).M;
	inertia.([segment '_I']) = trough_db.(trough_types{ii}).(size).I;
	inertia.([segment '_C_AXIAL']) = trough_db.(trough_types{ii}).(size).C_AXIAL + trough_location.(trough_types{ii});
	inertia.([segment '_C_ANTERIOR']) = trough_db.(trough_types{ii}).(size).C_ANTERIOR;
	total_inertia = KINARM_combine_inertias(total_inertia, inertia);
end					%end for loop 
% Add fields for each trough_type, and put the size as its value
for ii = 1:length(trough_types)
	total_inertia.(trough_types{ii}) = trough_size.(trough_types{ii});
end					%end for loop 


