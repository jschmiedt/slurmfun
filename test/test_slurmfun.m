
clc


nJobs = 300;
inputArgs = num2cell(randi(20,nJobs,1)+50);
inputArgs{end+1} = 5000000000;

out = slurmfun('myfunction', inputArgs, ...
    'partition', '8GBS', ...
    'stopOnError', false, 'deleteFiles', false);