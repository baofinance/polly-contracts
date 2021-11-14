pragma solidity ^0.8.1;
pragma abicoder v2;

import "../Recipes/OpenZeppelin/Ownable.sol";
import "../Recipes/Interfaces/IExperiPie.sol";
import "../Recipes/Interfaces/IUniRouter.sol";

contract rebalancer is Ownable{
    
    address routerAddr = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    IExperiPie nest;

    function setNest(address _nest) external onlyOwner{
        nest = IExperiPie(_nest);
    }

    function getSwapDataViaWeth(address _sellToken, address _buyToken, uint _sellAmount, uint minAmount) public view returns(address[] memory targets, bytes[] memory data, uint estimatedAmount){
        IERC20 sellToken = IERC20(_sellToken);
        address[] memory route = new address[](3);
        route[0] = _sellToken;
        route[1] = WETH;
        route[2] = _buyToken;
            
        IUniRouter router = IUniRouter(routerAddr);

        //If no minimum output amount is given, 
        if(minAmount == 0){
            estimatedAmount = router.getAmountsOut(_sellAmount, route)[2];
        }
        else{
            estimatedAmount = minAmount;
        }
        
        targets = new address[](3);
        data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _sellToken;
        data[0] = abi.encodeWithSelector(sellToken.approve.selector, address(router), 0);

        // Set approval
        targets[1] = _sellToken;
        data[1] = abi.encodeWithSelector(sellToken.approve.selector, address(router), _sellAmount);

        // Sell tokens
        targets[2] = address(router);
        data[2] = abi.encodeWithSelector(router.swapExactTokensForTokens.selector, _sellAmount, estimatedAmount, route, address(nest), block.timestamp + 1000000); 
        
        return(targets,data,estimatedAmount);
        //Execute calls
        //nest.callNoValue(targets, data);
    }
    
    function swapViaWeth(address _sellToken, address _buyToken, uint _sellAmount, uint minAmount) external onlyOwner{
        IERC20 sellToken = IERC20(_sellToken);
        //Set the path for selling and buying the tokens.
        address[] memory route = new address[](3);
        route[0] = _sellToken;
        route[1] = WETH;
        route[2] = _buyToken;
        
        IUniRouter router = IUniRouter(routerAddr);
        
        uint estimatedAmount;
        
        //If no minimum output amount is given, 
        if(minAmount == 0){
            estimatedAmount = router.getAmountsOut(_sellAmount, route)[2];
        }
        else{
            estimatedAmount = minAmount;
        }
        
        address[] memory targets = new address[](3);
        bytes[] memory data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _sellToken;
        data[0] = abi.encodeWithSelector(sellToken.approve.selector, address(router), 0);

        // Set approval
        targets[1] = _sellToken;
        data[1] = abi.encodeWithSelector(sellToken.approve.selector, address(router), _sellAmount);

        // Sell tokens
        targets[2] = address(router);
        data[2] = abi.encodeWithSelector(router.swapExactTokensForTokens.selector, _sellAmount, estimatedAmount, route, address(nest), block.timestamp + 1); 
        
        //Execute calls
        nest.callNoValue(targets, data);
    }

    function swapWeth(address _sellToken, address _buyToken, uint _sellAmount, uint minAmount) external onlyOwner{
        IERC20 sellToken = IERC20(_sellToken);
        //Set the path for selling and buying the tokens.
        address[] memory route = new address[](3);

        if(_sellToken == WETH){
            route[0] = WETH;
            route[1] = _buyToken;
        }
        else if(_buyToken == WETH){
            route[0] = _sellToken;
            route[1] = WETH; 
        }
        else{
            return;
        }
        
        IUniRouter router = IUniRouter(routerAddr);
        
         uint estimatedAmount;
        
        //If no minimum output amount is given, 
        if(minAmount == 0){
            estimatedAmount = router.getAmountsOut(_sellAmount, route)[2];
        }
        else{
            estimatedAmount = minAmount;
        }
        
        address[] memory targets = new address[](3);
        bytes[] memory data = new bytes[](3);
        
        targets = new address[](3);
        data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _sellToken;
        data[0] = abi.encodeWithSelector(sellToken.approve.selector, address(router), 0);

        // Set approval
        targets[1] = _sellToken;
        data[1] = abi.encodeWithSelector(sellToken.approve.selector, address(router), _sellAmount);

        // Sell tokens
        targets[2] = address(router);
        data[2] = abi.encodeWithSelector(router.swapExactTokensForTokens.selector, _sellAmount, estimatedAmount, route, address(nest), block.timestamp + 1); 
        
        //Execute calls
        nest.callNoValue(targets, data);
    }

}

