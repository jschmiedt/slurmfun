
clc


nJobs = 1000;
inputArgs = num2cell(randi(20,nJobs,1)+50);
% inputArgs{end+1} = 'asdvsd';

out = slurmfun('myfunction', inputArgs, ...
    'partition', '8GBS', ...
    'stopOnError', true);