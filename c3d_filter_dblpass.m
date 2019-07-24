function data_out = c3d_filter_dblpass(data_in, method, varargin)
%C3D_FILTER_DBLPASS Double-pass filter all analog data in c3d data_structure.
%	DATA_OUT = C3D_FILTER_DBLPASS(DATA_IN, METHOD, 'fc', FC) filters
%	all analog data in the structure DATA_IN. The data are all double-pass
%	filtered using a 3rd order filter for zero-lag filtering, with a 3db
%	cutoff of the 6th order final filter at FC Hz.  The sampling frequency
%	is extracted from DATA_IN.  The METHOD parameter can either be
%	'standard' or 'enhanced'.  The 'standard' method uses reflection of
%	data about the end-points to minimize starting and end transients
%	(similar to the filtfilt.m function in the Signal Processing toolbox).
%	The 'enhanced'  method builds upon the standard method to provide a
%	better reflection, particularly when a data stream starts or ends at
%	the peak of a noise spike.
%
%	Note: a typical values for FC for human kinematic data is 10 Hz.
%
%	DATA_OUT = C3D_FILTER_DBLPASS(DATA_IN, METHOD, 'fc', FC, 'fs', FS)
%	performs the same filtering, but uses sampling frequency FS. 
%
%	DATA_OUT = C3D_FILTER_DBLPASS(DATA_IN, METHOD, 'coeff', B, A)
%	implements a double-pass, zero-lag custom filter defined by filter
%	coeffecients B and A.  The filter defined by B and A will be applied
%	twice (once forwards and once backwards) for double-pass filter that is
%	twice the order of the filter defined by B and A and with a 3dB cutoff
%	at the frequency at which there is 1.5 db attenuation for the filter
%	defined by B and A.  
% 
%	The input structure DATA_IN	should be of the form produced by 
%	DATA_IN = ZIP_LOAD. ex.
%
%   data = zip_load('183485624_2010-09-21_11-26-21.zip')
%   out = c3d_filter_dblpass(data.c3d(3), 'standard', 'fc', 10, 'fs', 1000)
%
%   If the data is in Dexterit-E 2.3 or earlier format then the usage would
%   be:
%
%   data = c3d_load('Subject, Test_2879_1_N_tm_8_3_1.c3d')
%   out = c3d_filter_dblpass(data, 'standard', 'fc', 10, 'fs', 1000)
%


data_out = data_in;

if isempty(data_in)
	return
end

if ~exist('method', 'var') || isempty(method) || ~ischar(method) || isempty(strmatch(method, {'standard', 'enhanced'}, 'exact'))
	error(['---> No method was specified, or was specified improperly. Must be ''standard'' or ''enhanced''.']);
	
end
%check varargin
fc_specified = false;					%default is that cutoff frequency is not specified
fs_specified = false;					%default is that sampling frequency is not specified
coeff_specified = false;				%default is that filter coefficents are not specified
x = 1;
while x <= length(varargin)
	if strncmpi(varargin{x}, 'fs', 2)
		x = x + 1;
		if length(varargin) >= x
			fs = varargin{x};
		else
			error('---> Sampling frequency (fs) was not specified properly.  No filtering applied');
		end
		if ~isnumeric(fs)
			error('---> Sampling frequency (fs) was not numeric.  No filtering applied');
		end
		fs_specified = true;
	elseif strncmpi(varargin{x}, 'fc', 2)
		x = x + 1;
		if length(varargin) >= x
			fc = varargin{x};
			fc_specified = true;
		else
			error('---> Cutoff frequency (fc) was not specified properly.  No filtering applied');
		end
		if ~isnumeric(fc)
			error('---> Cutoff frequency (fc) was not numeric.  No filtering applied');
		end
	elseif strncmpi(varargin{x}, 'coeff', 5)
		x = x + 1;
		B = varargin{1};
		A = varargin{2};
		%if either of the filter inputs are empty, do not filter the data
		if isempty(B) || isempty(A)
			error('---> One or more of the filter coefficients was empty.  No filtering applied');
		end
		if ~isnumeric(B) || ~isnumeric(A)
			error('---> One or more of the filter coefficients was not numeric.  No filtering applied');
		end
		coeff_specified = true;	    
	end
    x = x + 1;
end

if ~coeff_specified && ~fc_specified
	error('---> Cutoff frequency (fc) was not specified.  No filtering applied');
end



% for each trial of data in data_in
for ii = 1:length(data_in)
	if ~coeff_specified
		if ~fs_specified
			fs = data_in(ii).ANALOG.RATE;
		end
		[B A] = create_filtercoeff_for_dblpass(fc, fs);
		n_reflect = round(fs/fc);
	else
		n_reflect = max(length(A), length(B));
	end
	
	%calculate the basis for the input delays (zi) for the filter
	zibasis = create_zibasis(B, A);
	
	%determine which fields of data_in to filter.  Only filter those which are
	%numeric. 
	names = fieldnames(data_in(ii));
	for jj = length(names):-1:1;
		if ~isnumeric(data_in(1).(names{jj}))
			names(jj) = [];
		end
	end

	for jj = 1:length(names)
		data = data_in(ii).(names{jj});
		if ~isempty(data)
			if strmatch(method, 'standard', 'exact')
				data_out(ii).(names{jj}) = double_pass_filter_standard(data, n_reflect, B, A, zibasis);	
			else
				data_out(ii).(names{jj}) = double_pass_filter_enhanced(data, n_reflect, B, A, zibasis);	
			end
			
		end
	end
end
disp('Finished filtering c3d data structure');


function	data_out = double_pass_filter_standard(data_in, n_reflect, B, A, zibasis)
% The traditional approach to avoid end_condition problems is to reflect
% the data about the end-points, filter the longer data stream, and then
% cut off the extra data from the reflection.  In addition, use the first
% and last points of the longer data stream to set the initial conditions
% of the filter. 
%
% NOTE: in the future can probably reduce n_reflect for greater speed.  

% Choose the number of reflection points.  The duration of the reflection
% data was chosen as 1/fc, which is very conservative. 
len = length(data_in);
if len < 2
% 	not enough data to filter
	data_out = data_in;
	return
end
n_reflect = min(n_reflect, len-1);

% Create reflection data and reflection points from original
% data
reflect_start = data_in(2:n_reflect + 1);
reflect_end = data_in(len - n_reflect:len - 1);
rp1 = data_in(1);
rp2 = data_in(len);
% Add reflection data to original data
data_temp = [2*rp1 - flipud(reflect_start); data_in; 2*rp2 - flipud(reflect_end)];
% Double-pass filter		
data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
% Clip off extra data
data_out = data_temp(n_reflect+1:len + n_reflect);




function	data_out = double_pass_filter_enhanced(data_in, n_reflect, B, A, zibasis)

len = length(data_in);
if len < 2
% 	not enough data to filter
	data_out = data_in;
	return
end
n_reflect = min(n_reflect, len-1);

% STEP 1.  Filter the data as per standard operation
% reflect_start = data_in(2:n_reflect + 1);
% reflect_end = data_in(len - n_reflect:len - 1);
% rp1 = data_in(1);
% rp2 = data_in(len);
% % Add reflection data to original data
% data_temp = [2*rp1 - flipud(reflect_start); data_in; 2*rp2 - flipud(reflect_end)];
% % Double-pass filter		
% data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
% data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
% % Clip off extra data
% data_filt = data_temp(n_reflect+1:len + n_reflect);
data_filt = double_pass_filter_standard(data_in, n_reflect, B, A, zibasis);

% STEP 2.  Calculate the residual (difference between original and
% filtered data).  Contains the noise and error.
residual = data_in - data_filt;						%Difference between original and filtered data.  Contains the noise and error

% STEP 3.  Filter the residual, but because the residual only contains
% noise and error, do NOT rotate about start/end points.  Noise should
% average to zero so a straight mirroring for the reflected data is
% appropriate to filter out the noise, but leave in the error
reflect_start = residual(2:n_reflect + 1);
reflect_end = residual(len - n_reflect:len - 1);
% Add reflection data to original data.  
data_temp = [flipud(reflect_start); residual; flipud(reflect_end)];
% Double-pass filter		
data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
% Clip off extra data
residual_filt = data_temp(n_reflect+1:len + n_reflect);

% STEP 4.  Use filtered data for the data to reflect, use the filtered
% residual to choose point to reflect/rotate about and then filter the
% original data.
reflect_start = data_filt(2:n_reflect + 1);
reflect_end = data_filt(len - n_reflect:len - 1);
rp1 = data_filt(1) + residual_filt(1);
rp2 = data_filt(len) + residual_filt(len);
% Add reflection data to original data
data_temp = [2*rp1 - flipud(reflect_start); data_in; 2*rp2 - flipud(reflect_end)];
% Double-pass filter		
data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
data_temp = flipud(filter(B, A, data_temp, zibasis * data_temp(1)));
% Clip off extra data
data_out = data_temp(n_reflect+1:len + n_reflect);


function	zibasis = create_zibasis(B, A)
%calculate the basis for the input delays (zi), which are used to
%initialize the filter correctly.  The zibasis is then multiplied by the
%first element of the vector being filtered (this has the effect of
%assuming that the n data points previous to the data_in were equal to the
%first data point)  

%initialize zibasis 
filterorder = length(B) - 1;
zibasis = [];
diff = B - A;
for ii = 1:filterorder
	zibasis(ii,:) = [diff(ii+1:filterorder+1) zeros(1,ii-1)];
end
zibasis = zibasis * ones(filterorder,1);



function [B A] = create_filtercoeff_for_dblpass(fc_final, fs)
% This function creates the coefficients for a 3rd order Butterworth filter
% which will be used subsequently as the basis of a double-pass (zero-lag) 6th
% order filter.  The input fc_final is the desired 3db cutoff frequency (Hz) of
% the 6th order filter.  fs is the sampling frequency (Hz).


% For a final 6th order filtering with a 3db cuttoff of fc, we need the 3rd
% order butterworth filter to have 1.5db cutoff at fc (because passing a
% given filter 2x over data_in will double the attenuation at all
% frequencies).  For 3rd order filters, the 3db cutoff is 1/0.864 above the
% 1.5 db attenuation (the correction factor is different for different order
% filters, e.g. it is 0.802 for 2nd order filters).

correction = 0.864;
fc = fc_final/correction;
wc = fc * 2 * pi;		%convert from Hz to rad/s
T = 1/fs;				%

wcw = 2/T*tan(wc*T/2);

% The following coefficients were taken from Alarcon et al. (2000, J. Neurosci
% Meth. 104, 35-44)
A0 =   8 + 8*wcw*T + 4*wcw^2*T^2 +   wcw^3*T^3;
A1 = -24 - 8*wcw*T + 4*wcw^2*T^2 + 3*wcw^3*T^3;
A2 =  24 - 8*wcw*T - 4*wcw^2*T^2 + 3*wcw^3*T^3;
A3 =  -8 + 8*wcw*T - 4*wcw^2*T^2 +   wcw^3*T^3;

B = [1 3 3 1]*wcw^3*T^3/A0;
A = [A0 A1 A2 A3]/A0;

