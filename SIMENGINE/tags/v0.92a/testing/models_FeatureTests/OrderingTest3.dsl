model (x)=Sub(step)
    state x = 0
    equation x' = step
end

model (y)=OrderingTest3

    submodel Sub s1
    submodel Sub s2 with {step=s1.x}    
    s1.step = s2.x

    output y = (s1.x, s2.x)
    t {solver=forwardeuler{dt=1}}
end
