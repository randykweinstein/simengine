model (y)=Fcn(x)
    equation z[t] = x^2

    output y = z
end

model (y, z)=AlgebraicSubModelTest5

    state x1 = 0
    equation x1' = 1

    submodel Fcn f with {x=x1}

    output y = f.y
    output z = x1
    t {solver=forwardeuler{dt=1}}
end
