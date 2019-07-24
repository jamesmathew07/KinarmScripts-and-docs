% The purpose of demo_c3d_load.m is to demonstrate the basic functionality
% of the library of m-files associated with c3d_load.
% 
% Please make sure that the path to the c3d_load m-files is in the Matlab
% path.  Then change to the directory containing the c3d_files of interest
% and type demo_c3d_load at the command prompt


data = c3d_load;											% Loads all c3d_files into a new structure called 'data'.
data = KINARM_add_hand_kinematics(data);					% Add hand velocity, acceleration and commanded forces to the data structure
data_filt = c3d_filter_dblpass(data, 'enhanced', 'fc', 10);	% Double-pass filter the data at 3db cutoff frequency of 10 Hz.  Use an enhanced method for reducing transients at ends.

% Message
disp(' ')
disp('**************************************************************')
disp('Demonstration of c3d_load functionality, using demo_c3d_load.m')
disp(' ')
% Display contents of final data structure
disp('Contents of first c3d trial:');
disp(data_filt(1));

% Plot example hand paths
figure
for ii = 1:length(data)
	hold on
	plot(data_filt(ii).Right_HandX,  data_filt(ii).Right_HandY);
end
ylabel('Y (m)');
xlabel('X (m)');
title ('Example - Hand Paths (all trials)');



