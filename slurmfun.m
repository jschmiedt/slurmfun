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
%   functionName    : function name or handle to executed
%   inputArguments  : cell array of input arguments. Length of the array
%                     determines number of jobs submitted to SLURM.
% This function has a number of optional arguments for configuration:
% 
% 

% TODO
%  - stacking
%  - variable number of output arguments?
%  - esi load /save
%  - memory profiling

if verLessThan('matlab', 'R2014a')
    error('MATLAB:slurmfun:MATLAB versions older than R2014a are not supported')
end


%% Handle inputs
parser = inputParser;

% function
parser.addRequired('func', @(x) isa(x, 'function_handle')||ischar(x));

% input arguments
parser.addRequired('inputArguments', @iscell);

% partitions
[availablePartitions,defaultPartition] = get_available_partitions();
parser.addParameter('partition', defaultPartition, @(x) ischar(validatestring(x, availablePartitions)))

% copy user path
parser.addParameter('copyPath', true, @islogical);

% MATLAB
parser.addParameter('matlabCmd', fullfile(matlabroot, 'bin', 'matlab'), @isstr);

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

userPath = path(); %#ok<*NASGU>
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


%% 
nJobs = length(inputArguments);



%% Create input files


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

fprintf('Submitting %u jobs into %s\n', nJobs, parser.Results.partition)
tic
for iJob = 1:nJobs
    
    cmd = sprintf([...
        'load(''%s''); path(userPath);' ...
        'try fexec(func, inputArgs, outputFile);' ...
        'catch exit; end' ...
        ], inputFiles{iJob});
    submittedJobs(iJob) = Job(cmd, parser.Results.partition, logFiles{iJob});
    if parser.Results.deleteFiles
        submittedJobs(iJob).deleteLogfile = true;
    end
end
tSubmission = toc;
fprintf('Submission of %u jobs took %g s\n', nJobs, tSubmission)

% Setup cleanup after completion/failure
if parser.Results.deleteFiles
    cleanup = onCleanup(@() delete_if_exist([inputFiles, outputFiles], ...
        parser.Results.slurmWorkingDirectory, slurmWDCreated));
end

%% Wait for jobs
fprintf('Waiting for jobs to complete\n')
[ids, states] = get_running_jobs();
tStart = tic;
tLoop = tic;
out = cell(1,nJobs);
breakOut = false;
while any(ismember([submittedJobs.id], ids)) && ~breakOut
    pause(1)
    [ids, states] = get_running_jobs();

    notRunning = ~ismember([submittedJobs.id], ids);
    if toc(tLoop) > 60
        fprintf('\t%u jobs remaining\n', sum(~notRunning));
        tLoop = tic;
    end
    [submittedJobs(notRunning).isRunning] = deal(false);
    notFinalized = ~[submittedJobs.finalized];
    iCompleteButNotFinalized = find(notRunning & notFinalized);
    for iJob = 1:length(iCompleteButNotFinalized)
        jobid = submittedJobs(iCompleteButNotFinalized(iJob)).id;
        submittedJobs(iCompleteButNotFinalized(iJob)).finalized = true;
        submittedJobs(iCompleteButNotFinalized(iJob)).state = get_final_status(jobid);
        
        if strcmp(submittedJobs(iCompleteButNotFinalized(iJob)).state, 'COMPLETED')
            tmpOut = load(outputFiles{iCompleteButNotFinalized(iJob)});
            out{iCompleteButNotFinalized(iJob)} = tmpOut.out;
            if isa(tmpOut, 'MException')
                warning('An error occured in job %u:%u. See %s', ...
                    iCompleteButNotFinalized(iJob), jobid, submittedJobs(iCompleteButNotFinalized(iJob)).logFile)
                disp(getReport(tmpOut, 'extended', 'hyperlinks', 'on' ) )
                submittedJobs(iCompleteButNotFinalized(iJob)).deleteLogfile = false;
                
                if parser.Results.stopOnError                                        
                    breakOut = true;
                    break
                end
                
                
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

function delete_if_exist(delFiles, delFolder, folderFlag)
fprintf('Deleting temporary input/output files from %s...\n', delFolder)
warning('off', 'MATLAB:DELETE:FileNotFound')
delete(delFiles{:})
warning('on', 'MATLAB:DELETE:FileNotFound')


% delete working directory if empty and created by slurmfun
if folderFlag && length(dir(delFolder)) == 2
    fprintf('Deleting SLURM working directory %s ...\n', delFolder)    
    rmdir(delFolder)
end

end
