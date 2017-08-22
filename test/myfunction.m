function out = myfunction(in)


fprintf('Pausing for %g s\n', in)
pause(in)
out = randi(10);

