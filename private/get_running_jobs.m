function [id, state] = get_running_jobs()
% GET_RUNNING_JOBS - Receive job ids of currently running jobs
% 


account = getenv('USER');
squeueCmd = sprintf('squeue -A %s -h -o "%%A %%T"', account);
[result, allJobs] = system(['/bin/bash -c "' squeueCmd '"']);
assert(result == 0, 'squeue query failed');
if isempty(allJobs)
    id = [];
    state = [];
    return
end
out = textscan(allJobs, '%f%s');

id = uint32(out{1});
state = out{2};


