// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./OpenZeppelin/Ownable.sol";

interface unitOracle {
   function quoteExactOutputSingle(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountOut,
    uint160 sqrtPriceLimitX96
  ) external returns (uint256 amountIn);
}

interface uniV2router {
    function getAmountsIn(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface uniV3Router {
    //UniV3 params
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params);
}

interface IBalancer{
    enum SwapKind { GIVEN_IN, GIVEN_OUT }

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    //Balancer params
    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function queryBatchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets,
        FundManagement memory funds
    ) external returns (int256[] memory assetDeltas);
}

contract Aggregator is Ownable{

    enum DexChoice {Uni1, Uni2, Sushi, Balancer}

    //Failing to query a price is expensive,
    //so we save info about the DEX state to prevent querying the price if it is not viable
    mapping(address => bytes32) balancerViable;
    mapping(address => uint) uniFee;

    struct BestPrice{
        uint price;
        uint ammIndex;
    }

    IBalancer balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    unitOracle oracle = unitOracle(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    uniV2router sushiRouter = uniV2router(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    uniV3Router uniRouter = uniV3Router(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);

    function swap(address _assetIn, address _assetOut, uint _amountOut) public {
        BestPrice memory bestPrice = getPrice(_assetIn, _assetOut, _amountOut);
        //Uni1
        if(bestPrice.ammIndex == 0){
            struct ExactOutputSingleParams params = {
                _assetIn;
                _assetOut;
                500;
                msg.sender;
                block.timestamp + 1;
                _amountOut;
                0;
                0;
            }
            uniRouter.exactOutputSingle(params);
        }
        //Uni2
        if(bestPrice.ammIndex == 1){
            struct ExactOutputSingleParams params = {
                _assetIn;
                _assetOut;
                3000;
                msg.sender;
                block.timestamp + 1;
                _amountOut;
                0;
                0;
            }
            uniRouter.exactOutputSingle(params);
        }
        //Sushi
        if(bestPrice.ammIndex == 2){
            sushiRouter.swapTokensForExactTokens(_amountOut,0,getRoute(_assetIn, _assetOut),msg.sender,block.timestamp + 1);
        }
        //Balancer
        IBalancer.SingleSwap memory singleSwap = IBalancer.SingleSwap(
            balancerViable[_assetOut];
            SwapKind kind;
            _assetIn;
            _assetOut;
            _amountOut;
            ""
        );
        IBalancer.FundManagement memory funds =  IBalancer.FundManagement(
            address sender;
            false;
            address payable recipient;
            false;
        );
        balancerVault.swap(
            singleSwap,
            funds,
            0,
            block.timestamp + 1
        );
    }

    //We get current price 
    function getPrice(address _assetIn, address _assetOut, uint _amountOut) public returns (BestPrice memory){  
        uint uniAmount1;
        uint uniAmount2;
        uint sushiAmount;
        uint balancerAmount;
        BestPrice memory bestPrice;

        //GET UNI PRICE
        //(Uni provides pools with different fees. The most popular being 0.05% and 0.3%)   
        //Unfortunately they have to be specified
        if(uniFee[_assetOut] == 500){
            try oracle.quoteExactOutputSingle(_assetIn,_assetOut,500,_amountOut,0) returns(uint256 returnAmount) {
                uniAmount1 = returnAmount;
            } catch {
                uniAmount1 = type(uint256).max;
            }
            bestPrice.price = uniAmount1;
            bestPrice.ammIndex = 0;
        }
        else if(uniFee[_assetOut] == 3000){
            try oracle.quoteExactOutputSingle(_assetIn,_assetOut,3000,_amountOut,0) returns(uint256 returnAmount) {
                uniAmount2 = returnAmount;
            } catch {
                uniAmount2 = type(uint256).max;
            }    
            bestPrice.price = uniAmount2;
            bestPrice.ammIndex = 1;
        }
        else{
            try oracle.quoteExactOutputSingle(_assetIn,_assetOut,500,_amountOut,0) returns(uint256 returnAmount) {
                uniAmount1 = returnAmount;
            } catch {
                uniAmount1 = type(uint256).max;
            }    
            bestPrice.price = uniAmount1;
            bestPrice.ammIndex = 0;
            
            try oracle.quoteExactOutputSingle(_assetIn,_assetOut,3000,_amountOut,0) returns(uint256 returnAmount) {
                uniAmount2 = returnAmount;
            } catch {
                uniAmount2 = type(uint256).max;
            }
            if(bestPrice.price>uniAmount2){
                bestPrice.price = uniAmount2;
                bestPrice.ammIndex = 1;
            }
        }
        
        //GET SUSHI PRICE
        try sushiRouter.getAmountsIn(_amountOut, getRoute(_assetIn, _assetOut)) returns(uint256[] memory amounts) {
            sushiAmount = amounts[0];
        } catch {
            sushiAmount = type(uint256).max;
        }    
        if(bestPrice.price>sushiAmount){
            bestPrice.price = sushiAmount;
            bestPrice.ammIndex = 2;
        }

        //GET BALANCER PRICE
        if(balancerViable[_assetOut]!= ""){
            //Get Balancer price
            balancer.SwapKind kind = balancer.SwapKind.GIVEN_OUT;

            address[] memory assets = new address[](2);
            assets[0] = _assetIn;
            assets[1] = _assetOut;

            IBalancer.BatchSwapStep[] memory swapStep = new IBalancer.BatchSwapStep[](1);
            swapStep[0] = balancer.BatchSwapStep(balancerViable[_assetOut], 0, 1, _amountOut, "");

            IBalancer.FundManagement memory funds = IBalancer.FundManagement(payable(msg.sender),false,payable(msg.sender),false);

            try balancer.queryBatchSwap(kind,swapStep,assets,funds) returns(int[] memory amounts) {
                balancerAmount = uint(amounts[0]);
            } catch {
                balancerAmount = type(uint256).max;
            }
            //balancer = balancerAmount;
            if(bestPrice.price>balancerAmount){
                bestPrice.price = balancerAmount;
                bestPrice.ammIndex = 3;
            } 
        }  
        return bestPrice; 
    }

    function getRoute(address _inputToken, address _outputToken) internal pure returns(address[] memory route) {

        route = new address[](2);
        route[0] = _inputToken;
        route[1] = _outputToken;

        return route;
    }

    //////////////////////////
    ///Admin Functions ///////
    //////////////////////////

    function setUniPoolMapping(address _inputAsset, uint8 _Fee) external onlyOwner {
        uniFee[_inputAsset] = _Fee;
    }

    function setBalancerPoolMapping(address _inputAsset, bytes32 _pool) external onlyOwner {
        balancerViable[_inputAsset] = _pool;
    }
}

