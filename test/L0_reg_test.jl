@testset "L0_reg normal" begin
	# Since my code seems to work, putting in some output as they can be verified by comparing with simulation

	#simulat data with k true predictors, from distribution d and with link l.
	n = 1000
	p = 10000
	k = 10
	d = Normal
	l = canonicallink(d())

	#set random seed
	Random.seed!(1111)

	#construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
	x, = simulate_random_snparray(n, p, "test1.bed")
	xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
	z = ones(n, 1)

	# simulate response, true model b, and the correct non-0 positions of b
	y, true_b, correct_position = simulate_random_response(x, xbm, k, d, l)

	#run result
	result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, use_maf=false)

	@test length(result.beta) == 10000
	@test findall(!iszero, result.beta) == [2384;3352;3353;4093;5413;5609;7403;8753;9089;9132]
	@test all(result.beta[findall(!iszero, result.beta)] .≈ [-1.2601406011046452;
	 				-0.2674202492177914; 0.14120810664715883; 0.289955803600036;
	  				0.3666894767520663; -0.1371805027382694; -0.3082545756160329;
	  				0.3328814701200445; 0.9645980728400257; -0.5094607091364866])
	@test result.c[1] == 0.0
	@test result.k == 10
	@test result.logl ≈ -1407.2533232402275
end

@testset "L0_reg Bernoulli" begin
	# Since my code seems to work, putting in some output as they can be verified by comparing with simulation

	#simulat data with k true predictors, from distribution d and with link l.
	n = 1000
	p = 10000
	k = 10
	d = Bernoulli
	l = canonicallink(d())

	#set random seed
	Random.seed!(1111)

	#construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
	x, = simulate_random_snparray(n, p, "test1.bed")
	xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
	z = ones(n, 1)

	# simulate response, true model b, and the correct non-0 positions of b
	y, true_b, correct_position = simulate_random_response(x, xbm, k, d, l)

	#run result
	result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, use_maf=false)

	@test length(result.beta) == 10000
	@test findall(!iszero, result.beta) == [1733;1816;2384;5413;7067;8753;8908;9089;9132;9765]
	@test all(result.beta[findall(!iszero, result.beta)] .≈ [-0.2787326116508012;
					  0.3113511410050774;-1.1292096054341005;0.5001816459301949;
					 -0.32694130827328116;0.4134742776599116;-0.3275424847038566;
					  0.8619785898062307;-0.5068258295825918;-0.32972421733995294])
	@test result.c[1] == 0.0
	@test result.k == 10
	@test result.logl ≈ -489.8770526620568
end

@testset "L0_reg Poisson" begin
	# Since my code seems to work, putting in some output as they can be verified by comparing with simulation

	#simulat data with k true predictors, from distribution d and with link l.
	n = 1000
	p = 10000
	k = 10
	d = Poisson
	l = canonicallink(d())

	#set random seed
	Random.seed!(1111)

	#construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
	x, = simulate_random_snparray(n, p, "test1.bed")
	xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
	z = ones(n, 1)

	# simulate response, true model b, and the correct non-0 positions of b
	y, true_b, correct_position = simulate_random_response(x, xbm, k, d, l)

	#run result
	result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, use_maf=false)
	@test length(result.beta) == 10000
	@test findall(!iszero, result.beta) == [298; 2384; 2631; 2830; 5891; 8753; 8755; 8931; 9089; 9132]
	@test all(result.beta[findall(!iszero, result.beta)] .≈ [0.11388053193848852;
		 -0.3656121710593458;   0.09709100199204676;  0.09256790216077444;  
		 0.11213018219691534;  0.1130270932574973;  0.11976499548849275;  
		 0.12654688802664316;  0.2774765841714746; -0.12145467673669649])
	@test result.c[1] == 0.0
	@test result.k == 10
	@test result.logl ≈ -1294.11508418671
end

@testset "L0_reg NegativeBinomial" begin
	# Since my code seems to work, putting in some output as they can be verified by comparing with simulation

	#simulat data with k true predictors, from distribution d and with link l.
	n = 1000
	p = 10000
	k = 10
	d = NegativeBinomial
	l = LogLink()

	#set random seed
	Random.seed!(1111)

	#construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
	x, = simulate_random_snparray(n, p, "test1.bed")
	xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
	z = ones(n, 1)

	# simulate response, true model b, and the correct non-0 positions of b
	y, true_b, correct_position = simulate_random_response(x, xbm, k, d, l)

	#run result
	result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, use_maf=false)

	@test length(result.beta) == 10000
	@test findall(!iszero, result.beta) == [1245; 1610; 1774; 2384; 5234; 5413; 5614; 8993; 9089; 9132]
	@test all(result.beta[findall(!iszero, result.beta)] .≈ [-0.12780331198500003;
		  0.11830730412942037; -0.17035163566280925; -0.3046187195569113;  
		  0.10000147030695117;  0.10954401862602865;  0.09732482177469551;
		 -0.09572322132444466;  0.26774034142677433; -0.19351730458773397])
	@test result.c[1] == 0.0
	@test result.k == 10
	@test result.logl ≈ -1390.9675106956904
end

@testset "L0_reg with non-genetic covariates" begin
	# Since my code seems to work, putting in some output as they can be verified by comparing with simulation

	#simulat data with k true predictors, from distribution d and with link l.
	n = 1000
	p = 10000
	k = 10
	d = Normal
	l = canonicallink(d())

	#set random seed
	Random.seed!(1111)

	#construct SnpArraym, snpmatrix, and non genetic covariate (intercept)
	x, = simulate_random_snparray(n, p, "test1.bed")
	xbm = SnpBitMatrix{Float64}(x, model=ADDITIVE_MODEL, center=true, scale=true); 
	z = ones(n, 2) # the intercept
	z[:, 2] .= randn(n)

	#define true_b and true_c
	true_b = zeros(p)
	true_b[1:k-2] = randn(k-2)
	shuffle!(true_b)
	correct_position = findall(!iszero, true_b)
	true_c = [3.0; 3.5]

	#simulate phenotype
	prob = linkinv.(l, xbm * true_b .+ z * true_c)
	y = [rand(d(i)) for i in prob]

	#run result
	result = L0_reg(x, xbm, z, y, 1, k, d(), l, debias=false, init=false, use_maf=false)

	@test length(result.beta) == 10000
	@test length(result.c) == 2
	@test findall(!iszero, result.beta) == [2984;4147;4604;6105;6636;7575;8271;9300]
	@test findall(!iszero, result.c) == [1;2]
	@test all(result.beta[findall(!iszero, result.beta)] .≈ [  1.0811374923376877;
					 -0.2117325990806942;-0.3322506195614783;0.40318468184323303;
					 -0.1318587627854617;1.6695482354179885;
					  0.3151131120568996;-1.596709800901686])
	@test all(result.c .≈ [2.9310914541779707; 3.467035167731262])
	@test result.k == 10
	@test result.logl ≈ -1372.8965392691769

	#clean up
	rm("test1.bed", force=true)
end