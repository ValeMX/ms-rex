load('stage3_results.mat', 'results', 'configs');
ib = find(configs(:,1)==0.30 & configs(:,2)==0  & configs(:,3)==0);    % baseline
ic = find(configs(:,1)==0.30 & configs(:,2)==35 & configs(:,3)==60);   % migliore
names = {'F1','rPrec','rRec','rF1','Compl','Corr','Quality'};
for m = [4 7]                                   % rF1 e Quality
    d = results(ic, :, m) - results(ib, :, m);          % differenza per tile
    fprintf('%s: media %+.3f, errore standard %.3f, migliora in %d/%d tile\n', ...
        names{m}, mean(d), std(d)/sqrt(numel(d)), sum(d > 0), numel(d));
end