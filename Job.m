classdef Job < handle
    
    properties ( SetAccess = immutable )
        id@uint32 % SLURM job id
        submissionTime     
        logFile
    end
    
    properties
        isRunning = false
        finalized = false
        deleteLogfile = true
        state
        finalState
    end
    
    properties ( Constant = true, Access = private )
        account = getenv('USER');
        gid = primary_group();      
        matlabCaller = fullfile(fileparts(mfilename('fullpath')), 'matlabcmd.sh');
    end
    
    methods
        function obj = Job(cmd, partition, logFile)
            baseCmd = sprintf(...
                'sbatch -A %s --uid=slurm --gid=%u --parsable ', ...
                obj.account, obj.gid);
            cmd = sprintf('%s -p %s -o %s %s "%s"', ...
                baseCmd, partition, logFile, obj.matlabCaller, cmd);
            [result, id] = system(cmd);
            assert(result == 0, 'Submission failed')        
            obj.id = uint32(sscanf(id,'%u'));
            obj.isRunning = true;                
            obj.submissionTime = datestr(now);
            obj.logFile = logFile;
        end
        
        
        function result = query_state(obj)
            [result, state] = system(['squeue -h -o %T -j ' num2str(obj.id)]);            
            assert(result == 0, 'Job query failed');
            
            if isempty(state)
                state = get_final_status(obj.id);
            end
            obj.state = strrep(state, char(10)', '');
                        
            
            if nargout == 0
                clear result
            end
            
        end        
        function delete(obj)            
            cmd = sprintf('scancel %u', obj.id);
            result = system(cmd);      
            assert(result == 0, 'Could not cancle job %u', obj.id)
            if obj.deleteLogfile
                delete(obj.logFile)
            end
        end
        
    end        
end