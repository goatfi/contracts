#Directories
ignoreCompile=./ignoreCompile/uniswapHelper
script=./script
infra=./src/infra/uniswapHelper

#File names
solFile=.sol
solScript=.s.sol
ignoreSolScript=.s.igsol
ignoreSolFile=.igsol

rm -rf $ignoreCompile
mkdir -p $ignoreCompile

mv "${script}/DeployUniswapPositionHelper${solScript}" "${ignoreCompile}/DeployUniswapPositionHelper${ignoreSolScript}"
mv "${infra}/FullMath${solFile}" "${ignoreCompile}/FullMath${ignoreSolFile}"
mv "${infra}/LiquidityAmounts${solFile}" "${ignoreCompile}/LiquidityAmounts${ignoreSolFile}"
mv "${infra}/TickMath${solFile}" "${ignoreCompile}/TickMath${ignoreSolFile}"
mv "${infra}/UniswapPositionHelper${solFile}" "${ignoreCompile}/UniswapPositionHelper${ignoreSolFile}"

rm -rf $infra