$s = compile(scmn.dsl)

$s.enable_output(*.Vm)

$s.set_param(inseg.length,35)
$s.set_param(inseg.diameter,7)
$s.set_param(inseg.GdensKdr,0.1)
$s.set_param(inseg.GdensNa,0.2)
$s.set_param(inseg.Gdensleak,0.001)
$s.set_param(inseg.GdensCaN,0)
$s.set_param(inseg.GdensCaL,0)
$s.set_param(inseg.GdensKCa,0)

$s.set_param(soma.length,50)
$s.set_param(soma.diameter,50)
$s.set_param(soma.GdensKdr,0.075)
$s.set_param(soma.GdensNa,0.05)
$s.set_param(soma.Gdensleak,0.002)
$s.set_param(soma.GdensCaN,0.0005)
$s.set_param(soma.GdensCaL,0)
$s.set_param(soma.GdensKCa,0.1)
$s.set_param(soma.KpN,80000)

$s.set_param(d1.length,2000)
$s.set_param(d1.diameter,28)
$s.set_param(d1.GdensKdr,0.05)
$s.set_param(d1.GdensNa,0.001)
$s.set_param(d1.Gdensleak,0.0005)
$s.set_param(d1.GdensCaN,0.0001)
$s.set_param(d1.GdensCaL,0)
$s.set_param(d1.GdensKCa,0.001)

$s.set_param(d2.length,1000)
$s.set_param(d2.diameter,25.2)
$s.set_param(d2.GdensKdr,0)
$s.set_param(d2.GdensNa,0)
$s.set_param(d2.Gdensleak,0.0005)
$s.set_param(d2.GdensCaN,0)
$s.set_param(d2.GdensCaL,0.0005)
$s.set_param(d2.GdensKCa,0.0005)

$s.set_param(d3.length,2500)
$s.set_param(d3.diameter,17.64)
$s.set_param(d3.GdensKdr,0)
$s.set_param(d3.GdensNa,0)
$s.set_param(d3.Gdensleak,0.0005)
$s.set_param(d3.GdensCaN,0)
$s.set_param(d3.GdensCaL,0)
$s.set_param(d3.GdensKCa,0)

$s.set_param(d4.length,1800)
$s.set_param(d4.diameter,8.82)
$s.set_param(d4.GdensKdr,0)
$s.set_param(d4.GdensNa,0)
$s.set_param(d4.Gdensleak,0.0005)
$s.set_param(d4.GdensCaN,0)
$s.set_param(d4.GdensCaL,0)
$s.set_param(d4.GdensKCa,0)

$s.runfor(1)
$s.set_param(soma.Iapp,15)
$s.runfor(5)
$s.set_param(soma.Iapp,0)
$s.runfor(4)

calc([a,b] = max($s.traces.inseg.Vm))
$maxVmInseg = calc(a)
$maxtInseg = calc($s.traces.t(b))

calc([a,b] = max($s.traces.soma.Vm))
$maxVmSoma = calc(a)
$maxtSoma = calc($s.traces.t(b))

calc([a,b] = max($s.traces.d1.Vm))
$maxVmd1 = calc(a)
$maxtd1 = calc($s.traces.t(b))

calc([a,b] = max($s.traces.d2.Vm))
$maxVmd2 = calc(a)
$maxtd2 = calc($s.traces.t(b))

calc([a,b] = max($s.traces.d3.Vm))
$maxVmd3 = calc(a)
$maxtd3 = calc($s.traces.t(b))

calc([a,b] = max($s.traces.d4.Vm))
$maxVmd4 = calc(a)
$maxtd4 = calc($s.traces.t(b))

assert($maxVmInseg == 26.997)
assert($maxVmSoma == 21.775)
assert($maxVmd1 == -49.038)
assert($maxVmd2 == -61.91)
assert($maxVmd3 == -68.663)
assert($maxVmd4 == -69.774)

assert($maxtInseg == 3.7678)
assert($maxtSoma == 3.7721)
assert($maxtd1 == 4.3923)
assert($maxtd2 == 4.8859)
assert($maxtd3 == 5.7267)
assert($maxtd4 == 6.8268)

assertion_report