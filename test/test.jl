using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using StatsFuns: logistic
using Random
using LinearAlgebra

function run_poisson(n :: Int64, p :: Int64)
    #set random seed
    Random.seed!(1111)

    #simulate data
    k = 10 # number of true predictors
    bernoulli_rates = 0.5rand(p) #minor allele frequencies are drawn from uniform (0, 0.5)
    x = simulate_random_snparray(n, p, bernoulli_rates)
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 

    #construct snpmatrix, covariate files, and true model b
    z           = ones(n, 1)                   # non-genetic covariates, just the intercept
    true_b      = zeros(p)                     # model vector
    true_b[1:k] = randn(k)                     # Initialize k non-zero entries in the true model
    shuffle!(true_b)                           # Shuffle the entries
    correct_position = findall(x -> x != 0, true_b) # keep track of what the true entries are

    #check maf
    bernoulli_rates[correct_position]

    #simulate phenotypes under different noises by: y = Xb + noise
    y_temp = xbm * true_b

    # Simulate poisson data
    λ = exp.(y_temp) #inverse log link
    y = [rand(Poisson(x)) for x in λ]
    y = Float64.(y)

    #compute poisson IHT result
    result = L0_poisson_reg(x, z, y, 1, k, glm = "poisson", debias=false, convg=false, show_info=false)

    #check result
    estimated_models = result.beta[correct_position]
    true_model = true_b[correct_position]
    compare_model = DataFrame(
        correct_position = correct_position, 
        true_β           = true_model, 
        estimated_β      = estimated_models)
    
    #display results
    @show compare_model
    println("Total iteration number was " * string(result.iter))
    println("Total time was " * string(result.time))
end

Random.seed!(2019)
for i = 1:25
    @info("running the $i th model")
    n = rand(500:2000) 
    p = rand(1:10)n
    println("n, p = " * string(n) * ", " * string(p))
    run_poisson(n, p)
end



#some function that runs poisson regression on same SNP matrices, using different model sizes
function run_poisson()

	n, p = 2000, 20000

    #set random seed
    Random.seed!(1111)

    #simulate data
    bernoulli_rates = 0.5rand(p) #minor allele frequencies are drawn from uniform (0, 0.5)
    x = simulate_random_snparray(n, p, bernoulli_rates)
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
    z = ones(n, 1)                   # non-genetic covariates, just the intercept

    for k in 1:30
	    true_b      = zeros(p)                     # model vector
	    true_b[1:k] = randn(k)                     # Initialize k non-zero entries in the true model
	    shuffle!(true_b)                           # Shuffle the entries
	    correct_position = findall(x -> x != 0, true_b) # keep track of what the true entries are

	    #simulate phenotypes under different noises by: y = Xb + noise
	    y_temp = xbm * true_b

	    # Simulate poisson data
	    λ = exp.(y_temp) #inverse log link
	    y = [rand(Poisson(x)) for x in λ]
	    y = Float64.(y)

	    #compute poisson IHT result
	    result = L0_poisson_reg(x, z, y, 1, k, glm = "poisson", debias=false, convg=false, show_info=false)

	    #check result
	    estimated_models = result.beta[correct_position]
	    true_model = true_b[correct_position]
	    compare_model = DataFrame(
	        correct_position = correct_position, 
	        true_β           = true_model, 
	        estimated_β      = estimated_models)
    
	    #display results
	    @show compare_model
	    println("Total iteration number was " * string(result.iter))
	    println("Total time was " * string(result.time))
	end
end









function run_logistic(n :: Int64, p :: Int64, debias :: Bool)
    #set random seed
    Random.seed!(1111)

    #simulate data
    k = 10 # number of true predictors
    bernoulli_rates = 0.5rand(p) #minor allele frequencies are drawn from uniform (0, 0.5)
    x = simulate_random_snparray(n, p, bernoulli_rates)
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 

    #construct snpmatrix, covariate files, and true model b
    z           = ones(n, 1)                   # non-genetic covariates, just the intercept
    true_b      = zeros(p)                     # model vector
    true_b[1:k] = randn(k)                     # Initialize k non-zero entries in the true model
    shuffle!(true_b)                           # Shuffle the entries
    correct_position = findall(x -> x != 0, true_b) # keep track of what the true entries are

    #simulate phenotypes under different noises by: y = Xb + noise
    y_temp = xbm * true_b

    # Apply inverse logit link and sample from the vector of distributions
    prob = logistic.(y_temp) #inverse logit link
    y = [rand(Bernoulli(x)) for x in prob]
    y = Float64.(y)

    #compute logistic IHT result
    result = L0_logistic_reg(x, z, y, 1, k, glm = "logistic", debias=debias, show_info=false)

    #check result
    estimated_models = result.beta[correct_position]
    true_model = true_b[correct_position]
    compare_model = DataFrame(
        correct_position = correct_position, 
        true_β           = true_model, 
        estimated_β      = estimated_models)

    #display results
    @show compare_model
    println("n = " * string(n) * ", and p = " * string(p))
    println("Total iteration number was " * string(result.iter))
    println("Total time was " * string(result.time))
end

for i = 1:100
    println("running the $i th model")
    n = rand(500:2000) 
    p = rand(1:10)n
    debias = true
    run_logistic(n, p, debias)
end










using Revise
using Random
using LinearAlgebra
using GLMNet
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using StatsFuns: logistic
using Random
using LinearAlgebra

function iht_lasso_poisson(n :: Int64, p :: Int64)
    #set random seed
    Random.seed!(1111)

    #define maf and true model size
    bernoulli_rates = 0.5rand(p)
    k = 10

    #construct snpmatrix, covariate files, and true model b
    x = simulate_random_snparray(n, p, bernoulli_rates)
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
    z           = ones(n, 1)                   # non-genetic covariates, just the intercept
    true_b      = zeros(p)                     # model vector
    true_b[1:k] = randn(k)                     # Initialize k non-zero entries in the true model
    shuffle!(true_b)                           # Shuffle the entries
    correct_position = findall(x -> x != 0, true_b) # keep track of what the true entries are

    # Simulate poisson data
    y_temp = xbm * true_b
    λ = exp.(y_temp) #inverse log link
    y = [rand(Poisson(x)) for x in λ]
    y = Float64.(y)

    #compute poisson IHT result
    path = collect(1:15)
    num_folds = 5
    folds = rand(1:num_folds, size(x, 1))
    k_est_iht = cv_iht(x, z, y, 1, path, folds, num_folds, use_maf=false, glm="poisson", debias=false)
    iht_result = L0_poisson_reg(x, z, y, 1, k_est, glm = "poisson", debias=false, convg=false, show_info=false, true_beta=true_b)

    #compute poisson lasso result
    x_float = [convert(Matrix{Float64}, x, center=true, scale=true) z]
    cv = glmnetcv(x_float, y, Poisson(), dfmax=15, nfolds=5, folds=folds)
    best = argmin(cv.meanloss)
    lasso_result = cv.path.betas[:, best]
    k_est_lasso = length(findall(!iszero, lasso_result))

    #check result
    IHT_model = iht_result.beta[correct_position]
    lasso_model = lasso_result[correct_position]
    true_model = true_b[correct_position]
    compare_model = DataFrame(
        correct_position = correct_position, 
        true_β           = true_model, 
        iht_β            = IHT_model,
        lasso_β          = lasso_model)
    @show compare_model

    #compute summary statistics
    lasso_num_correct_predictors = findall(!iszero, lasso_model)
    lasso_false_positives = k_est_lasso - lasso_num_correct_predictors
    lasso_false_negatives = k - lasso_num_correct_predictors
    iht_num_correct_predictors = findall(!iszero, IHT_model)
    iht_false_positives = k_est_iht - iht_num_correct_predictors
    iht_false_negatives = iht_num_correct_predictors
    println("IHT: cv found " * "$k_est_iht predictors, with " * "$iht_false_positives false positives " * "and $iht_false_negatives false negatives")
    println("lasso: cv found " * "$k_est_lasso predictors, with " * "$lasso_false_positives false positives and " * "$lasso_false_negatives false negatives \n\n")

    return lasso_false_positives, lasso_false_negatives, iht_false_positives, iht_false_negatives
end


Random.seed!(2019)
lasso_false_positives = 0
lasso_false_negatives = 0 
iht_false_positives = 0
iht_false_negatives = 0
for i = 1:25
    @info("running the $i th model")
    n = rand(100:1000) 
    p = rand(1:10)n
    println("n, p = " * string(n) * ", " * string(p))
    lfp, lfn, ifp, ifn = iht_lasso_poisson(n, p)

    lasso_false_positives += lfp
    lasso_false_negatives += lfn
    iht_false_positives += ifp
    iht_false_negatives += ifn
end
println("Lasso: Total number of false positives = $lasso_false_positives")
println("Lasso: Total number of false negatives = $lasso_false_negatives")
println("IHT  : Total number of false positives = $iht_false_positives")
println("IHT  : Total number of false negatives = $iht_false_negatives")








using Revise
using GLMNet #julia wrapper for GLMNet package in R, which calls fortran
using GLM
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using StatsFuns: logistic
using Random
using LinearAlgebra
using MendelBase

n, p = 223, 2411

#set random seed
Random.seed!(1234)

#define maf and true model size
bernoulli_rates = 0.5rand(p)
k = 5

#construct snpmatrix, covariate files, and true model b
x = simulate_random_snparray(n, p, bernoulli_rates)
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z           = ones(n, 1)                   # non-genetic covariates, just the intercept
true_b      = zeros(p)                     # model vector
true_b[1:k] = randn(k)                     # Initialize k non-zero entries in the true model
shuffle!(true_b)                           # Shuffle the entries
correct_position = findall(x -> x != 0, true_b) # keep track of what the true entries are

# Simulate poisson data
y_temp = xbm * true_b
λ = exp.(y_temp) #inverse log link
y = [rand(Poisson(x)) for x in λ]
y = Float64.(y)

x_float = convert(Matrix{Float64}, x, center=true, scale=true)
x_true = [x_float[:, correct_position] z]
regular_result = glm(x_true, y, Poisson(), LogLink())
regular_result = regular_result.pp.beta0
true_model = true_b[correct_position]
compare_model = DataFrame(
    true_β  = true_model, 
    regular_β = regular_result[1:end-1])









#problem diagnosis
using DelimitedFiles
using Statistics
using Plots

#doesn't work at all
sim = 28

#works well
sim = 25
sim = 1

y = readdlm("/Users/biona001/.julia/dev/MendelIHT/docs/IHT_GLM_simulations_mean/data_simulation_$sim" * ".txt")
mean(y)
var(y)
histogram(y)







function simulate_random_snparray(
    n :: Int64,
    p :: Int64,
)
    #first simulate a random {0, 1, 2} matrix with each SNP drawn from Binomial(2, r[i])
    A1 = BitArray(undef, n, p)
    A2 = BitArray(undef, n, p)
    mafs = zeros(Float64, p)
    for j in 1:p
        minor_alleles = 0
        maf = 0
        while minor_alleles <= 5
            maf = 0.5rand()
            for i in 1:n
                A1[i, j] = rand(Bernoulli(maf))
                A2[i, j] = rand(Bernoulli(maf))
            end
            minor_alleles = sum(view(A1, :, j)) + sum(view(A2, :, j))
        end
        mafs[j] = maf
    end

    #fill the SnpArray with the corresponding x_tmp entry
    return _make_snparray(A1, A2), mafs
end

function _make_snparray(A1 :: BitArray, A2 :: BitArray)
    n, p = size(A1)
    x = SnpArray(undef, n, p)
    for i in 1:(n*p)
        c = A1[i] + A2[i]
        if c == 0
            x[i] = 0x00
        elseif c == 1
            x[i] = 0x02
        elseif c == 2
            x[i] = 0x03
        else
            throw(error("matrix shouldn't have missing values!"))
        end
    end
    return x
end









using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra

#run directly
function should_be_slow(n :: Int64, p :: Int64)
    #set random seed
    Random.seed!(1111)
    simulate_random_snparray(n, p)
end
@time should_be_slow(10000, 100000)




using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra

#run once with super small data
function should_be_fast(n :: Int64, p :: Int64)
    #set random seed
    Random.seed!(1111)
    simulate_random_snparray(n, p)
end
should_be_fast(10, 10)
@time should_be_fast(10000, 100000)







function sum_random(x :: Vector{Float64})
   s = 0.0
   for i in x
       s += i
   end
   return s
end

#lets say I really want to sum 10 million random numbers
x = rand(3 * 10^8)
@time sum_random(x) # 2.419125 seconds (22.48 k allocations: 1.161 MiB)


#Can I first run the code on a small problem, and then my larger problem?
x = rand(3 * 10^8)
y = rand(10)
@time sum_random(y) # 0.010076 seconds (22.48 k allocations: 1.161 MiB)
@time sum_random(x) # 0.324422 seconds (5 allocations: 176 bytes)









using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra
using StatsFuns: logistic

function time_normal_response(
    n :: Int64,  # number of cases
    p :: Int64,  # number of predictors (SNPs)
    k :: Int64,  # number of true predictors per group
    debias :: Bool # whether to debias
)
    Random.seed!(1111)

    #construct snpmatrix, covariate files, and true model b
    x, maf = simulate_random_snparray(n, p)
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
    z = ones(n, 1) # non-genetic covariates, just the intercept
    true_b = zeros(p)
    true_b[1:k] = randn(k)
    shuffle!(true_b)
    correct_position = findall(x -> x != 0, true_b)
    noise = rand(Normal(0, 0.1), n) # noise vectors from N(0, s) 

    #simulate phenotypes (e.g. vector y) via: y = Xb + noise
    y = xbm * true_b + noise

    #free memory from xbm.... does this work like I think it works?
    xbm = nothing
    GC.gc()

    #time the result and return
    result = @timed L0_normal_reg(x, z, y, 1, k, debias=debias)
    iter = result[1].iter
    runtime = result[2]      # seconds
    memory = result[3] / 1e6 # MB

    return iter, runtime, memory
end


#time directly:
n = 10000
p = 30000
k = 10
debias = false
iter, runtime, memory = time_normal_response(n, p, k, debias)
#(7, 17.276706309, 119.911048)

#run small example first:
n = 10000
p = 30000
k = 10
debias = false
iter, runtime, memory = time_normal_response(100, 100, 10, debias)
iter, runtime, memory = time_normal_response(n, p, k, debias)
#(14, 2.47283539, 37.778872)
#(7, 12.801054742, 82.478688)

#run same example twice:
n = 10000
p = 30000
k = 10
debias = false
iter, runtime, memory = time_normal_response(n, p, k, debias)
iter, runtime, memory = time_normal_response(n, p, k, debias)
#(7, 15.82780056, 119.911048)
#(7, 13.610244645, 82.478688)

#no GC.gc():
n = 10000
p = 30000
k = 10
debias = false
iter, runtime, memory = time_normal_response(100, 100, 10, debias)
iter, runtime, memory = time_normal_response(n, p, k, debias)
#(14, 2.661537431, 37.778872)
#(7, 12.977118564, 82.478688)





#NORMAL CROSS VALIDATION USING MEMORY MAPPED SNPARRAY - does it fix my problem?
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra
using BenchmarkTools
using Distributed

#simulat data
n = 1000
p = 10000
k = 10 # number of true predictors

#set random seed
Random.seed!(2019)

#construct snpmatrix, covariate files, and true model b
x, maf = simulate_random_snparray(n, p, "tmp.bed")
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z = ones(n, 1) # non-genetic covariates, just the intercept
true_b = zeros(p)
true_b[1:k] = randn(k)
shuffle!(true_b)
correct_position = findall(x -> x != 0, true_b)
noise = rand(Normal(0, 0.1), n) # noise vectors from N(0, s) 

#simulate phenotypes (e.g. vector y) via: y = Xb + noise
y = xbm * true_b + noise

#specify path and folds
path = collect(1:20)
num_folds = 4
folds = rand(1:num_folds, size(x, 1))

#compute cross validation
# mses = cv_iht(x, z, y, 1, path, folds, num_folds, use_maf = false, glm = "normal", debias=false)
# @time cv_iht_distributed(x, z, y, 1, path, folds, num_folds, use_maf = false, glm = "normal", debias=false, showinfo=false, parallel=true);

@benchmark cv_iht_distributed(x, z, y, 1, path, folds, num_folds, use_maf = false, glm = "normal", debias=false, showinfo=false, parallel=true) seconds=60

rm("tmp.bed", force=true)


########### LOGISTIC CROSS VALIDATION SIMULATION CODE##############
using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using StatsFuns: logistic
using BenchmarkTools
using Random
using LinearAlgebra


#simulat data
n = 1000
p = 10000
k = 10    # number of true predictors

#set random seed
Random.seed!(1111)

#construct snpmatrix, covariate files, and true model b
x, maf = simulate_random_snparray(n, p, "tmp.bed")
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z           = ones(n, 1)                   # non-genetic covariates, just the intercept
true_b      = zeros(p)                     # model vector
true_b[1:k] = randn(k)                     # k true response
shuffle!(true_b)                           # Shuffle the entries
correct_position = findall(x -> x != 0, true_b) # keep track of what the true entries are

#simulate bernoulli data
y_temp = xbm * true_b
prob = logistic.(y_temp) #inverse logit link
y = [rand(Bernoulli(x)) for x in prob]
y = Float64.(y)

#specify path and folds
path = collect(1:20)
num_folds = 3
folds = rand(1:num_folds, size(x, 1))

#compute cross validation
mses = cv_iht_test(x, z, y, 1, path, folds, num_folds, use_maf = false, glm = "logistic", debias=true)


K = collect(1:2:10)
errors = map(K) do k
    return k
end




using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra
using BenchmarkTools
using Distributed


#simulat data
n = 1000
p = 10000
k = 10 # number of true predictors

#set random seed
Random.seed!(1111)

#construct snpmatrix, covariate files, and true model b
x, maf = simulate_random_snparray(n, p, "tmp.bed")
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z = ones(n, 1) # non-genetic covariates, just the intercept
true_b = zeros(p)
true_b[1:k] = randn(k)
shuffle!(true_b)
correct_position = findall(x -> x != 0, true_b)
noise = rand(Normal(0, 0.1), n) # noise vectors from N(0, s) 

#simulate phenotypes (e.g. vector y) via: y = Xb + noise
y = xbm * true_b + noise

#run k = 1,2,....,20
path = collect(1:20)

#compute IHT result for each k in path
iht_run_many_models(x, z, y, 1, path, "normal", use_maf = false, debias=false, showinfo=false, parallel=true)







using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra
using BenchmarkTools
using Distributed
using DelimitedFiles

#simulat data
n = 1000
p = 10000
k = 10 # number of true predictors

#set random seed
Random.seed!(2019)

#construct snpmatrix, covariate files, and true model b
x, maf = simulate_random_snparray(n, p, "normal.bed")
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z = ones(n, 1) # non-genetic covariates, just the intercept
true_b = zeros(p)
true_b[1:k] = randn(k)
shuffle!(true_b)
correct_position = findall(x -> x != 0, true_b)
noise = rand(Normal(0, 0.1), n) # noise vectors from N(0, s) 

#simulate phenotypes (e.g. vector y) via: y = Xb + noise
y = xbm * true_b + noise

#specify path and folds
path = collect(1:20)
num_folds = 5
folds = rand(1:num_folds, size(x, 1))

# convert and save floating point version of the genotype matrix for glmnet
x_float = [convert(Matrix{Float64}, x, center=true, scale=true) z]
writedlm("x_float", x_float)
writedlm("y", y)
writedlm("folds", folds)




# trying GLM's fitting function
Random.seed!(2019)
n = 1000000
p = 10
x = randn(n, p)
b = randn(p)
L = LogitLink()

#simulate bernoulli data
y_temp = x * b
prob = linkinv.(L, y_temp) #inverse logit link
y = [rand(Bernoulli(i)) for i in prob]
y = Float64.(y)

glm_result = fit(GeneralizedLinearModel, x, y, Bernoulli(), L)
hi = glm_result.pp.beta0

glm_result_old = regress(x, y, "logistic")
hii = glm_result_old[1]

[b hi hii]






#deviance residual vs y - xb

function run_once()
    n = 1000
    p = 10000
    k = 10
    d = Poisson
    l = canonicallink(d())

    #construct snpmatrix, covariate files, and true model b
    x, maf = simulate_random_snparray(n, p, "tmp.bed")
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
    z = ones(n, 1) # the intercept
    true_b = zeros(p)
    d == Poisson ? true_b[1:k] = rand(Normal(0, 0.3), k) : true_b[1:k] = randn(k)
    shuffle!(true_b)
    correct_position = findall(x -> x != 0, true_b)

    #simulate phenotypes (e.g. vector y) via: y = Xb + noise
    y_temp = xbm * true_b
    prob = linkinv.(l, y_temp)
    y = [rand(d(i)) for i in prob]
    y = Float64.(y)

    #run IHT
    result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, show_info=false, convg=true)

    #clean up
    rm("tmp.bed", force=true)

    found = length(findall(!iszero, result.beta[correct_position]))
    runtime = result.time

    return found, runtime
end

#set random seed
Random.seed!(1111)
function run()
    total_found = 0
    total_time = 0
    for i in 1:30
        f, t = run_once()
        total_found += f
        total_time += t
        println("finished $i run")
    end
    avg_found = total_found / 30
    avg_time = total_time / 30
    println(avg_found)
    println(avg_time)
end
run()





function loglik_obs(::Normal, y, μ, wt, ϕ) #this is wrong
    return wt*logpdf(Normal(μ, sqrt(ϕ)), y)
end

function test()
    y, mu = rand(1000), rand(1000)
    ϕ = MendelIHT.deviance(Normal(), y, mu)/length(y)
    ϕ = 1.0
    logl = 0.0
    for i in eachindex(y, mu)
        logl += loglik_obs(Normal(), y[i], mu[i], 1, ϕ)
    end
    println(logl)

    println(loglikelihood(Normal(), y, mu))
end
test() 






b = result.beta
μ = linkinv.(l, xbm*b)
# sum(logpdf.(Poisson.(μ), y))
loglikelihood(Poisson(), y, xbm*b)
loglikelihood_test(Poisson(), y, μ)









#debugging malloc: Incorrect checksum for freed object
using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra
using GLM

#simulat data with k true predictors, from distribution d and with link l.
n = 1000
p = 10000
k = 10
d = Normal
l = canonicallink(d())

#set random seed
Random.seed!(1111)

#construct snpmatrix, covariate files, and true model b
x, maf = simulate_random_snparray(n, p, "tmp.bed")
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z = ones(n, 1) # the intercept
true_b = zeros(p)
d == Poisson ? true_b[1:k] = rand(Normal(0, 0.3), k) : true_b[1:k] = randn(k)
shuffle!(true_b)
correct_position = findall(x -> x != 0, true_b)

#simulate phenotypes (e.g. vector y) 
y_temp = xbm * true_b
prob = linkinv.(l, y_temp)
y = [rand(d(i)) for i in prob]
y = Float64.(y)

#run IHT
result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, show_info=false, convg=true)

train_idx = bitrand(n)
path = collect(1:20)

p, q = size(x, 2), size(z, 2)
nmodels = length(path)
betas = zeros(p, nmodels)
cs = zeros(q, nmodels)

x_train = SnpArray(undef, sum(train_idx), p)
copyto!(x_train, @view x[train_idx, :])
y_train = @view(y[train_idx])
z_train = @view(z[train_idx, :])
x_trainbm = SnpBitMatrix{Float64}(x_train, model=ADDITIVE_MODEL, center=true, scale=true); 

k = path[1]
debias = false
showinfo = false
d = d()
result = L0_reg(x_train, x_trainbm, z_train, y_train, 1, k, d, l, debias=debias, init=false, show_info=showinfo, convg=true)





#simulate correlated columns


n = 1000
p = 10000
k = 10
d = Bernoulli
l = canonicallink(d())

#set random seed
Random.seed!(1111)

#construct snpmatrix, covariate files, and true model b
x, = simulate_random_snparray(n, p, "tmp.bed")

#ad hoc method to construct correlated columns
c = 0.9
for i in 1:size(x, 1)
    prob = rand(Bernoulli(c))
    prob == 1 && (x[i, 2] = x[i, 1]) #make 2nd column the same as first column 90% of the time
end

tmp = convert(Matrix{Float64}, @view(x[:, 1:2]), center=true, scale=true)
cor(tmp[:, 1], tmp[:, 2])








#testing if IHT finds intercept and/or nongenetic covariates, normal response
using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using BenchmarkTools
using Random
using LinearAlgebra
using GLM

#simulat data with k true predictors, from distribution d and with link l.
n = 1000
p = 10000
k = 10
d = Normal
l = canonicallink(d())

#set random seed
Random.seed!(1111)

#construct snpmatrix, covariate files, and true model b
x, = simulate_random_snparray(n, p, "tmp.bed")
xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
z = ones(n, 2) # the intercept
z[:, 2] .= randn(n)

#define true_b and true_c
true_b = zeros(p)
true_b[1:k-2] = randn(k-2)
shuffle!(true_b)
correct_position = findall(!iszero, true_b)
true_c = [0.1; 0.1]

#simulate phenotype
prob = linkinv.(l, xbm * true_b .+ z * true_c)
y = [rand(d(i)) for i in prob]

#run result
result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, use_maf=false)

#compare with correct answer
compare_model = DataFrame(
    position    = correct_position,
    true_β      = true_b[correct_position], 
    estimated_β = result.beta[correct_position])

compare_model = DataFrame(
    true_c      = true_c[1:2], 
    estimated_c = result.c[1:2])





using BenchmarkTools
using Random

function test(z::Matrix{Float64})
    for i in 2:size(z, 2)
        col_mean = mean(z[:, i])
        col_std  = std(z[:, i])
        z[:, i] .= (z[:, i] .- col_mean) ./ col_std
    end
end
#memory estimate:  23.23 MiB
#allocs estimate:  2997
#median time:      8.278 ms (26.30% GC)

function test2(z::Matrix{Float64})
    n, q = size(z)
    for j in 2:q
        μ = 0.0
        for i in 1:n
            μ += z[i, j]
        end
        μ /= n
        σ = 0.0
        for i in 1:n
            σ += (z[i, j] - μ)^2
        end
        σ = sqrt(σ / (n - 1))
        for i in 1:n
            z[i, j] = (z[i, j] - μ) / σ
        end
    end
end
#memory estimate:  0 bytes
#allocs estimate:  0
#median time:      5.629 ms (0.00% GC)

function test3(z::Matrix{Float64})
    n, q = size(z)
    @inbounds for j in 2:q
        μ = 0.0
        @simd for i in 1:n
            μ += z[i, j]
        end
        μ /= n
        σ = 0.0
        for i in 1:n
            σ += (z[i, j] - μ)^2
        end
        σ = sqrt(σ / (n - 1))
        for i in 1:n
            z[i, j] = (z[i, j] - μ) / σ
        end
    end
end
#memory estimate:  0 bytes
#allocs estimate:  0
#median time:      3.289 ms (0.00% GC)

@inline function test4(z::Matrix{Float64})
    n, q = size(z)
    μ = _mean(z)
    σ = _std(z, μ)

    @inbounds for j in 1:q
        @simd for i in 1:n
            z[i, j] = (z[i, j] - μ[j]) * σ[j]
        end
    end
end
#memory estimate:  15.88 KiB
#allocs estimate:  2
#median time:      1.918 ms (0.00% GC)

@inline function _mean(z::Matrix{Float64})
    n, q = size(z)
    μ = zeros(q)
    @inbounds for j in 1:q
        tmp = 0.0
        @simd for i in 1:n
            tmp += z[i, j]
        end
        μ[j] = tmp / n
    end
    return μ
end

function _std(z::Matrix{Float64}, μ::Vector{Float64})
    n, q = size(z)
    σ = zeros(q)

    @inbounds for j in 1:q
        @simd for i in 1:n
            σ[j] += (z[i, j] - μ[j])^2
        end
        σ[j] = 1.0 / sqrt(σ[j] / (n - 1))
    end
    return σ
end
@benchmark _std(z, μ) setup=(z=rand(1000, 1000), μ = _mean(z))
@benchmark _mean(z) setup=(z=rand(1000, 1000))

Random.seed!(2019)
@benchmark test(z) setup=(z=rand(1000, 1000))
@benchmark test2(z) setup=(z=rand(1000, 1000))
@benchmark test3(z) setup=(z=rand(1000, 1000))
@benchmark test4(z) setup=(z=rand(1000, 1000))
@benchmark standardize!(@view(z[:, 2:end])) setup=(z=rand(1000, 1000))



function _scale!(des1::AbstractVector{T}, v1::AbstractVector{T}, w1::AbstractVector{T}, 
         des2::AbstractVector{T}, v2::AbstractVector{T}, w2::AbstractVector{T}) where {T <: Float64}
    copyto!(des1, v1 .* w1)
    copyto!(des2, v2 .* w2)
end

n=1000

@benchmark _scale!(des1, v1, w1, des2, v2, w2) setup=(des1 = zeros(n),des2 = zeros(n),v1 = rand(n),v2 = rand(n),w1 = rand(n),w2 = rand(n))

full_grad = zeros(2000)
weight = rand(2000)
b = rand(1000)
c = rand(1000)

function test_scale(b, c, full_grad, weight)
    lb = length(b)
    lf = length(full_grad)
    copyto!(v.b, @view(full_grad[1:lb]) ./ @view(v.weight[1:lb]))
    copyto!(v.c, @view(full_grad[lb+1:lf]) ./ @view(v.weight[lb+1:lf]))
end

@benchmark test_scale(b, c, full_grad, weight) setup=(b=rand(100000),c = rand(100000),full_grad = zeros(200000),weight = rand(200000))





function iht_stepsize(v::IHTVariable{T}, z::AbstractMatrix{T}, 
                      d::UnivariateDistribution, l::Link) where {T <: Float64}
    
    # first store relevant components of gradient
    copyto!(v.gk, view(v.df, v.idx))
    A_mul_B!(v.xgk, v.zdf2, v.xk, view(z, :, v.idc), v.gk, view(v.df2, v.idc))
    
    #use zdf2 as temporary storage
    v.xgk .+= v.zdf2
    v.zdf2 .= mueta.(l, v.xb).^2 ./ glmvar.(d, v.μ)
    
    # now compute and return step size. Note non-genetic covariates are separated from x
    numer = sum(abs2, v.gk) + sum(abs2, @view(v.df2[v.idc]))
    denom = Transpose(v.xgk) * Diagonal(v.zdf2) * v.xgk
    return (numer / denom) :: T
end

function test(x, y, z)
    x .+= y
    y .= mueta.(IdentityLink(), z).^2 ./ glmvar.(Normal(), z)
end


function test2(x, y, z)
    @inbounds for i in eachindex(x)
        x[i] += y[i]
        y[i] = mueta(IdentityLink(), z[i])^2 / glmvar(Normal(), z[i])
    end
end






using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using DelimitedFiles
using BenchmarkTools
using Random
using LinearAlgebra
using GLM

#simulat data with k true predictors, from distribution d and with link l.
n = 1000
p = 10000
k = 10
d = Normal
l = canonicallink(d())
# l = LogLink()

#set random seed
Random.seed!(1111)

for i in 1:10
    #construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
    mafs = clamp!(0.5rand(p), 0.1, 0.5)
    x = simulate_random_snparray(n, p, "test1.bed", mafs=mafs)
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
    z = ones(n, 1)

    # simulate response, true model b, and the correct non-0 positions of b
    y, true_b, correct_position = simulate_random_response(x, xbm, k, d, l)

    # specify weights 
    weight = ones(p + 1)
    weight[1:p] .= maf_weights(x, max_weight=2.0)

    #run IHT
    result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=true, init=false, use_maf=false)
    result_weighted = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=true, init=false, use_maf=false, weight=weight)

    #check result
    compare_model = DataFrame(
        unweighted = result.beta[correct_position], 
        weighted   = result_weighted.beta[correct_position])
    @show compare_model

    #clean up
    rm("test1.bed", force=true)
end


function graph(inter)
    n = 1000
    p = 10000
    k = 10
    d = Poisson
    l = canonicallink(d())
    # l = LogLink()

    #set random seed
    Random.seed!(2019)

    #construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
    x = simulate_random_snparray(n, p, "test1.bed")
    xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
    z = ones(n, 1)

    # simulate response, true model b, and the correct non-0 positions of b
    true_b = zeros(p)
    # true_b[1:4] .= [0.1; 0.25; 0.5; 0.8]
    true_b[1:10] .= collect(0.1:0.1:1.0)
    # true_b[1:k] = rand(Normal(0, 0.3), k)
    shuffle!(true_b)
    correct_position = findall(!iszero, true_b)

    #simulate phenotypes (e.g. vector y)
    if d == Normal || d == Poisson || d == Bernoulli
        prob = linkinv.(l, xbm * true_b .+ inter)
        clamp!(prob, -20, 20)
        y = [rand(d(i)) for i in prob]
    elseif d == NegativeBinomial
        nn = 10
        μ = linkinv.(l, xbm * true_b)
        clamp!(μ, -20, 20)
        prob = 1 ./ (1 .+ μ ./ nn)
        y = [rand(d(nn, i)) for i in prob] #number of failtures before nn success occurs
    elseif d == Gamma
        μ = linkinv.(l, xbm * true_b)
        β = 1 ./ μ # here β is the rate parameter for gamma distribution
        y = [rand(d(α, i)) for i in β] # α is the shape parameter for gamma
    end
    y = Float64.(y)
    return histogram(y, bin=50)
end

using Revise
using MendelIHT
using SnpArrays
using DataFrames
using Distributions
using DelimitedFiles
using BenchmarkTools
using Random
using LinearAlgebra
using Statistics
using GLM
using BenchmarkTools

n = 1000
p = 10000
x = simulate_correlated_snparray(n, p, undef, prob=0.75)

col1, col2 = zeros(n), zeros(n)
copyto!(col1, @view(x[:, 1]));
copyto!(col2, @view(x[:, 2]));
cor(col1, col2)
sum(col1 .== col2)

col1, col2 = zeros(n), zeros(n)
for i in 1:19
    copyto!(col1, @view(x[:, i]), center=true, scale=true)
    copyto!(col2, @view(x[:, i+1]), center=true, scale=true)
    println(cor(col1, col2))
end

@benchmark simulate_random_snparray(n, p, undef)
@benchmark simulate_correlated_snparray(n, p, undef)



