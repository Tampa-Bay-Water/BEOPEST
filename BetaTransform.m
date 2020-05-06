function y=BetaTransform(x,mu,sig,lb,ub,my,sy)

if nargin<7, sy = 1; end
if nargin<6, my = 0; end
if nargin<5, ub = 1; end
if nargin<4, lb = 0; end

% re-scale
mu = (mu-lb)./(ub-lb);
sig = sig./(ub-lb);
x = (x-lb)./(ub-lb);
y = BetaTransform0(x,mu,sig,my,sy);


%% close form beta parameters with bounds at (0,1)
function y=BetaTransform0(x,mu,sig,my,sy)
fmu = (1-mu)./mu;
a = ((fmu./sig./sig./(1+fmu).^2)-1)./(1+fmu);
b = a.*fmu;
plot(x,betapdf(x,a,b));
y = norminv(betacdf(x,a,b),my,sy);
