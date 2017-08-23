function out = myfunction(in)

fprintf('Creating %g random numbers\n', in)
out = rand(in,1);
tWait = randi(10)+60;
fprintf('Pausing for %g s\n', tWait)
pause(tWait);

