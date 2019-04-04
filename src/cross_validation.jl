
"""
THIS FUNCTION DOES NOT WORK YET! THERE'S A BUG SOMEWHERE CAUSING CONVERGENCE ISSUES. 
Running this function with 1 thread vs 8 threads should return the same answer, but currently not. 

This function runs q-fold cross-validation across a specified regularization path in a 
maximum of 2n parallel threads, where n is the number of CPU cores available.  

Important arguments and defaults include:
- `x` is the genotype matrix
- `z` is the matrix of non-genetic covariates (which includes the intercept as the first column)
- `y` is the response (phenotype) vector
- `J` is the maximum allowed active groups. 
- `path` is vector of model sizes k1, k2...etc. IHT will compute all model sizes on each fold.
- `folds` a vector of integers, with the same length as the number predictor, indicating a partitioning of the samples into q disjoin subsets
- `num_folds` indicates how many disjoint subsets the samples are partitioned into. 
- `use_maf` whether IHT wants to scale predictors using their minor allele frequency. This is experimental feature
"""
function cv_iht(
    d        :: UnivariateDistribution,
    l        :: Link,
    x        :: SnpArray,
    z        :: AbstractMatrix{T},
    y        :: AbstractVector{T},
    J        :: Int64,
    path     :: DenseVector{Int},
    folds    :: DenseVector{Int},
    num_fold :: Int64;
    use_maf  :: Bool = false,
    debias   :: Bool = false,
    showinfo :: Bool = true,
) where {T <: Float}

    # how many elements are in the path?
    nmodels = length(path)

    # compute folds
    mses = pfold(d, l, x, z, y, J, path, folds, num_fold, use_maf=use_maf, debias=debias)

    # find best model size and print cross validation result
    k = path[argmin(mses)] :: Int
    showinfo && print_cv_results(mses, path, k)

    return mses
end

"""
Wrapper function for one_fold. Returns the averaged MSE for each fold of cross validation.
mse[i, j] stores the ith model size for fold j. Thus to obtain the mean mse for each fold, 
we take average along the rows and find the minimum.  
"""
function pfold(d::UnivariateDistribution, l::Link, x::SnpArray, z::AbstractMatrix{T},
            y::AbstractVector{T}, J::Int64, path::DenseVector{Int}, folds::DenseVector{Int},
            num_fold::Int64; use_maf::Bool = false, debias::Bool = false) where {T <: Float}
    @assert num_fold >= 1 "number of folds must be positive integer"

    mses = zeros(T, length(path), num_fold)
    for fold in 1:num_fold
        mses[:, fold] = one_fold(d, l, x, z, y, J, path, folds, fold, use_maf=use_maf, debias=debias)
    end
    return vec(sum(mses, dims=2) ./ num_fold)
end

"""
Single threaded version of iht_path_threaded. This function computes and stores different 
models in each column of the matrix `betas` and matrix `cs`. 
"""
function iht_path(
    d         :: UnivariateDistribution,
    l         :: Link,
    x         :: SnpArray,
    xbm       :: SnpBitMatrix,
    z         :: AbstractMatrix{T},
    y         :: AbstractVector{T},
    J         :: Int64,
    path      :: DenseVector{Int},
    fold      :: Int64,
    train_idx :: BitArray;
    use_maf   :: Bool  = false,
    debias    :: Bool  = false,
    tol       :: T    = convert(T, 1e-4),
    max_iter  :: Int  = 100,
    max_step  :: Int  = 3,
) where {T <: Float}

    # size of problem?
    n, p = size(x)
    q    = size(z, 2) #number of non-genetic covariates

    # how many models will we compute?
    nmodels = length(path)

    # Initialize vector of matrices to hold a separate matrix for each thread to access. This makes everything thread-safe
    betas  = spzeros(T, p, nmodels)
    cs     = zeros(T, q, nmodels)

    # compute the specified paths
    for i = 1:nmodels

        # current thread?
        cur_thread = Threads.threadid()

        # current model size?
        k = path[i]

        # now compute current model
        output = L0_reg(x, xbm, z, y, J, k, d, l, debias=debias, init=false, use_maf=use_maf)

        # put model into sparse matrix of betas
        betas[:, i] .= sparsevec(output.beta)
        cs[:, i] .= output.c
    end

    # reduce the vector of matrix into a single matrix, where each column stores a different model 
    return sum(betas), sum(cs)
end

"""
Multi-threaded version of `iht_path`. Each thread writes to a different matrix of betas
and cs, and the reduction step is to sum all these matrices. The increase in memory usage 
increases linearly with the number of paths, which is negligible as long as the number of 
paths is reasonable (e.g. less than 100). 
"""
function iht_path_threaded(
    d         :: UnivariateDistribution,
    l         :: Link,
    x         :: SnpArray,
    xbm       :: SnpBitMatrix,
    z         :: AbstractMatrix{T},
    y         :: AbstractVector{T},
    J         :: Int64,
    path      :: DenseVector{Int},
    fold      :: Int64,
    train_idx :: BitArray;
    use_maf   :: Bool  = false,
    debias    :: Bool  = false,
    tol       :: T    = convert(T, 1e-4),
    max_iter  :: Int  = 100,
    max_step  :: Int  = 3,
) where {T <: Float}
    
    # number of threads available?
    num_threads = Threads.nthreads()

    # size of problem?
    n, p = size(x)
    q    = size(z, 2) #number of non-genetic covariates

    # how many models will we compute?
    nmodels = length(path)

    # Initialize vector of matrices to hold a separate matrix for each thread to access. This makes everything thread-safe
    betas = [zeros(p, nmodels) for i in 1:num_threads]
    cs    = [zeros(q, nmodels) for i in 1:num_threads]

    # compute the specified paths
    Threads.@threads for i = 1:nmodels

        # current thread?
        cur_thread = Threads.threadid()

        # current model size?
        k = path[i]

        # now compute current model
        output = L0_reg(x, xbm, z, y, J, k, d, l, debias=debias, init=false, use_maf=use_maf, show_info=true)

        # put model into sparse matrix of betas in the corresponding thread
        betas[cur_thread][:, i] = output.beta
        cs[cur_thread][:, i]    = output.c
    end

    # reduce the vector of matrix into a single matrix, where each column stores a different model 
    return sum(betas), sum(cs)
end

"""
In cross validation we separate samples into `q` disjoint subsets. This function fits a model on 
q-1 of those sets (indexed by train_idx), and then tests the model's performance on the 
qth set (indexed by test_idx). We loop over all sparsity level specified in `path` and 
returns the out-of-sample errors in a vector. 

- `path` , a vector of various model sizes
- `folds`, a vector indicating which of the q fold each sample belongs to. 
- `fold` , the current fold that is being used as test set. 
"""
function one_fold(
    d        :: UnivariateDistribution,
    l        :: Link,
    x        :: SnpArray,
    z        :: AbstractMatrix{T},
    y        :: AbstractVector{T},
    J        :: Int64,
    path     :: DenseVector{Int},
    folds    :: DenseVector{Int}, 
    fold     :: Int;
    use_maf  :: Bool = false,
    debias   :: Bool = false,
    showinfo :: Bool = true,
    tol      :: T    = convert(T, 1e-4),
    max_iter :: Int  = 100,
    max_step :: Int  = 3,
) where {T <: Float}
    # dimensions of problem
    n, p = size(x)
    q    = size(z, 2)

    # find entries that are for test sets and train sets
    test_idx  = folds .== fold
    train_idx = .!test_idx

    # allocate test model
    # x_test = SnpArray("x_test_fold$fold.bed", sum(test_idx), p)
    x_test = SnpArray(undef, sum(test_idx), p)
    copyto!(x_test, @view(x[test_idx, :]))
    y_test = y[test_idx]
    z_test = z[test_idx, :]
    x_testbm = SnpBitMatrix{Float64}(x_test, model=ADDITIVE_MODEL, center=true, scale=true); 

    # Construct the training datas (it appears I must make the training data sets inside the threaded for loop. Not sure why. Perhaps to avoid thread access issues even though I shouldn't have any)
    # tmp_bed_file = "x_train_fold$fold" * "_thread$cur_thread.bed"
    # x_train = SnpArray(tmp_bed_file, sum(train_idx), p)
    x_train = SnpArray(undef, sum(train_idx), p)
    copyto!(x_train, @view(x[train_idx, :]))
    y_train = y[train_idx]
    z_train = z[train_idx, :]
    x_trainbm = SnpBitMatrix{Float64}(x_train, model=ADDITIVE_MODEL, center=true, scale=true); 

    # compute the regularization path on the training set
    if Threads.nthreads() > 1
        betas, cs = iht_path_threaded(d, l, x_train, x_trainbm, z_train, y_train, J, path, fold, train_idx, use_maf=use_maf, max_iter=max_iter, max_step=max_step, tol=tol, debias=debias)
    else
        betas, cs = iht_path(d, l, x_train, x_trainbm, z_train, y_train, J, path, fold, train_idx, use_maf=use_maf, max_iter=max_iter, max_step=max_step, tol=tol, debias=debias)
    end

    # preallocate arrays
    p, q = size(x, 2), size(z, 2)
    test_size = sum(test_idx)
    mse = zeros(T, length(path))
    xb = zeros(T, test_size)
    zc = zeros(T, test_size)
    μ  = zeros(T, test_size)
    b  = zeros(T, p)
    c  = zeros(T, q)

    # for each computed model stored in betas, compute the mean out-of-sample error for the test set
    for i = 1:size(betas,2)
        # pull ith model in dense vector format
        copyto!(b, @view(betas[:, i]))
        copyto!(c, @view(cs[:, i])) 

        # compute estimated response Xb: [xb zc] = [x_test z_test] * [b; c] and update mean μ = g^{-1}(xb)
        A_mul_B!(xb, zc, x_testbm, z_test, b, c) 
        update_μ!(μ, xb .+ zc, l)

        # compute sum of squared deviance residuals. For normal, this is equivalent to out-of-sample error
        mse[i] = deviance(d, y_test, μ)
    end

    #clean up
    rm("x_test_fold$fold.bed", force=true)

    return mse :: Vector{T}
end
