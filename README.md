# MendelIHT

**Iterative hard thresholding -** *a multiple regression approach to analyze data from a Genome Wide Association Studies (GWAS)*

| **Documentation** | **Build Status** | **Code Coverage**  |
|-------------------|------------------|--------------------|
| [![](https://img.shields.io/badge/docs-latest-blue.svg)](https://OpenMendel.github.io/MendelIHT.jl/latest) [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://OpenMendel.github.io/MendelIHT.jl/stable) | [![build Actions Status](https://github.com/OpenMendel/MendelIHT.jl/workflows/CI/badge.svg)](https://github.com/OpenMendel/MendelIHT.jl/actions) | [![codecov](https://codecov.io/gh/OpenMendel/MendelIHT.jl/branch/master/graph/badge.svg?token=YyPqiFpIM1)](https://codecov.io/gh/OpenMendel/MendelIHT.jl) |

## Installation

Download and install [Julia](https://julialang.org/downloads/). Within Julia, copy and paste the following:
```
using Pkg
pkg"add https://github.com/OpenMendel/SnpArrays.jl"
pkg"add https://github.com/OpenMendel/VCFTools.jl"
pkg"add https://github.com/OpenMendel/MendelIHT.jl"
```
This package supports Julia `v1.5`+ for Mac, Linux, and window machines. 

## Documentation

+ [**Latest**](https://OpenMendel.github.io/MendelIHT.jl/latest/)
+ [**Stable**](https://OpenMendel.github.io/MendelIHT.jl/stable/)

## Quick Start

The following uses data under the `data` directory. PLINK files are stored in `normal.bed`, `normal.bim`, `normal.fam`. 

```julia
# load package & cd to data directory
using MendelIHT
cd(normpath(MendelIHT.datadir()))

# if sparsity parameter k is known
result = iht("normal", 9) # run IHT with k = 9, default d=Normal(), l = IdentityLink()
result = iht("normal", "covariates.txt", 10) # separately include covariates, k = 10
result = iht("phenotypes.txt", "normal", "covariates.txt", 10) # if phenotypes are in separate file

# run cross validation to determine best k
mses = cross_validate("normal", 1:20) # test k = 1, 2, ..., 20
mses = cross_validate("normal", [1, 5, 10, 15, 20]) # test k = 1, 5, 10, 15, 20
mses = cross_validate("normal", "covariates.txt", 1:20) # separately include covariates
mses = cross_validate("phenotypes.txt", "normal", "covariates.txt", 1:20) # if phenotypes are in separate file

# other distributions
result = iht("plinkfile", 10, d=Bernoulli(), l = LogitLink()) # logistic regression with k = 10
result = iht("plinkfile", 10, d=Poisson(), l = LogLink()) # Poisson regression with k = 10
result = iht("plinkfile", 10, d=NegativeBinomial(), l = LogLink(), est_r=true) # Negative Binomial regression with k = 10
```

Please see our latest [documentation](https://OpenMendel.github.io/MendelIHT.jl/latest/) for more detail. 

## Citation and Reproducibility:

See our [paper](https://academic.oup.com/gigascience/article/9/6/giaa044/5850823?searchresult=1) for algorithmic details. If you use `MendelIHT.jl`, please cite:

```
@article{mendeliht,
  title={{Iterative hard thresholding in genome-wide association studies: Generalized linear models, prior weights, and double sparsity}},
  author={Chu, Benjamin B and Keys, Kevin L and German, Christopher A and Zhou, Hua and Zhou, Jin J and Sobel, Eric M and Sinsheimer, Janet S and Lange, Kenneth},
  journal={GigaScience},
  volume={9},
  number={6},
  pages={giaa044},
  year={2020},
  publisher={Oxford University Press}
}
```

In the `figures` subfolder, one can find all the code to reproduce the figures and tables in our paper. 

## Bug fixes and user support

If you encounter a bug or need user support, please open a new issue on Github. Please provide as much detail as possible for bug reports, ideally a sequence of reproducible code that lead to the error.

PRs and feature requests are welcomed!
