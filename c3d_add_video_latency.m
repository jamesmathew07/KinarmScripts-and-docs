function data_out = c3d_add_video_latency(data_in, display_latency, num_buffered_frames)
%C3D_ADD_VIDEO_LATENCY Add min/max limits to video latency
%	DATA_OUT = C3D_ADD_VIDEO_LATENCY(DATA_IN, DISPLAY_LATENCY,
%	NUM_BUFFERED_FRAMES) adds minimum and maximum times to the Video_Latency
%	field of the structure DATA_IN.  These minimum and maximum times represent
%	the limits of when the upper-left pixel in the video frame was shown to the
%	subject. These times are based on:  
%
%		(1) the send and acknowledge times for the video frames (i.e. between
%		the Robot Computer and the Dexterit-E Computer), which provide absolute
%		time constraints on the command sequence. These calculations also
%		include some 'intelligence' which corrects acknowledgement times based
%		on the fact that the minimum time between the actual display of an image
%		is the video frame period.   
%
%		(2) buffering by the subject display, if present (most modern displays
%		buffer the entire image before displaying it, whereas CRT-like displays
%		have no buffer) 
%
%		(3) other latencies in the display (which includes the "response time"
%		reported by the display manufacturer, but can also include other delays
%		if they exist. Please see the Dexterit-E User Guide reference section
%		for more information).   
%
%	The DISPLAY_LATENCY input is a required input (in seconds), and should be a
%	measure of all delays inherent in the display, excluding any buffering by
%	the display. The typical sources of delay are: (i) response time (e.g. 5-10
%	ms); (ii)asynchronous backlight pulse-width-modulation (0 if none, or 4 ms
%	if 120 Hz PWM); (iii) internal processing delays (0-5 ms) 
%
%	The NUM_BUFFERED_FRAMES is an optional input which indicates the number of
%	frames that the display buffers. The default value is 1 (i.e. if no argument
%	is input to the function) . For most modern displays, this value = 1. For
%	CRT or CRT-like displays, this value should be set = 0. 
%
%   Note 1: under normal conditions (i.e. in which the communication between the
%   Robot and Dexterit-E computers is not delayed via parallel or conflicting
%   process), the maximum time represents the actual time of the display (i.e.
%   typically the acknowledgement is received within ~1 ms of the Vsync pulse on
%   the video card displaying the image).  
%
%	Note 2: this function does NOT account for discrepancies in timing of visual
%	stimulus on different parts of the screen. Most modern displays behave in a
%	manner similar to CRTs: the frame is displayed sequentially, line-by-line,
%	from top to bottom, over the duration of an entire single frame. An example
%	of an exception to this behaviour are many DLP projectors which display the
%	entire frame synchronously, but which display the RGB colours sequentially.

if nargin==0
	error('---> No input provided ');
elseif nargin == 1 || isempty(display_latency) || ~isnumeric(display_latency) 
	error('---> No display_latency was specified, or was specified improperly. Must be a numeric value for display device latency (specified in seconds). ');
elseif nargin == 2
	num_buffered_frames = 1;
elseif isempty(num_buffered_frames) || ~isnumeric(num_buffered_frames) 
	error('---> num_buffered_frames was specified improperly. Must be a numeric value (specified in frames). ');
end

data_out = data_in;								%set the default

% for each trial of data in data_in
for ii = 1:length(data_in)
	if ~isempty(data_in(ii).VIDEO_LATENCY)
		video_frame_period = 1/data_in(ii).VIDEO_SETTINGS.REFRESH_RATE;				%reported video refresh rate in sec (Dexterit-E computer clock)
		buffer_delay = num_buffered_frames * video_frame_period;
		
		%reported video refresh rate is rounded to the nearest ms, and differences
		%of a few percent between GUI and real-time computer is possible.
		%video_frame_period_floor puts minimum limit on the different that could be
		%recorded by the real-time computer.
		video_frame_period_floor = 0.001 * floor( 0.95* video_frame_period *1000);						
		ack_time_corrected = data_in(ii).VIDEO_LATENCY.ACK_TIMES;

		% The following correction is based on the fact that the time between video
		% display refresh is the video_frame_period, which on the real-time computer
		% has a minimum expected value of video_frame_period_floor.  As such, the time
		% between any two adjacent video acknowledgements must be
		% >=video_frame_period_floor.  Any discrepancies with this fact are corrected
		% here.
		for jj = length(ack_time_corrected):-1:2
			if (ack_time_corrected(jj) - ack_time_corrected(jj-1)) < video_frame_period_floor	%use of floor ensures that only those periods 
				ack_time_corrected(jj - 1) = ack_time_corrected(jj) - video_frame_period_floor;
			end
		end

		% The minimum and maximum video latencies are calculated from the SEND and
		% corrected acknowledgement times, plus the following:
		% (1) the addition of a refresh period (required to transmit the image)
		% (2) the display_latency

		data_out(ii).VIDEO_LATENCY.DISPLAY_MIN_TIMES = data_in(ii).VIDEO_LATENCY.SEND_TIMES + buffer_delay + display_latency;
		data_out(ii).VIDEO_LATENCY.DISPLAY_MAX_TIMES = ack_time_corrected + buffer_delay + display_latency;
	else
		% no video latency data, so do nothing
	end
end
