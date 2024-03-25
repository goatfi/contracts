// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface ICurveRouter {
    /// 
    /// @param _route Array of [initial token, pool or zap, token, pool or zap, token, ...]
                    //The array is iterated until a pool address of 0x00, then the last
                    //given token is transferred to `_receiver`
    /// @param _swap_params Multidimensional array of [i, j, swap type, pool_type, n_coins] where
                    //i is the index of input token
                    //j is the index of output token

                    //The swap_type should be:
                    //1. for `exchange`,
                    //2. for `exchange_underlying`,
                    //3. for underlying exchange via zap: factory stable metapools with lending base pool `exchange_underlying`
                        //and factory crypto-meta pools underlying exchange (`exchange` method in zap)
                    //4. for coin -> LP token "exchange" (actually `add_liquidity`),
                    //5. for lending pool underlying coin -> LP token "exchange" (actually `add_liquidity`),
                    //6. for LP token -> coin "exchange" (actually `remove_liquidity_one_coin`)
                    //7. for LP token -> lending or fake pool underlying coin "exchange" (actually `remove_liquidity_one_coin`)
                    //8. for ETH <-> WETH

                    //pool_type: 1 - stable, 2 - crypto, 3 - tricrypto, 4 - llamma
                    //n_coins is the number of coins in pool
    /// @param _amount The amount of input token (`_route[0]`) to be sent.
    /// @param _expected The minimum amount received after the final swap.
    function exchange(address[11] memory _route, uint256[5][5] memory _swap_params, uint256 _amount, uint256 _expected) external returns(uint256);
}