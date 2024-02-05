#Directories
ignoreCompile=./ignoreCompile/uniswapHelper
script=./script
infra=./src/infra/uniswapHelper

#File names
solFile=.sol
solScript=.s.sol
ignoreSolScript=.s.igsol
ignoreSolFile=.igsol

mkdir -p $infra

mv "${ignoreCompile}/DeployUniswapPositionHelper${ignoreSolScript}" "${script}/DeployUniswapPositionHelper${solScript}"
mv "${ignoreCompile}/FullMath${ignoreSolFile}" "${infra}/FullMath${solFile}" 
mv "${ignoreCompile}/LiquidityAmounts${ignoreSolFile}" "${infra}/LiquidityAmounts${solFile}"
mv "${ignoreCompile}/TickMath${ignoreSolFile}" "${infra}/TickMath${solFile}"
mv "${ignoreCompile}/UniswapPositionHelper${ignoreSolFile}" "${infra}/UniswapPositionHelper${solFile}"

rm -rf $ignoreCompile