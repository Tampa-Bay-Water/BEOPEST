#.\Transform-Bata -x 1.05 -mu 1.1 -sig 0.2 -lb 0.1 -ub 10
param([double]$x,[double]$mu,[double]$sig,
	[double]$lb = 0,
	[double]$ub = 1,
	[double]$my = 0,
	[double]$sy = 1
)

# load numerics4net if not already load
if (!$numerics4net) {
	$numerics4net = 'F:\Assembly\numerics4net-1.2\numerics4net-1.2.dll'
	$numerics4net = [reflection.assembly]::LoadFrom($numerics4net)
}
$normtype = $numerics4net.GetTypes() |where {$_.Name -match '^NormalDistribution'}
$betatype = $numerics4net.GetTypes() |where {$_.Name -match '^BetaDistribution'}

# re-scale
$mu = ($mu-$lb)/($ub-$lb)
$sig = $sig/($ub-$lb)
$x = ($x-$lb)/($ub-$lb)

# use method of moment to determine beta distribution parameters
$fmu = (1-$mu)/$mu
$a = (($fmu/$sig/$sig/(1+$fmu)/(1+$fmu))-1)/(1+$fmu)
$b = $a*$fmu

$norm = New-Object -type $normtype -Arg $my,$sy
$beta = New-Object -type $betatype -Arg $a,$b
return $norm.InverseCumulativeProbability($beta.CumulativeProbability($x))