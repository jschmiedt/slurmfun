function id = get_running_jobs()
% GET_RUNNING_JOBS - Receive job ids of currently running jobs
% 
% Note: The output of squeue is sometimes truncated in MATLAB. Double check
% if your job is still running or not.

account = getenv('USER');
squeueCmd = sprintf('squeue -A %s -h -o "%%A"', account);
[result, allJobs] = unix(squeueCmd);
assert(result == 0, 'squeue query failed');
if isempty(allJobs)
    id = [];
    state = [];
    return
end
out = textscan(allJobs, '%f');

id = uint32(out{1});


