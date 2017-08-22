function [id, state] = get_running_jobs()
account = getenv('USER');
squeueCmd = sprintf('squeue -A %s -h -o "%%A %%t"', account);
[~, allJobs] = system(squeueCmd);
if isempty(allJobs)
    id = [];
    state = [];
    return
end
out = textscan(allJobs, '%u %s');
id = out{1};
state = out{2};
