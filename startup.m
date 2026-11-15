%% startup.m

% This script sets up the MATLAB environment for the project by adding the necessary paths.
projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(genpath(fullfile(projectRoot, 'scripts')));
disp('Project paths added to MATLAB environment.');
