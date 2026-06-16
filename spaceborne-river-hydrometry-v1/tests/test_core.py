"""Basic tests. Author: Xuanwei Xing."""
import numpy as np
from spaceborne_hydrometry.smcbam import SMCBAMParameters, estimate_discharge

def test_discharge_increases_with_width():
    p=SMCBAMParameters(20,.55,.2,.35,35,2.8,1.5,.0015,.035,.68,1)
    q=estimate_discharge(np.array([5.,10.,20.]),.25,p)
    assert np.all(np.diff(q)>0)

def test_dry_state_is_zero():
    p=SMCBAMParameters(20,.55,.2,.35,35,2.8,1.5,.0015,.035,.68,1)
    q=estimate_discharge([5.,10.],[.25,.25],p,[True,False])
    assert q[0]>0 and q[1]==0
