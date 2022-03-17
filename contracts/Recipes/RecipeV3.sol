pragma solidity 0.8.1;

import "./Interfaces/IRecipe.sol";
import "./Interfaces/IBalancer.sol";
import "./Interfaces/IUniRouter.sol";
import "./Interfaces/ILendingRegistry.sol";
import "./Interfaces/ILendingLogic.sol";
import "./Interfaces/IPieRegistry.sol";
import "./Interfaces/IPie.sol";
import "./Interfaces/IERC20Metadata.sol";
import "./Interfaces/IPollyToken.sol";
import "./Interfaces/IBentoBoxV1.sol";
import "./Interfaces/IUniV3Router.sol";
import "./OpenZeppelin/SafeERC20.sol";
import "./OpenZeppelin/Context.sol";
import "./OpenZeppelin/Ownable.sol";

contract RecipeV3 is IRecipe, Ownable {
    using SafeERC20 for IERC20;

    IERC20 immutable WETH;
    ILendingRegistry immutable lendingRegistry;
    IPieRegistry immutable pieRegistry;

    //Failing to query a price is expensive,
    //so we save info about the DEX state to prevent querying the price if it is not viable
    mapping(address => bytes32) balancerViable;
    mapping(address => uint16) uniFee;

    struct BestPrice{
        uint price;
        uint ammIndex;
    }

    IBalancer balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    uniOracle oracle = uniOracle(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    uniV3Router uniRouter = uniV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniRouter sushiRouter = IUniRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    constructor(
        address _weth,
        address _lendingRegistry,
        address _pieRegistry,
        address _bentoBox,
        address _masterContract
    ) { 
        require(_weth != address(0), "WETH_ZERO");
        require(_lendingRegistry != address(0), "LENDING_MANAGER_ZERO");
        require(_pieRegistry != address(0), "PIE_REGISTRY_ZERO");

        WETH = IERC20(_weth);
        lendingRegistry = ILendingRegistry(_lendingRegistry);
        pieRegistry = IPieRegistry(_pieRegistry);
    
        _bentoBox.call{ value: 0 }(abi.encodeWithSelector(IBentoBoxV1.setMasterContractApproval.selector,address(this),_masterContract,true,0,0x0000000000000000000000000000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000));
    }

    function bake(
        address _inputToken,
        address _outputToken,
        uint256 _maxInput,
        uint256 _mintAmount
    ) external override returns(uint256 inputAmountUsed, uint256 outputAmount) {
        IERC20 inputToken = IERC20(_inputToken);
        IERC20 outputToken = IERC20(_outputToken);
        inputToken.safeTransferFrom(_msgSender(), address(this), _maxInput);
        
        outputAmount = _bake(_inputToken, _outputToken, _maxInput, _mintAmount);

        uint256 remainingInputBalance = inputToken.balanceOf(address(this));
        
        if(remainingInputBalance > 0) {
            inputToken.transfer(_msgSender(), inputToken.balanceOf(address(this)));
        }

        outputToken.safeTransfer(_msgSender(), outputAmount);  

        return(inputAmountUsed, outputAmount);
    }

    function _bake(address _inputToken, address _outputToken, uint256 _maxInput, uint256 _mintAmount) internal returns(uint256 outputAmount) {
        swap(_inputToken, _outputToken, _mintAmount);

        outputAmount = IERC20(_outputToken).balanceOf(address(this));

        return(outputAmount);
    }

    function swap(address _inputToken, address _outputToken, uint256 _outputAmount) internal {
        if(_inputToken == _outputToken) {
            return;
        }

        if(pieRegistry.inRegistry(_outputToken)) {
            swapPie(_outputToken, _outputAmount);
            return;
        }
        
        address underlying = lendingRegistry.wrappedToUnderlying(_outputToken);
        if(underlying != address(0)) {
            // calc amount according to exchange rate
            ILendingLogic lendingLogic = getLendingLogicFromWrapped(_outputToken);
            uint256 exchangeRate = lendingLogic.exchangeRate(_outputToken); // wrapped to underlying
            uint256 underlyingAmount = _outputAmount * exchangeRate / (1e18) + 1;

            swap(_inputToken, underlying, underlyingAmount);
            (address[] memory targets, bytes[] memory data) = lendingLogic.lend(underlying, underlyingAmount, address(this));

            //execute lending transactions
            for(uint256 i = 0; i < targets.length; i ++) {
                (bool success, ) = targets[i].call{ value: 0 }(data[i]);
                require(success, "CALL_FAILED");
            }

            return;
        }
        BestPrice memory bestPrice = getBestPrice(_inputToken, _outputToken, _outputAmount);

        // else normal swap
        dexSwap(_inputToken, _outputToken, _outputAmount, bestPrice.ammIndex);
    }

    function dexSwap(address _assetIn, address _assetOut, uint _amountOut, uint _ammIndex) public {
        //Uni1
        if(_ammIndex == 0){
            uniV3Router.ExactOutputSingleParams memory params = uniV3Router.ExactOutputSingleParams(
                _assetIn,
                _assetOut,
                500,
                address(this),
                block.timestamp + 1,
                _amountOut,
                type(uint256).max,
                0
            );
            IERC20(_assetIn).approve(address(uniRouter), 0);
            IERC20(_assetIn).approve(address(uniRouter), type(uint256).max);
            uniRouter.exactOutputSingle(params);
            return;
        }
        //Uni2
        if(_ammIndex == 1){
            uniV3Router.ExactOutputSingleParams memory params = uniV3Router.ExactOutputSingleParams(
                _assetIn,
                _assetOut,
                3000,
                address(this),
                block.timestamp + 1,
                _amountOut,
                type(uint256).max,
                0
            );
            
            IERC20(_assetIn).approve(address(uniRouter), 0);
            IERC20(_assetIn).approve(address(uniRouter), type(uint256).max);
            uniRouter.exactOutputSingle(params);
            return;
        }
        //Sushi
        if(_ammIndex == 2){
            IERC20(_assetIn).approve(address(sushiRouter), 0);
            IERC20(_assetIn).approve(address(sushiRouter), type(uint256).max);
            sushiRouter.swapTokensForExactTokens(_amountOut,type(uint256).max,getRoute(_assetIn, _assetOut),address(this),block.timestamp + 1);
            return;
        }

        //Balancer
        IBalancer.SwapKind kind = IBalancer.SwapKind.GIVEN_OUT;
        IBalancer.SingleSwap memory singleSwap = IBalancer.SingleSwap(
            balancerViable[_assetOut],
            kind,
            _assetIn,
            _assetOut,
            _amountOut,
            ""
        );
        IBalancer.FundManagement memory funds =  IBalancer.FundManagement(
            address(this),
            false,
            payable(address(this)),
            false
        );

        IERC20(_assetIn).approve(address(balancer), 0);
        IERC20(_assetIn).approve(address(balancer), type(uint256).max);
        balancer.swap(
            singleSwap,
            funds,
            type(uint256).max,
            block.timestamp + 1
        );
    }

    function swapPie(address _pie, uint256 _outputAmount) internal {
        IPie pie = IPie(_pie);
        (address[] memory tokens, uint256[] memory amounts) = pie.calcTokensForAmount(_outputAmount);
        for(uint256 i = 0; i < tokens.length; i ++) {
            swap(address(WETH), tokens[i], amounts[i]);
            IERC20 token = IERC20(tokens[i]);
            token.approve(_pie, 0);
            token.approve(_pie, amounts[i]);
            require(amounts[i] <= token.balanceOf(address(this)), "We are trying to deposit more then we have");
        }
        pie.joinPool(_outputAmount);
    }

    function getPrice(address _inputToken, address _outputToken, uint256 _outputAmount) public returns(uint256)  {
        if(_inputToken == _outputToken) {
            return _outputAmount;
        }

        address underlying = lendingRegistry.wrappedToUnderlying(_outputToken);
        if(underlying != address(0)) {
            // calc amount according to exchange rate
            ILendingLogic lendingLogic = getLendingLogicFromWrapped(_outputToken);
            uint256 exchangeRate = lendingLogic.exchangeRate(_outputToken); // wrapped to underlying
            uint256 underlyingAmount = _outputAmount * exchangeRate / (10**18) + 1;

            return getPrice(_inputToken, underlying, underlyingAmount);
        }

        // check if token is pie
        if(pieRegistry.inRegistry(_outputToken)) {
            uint256 ethAmount =  getPricePie(_outputToken, _outputAmount);

            // if input was not WETH
            if(_inputToken != address(WETH)) {
                return getPrice(_inputToken, address(WETH), ethAmount);
            }

            return ethAmount;
        }

        //At this point we only want price queries from WETH to other token
        require(_inputToken == address(WETH));

        //Input amount from single swap
        BestPrice memory bestPrice = getBestPrice(_inputToken, _outputToken, _outputAmount);

        return bestPrice.price;
    }

    function getBestPrice(address _assetIn, address _assetOut, uint _amountOut) public returns (BestPrice memory){  
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
            IBalancer.SwapKind kind = IBalancer.SwapKind.GIVEN_OUT;

            address[] memory assets = new address[](2);
            assets[0] = _assetIn;
            assets[1] = _assetOut;

            IBalancer.BatchSwapStep[] memory swapStep = new IBalancer.BatchSwapStep[](1);
            swapStep[0] = IBalancer.BatchSwapStep(balancerViable[_assetOut], 0, 1, _amountOut, "");

            IBalancer.FundManagement memory funds = IBalancer.FundManagement(payable(msg.sender),false,payable(msg.sender),false);

            try balancer.queryBatchSwap(kind,swapStep,assets,funds) returns(int[] memory amounts) {
                balancerAmount = uint(amounts[0]);
            } catch {
                balancerAmount = type(uint256).max;
            }
            if(bestPrice.price>balancerAmount){
                bestPrice.price = balancerAmount;
                bestPrice.ammIndex = 4;
            } 
        }  
        return bestPrice; 
    }

    function getRoute(address _inputToken, address _outputToken) internal returns(address[] memory route) {
        // if both input and output are not WETH
        if(_inputToken != address(WETH) && _outputToken != address(WETH)) {
            route = new address[](3);
            route[0] = _inputToken;
            route[1] = address(WETH);
            route[2] = _outputToken;
            return route;
        }

        route = new address[](2);
        route[0] = _inputToken;
        route[1] = _outputToken;

        return route;
    }

    // NOTE input token must be WETH
    function getPricePie(address _pie, uint256 _pieAmount) internal returns(uint256) {
        IPie pie = IPie(_pie);
        (address[] memory tokens, uint256[] memory amounts) = pie.calcTokensForAmount(_pieAmount);

        uint256 inputAmount = 0;

        for(uint256 i = 0; i < tokens.length; i ++) {
            inputAmount += getPrice(address(WETH), tokens[i], amounts[i]);
        }

        return inputAmount;
    }

    function getLendingLogicFromWrapped(address _wrapped) internal view returns(ILendingLogic) {
        return ILendingLogic(
                lendingRegistry.protocolToLogic(
                    lendingRegistry.wrappedToProtocol(
                        _wrapped
                    )
                )
        );
    }

    //////////////////////////
    ///Admin Functions ///////
    //////////////////////////

    function setUniPoolMapping(address _outputAsset, uint16 _Fee) external onlyOwner {
        uniFee[_outputAsset] = _Fee;
    }

    function setBalancerPoolMapping(address _inputAsset, bytes32 _pool) external onlyOwner {
        balancerViable[_inputAsset] = _pool;
    }

    function saveToken(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }
  
    function saveEth(address payable _to, uint256 _amount) external onlyOwner {
        _to.call{value: _amount}("");
    }
}