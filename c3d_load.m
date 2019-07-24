function c3dstruct = c3d_load(varargin)

%C3D_LOAD Load and format c3d files.
%   C3D_DATA = C3D_LOAD opens all .c3d files in the current directory and
%   outputs the data into the C3D_DATA structure.
%
%   C3D_DATA is a structured array, each element of which corresponds to a
%   single .c3d file.  The fields of the structure are of two types: 
%   time-varying data or a c3d Parameter Group.  Time-varying data are
%   vectors of data corresponding to the field name.  Details of the time
%   varying data can be found in the related Parameter Group.  The
%   Parameter Group fields have sub-fields of their own, most of which are
%   specific to each Parameter Group.
% 
%   C3D_DATA = C3D_LOAD(FILENAME) opens FILENAME and
%   outputs the data into the C3D_DATA structure.  FILENAME can contain the
%   '*' wildcard.
% 
%   C3D_DATA = C3D_LOAD(FILENAME1, FILENAME2) opens FILENAME1 and FILENAME2
%   and outputs the data into the C3D_DATA structure.  FILENAME1 and
%   FILENAME2 can both contain the % '*' wildcard.  Any number of filenames
%   can be listed.  
% 
%   C3D_DATA = C3D_LOAD('dir', DIRECTORY) looks for all .c3d files in
%   DIRECTORY.
% 
%   C3D_DATA = C3D_LOAD('ignore', IGNORE) removes data fields containing
%   the IGNORE string from the C3D_DATA structure.  IGNORE can either be a 
%   string, or a cell array of strings.  This command is case insensitive.
%   The special string 'PARAMETERS' can be used to ignore the c3d PARAMETER
%   groups (i.e. all Parameter Groups will be removed from the C3D_DATA
%   structure)
% 
%   C3D_DATA = C3D_LOAD('keep', KEEP) only keeps those data fields
%   containing the KEEP string in the C3D_DATA structure.  KEEP can either
%   be a string, or a cell array of strings.  This command is case
%   insensitive.  The special string 'PARAMETERS' can be used to keep all
%   of the c3d PARAMETER Groups (i.e. all Parameter Groups will be kept in
%   the C3D_DATA structure)
% 
%   The above arguments can be combined in any combination and/or order,
%   except for the 'ignore' and 'keep' arguments - both may not be present.
%   For example, 
%   C3D_DATA = C3D_LOAD(FILENAME1, 'dir', DIRECTORY, FILENAME2,...
%   'keep',{'right', 'PARAMETERS') will load up the files FILENAME1 and
%   FILENAME2 in the directory DIRECTORY, and will keep all data fields
%   with the string 'right' in the field name and will keep all of the c3d
%   Parameter Groups.


% Written by Jon Swaine on December 14, 2005 for LIMB
% Queen's University, Kingston, ON, Botterell Hall.

% Modified by Ian Brown for BKIN Technologies, Kingston, ON.  July 17, 2007
% Spaces and dashes in Parameter Names have been replaced with '_' to make
% them valid as a name for a structure field.
%
% Parameters are no longer fields of the main 'c3dstruct' structure.  Instead,
% parameter groups are fields of the main structure, and parameters are
% sub-fields within each parameter group's field.
%
% Cleaned up Event times to have only one number per event instance
%
% Renamed 'POINT' ParameterGroup to 'HAND' parametergroup to be more
% descriptive of KINARM data collected by Dexterit-E 
%
% Only ParameterGroups that contain parameters are added to the final
% structure (i.e. USED > 0).  This eliminates the FORCE_PLATFORM group etc.

% Aug, 2007.  Brackets in Parameter Names are replaced with '_' to make them
% valid as field names

% Aug, 2007.  Parameter groups that do not have a 'DESCRIPTIONS' Parameter
% now have one created for them that grabs the descriptions from the
% parameters.

% Nov, 2008.  Valid field names (i.e. cannot begin with numeric or
% underscore) are now forced for genvarname function 

% June, 2009.  Function updated to reflect re-naming of
% c3d_load_single_file.m 

% Aug, 2009.  Events from new NER section over-write any other events.
% Range data from NER section are added as VIDEO_LATENCY field

% Nov 2011.  Added check to see if descritption is sub-field before
% checking to see if it was empty and creating DESCRIPTIONTEXT

x = 1;
num_files = 0;
% Save old directory
olddir = cd;

to_ignore = [];
to_keep = [];

while x <= length(varargin)
    % See if the user included a directory to look in
    if strncmpi(varargin{x}, 'dir', 3)
        x = x + 1;
        cd(varargin{x});
    elseif strncmpi(varargin{x}, 'ignore', 6)
        x = x + 1;
        to_ignore = varargin{x};   
    elseif strncmpi(varargin{x}, 'keep', 4)
        x = x + 1;
        to_keep = varargin{x};   
	else
		num_files = num_files + 1;
		c3dfiles{num_files} = varargin{x};
    end
    x = x + 1;
end


if num_files > 0
	% check for '*' wild card in filename - expand file list if it exists
	for ii = num_files:-1:1
		if ~isempty(findstr('*', c3dfiles{ii}))
			temp = dir(c3dfiles{ii});
			c3dfiles = [c3dfiles {temp.name}];
			%erase the filename with the wildcard
			c3dfiles(ii) = [];		
		end
	end
	num_files = length(c3dfiles);
	if num_files == 0
		disp(strvcat(' ','WARNING!!!  No c3d files found.'));
		c3dstruct = [];
		return;
	end
else
	% Get all c3d files
	c3dfiles = dir('*.c3d');
	if isempty(c3dfiles)
		disp(strvcat(' ','WARNING!!!  No c3d files found in:', pwd));
		c3dstruct = [];
		return;
	end
	c3dfiles = {c3dfiles.name};
end

if ~isempty(to_ignore) && ~isempty(to_keep)
    disp('You can only specify the params/signals to keep OR to ignore, not both.');
    return;
else
	if ~iscell(c3dfiles)
		c3dfiles = {c3dfiles};
	end

	% Read in each c3d file and organize into structure
	for x = 1:length(c3dfiles)

		c3d = c3d_load_single_file(c3dfiles{x});
		
		%check if data was loaded, otherwise proceed to next file
		if isempty(c3d.FileName)
			continue;				
		end
		
		load_parameters = 1;		%default is to load the c3d parameters
		% Get hand data
		c3dstruct(x).Right_HandX = c3d.Hand.RightX;
		c3dstruct(x).Right_HandY = c3d.Hand.RightY;
		c3dstruct(x).Left_HandX = c3d.Hand.LeftX;
		c3dstruct(x).Left_HandY = c3d.Hand.LeftY;
		
		% Get analog and kinematic signals
		indANA = find(strcmpi([c3d.ParameterGroup.name], 'Analog'));
		indLAB = find(strcmpi([c3d.ParameterGroup(indANA).Parameter.name], 'Labels'));
		% Get analog signal names and attach them to the analog signal data
		% (they are in the same order in the Parameters that they are in the
		% data matrix).
		sig_names = c3d.ParameterGroup(indANA).Parameter(indLAB).data;
		
		for y = 1:length(sig_names)
			c3dstruct(x).(sig_names{y}) = c3d.AnalogSignals(:, y);
		end

		%keep only those data fields requested
		if ~isempty(to_keep)
			if ~iscell(to_keep)
				to_keep = {to_keep};
			end
			fnames = fieldnames(c3dstruct);
			for ii = 1:length(fnames)
				%for each field, check if it contains any of the 'keep'
				%expressions 
				if isempty( cell2mat( regexp(upper(fnames{ii}), upper(to_keep)) ) )
					c3dstruct = rmfield(c3dstruct, fnames{ii});
				end
			end
			load_parameters = ~isempty( cell2mat( regexp('PARAMETERS', upper(to_keep)) ) );
		end
		
		%remove those data fields requested
		if ~isempty(to_ignore)
			if ~iscell(to_ignore)
				to_ignore = {to_ignore};
			end
			fnames = fieldnames(c3dstruct);
			for ii = 1:length(fnames)
				%for each field, check if it contains any of the 'ignore' expressions 
				if ~isempty( cell2mat( regexp(upper(fnames{ii}), upper(to_ignore)) ) )
					c3dstruct = rmfield(c3dstruct, fnames{ii});
				end
			end
			load_parameters = isempty( cell2mat( regexp('PARAMETERS', upper(to_ignore)) ) );
		end
		
		if load_parameters ==1;
			% Go through all parameters and add them to structure, but ONLY if
			% the USED parameter for the Group is > 0
			AllParamGroupNames = [c3d.ParameterGroup.name];
			for y = 1:length(AllParamGroupNames)
				add_ParamGroup = 1;		%default value....
                
                if isempty(c3d.ParameterGroup(y).Parameter)  % Case added by Bretzke to push through Dex3.5 Beta testing (2015-01-14)
                   add_ParamGroup = 0;
                   disp(['Parameter group ' c3d.ParameterGroup(y).name ' is empty.']) 
                else                
                    %is there a 'USED' parameter, and if so is it > 0?
                    USEDindex = strmatch('USED', [c3d.ParameterGroup(y).Parameter.name]);
                    if ~isempty(USEDindex)					
                        if c3d.ParameterGroup(y).Parameter(USEDindex).data == 0
                            add_ParamGroup = 0;		%do not add this Parameter Group
                        end
                    end
                end

				%add the ParameterGroup if USED > 0 (or if there is no 'USED'
				%parameters)
				if add_ParamGroup == 1
					ParamGroupName = c3d.ParameterGroup(y).name{1};

					clear DESCRIPTIONTEXT;		%clear this cell array before adding to it

					%rename the 'POINT' ParameterGroup to 'HAND'
					if strcmp(ParamGroupName, 'POINT')
						ParamGroupName = 'HAND';
					end
					
					for z = 1:length([c3d.ParameterGroup(y).Parameter.name])
                        
                        if ~iscell(c3d.ParameterGroup(y).Parameter(z).name)
                            continue
                        end
						ParameterName = [c3d.ParameterGroup(y).Parameter(z).name{1}];

						%replace all dashes and spaces with '_' for valid field name
						spaces = strfind(ParameterName, ' ');
						dashes = strfind(ParameterName, '-');
						fslashes = strfind(ParameterName, '\');
						bslashes = strfind(ParameterName, '/');
						fbracket = strfind(ParameterName, '(');
						bbracket = strfind(ParameterName, ')');
						f2bracket = strfind(ParameterName, '[');
						b2bracket = strfind(ParameterName, ']');
						ParameterName([spaces dashes fslashes bslashes fbracket bbracket f2bracket b2bracket]) = '_';			
						
						%add 'a_' if the first character is numeric to make it a valid field name
						%if str2num(ParameterName(1))
						%	ParameterName = ['a_' ParameterName];
						%end

						%ensure the ParameterName is a valid field name
						%(i.e. does not begin with numeric or underscore)
						ParameterName = genvarname(ParameterName);
						
						%if data is singleton cell array, remove cell array structure	
                        if ~isfield(c3d.ParameterGroup(y).Parameter(z), 'data')
                            c3d.ParameterGroup(y).Parameter(z).data = [];
                        end
						data = c3d.ParameterGroup(y).Parameter(z).data;
						if iscell(data) && length(data) == 1
							c3dstruct(x).(ParamGroupName).(ParameterName) = data{1};
						else
							c3dstruct(x).(ParamGroupName).(ParameterName) = data;
						end

						%create cell array of Parameter descriptions,
						%which is text that includes the ParameterName
%                         try%!!!!
% 							description = c3d.ParameterGroup(y).Parameter(z).description{1};
%                         catch
% 							description = '';
%                         end
						if isfield(c3d.ParameterGroup(y).Parameter(z), 'description') && ~isempty(c3d.ParameterGroup(y).Parameter(z).description)
							description = c3d.ParameterGroup(y).Parameter(z).description{1};
						else
							description = '';
						end
						DESCRIPTIONTEXT(z) = {[ParameterName ' -- ' description]};
					
					end

					%Nominally, Parameter descriptions are not passed on to
					%the final c3dstruct because in those cases the
					%parameters are self-explanatory (e.g. 'UNITS',
					%'DATA').  However, for some ParameterGroups, the data
					%are self-explanatory, and instead it is the Parameters
					%that are not.  In those cases, there is no Parameter
					%called DESCRIPTIONS, so in those cases the description
					%of each Parameter needs to be passed on.
					DESCRIPTIONindex = strmatch('DESCRIPTIONS', [c3d.ParameterGroup(y).Parameter.name], 'exact');
					if isempty(DESCRIPTIONindex)
						c3dstruct(x).(ParamGroupName).DESCRIPTIONS = DESCRIPTIONTEXT;
					end
					
				end
			end

			%clean up event times.  Event times from Dexterit-E do not use the
			%first number of the two numbers stored for each event
			if isfield(c3dstruct(x), 'EVENTS') && ~isempty(c3dstruct(x).EVENTS)
				if size(c3dstruct(x).EVENTS.TIMES,1) == 2 
					c3dstruct(x).EVENTS.TIMES(1,:) = [];
				end
			end
			
			%Check to see if events exist in the new Events and Ranges
			%section.  If so, then over-write any other events.
			if ~isempty(c3d.NEREvents)
				c3dstruct(x).EVENTS = c3d.NEREvents;
			end	
			
			%Check to see if ranges exist in the new Events and Ranges
			%section.  If a Ranges section exists, then check if any have
			%'Video Frame' as the first part of the Label.  If so, then we
			%will assume that these have been used for recording the
			%confirmation of video display and that the start/stop times
			%were explicitly recorded, so those data are copied to a new
			%VIDEO_LATENCY field.  All other range information is copied to
			%a Ranges field. 
			if ~isempty(c3d.NERRanges)
				Video_Frames = strncmp('Video Frame', c3d.NERRanges.LABELS, 11);
				non_Video_Frames = not(Video_Frames);
				if sum(non_Video_Frames) > 0
					c3dstruct(x).Ranges.LABELS = c3d.NERRanges.LABELS(non_Video_Frames);
					c3dstruct(x).Ranges.SEND_TIMES = c3d.NERRanges.STARTTIMES(non_Video_Frames);
					c3dstruct(x).Ranges.ACK_TIMES = c3d.NERRanges.STOPTIMES(non_Video_Frames);
					c3dstruct(x).Ranges.USED = sum(non_Video_Frames);
				end
				if sum(Video_Frames) > 0
					c3dstruct(x).VIDEO_LATENCY.LABELS = c3d.NERRanges.LABELS(Video_Frames);
					c3dstruct(x).VIDEO_LATENCY.SEND_TIMES = c3d.NERRanges.STARTTIMES(Video_Frames);
					c3dstruct(x).VIDEO_LATENCY.ACK_TIMES = c3d.NERRanges.STOPTIMES(Video_Frames);
					c3dstruct(x).VIDEO_LATENCY.USED = sum(Video_Frames);
				end
			end	
		end
		
		% Add filename
		c3dstruct(x).FILE_NAME = c3d.FileName;
		
		% Find all of the fields with one string inside a cell array and just
		% "unwrap" that string so the field contains the string rather than the
		% cell array.
%		c3dstructfields = fields(c3dstruct(x));
%		for y = 1:length(c3dstructfields)
%			if iscell(c3dstruct(x).(c3dstructfields{y})) && length(c3dstruct(x).(c3dstructfields{y})) == 1
%				c3dstruct(x).(c3dstructfields{y}) = c3dstruct(x).(c3dstructfields{y}){1};
%			end
%		end

	end
end
     
cd(olddir);
