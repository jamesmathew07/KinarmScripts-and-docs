%SORT_TRIALS given a set of trials loaded from zip_load this will sort the
%   trials based on the criteria you specify.
%
%   sorted = sort_trials(zip_load()) Will sort the trials based on the
%   execution order.
%
%   sorted = sort_trials(zip_loads(), [type], [method]). Type is one of:
%   'execution' - execution order sort
%   'tp' - sort by trial protocol number (and run order when tp's match).
%   'custom' - use the supplied method argument as the sorting method.
%   method - a pointer to a method with the signature sortMethod(c3d1,
%   c3d2). The method should return true when c3d1 > c3d2, false otherwise.
%
function exam = sort_trials(exam, method, varargin)
    % This method implements a simple bubble sort for the trials in an exam
    % loaded using zip_load.
    n = length(exam.c3d);
    
    if isempty(method) ||  strcmpi('execution', method)
        sortMethod = @sortByRunOrder;
    elseif strcmpi('tp', method)
        sortMethod = @sortByTP;
    elseif strcmpi('custom', method)
        sortMethod = varargin{1};
    end
    
    
    while (n > 0)
        % Iterate through c3d
        nnew = 0;
        for i = 2:n
            % Swap elements in wrong order
            if sortMethod(exam.c3d(i - 1), exam.c3d(i))
                swap(i,i - 1);
                nnew = i;
            end
        end
        n = nnew;
    end
    
    function swap(i,j)
        val = exam.c3d(i);
        exam.c3d(i) = exam.c3d(j);
        exam.c3d(j) = val;
    end    
end

function ret = sortByRunOrder(c3d1, c3d2)
    ret = c3d1.TRIAL.TRIAL_NUM > c3d2.TRIAL.TRIAL_NUM;  
end

function ret = sortByTP(c3d1, c3d2)
    if c3d1.TRIAL.TP == c3d2.TRIAL.TP
        ret = sortByRunOrder(c3d1, c3d2);
    else
        ret = c3d1.TRIAL.TP > c3d2.TRIAL.TP;  
    end
end
