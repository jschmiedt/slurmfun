function out = slurmfun(func, inputArguments, varargin)
% SLURMFUN - Apply a function to each element of a cell array in parallel
% using the SLURM queueing system.
%
% USAGE
% -----
%   argout = slurmfun(functionName, inputArguments, ...
%
% INPUT
% -----
%   functionName    : function name or handle to executed. The function
%                     must only take one input argument and give out one
%                     output argument. Multiple arguments can be stored in
%                     cell arrays.
%   inputArguments  : cell array of input arguments for function. Length of
%                     the array determines number of jobs submitted to SLURM.
%
% This function has a number of optional arguments for configuration:
%   'partition'     : name of partition/queue to be submitted to. Default
%                     is the default SLURM queue.
%   'matlabCmd'     : path to matlab binary to be used. Default is the same
%                     as the submitting user
%   'stopOnError'   : boolean flag for continuing execution after a job
%                     fails. Default is true.
%   'slurmWorkingDirectory' : path to working directory where input, output
%                     and logfiles will be created. Default is
%                     /mnt/hpx/slurm/<user>/<user>_<date/, e.g.
%                     /mnt/hpx/slurm/schmiedtj/schmiedtj_20170823-125121
%   'deleteFiles'   : boolean flag for deletion of input, output and log
%                     files after completion of all jobs. Default is true.
%   'useUserPath'   : boolean flag flag whether the MATLAB path of the user
%                     should be used in job. Default is true.
%
% OUTPUT
% ------
%   argout : cell array of output argument
% 
% 
% EXAMPLE
% -------
% This example will spawn 50 jobs that pause for 50-70s.
% 
% nJobs = 50;
% inputArgs = num2cell(randi(20,nJobs,1)+50); 
% out = slurmfun(@pause, inputArgs, ...
%     'partition', '8GBS', ...
%     'stopOnError', false);
% 
% 
% 
% See also CELLFUN
% 

% TODO
%  - stacking
%  - variable number of input/output arguments
%  - memory profiling
%  - license checkout

if verLessThan('matlab', 'R2014a')
    error('MATLAB:slurmfun:MATLAB versions older than R2015b are not supported')
end

% empty the LD_PRELOAD environment variable 
% vglrun libraries don't have SUID bit, sbatch does. See
% ihttps://virtualgl.org/vgldoc/2_2/#hd0012

LD_PRELOAD = getenv('LD_PRELOAD');
if ~isempty(LD_PRELOAD)
    setenv('LD_PRELOAD', '');
end

%% Handle inputs
parser = inputParser;

% function
parser.addRequired('func', @(x) isa(x, 'function_handle')||ischar(x));

% input arguments
parser.addRequired('inputArguments', @iscell);

% partitions
[availablePartitions,defaultPartition] = get_available_partitions();
parser.addParameter('partition', defaultPartition, ...
    @(x) ischar(validatestring(x, availablePartitions)))

% copy user path
parser.addParameter('useUserPath', true, @islogical);

% MATLAB
parser.addParameter('matlabCmd', fullfile(matlabroot, 'bin', 'matlab'), @(x) ischar(x) && exist(x, 'file') == 2)

% SLURM home folder
account = getenv('USER');
submissionTime = datestr(now, 'YYYYmmDD-HHMMss');
parser.addParameter('slurmWorkingDirectory', fullfile('/mnt/hpx/slurm', account, [account '_' submissionTime]), @isstr);

% stop on error
parser.addParameter('stopOnError', true, @islogical);

% delete files
parser.addParameter('deleteFiles', true, @islogical);

% parse inputs
parser.parse(func, inputArguments, varargin{:})

if ischar(parser.Results.func)
    func = str2func(parser.Results.func);
end

if parser.Results.useUserPath
    assert(strcmp(parser.Results.matlabCmd, ...
        fullfile(matlabroot, 'bin', 'matlab')), ...
        'If useUserPath is true, matlabBinary must match current MATLAB')
end

nJobs = length(inputArguments);

%% Working directory
slurmWDCreated = false;
% permissions
if ~(exist(parser.Results.slurmWorkingDirectory, 'dir') == 7)
    result = system(['mkdir -p ' parser.Results.slurmWorkingDirectory]);
    assert(result == 0, 'Could not create SLURM working directory (%s)', ...
        parser.Results.slurmWorkingDirectory)
    slurmWDCreated = true;
end
cmd = sprintf('chmod -R g+w %s', parser.Results.slurmWorkingDirectory);
result = system(cmd);
assert(result == 0, ...
    'Could not set write permissions for SLURM working directory (%s)', ...
    parser.Results.slurmWorkingDirectory)



%% Create input files
addpath(pwd)
userPath = path(); %#ok<*NASGU>
inputFiles = cell(1,nJobs);
outputFiles = cell(1,nJobs);
logFiles = cell(1,nJobs);
fprintf('Creating input files in %s\n', parser.Results.slurmWorkingDirectory);
for iJob = 1:nJobs
    
    baseFile = fullfile(parser.Results.slurmWorkingDirectory, ...
        sprintf('%s_%s_%05u', account, submissionTime, iJob));
    inputFiles{iJob} = [baseFile '_in.mat'];
    outputFiles{iJob} = [baseFile '_out.mat'];
    logFiles{iJob} = [baseFile '.log'];
    
    
    inputArgs = inputArguments(iJob);
    outputFile = outputFiles{iJob};
    inputArgsSize = whos('inputArgs');
    if inputArgsSize.bytes > 2*1024*1024*1024
        error(['Size of the input arguments must not exceed 2 GB. ', ...
            'For large data please pass a filename instead of the data'])
    end
    save(inputFiles{iJob}, 'func', 'inputArgs', 'userPath', 'outputFile', '-v6')
end
%% Submit jobs

fprintf('Submitting %u jobs into %s at %s\n', ...
    nJobs, parser.Results.partition, datestr(now))
tic
for iJob = 1:nJobs
    if parser.Results.useUserPath
        cmd = sprintf([...
            'load(''%s''); path(userPath);' ...
            'try fexec(func, inputArgs, outputFile);' ...
            'catch exit; end' ...
            ], inputFiles{iJob});
    else
        cmd = sprintf([...
            'load(''%s'');' ...
            'try fexec(func, inputArgs, outputFile);' ...
            'catch exit; end' ...
            ], inputFiles{iJob});
    end
    
    submittedJobs(iJob) = Job(cmd, parser.Results.partition, logFiles{iJob}, parser.Results.matlabCmd);
    if parser.Results.deleteFiles
        submittedJobs(iJob).deleteLogfile = true;
    end
end
tSubmission = toc;
fprintf('Submission of %u jobs took %g s\n', nJobs, tSubmission)

% Setup cleanup after completion/failure
if parser.Results.deleteFiles
    cleanup = onCleanup(@() delete_if_exist([inputFiles, outputFiles], ...
        parser.Results.slurmWorkingDirectory, slurmWDCreated, LD_PRELOAD));
end

%% Wait for jobs
fprintf('Waiting for jobs to complete\n')
ids = get_running_jobs();
tStart = tic;
out = cell(1,nJobs);
breakOut = false;

printString = sprintf('Remaining jobs: %6d\nElapsed time: %6.1f min\n', ...
    sum([submittedJobs.isRunning]), toc(tStart));
fprintf(printString)


while any(ismember([submittedJobs.id], ids)) && ~breakOut
    pause(5)
    fprintf(repmat('\b',1,length(printString)));
    printString = sprintf('\nRemaining jobs: %6d\nElapsed time: %6.1f min', ...
        sum([submittedJobs.isRunning]), toc(tStart)/60);
    fprintf(printString)
    
    
    ids = get_running_jobs();
    
    notRunning = ~ismember([submittedJobs.id], ids);
    [submittedJobs(notRunning).isRunning] = deal(false);
    notFinalized = ~[submittedJobs.finalized];
    iCompleteButNotFinalized = find(notRunning & notFinalized);
    for iJob = 1:length(iCompleteButNotFinalized)
        jJob = iCompleteButNotFinalized(iJob);
        jobid = submittedJobs(jJob).id;
        submittedJobs(jJob).finalized = true;
        submittedJobs(jJob).state = get_final_status(jobid);
        
        switch submittedJobs(jJob).state
            case 'COMPLETED'
                
                % load output file
                tmpOut = load(outputFiles{iCompleteButNotFinalized(iJob)});
                out{iCompleteButNotFinalized(iJob)} = tmpOut.out;
                
                if isa(tmpOut.out, 'MException')
                    fprintf('\n')
                    warning('An error occured in job %u:%u. See %s', ...
                        jJob, jobid, submittedJobs(jJob).logFile)
                    disp(getReport(tmpOut.out, 'extended', 'hyperlinks', 'on' ) )
                    submittedJobs(jJob).deleteLogfile = false;
                   
                    fprintf(repmat(' ', 1,length(2*printString)));
                    fprintf('\n')
                    if parser.Results.stopOnError
                        breakOut = true;
                        break
                    end
                   
                end
                
                % get_running_jobs based on squeue sometimes doesn't return the ids
                % properly. Therfore we check again, the status of the jobs
            case 'RUNNING'
                submittedJobs(jJob).isRunning = true;
                submittedJobs(jJob).finalized = false;
            case {'FAILED','CANCELLED'}
                fprintf('\n')
                warning('An error occured in job %u:%u. See %s', ...
                    jJob, jobid, submittedJobs(jJob).logFile)
                fprintf(repmat(' ', 1,length(2*printString)));
                fprintf('\n')
                submittedJobs(jJob).deleteLogfile = false;
                if parser.Results.stopOnError
                    breakOut = true;
                    break
                end
        end
    end
    
    
    
end

iCompleted = ~cellfun(@isempty, out);
iMatlabError = cellfun(@(x) isa(x, 'MException'), out(iCompleted));


fprintf('\n')
fprintf('%u jobs completed without errors, %u completed with errors, %u failed/aborted.\n', ...
    sum(~iMatlabError), sum(iMatlabError), sum(~iCompleted));
fprintf('Elapsed time: %g s\n', toc(tStart));

if sum(iMatlabError) > 0
    fprintf('Log files of failed jobs can be found in %s\n', ...
        parser.Results.slurmWorkingDirectory);
end

if nargout == 0
    clear out
end

end

function delete_if_exist(delFiles, delFolder, folderFlag, LD_PRELOAD)
fprintf('Deleting temporary input/output files from %s...\n', delFolder)
warning('off', 'MATLAB:DELETE:FileNotFound')
delete(delFiles{:})
warning('on', 'MATLAB:DELETE:FileNotFound')


% delete working directory if empty and created by slurmfun
if folderFlag && length(dir(delFolder)) == 2
    fprintf('Deleting SLURM working directory %s ...\n', delFolder)
    rmdir(delFolder)
end

% restore original LD_PRELOAD variable
setenv('LD_PRELOAD', LD_PRELOAD)

end

