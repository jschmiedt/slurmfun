function out = slurmfun(func, inputArguments, varargin)

%% Handle inputs
parser = inputParser;

% function
parser.addRequired('func', @(x) isa(x, 'function_handle')||ischar(x));

% input arguments
parser.addRequired('inputArguments', @iscell);

% partitions
[availablePartitions,defaultPartition] = available_partitions();
parser.addParameter('partition', defaultPartition, @(x) validatestring(x, availablePartitions))

% copy user path
parser.addParameter('copyPath', true, @islogical);

% MATLAB
parser.addParameter('matlabCmd', fullfile(matlabroot, 'bin', 'matlab'), @isstr);

% SLURM home folder
account = getenv('USER');
parser.addParameter('slurmHome', fullfile('/mnt/hpx/slurm/', account), @isstr);

% parse inputs
parser.parse(func, inputArguments, varargin{:})


userPath = path();
% permissions
if ~(exist(parser.Results.slurmHome, 'dir') == 7)
    result = system(['mkdir ' parser.Results.slurmHome]);
    assert(result == 0, 'Could not create SLURM home directory')
end
cmd = sprintf('chmod -R g+w %s', parser.Results.slurmHome')



%% Create input files
nJobs = length(inputArguments);

for iJob = 1:nJobs
%     inputFile = fullfile(parser.Results.slurmHome
    save(inputFile, 'func', 'inputArgs', 'userPath', 'outputFile')
end
%% Submit jobs
cmd = sprintf([...
    'load(%s); path(userPath);' ...
    'try fexec(func, inputArgs, outputFile);' ...
    'catch exit; end' ...
    ], inputFile);


%% Wait for jobs
%%
while any(ismember([submittedJobs.id], ids))
    [ids, states] = get_running_jobs();
    notRunning = ~ismember([submittedJobs.id], ids);
    [submittedJobs(notRunning).isRunning] = deal(false);
    notFinalized = ~[submittedJobs.finalized];
    fetchStatus = find(notRunning & notFinalized);
    for iJob = 1:length(fetchStatus)        
        jobid = submittedJobs(fetchStatus(iJob)).id;
        submittedJobs(fetchStatus(iJob)).finalized = true;
        submittedJobs(fetchStatus(iJob)).finalState = get_final_status(jobid);
    end
    pause(1)
end

%% Read output files


%% Create output