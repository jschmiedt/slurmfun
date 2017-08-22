
clc


nJobs = 20;
inputArgs = num2cell(randi(20,nJobs,1)+120);
inputArgs{end+1} = 'asdvsd';

out = slurmfun('myfunction', inputArgs, ...
    'partition', '8GBS', ...
    'stopOnError', true);