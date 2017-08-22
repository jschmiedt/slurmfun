close all
clear

%% Configure fractal computation
xpos = -1.2676;
ypos = 0.3554;

steps = 400;
span = 2;
maxcount = 400;
zoom = 0.98;

cfg = {};
for count=1:maxcount,
    cfg{count}.xpos=xpos;
    cfg{count}.ypos=ypos;
    cfg{count}.span=span;
    cfg{count}.steps=steps;
    span=span*zoom;
end

%% Parallel computation
tStart = tic;
Z = slurmfun(@calcfrac, cfg, 'partition','8GB');
tParallel = toc;

fprintf('Parallel computation took %g s\n', tParallel)

%% Local, sequential computation
tStart = tic;
Z = cellfun(@calcfrac, cfg, 'UniformOutput', false);
tSequential = toc;
fprintf('Sequential computation took %g s\n', tSequential)


%%
fprintf('Parallel computation was %gx faster than sequential.\n', tSequential/tParallel);

%%

% 
% figure(1);
% for count=1:maxcount,
%     imagesc(Z{count});
%     axis off;
%     drawnow;
%     pause(0.5)
% end

