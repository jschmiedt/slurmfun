classdef Job < handle
    
    properties ( SetAccess = immutable )
        id@uint32 % SLURM job id
        submissionTime 
        startScript % bash script calling the MATLAB engine
        inputFile % .mat file passed to start script
        outputFile % .mat file for output of function
    end
    
    properties
        isRunning = false
        finalized = false
        state
        finalState
    end
    
    properties ( Constant = true, Access = private )
        account = getenv('USER');
        gid = primary_group();
        baseCmd = sprintf(...
            'sbatch -A %s --uid=slurm --gid=%u --parsable ', ...
            obj.account, obj.gid);
    end
    
    methods
        function obj = Job(cmd)
            cmd = [obj.baseCmd sprintf('-p %s %s', partition %s )];    
            [result, id] = system(cmd);
            assert(result == 0, 'Submission failed')        
            obj.id = uint32(sscanf(id,'%u'));
            obj.startScript = startScript;
            obj.inputFile = inputFile;
            obj.outputFile = outputFile;
            obj.isRunning = true;                
            obj.submissionTime = datestr(now);
        end
        
        
        function result = query_state(obj)
            [~, result] = system(['squeue -h -o %t -j ' num2str(obj.id)]);
            obj.state = result;
            if nargout == 0
                clear result
            end
            
        end        
        function delete(obj)            
            cmd = sprintf('scancel %u', obj.id);
            system(cmd);
            delete(obj.inputFile)
            delete(obj.outputFile)
            delete(obj.logFile)
        end
        
    end        
end