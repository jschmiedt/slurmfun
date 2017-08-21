function out = fexec(func, inputVars, outputFile)
% 
% input file must contain the variables func, inputVars, outputFile
fprintf('Trying to evaluate %s\n')
try
    out = feval(func, inputVars{:});
catch me
    warning('An error occurred')
    out = me;
end
fprintf('Storing output in %s\n', outputFile)
save(outputFile, 'out')

exit