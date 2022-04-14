function linRegConf(x, y, cc)
% this function plots x vs. y scatter with line fit with confidence 
% intervals
% cc (varargin) is confidence coefficiet e.g. 0.95 makes 95% confidence lines
% default cc is 0.99
%
% modified from https://www.mathworks.com/matlabcentral/fileexchange/39339-linear-regression-confidence-interval

if(length(x) ~= length(y))
    error('x and y size mismatch'); 
end

% linear regression
[R,P] = corr(x,y);
stats = regstats(y, x, 'linear', 'beta');
beta = stats.beta; % beta(1) is intercept, beta(2) is slope

N = length(x);
x_min = min(x);
x_max = max(x);
n_pts = 100;

X = x_min:(x_max-x_min)/n_pts:x_max;
Y = ones(size(X))*beta(1) + beta(2)*X;

% confidence intervals
SE_y_cond_x = sum((y - beta(1)*ones(size(y))-beta(2)*x).^2)/(N-2);
SSX = (N-1)*var(x);
SE_Y = SE_y_cond_x*(ones(size(X))*(1/N + (mean(x)^2)/SSX) + (X.^2 - 2*mean(x)*X)/SSX);
alpha = 0.99;
if nargin > 2
    alpha = 1-cc;
end
Yoff = (2*finv(1-alpha,2,N-2)*SE_Y).^0.5;

top_int = Y + Yoff;
bot_int = Y - Yoff;

figure;
scatter(x,y);
hold on

plot(X,Y,'red','LineWidth',2);
plot(X,top_int,'green--','LineWidth',2);
plot(X,bot_int,'green--','LineWidth',2);
text((x_min+x_max)/2, (min(y)+max(y))/2, sprintf('r=%.3f\np=%.3f',R,P))
hold off

end