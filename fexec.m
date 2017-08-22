function out = fexec(func, inputVars, outputFile)
% 
% input file must contain the variables func, inputVars, outputFile
fprintf('Trying to evaluate %s\n', func2str(func))
try
    out = feval(func, inputVars{:});
catch me
    display(me)
    out = me;
end
fprintf('Storing output in %s\n', outputFile)
save(outputFile, 'out')

exit