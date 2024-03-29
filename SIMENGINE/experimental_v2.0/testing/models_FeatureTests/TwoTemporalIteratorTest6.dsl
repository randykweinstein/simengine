model (y1,y2)=TwoTemporalIteratorTest6

    iterator t1 with {continuous, solver=forwardeuler{dt=10}}
    iterator t2 with {continuous, solver=rk4{dt=3}}
    state x1 = 0 with {iter=t1}
    state x2 = 0 with {iter=t2}
    
    equation x1' = 1
    equation x2' = 2

    output y1[t1] = (x1, x2)
    output y2[t2] = (x1, x2)

end
