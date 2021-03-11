"""
    heritability(y, X, β; l = IdentityLink())

Estimates the proportion of phenotypic variance explained by typed genotypes 
(i.e. chip heritability or SNP heritability).

# Model
We compute `Var(μ) / Var(y)` where `y` is the raw phenotypes, `X` contains 
all the genotypes, and `μ = g^{-1}(Xβ)` is the predicted (average) phenotype
values from the statistical model β. 
"""
function heritability(
    y::AbstractVecOrMat,
    X::AbstractVecOrMat,
    β::AbstractVecOrMat;
    l::Link = IdentityLink()
    )
    μ = linkinv.(l, X * β) # mean
    return _heritability(y, μ)
end

function _heritability(y::AbstractVecOrMat, μ::AbstractVecOrMat)
    return var(μ) / var(y)
end

function heritability(v::IHTVariable)
    update_μ!(v.μ, v.xb, v.l) # update estimated mean μ with genotype predictors
    return _heritability(v.y, v.μ)
end

function heritability(v::mIHTVariable)
    update_μ!(v.μ, v.BX, IdentityLink()) # update estimated mean μ with genotype predictors
    return _heritability(v.Y, v.μ)
end