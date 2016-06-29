"""
ITERATIVE HARD THRESHOLDING

    iht(b,x,y,k,g) -> (Float, Int)

This function computes a hard threshold update

    b = P_Sk(b0 + mu*x'*(y - x*b0))

where `mu` is the step size (or learning rate) and P_Sk denotes the projection onto the set S_k defined by

S_k = { x in R^p : || x ||_0 <= k }.

The projection in question preserves the largest `k` components of `b` in magnitude, and it sends the remaining
`p - k` components to zero. This update is intimately related to a projected gradient step used in Landweber iteration.
Unlike the Landweber method, this function performs a line search on `mu` whenever the step size exceeds a specified
threshold `omega` given by

    omega = sumabs2(b - b0) / sumabs2(x*(b - b0))

By backtracking on `mu`, this function guarantees a stable estimation of a sparse `b`.
This function is based on the [HardLab](http://www.personal.soton.ac.uk/tb1m08/sparsify/sparsify.html/) demonstration code written in MATLAB by Thomas Blumensath.

Arguments:

- `b` is the iterate of `p` model components.
- `x` is the `n` x `p` design matrix.
- `y` is the vector of `n` responses.
- `k` is the model size.
- `g` is the negative gradient `x'*(y - x*b)`.

Optional Arguments:

- `n` is the number of samples. Defaults to `length(y)`.
- `p` is the number of predictors. Defaults to `length(b)`.
- `b0` is the previous iterate beta. Defaults to `copy(b)`.
- `xb` = `x*b`.
- `xb0` = `x*b0`. Defaults to `copy(xb)`.
- `xk` stores the `k` columns of `x` corresponding to the support of `b`.
- `gk` stores the `k` components of the gradient `g` with the support of `b`.
- `xgk` = `x*gk`. Defaults to `zeros(n)`.
- `sortidx` stores the indices that sort `b`. Defaults to `collect(1:p)`.
- `v.idx` is a `BitArray` indicating the nonzero status of components of `b`. Defaults to `falses(p)`.
- `v.idx0` = `copy(v.idx0)`.
- iter is the current iteration count in the IHT algorithm. Defaults to `1`.
- max_step is the maximum permissible number of backtracking steps. Defaults to `50`.

Output:

- `mu` is the step size used to update `b`, after backtracking.`
- `mu_step` is the number of backtracking steps used on `mu`.
"""
function iht!{T <: Float}(
    v     :: IHTVariables{T},
    x     :: DenseMatrix{T},
    y     :: DenseVector{T},
    k     :: Int;
    iter  :: Int = 1,
    nstep :: Int = 50,
)

    # which components of beta are nonzero?
    update_indices!(v.idx, v.b)

    # if current vector is 0,
    # then take largest elements of d as nonzero components for b
    if sum(v.idx) == 0
        a = select(v.df, k, by=abs, rev=true)
#        threshold!(v.idx, g, abs(a), n=p)
        v.idx[abs(v.df) .>= abs(a)-2*eps()] = true
    end

    # store relevant columns of x
    # need to do this on 1st iteration
    # afterwards, only do if support changes
    if !isequal(v.idx, v.idx0) || iter < 2
        update_xk!(v.xk, x, v.idx)   # xk = x[:,v.idx]
    end

    # store relevant components of gradient
    fill_perm!(v.gk, v.df, v.idx)    # gk = g[v.idx]

    # now compute subset of x*g
    BLAS.gemv!('N', one(T), v.xk, v.gk, zero(T), v.xgk)

    # compute step size
    mu = sumabs2(sdata(v.gk)) / sumabs2(sdata(v.xgk))
    isfinite(mu) || throw(error("Step size is not finite, is active set all zero?"))

    # take gradient step
    BLAS.axpy!(mu, sdata(v.df), sdata(v.b))

    # preserve top k components of b
    project_k!(v.b, k)

    # which indices of new beta are nonzero?
    copy!(v.idx0, v.idx)
    update_indices!(v.idx, v.b)

    # must correct for equal entries at kth pivot of b
    # this is a total hack! but matching magnitudes are very rare
    # should not drastically affect performance, esp. with big data
    # hack randomly permutes indices of duplicates and retains one 
    if sum(v.idx) > k 
        a = select(v.b, k, by=abs, rev=true)          # compute kth pivot
        dupes = abs(v.b) .== abs(a)
        duples = find(dupes)    # find duplicates
        c = randperm(length(duples))                # shuffle 
        d = duples[c[2:end]]                        # permute, clipping top 
        v.b[d] = zero(T)                              # zero out duplicates
        v.idx[d] = false                              # set corresponding indices to false
    end 

    # update xb
    update_xb!(v.xb, x, v.b, v.idx, k)

    # calculate omega
    omega_top = sqeuclidean(sdata(v.b), v.b0)
    omega_bot = sqeuclidean(sdata(v.xb), v.xb0)

    # backtrack until mu sits below omega and support stabilizes
    mu_step = 0
    while mu*omega_bot > 0.99*omega_top && sum(v.idx) != 0 && sum(v.idx $ v.idx0) != 0 && mu_step < nstep 

        # stephalving
        mu /= 2

        # recompute gradient step
        copy!(v.b,v.b0)
        BLAS.axpy!(mu, sdata(v.df), sdata(v.b))

        # recompute projection onto top k components of b
        project_k!(v.b, k)

        # which indices of new beta are nonzero?
        update_indices!(v.idx, v.b)

        # must correct for equal entries at kth pivot of b
        # this is a total hack! but matching magnitudes are very rare
        # should not drastically affect performance, esp. with big data
        # hack randomly permutes indices of duplicates and retains one 
        if sum(v.idx) > k 
            a = select(v.b, k, by=abs, rev=true)          # compute kth pivot
            dupes = abs(v.b) .== abs(a)
            duples = find(dupes)    # find duplicates
            c = randperm(length(duples))                # shuffle 
            d = duples[c[2:end]]                        # permute, clipping top 
            v.b[d] = zero(T)                             # zero out duplicates
            v.idx[d] = false                              # set corresponding indices to false
        end 

        # recompute xb
        update_xb!(v.xb, x, v.b, v.idx, k)

        # calculate omega
        omega_top = sqeuclidean(sdata(v.b), v.b0)
        omega_bot = sqeuclidean(sdata(v.xb), v.xb0)

        # increment the counter
        mu_step += 1
    end

    return mu, mu_step
end

"""
L0 PENALIZED LEAST SQUARES REGRESSION

    L0_reg(x,y,k) -> Dict{ASCIIString,Any}

This routine minimizes the loss function

    0.5*sumabs2( y - x*b )

subject to `b` lying in the set S_k = { x in R^p : || x ||_0 <= k }.

It uses Thomas Blumensath's iterative hard thresholding framework to keep `b` feasible.

Arguments:

- `x` is the `n` x `p` data matrix.
- `y` is the `n`-dimensional continuous response vector.
- `k` is the desired model size (support).

Optional Arguments:

- `b` is the statistical model. Warm starts should use this argument. Defaults `zeros(p)`, the null model.
- `max_iter` is the maximum number of iterations for the algorithm. Defaults to `1000`.
- `max_step` is the maximum number of backtracking steps for the step size calculation. Defaults to `50`.
- `tol` is the global tolerance. Defaults to `1e-4`.
- `quiet` is a `Bool` that controls algorithm output. Defaults to `true` (no output).
- several temporary arrays for intermediate steps of algorithm calculations:

    Xk        = zeros(T,n,k)  # store k columns of X
    b0        = zeros(T,p)    # previous iterate beta0
    df        = zeros(T,p)    # (negative) gradient
    r         = zeros(T,n)    # for || Y - XB ||_2^2
    Xb        = zeros(T,n)    # X*beta
    Xb0       = zeros(T,n)    # X*beta0
    tempn     = zeros(T,n)    # temporary array of n floats
    gk        = zeros(T,k)    # another temporary array of k floats
    indices   = collect(1:p)        # indices that sort beta
    support   = falses(p)           # indicates nonzero components of beta
    support0  = copy(support)       # store previous nonzero indicators

Outputs are wrapped into a `Dict{ASCIIString,Any}` with the following fields:

- 'time' is the compute time for the algorithm. Note that this does not account for time spent initializing optional argument defaults.
- 'iter' is the number of iterations that the algorithm took before converging.
- 'loss' is the optimal loss (half of residual sum of squares) at convergence.
- 'beta' is the final estimate of `b`.
"""
function L0_reg{T <: Float}(
    x         :: DenseMatrix{T},
    y         :: DenseVector{T},
    k         :: Int;
    temp      :: IHTVariables{T}  = IHTVariables(x, y, k),
    tol       :: Float            = convert(T, 1e-4),
    max_iter  :: Int              = 100,
    max_step  :: Int              = 50,
    quiet     :: Bool             = true
)

    # start timer
    tic()

    # first handle errors
    k        >= 0     || throw(ArgumentError("Value of k must be nonnegative!\n"))
    max_iter >= 0     || throw(ArgumentError("Value of max_iter must be nonnegative!\n"))
    max_step >= 0     || throw(ArgumentError("Value of max_step must be nonnegative!\n"))
    tol      >  eps() || throw(ArgumentError("Value of global tol must exceed machine precision!\n"))

    # initialize return values
    mm_iter   = 0                 # number of iterations of L0_reg
    mm_time   = zero(T)           # compute time *within* L0_reg
    next_obj  = zero(T)           # objective value
    next_loss = zero(T)           # loss function value

    # initialize floats
    current_obj = oftype(tol,Inf) # tracks previous objective function value
    the_norm    = zero(T)         # norm(b - b0)
    scaled_norm = zero(T)         # the_norm / (norm(b0) + 1)
    mu          = zero(T)         # Landweber step size, 0 < tau < 2/rho_max^2

    # initialize integers
    i       = 0                   # used for iterations in loops
    mu_step = 0                   # counts number of backtracking steps for mu

    # initialize booleans
    converged = false             # scaled_norm < tol?

    # update X*beta
    if sum(temp.idx) == 0
        fill!(temp.xb, zero(T))
    else
        update_indices!(temp.idx, temp.b)
        update_xb!(temp.xb, x, temp.b, temp.idx, k)
    end

    # update r and gradient
    difference!(temp.r, y, temp.xb)
    BLAS.gemv!('T', one(T), x, temp.r, zero(T), temp.df)

    # update loss and objective
    next_loss = oftype(tol,Inf)

    # formatted output to monitor algorithm progress
    if !quiet
         println("\nBegin MM algorithm\n")
         println("Iter\tHalves\tMu\t\tNorm\t\tObjective")
         println("0\t0\tInf\t\tInf\t\tInf")
    end

    # main loop
    for mm_iter = 1:max_iter

        # notify and break if maximum iterations are reached.
        if mm_iter >= max_iter

            if !quiet
                print_with_color(:red, "MM algorithm has hit maximum iterations $(max_iter)!\n")
                print_with_color(:red, "Current Objective: $(current_obj)\n")
            end

            # send elements below tol to zero
            threshold!(temp.b, tol)

            # stop timer
            mm_time = toq()

            # these are output variables for function
            # wrap them into a Dict and return
            output = Dict{ASCIIString, Any}("time" => mm_time, "loss" => next_loss, "iter" => mm_iter, "beta" => copy(temp.b))

            return output
        end

        # save values from previous iterate
        copy!(temp.b0, temp.b)             # b0 = b
        copy!(temp.xb0, temp.xb)           # Xb0 = Xb
        current_obj = next_obj

        # now perform IHT step
        (mu, mu_step) = iht!(temp, x, y, k, nstep=max_step, iter=mm_iter) 

        # the IHT kernel gives us an updated x*b
        # use it to recompute residuals and gradient
        difference!(temp.r, y, temp.xb)
        BLAS.gemv!('T', one(T), x, temp.r, zero(T), temp.df)

        # update loss, objective, and gradient
        next_loss = sumabs2(temp.r) / 2

        # guard against numerical instabilities
        isnan(next_loss) && throw(error("Loss function is NaN, something went wrong..."))
        isinf(next_loss) && throw(error("Loss function is NaN, something went wrong..."))

        # track convergence
        the_norm    = chebyshev(temp.b, temp.b0)
        scaled_norm = the_norm / ( norm(temp.b0,Inf) + 1)
        converged   = scaled_norm < tol

        # output algorithm progress
        quiet || @printf("%d\t%d\t%3.7f\t%3.7f\t%3.7f\n", mm_iter, mu_step, mu, the_norm, next_loss)

        # check for convergence
        # if converged and in feasible set, then algorithm converged before maximum iteration
        # perform final computations and output return variables
        if converged

            # send elements below tol to zero
            threshold!(temp.b, tol)

            # stop time
            mm_time = toq()

            if !quiet
                println("\nMM algorithm has converged successfully.")
                println("MM Results:\nIterations: $(mm_iter)")
                println("Final Loss: $(next_loss)")
                println("Total Compute Time: $(mm_time)")
            end

            # these are output variables for function
            # wrap them into a Dict and return
            output = Dict{ASCIIString, Any}("time" => mm_time, "loss" => next_loss, "iter" => mm_iter, "beta" => copy(temp.b))

            return output
        end

        # algorithm is unconverged at this point.
        # if algorithm is in feasible set, then rho should not be changing
        # check descent property in that case
        # if rho is not changing but objective increases, then abort
        if next_obj > current_obj + tol
            if !quiet
                print_with_color(:red, "\nMM algorithm fails to descend!\n")
                print_with_color(:red, "MM Iteration: $(mm_iter)\n")
                print_with_color(:red, "Current Objective: $(current_obj)\n")
                print_with_color(:red, "Next Objective: $(next_obj)\n")
                print_with_color(:red, "Difference in objectives: $(abs(next_obj - current_obj))\n")
            end

            throw(error("Descent failure!"))
#            output = Dict{ASCIIString, Any}("time" => -1.0, "loss" => -1.0, "iter" => -1, "beta" => fill!(b,Inf))
#            return output
        end
    end # end main loop
end # end function

"""
COMPUTE AN IHT REGULARIZATION PATH FOR LEAST SQUARES REGRESSION

    iht_path(x,y,path) -> SparseCSCMatrix

This subroutine computes best linear models for matrix `x` and response `y` by calling `L0_reg` for each model over a regularization path denoted by `path`.

Arguments:

- `x` is the `n` x `p` design matrix.
- `y` is the `n`-vector of responses.
- `path` is an `Int` vector that contains the model sizes to test.

Optional Arguments:

- `b` is the `p`-vector of effect sizes. This argument permits warmstarts to the path computation. Defaults to `zeros(p)`.
- `tol` is the global convergence tolerance for `L0_reg`. Defaults to `1e-4`.
- `max_iter` caps the number of iterations for the algorithm. Defaults to `1000`.
- `max_step` caps the number of backtracking steps in the IHT kernel. Defaults to `50`.
- `quiet` is a Boolean that controls the output. Defaults to `true` (no output).

Output:

- a sparse `p` x `length(path)` matrix where each column contains the computed model for each component of `path`.
"""
function iht_path{T <: Float}(
    x        :: DenseMatrix{T},
    y        :: DenseVector{T},
    path     :: DenseVector{Int};
    tol      :: Float          = convert(T, 1e-4),
    max_iter :: Int            = 1000,
    max_step :: Int            = 50,
    quiet    :: Bool           = true
)

    # size of problem?
    (n,p) = size(x)
    b = zeros(T, p)

    # how many models will we compute?
    num_models = length(path)

    # preallocate space for intermediate steps of algorithm calculations
    temp  = IHTVariables(x, y, 1)
    betas = spzeros(T, p, num_models)  # a matrix to store calculated models

    # compute the path
    for i = 1:num_models

        # model size?
        q = path[i]

        # monitor progress
        quiet || print_with_color(:blue, "Computing model size $q.\n\n")

        # store projection of beta onto largest k nonzeroes in magnitude
        project_k!(temp.b, q)

        # these arrays change in size from iteration to iteration
        # we must allocate them for every new model size
        update_variables!(temp, x, q)

        # now compute current model
        output = L0_reg(x, y, q, temp=temp, tol=tol, max_iter=max_iter, max_step=max_step, quiet=quiet)

        # extract and save model
        copy!(b, output["beta"])
        betas[:,i] = sparsevec(b)
    end

    # return a sparsified copy of the models
    return betas
end
