function out = slurmfun(func, varargin)
% func = @somefunction


% in = 
parser = inputParser;

% function
parser.addRequired('func', @(x) isa(x, 'function_handle')||ischar(x));


% available partitions
[result, availablePartitions] = system('sinfo -h -o %P');
assert(result == 0, 'Could not receive available SLURM partitions using sinfo');
availablePartitions = strsplit(availablePartitions);
availablePartitions(cellfun(@isempty, availablePartitions)) = '';
defaultPartition = ~cellfun(@isempty, strfind(availablePartitions, '*'));
assert(sum(defaultPartition) == 1, 'Multiple default partitions found (contain * in name).')
availablePartitions = strrep(availablePartitions, '*', '');
defaultPartition = availablePartitions(defaultPartition);
parser.addParameter('partition', defaultPartition, @(x) validatestring(x, availablePartitions))

% copy user pathany(validatestring(x,expectedShapes))
parser.addParameter('copyPath', true, @islogical);

% MATLAB
parser.addParameter('matlabCmd', fullfile(matlabroot, 'bin', 'matlab'), @isstr);

% first parameter input
iFirstParameter = find(...
    ismember(cellfun(@char, varargin, 'UniformOutput', false), ...
    parser.Parameters),1);

% parse inputs
parser.parse(func, varargin{iFirstParameter:end})
display(parser.Results)


%%
% userPath = path();
% userMatlab = fullfile(matlabroot, 'bin', 'matlab');


% nJobs = lenght(in);

%% Create files


%% Submit jobs


%% Wait for jobs


%% Read output files


%% Create output