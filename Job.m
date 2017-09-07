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
    end
    
    properties ( Constant = true, Access = private )
        account = getenv('USER');
        gid = primary_group();
        matlabCaller = fullfile(fileparts(mfilename('fullpath')), 'matlabcmd.sh');
    end
    
    methods
        function obj = Job(cmd, partition, logFile, matlabBinary)
            [folder,~,~] = fileparts(logFile);
            baseCmd = sprintf(...
                'sbatch -A %s -D %s --uid=slurm --gid=%u --parsable ', ...
                obj.account, folder, obj.gid);
            cmd = sprintf('%s -p %s -o %s %s -m "%s" "%s"', ...
                baseCmd, partition, logFile, obj.matlabCaller, matlabBinary, cmd);
            [result, id] = system(cmd);
            % workaround for MATLAB bug: https://www.mathworks.com/support/bugreports/1400063
            [~,remainder] = system('');
            id = [id remainder];
            assert(result == 0 || isempty(id), 'Submission failed: %s\n', id)
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
            if obj.isRunning
                cmd = sprintf('scancel %u', obj.id);
                result = system(cmd);
                assert(result == 0, 'Could not cancel job %u', obj.id)
            end
            
            if obj.deleteLogfile
                delete(obj.logFile)
            end
        end
        
    end
end
