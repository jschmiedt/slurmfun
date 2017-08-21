function [availablePartitions, defaultPartition] = get_available_partitions()
% AVAILABLE_PARTITIONS - Retreive partitions avilable in SLURM
% 
[result, availablePartitions] = system('sinfo -h -o %P');
assert(result == 0, 'Could not receive available SLURM partitions using sinfo');
availablePartitions = strsplit(availablePartitions);
availablePartitions(cellfun(@isempty, availablePartitions)) = '';
defaultPartition = ~cellfun(@isempty, strfind(availablePartitions, '*'));
assert(sum(defaultPartition) == 1, 'Multiple default partitions found (contain * in name).')
availablePartitions = strrep(availablePartitions, '*', '');
defaultPartition = availablePartitions(defaultPartition);