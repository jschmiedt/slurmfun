function [id, state] = get_running_jobs()
account = getenv('USER');
squeueCmd = sprintf('squeue -A %s -h -o "%%A %%T"', account);
[result, allJobs] = unix(squeueCmd);
assert(result == 0, 'squeue query failed');
if isempty(allJobs)
    id = [];
    state = [];
    return
end
out = textscan(allJobs, '%f %s');

id = uint32(out{1});
state = out{2};


% out = strsplit(allJobs);
% out(cellfun(@isempty, out)) = '';
% 
% id = out(1:2:end);
% id = uint32(str2double(id));
% state = out(2:2:end);
if isempty(id)
    bla = 1;
end

