function x=test(x0,mu,sig,lb,ub)
x = gbetaTransform0(x0,mu,sig,lb,ub);

%% generalize beta transform with close form solution
  function y=gbetaTransform0(x,mu,sig,lb,ub)
  % re-scale
  mu = (mu-lb)/(ub-lb);
  sig = sig/(ub-lb);
  x = (x-lb)/(ub-lb);
  y = betaTransform0(x,mu,sig);
  end

  function x=gbetaInvTransform0(y,mu,sig,lb,ub)
  % re-scale
  mu = (mu-lb)/(ub-lb);
  sig = sig/(ub-lb);
  x = betaInvTransform0(y,mu,sig);
  x = x*(ub-lb)+lb;
  end


%% close form beta parameters with bounds at (0,1)
  function y=betaTransform0(x,mu,sig)
  fmu = (1-mu)/mu;
  a = ((fmu/sig/sig/(1+fmu)^2)-1)/(1+fmu);
  b = a*fmu;
  y = norminv(betacdf(x,a,b),0,1);
  end

  function x=betaInvTransform0(y,mu,sig)
  fmu = (1-mu)/mu;
  a = ((fmu/sig/sig/(1+fmu)^2)-1)/(1+fmu);
  b = a*fmu;
  x = betainv(mormcdf(y,0,1),a,b);
  end


%% use fsolve for beta parameters with bounds at (0,1)
  function y=betaTransform1(x,mu,sig)
  ab = fsolve(@fn,[1,1]);
  y = norminv(betacdf(x,ab(1),ab(2)),0,1);

    function ab=fn(x)
    ab = [...
      mu-x(1)/(x(1)+x(2));
      sig*sig-x(1)*x(2)/(x(1)+x(2)+1)/(x(1)+x(2))^2;...
      ];
    end
  end

  function x=betaInvTransform1(y,mu,sig)
  ab = fsolve(@(x) [...
    mu-x(1)/(x(1)+x(2));
    sig*sig-x(1)*x(2)/(x(1)+x(2)+1)/(x(1)+x(2))^2;...
    ],[1,1]);
  x = betainv(mormcdf(y,0,1),ab(1),ab(2));
  end

end