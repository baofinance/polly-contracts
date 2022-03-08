pragma solidity ^0.7.0;

import "@chainlink/contracts/src/v0.7/KeeperCompatible.sol";

contract rebalancer is Ownable{

    mapping(address => uint) public nestWeights;
    mapping(address => uint) public tokenDeltaLimit;
    mapping(address => chainLinkInterface) public linkFeeds;

    ////////////////////
    //KEEPER FUNCTIONS
    ////////////////////
    function checkUpkeep(bytes calldata /* checkData */) external override cannotExecute returns (bool upkeepNeeded, bytes memory tradingLogic) {
        
        (address[] memory tokens, uint sum) = calcTokenWeights();

        (upkeepNeeded, tradingLogic) = determineTradingPairs(tokens,sum);

        return(upkeepNeeded, tradingLogic);
    }

    function performUpkeep(bytes calldata tradingLogic) external override {
        (bool UpkeppAllowed,) = checkUpkeep();
        require(UpkeppAllowed)

        (uint tradeAmount, address token, buy) = decode(tradingLogic, (uint, bool))

        address[] tokens = ;//get nest tokens

        if(buy){
            for (uint256 i = 0; i < tokens.length; i++) {
                uint amountToBuy = fmul(nestWeights[i],tradeAmount)
                //Router any amount that leads to calculated amount out 
            }
        }
        }else{
            //uint wethAmount = Router tradeAmount of token => weth
            for (uint256 i = 0; i < tokens.length; i++) {
                uint amountToSell = fmul(nestWeights[i],wethAmount);
                //Router amountToSell => tokens[i] 
            }
        }
        
    }

    ////////////////////////
    //REBALANCER FUNCTIONS
    ////////////////////////
    
    //Calculate the current value of each token in the nest and its relative weighting 
    function calcTokenWeights() public view returns(address[] memory tokens, uint sum){
        uint sum;
        uint[] memory tokenValues;
        uint[] memory tokenAmounts;

        //use weights to determine which tokens need to be rebalanced
        for (uint256 i = 0; i < tokens.length; i++) {
            //save nest amount of tokens
            tokenAmounts[i] = IERC20(tokens[i]).balanceOf(address(nest));
            //save Chainlink token value
            chainLinkInterface linkFeed = linkFeeds[underlying];
            //Token Value * token balance
            uint tokenValue = fmul(tokenAmounts[i],fmul(10 ** (18 - IERC20(tokens[i]).decimals()), uint256(linkFeed.latestAnswer()), 10 ** linkFeed.decimals()));
            tokenValues[i] = tokenValue;
            //total nest value
            sum = sum.add(tokenValue);
        }

        return(tokenAmounts,tokenValues,sum)
    }

    //Return a pair to be traded in order to get closer to the original token value ratios
    function determineTradingPairs(address[] memory tokens, uint[] memory tokenAmounts, uint[] memory tokenValues, uint[] memory weights, uint sum) public view returns(bytes memory tradeData){

        uint[] memory tokenWeightDelta;
        uint[] memory negativeWeightsToAdjust;
        uint[] memory positiveWeightsToAdjust;
        mapping(address[] => uint) public addressToValue; 
        addressToValue[] memory valuesToBuy;
        addressToValue[] memory valuesToSell;

        for (uint256 i = 0; i < tokens.length; i++) {
                  
            weights[i] = tokenValues[i].mul(1e8).div(sum);

            if(nestWeights[tokens[i]] >= weights[i]){
                tokenWeightDelta[i] = nestWeights[tokens[i]] - weights[i];
                if(tokenWeightDelta[i] > tokenDeltaLimit[tokens[i]]){
                    
                    //Value to Buy

                    positiveWeightsToAdjust.push(i);
                    return(true, abi.encode((nestWeights[tokens[i]].mul(sum)).sub(tokenValues[i]), false, tokenAmounts));
                }
            }
            else{
                tokenWeightDelta[i] = weights[i] - nestWeights[tokens[i]];
                if(tokenWeightDelta[i] > tokenDeltaLimit[tokens[i]]){
                    
                    //Value to Sell 

                    negativeWeightsToAdjust.push(i);

                    return(true, abi.encode(tokenValues[i].sub(nestWeights[tokens[i]].mul(sum)), true, tokenAmounts));
                }
            }
        }     

        /*
            uint wethAmount;
            uint wethUSDValue = uint tokenValue = fmul(10 ** (18 - IERC20(weth).decimals()), uint256(linkFeed.latestAnswer()), 10 ** linkFeed.decimals());
            //Sell positive delta token amounts
            for (uint256 i = 0; i < positiveWeightsToAdjust.length; i++) {
                wethAmount = wethAmount.add(tokens[positiveWeightsToAdjust[i]].sellForWeth(tokenWeightDelta[positiveWeightsToAdjust[i]]));
            }     

            //Buy negative delta token amounts
            for (uint256 i = 0; i < positiveWeightsToAdjust.length; i++) {
                tokens[positiveWeightsToAdjust[i]].sellForWeth(tokenWeightDelta[positiveWeightsToAdjust[i]]);
            }     
        */        
    }

    //Return a the trading logic to transfer inToken to outToken
    function getTradingLogic(address[] tokenIn, address[] tokenOut, uint[] tokenInAmount) public view returns(bytes memory tradeData){
        
        return(tradeData)
    }

    //
    function performTrades(){

    }

    //Set the weights of all tokens in the nest
    // 1% of nest value = 100
    function setNestWeights(address[] _tokenAddress, uint[] _newWeight) external onlyOwner{
        require(_newWeight.length == _tokenAddress.length);
        uint sum;

        for (uint256 i = 0; i < _tokenAddress.length; i++) {
            nestWeight[_tokenAddress[i]] = _newWeight[i];
            sum += _newWeight[i];
        }
        
        require(sum == 10000)
    }

}

