function partitions = available_partitions()
% AVAILABLE_PARTITIONS - Retreive partitions avilable in SLURM

cmd = 'sinfo -o %R -h';
[~, partitions] = system(cmd);
partitions = strsplit(partitions);

partitions(cellfun(@isempty, partitions)) = '';