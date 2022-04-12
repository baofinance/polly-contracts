import "./Interfaces/IBalancer.sol";
import "./Interfaces/IRecipe.sol";
import "./Interfaces/IUniV3Router.sol";
import "./Interfaces/IUniRouter.sol";
import "./Interfaces/ILendingLogic.sol";
import "./Interfaces/ILendingRegistry.sol";
import "./Interfaces/IPie.sol";
import "./OpenZeppelin/SafeERC20.sol";
import "./OpenZeppelin/Ownable.sol";

pragma solidity 0.8.1;

contract NestRedeem is Ownable {
    using SafeERC20 for IERC20;

    //Failing to query a price is expensive,
    //so we save info about the DEX state to prevent querying the price if it is not viable
    mapping(address => bytes32) balancerViable;
    mapping(address => uint16) uniFee;

    // Adds a custom hop before reaching the destination token
    mapping(address => address) public customHops;

    struct BestPrice{
        uint price;
        uint ammIndex;
    }

    IBalancer balancer = IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    uniOracle oracle = uniOracle(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    uniV3Router uniRouter = uniV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniRouter sushiRouter = IUniRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IUniRouter quickRouter = IUniRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    IERC20 immutable WETH;
    ILendingRegistry immutable lendingRegistry;

    constructor(address _weth, address _lendingRegistry) {
        WETH = IERC20(_weth);
        lendingRegistry = ILendingRegistry(_lendingRegistry);
    }

    function redeemNestToWeth(address _nestAddress, uint256 _nestAmount) external {
        require(_nestAmount >= 1e2, "Min nest amount: 0.01");

        IPie pie = IPie(_nestAddress);
        require(pie.balanceOf(msg.sender) >= _nestAmount, "Insufficient nest balance");

        // Transfer nest tokens to redeem contract
        pie.transferFrom(msg.sender, address(this), _nestAmount);
        uint256 pieBalance = pie.balanceOf(address(this));

        // Get tokens inside the index, as well as the amounts received.
        (address[] memory tokens, uint256[] memory amounts) = pie.calcTokensForAmount(pieBalance);

        // Dissolve index for the individual tokens
        pie.exitPool(pieBalance);

        // Exchange underlying tokens for WETH
        for(uint256 i = 0; i < tokens.length; i++) {
            tokensToWeth(tokens[i],amounts[i]);
        }

        // Transfer redeemed WETH to msg.sender
        WETH.transfer(msg.sender, WETH.balanceOf(address(this)));
    }

    function tokensToWeth(address _token, uint256 _amount) internal {

        // If they are lending tokens, unlend them
        address underlying = lendingRegistry.wrappedToUnderlying(_token);
        if (underlying != address(0)) {
            // calc amount according to exchange rate
            ILendingLogic lendingLogic = getLendingLogicFromWrapped(_token);
            uint256 exchangeRate = lendingLogic.exchangeRate(_token); // wrapped to underlying exchangeRate

            uint256 underlyingAmount = _amount * exchangeRate / 1e18;

            // Unlend token
            (address[] memory _targets, bytes[] memory _data) = lendingRegistry.getUnlendTXData(_token, _amount, address(this));
            for(uint256 j = 0; j < _targets.length; j++) {
                _targets[j].call(_data[j]);
            }
            _amount = underlyingAmount;
            _token = underlying;
        }

        // If underlying token is wETH, no need to swap
        if (_token == address(WETH)) return;

        address customHopToken = customHops[_token];
        //If we customHop token is set, we first swap from token -> hopToken -> WETH
        if(customHopToken != address(0)) {
            BestPrice memory hopInPrice = getBestPrice(customHopToken, address(WETH), _amount);
            
            BestPrice memory wethInPrice = getBestPrice(_token, customHopToken, hopInPrice.price);
            //Swap weth for hopToken
            dexSwap(_token, customHopToken, hopInPrice.price, wethInPrice.ammIndex);
            //Swap hopToken for outputToken
            dexSwap(customHopToken, address(WETH), _amount, hopInPrice.ammIndex);
        }
        // else normal swap
        else{
            BestPrice memory bestPrice = getBestPrice(_token, address(WETH), _amount);
            
            dexSwap(address(WETH), _token, _amount, bestPrice.ammIndex);
        }
    }

    function getBestPrice(address _assetIn, address _assetOut, uint _amountIn) public returns (BestPrice memory){
        uint uniAmount;
        uint sushiAmount;
        uint quickAmount;
        uint balancerAmount;
        BestPrice memory bestPrice;

        //GET UNI PRICE
        uint uniIndex;
        (uniAmount,uniIndex) = getPriceUniV3(_assetIn,_assetOut,_amountIn,uniFee[_assetOut]);
        bestPrice.price = uniAmount;
        bestPrice.ammIndex = uniIndex;
        
        //GET SUSHI PRICE
        try sushiRouter.getAmountsOut(_amountIn, getRoute(_assetIn, _assetOut)) returns(uint256[] memory amounts) {
            sushiAmount = amounts[0];
        } catch {
            sushiAmount = 0;
        }
        if(bestPrice.price>sushiAmount){
            bestPrice.price = sushiAmount;
            bestPrice.ammIndex = 2;
        }

        //GET QUICKSWAP PRICE
        try quickRouter.getAmountsOut(_amountIn, getRoute(_assetIn, _assetOut)) returns(uint256[] memory amounts) {
            quickAmount = amounts[0];
        } catch {
            quickAmount = 0;
        }
        if(bestPrice.price>quickAmount){
            bestPrice.price = quickAmount;
            bestPrice.ammIndex = 3;
        }

        //GET BALANCER PRICE
        if(balancerViable[_assetIn]!= ""){
            balancerAmount = getPriceBalancer(_assetIn,_assetOut,_amountIn);
            if(bestPrice.price>balancerAmount){
                bestPrice.price = balancerAmount;
                bestPrice.ammIndex = 4;
            }
        }

        require(bestPrice.price > 0);

        return bestPrice;
    }

    function dexSwap(address _assetIn, address _assetOut, uint _amountIn, uint _ammIndex) public {
        //Uni1
        if(_ammIndex == 0){
            uniV3Router.ExactInputSingleParams memory params = uniV3Router.ExactInputSingleParams(
                _assetIn,
                _assetOut,
                500,
                address(this),
                block.timestamp + 1,
                _amountIn,
                0,
                0
            );
            IERC20(_assetIn).approve(address(uniRouter), 0);
            IERC20(_assetIn).approve(address(uniRouter), type(uint256).max);
            uniRouter.exactInputSingle(params);
            return;
        }
        //Uni2
        if(_ammIndex == 1){
            uniV3Router.ExactInputSingleParams memory params = uniV3Router.ExactInputSingleParams(
                _assetIn,
                _assetOut,
                3000,
                address(this),
                block.timestamp + 1,
                _amountIn,
                0,
                0
            );

            IERC20(_assetIn).approve(address(uniRouter), 0);
            IERC20(_assetIn).approve(address(uniRouter), type(uint256).max);
            uniRouter.exactInputSingle(params);
            return;
        }
        //Sushi
        if(_ammIndex == 2){
            IERC20(_assetIn).approve(address(sushiRouter), 0);
            IERC20(_assetIn).approve(address(sushiRouter), type(uint256).max);
            sushiRouter.swapExactTokensForTokens(_amountIn,0,getRoute(_assetIn, _assetOut),address(this),block.timestamp + 1);
            return;
        }
        //Quickswap
        if(_ammIndex == 3){
            IERC20(_assetIn).approve(address(quickRouter), 0);
            IERC20(_assetIn).approve(address(quickRouter), type(uint256).max);
            quickRouter.swapExactTokensForTokens(_amountIn,0,getRoute(_assetIn, _assetOut),address(this),block.timestamp + 1);
            return;
        }

        //Balancer
        IBalancer.SwapKind kind = IBalancer.SwapKind.GIVEN_IN;
        IBalancer.SingleSwap memory singleSwap = IBalancer.SingleSwap(
            balancerViable[_assetIn],
            kind,
            _assetIn,
            _assetOut,
            _amountIn,
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
            0,
            block.timestamp + 1
        );

    }

    function getPriceUniV3(address _assetIn, address _assetOut, uint _amountIn, uint16 _uniFee) internal returns(uint uniAmount, uint index){
        //Uni provides pools with different fees. The most popular being 0.05% and 0.3%
        //Unfortunately they have to be specified
        if(_uniFee == 500){
            try oracle.quoteExactInputSingle(_assetIn,_assetOut,500,_amountIn,0) returns(uint256 returnAmount) {
                uniAmount = returnAmount;
            } catch {
                uniAmount = 0;
            }
            //index = 0; no need to set 0, as it is the default value
        }
        else if(_uniFee == 3000){
            try oracle.quoteExactInputSingle(_assetIn,_assetOut,3000,_amountIn,0) returns(uint256 returnAmount) {
                uniAmount = returnAmount;
            } catch {
                uniAmount = 0;
            }
            index = 1;
        }
        else{
            try oracle.quoteExactInputSingle(_assetIn,_assetOut,500,_amountIn,0) returns(uint256 returnAmount) {
                uniAmount = returnAmount;
            } catch {
                uniAmount = 0;
            }
            //index = 0
            try oracle.quoteExactInputSingle(_assetIn,_assetOut,3000,_amountIn,0) returns(uint256 returnAmount) {
                if(uniAmount>returnAmount){
                    index = 1;
                    uniAmount = returnAmount;
                }
            } catch {
                //uniAmount is either already 0 or higher
            }
        }
    }

    function getPriceBalancer(address _assetIn, address _assetOut, uint _amountIn) internal returns(uint balancerAmount){
        
        //Get Balancer price
        IBalancer.SwapKind kind = IBalancer.SwapKind.GIVEN_IN;

        address[] memory assets = new address[](2);
        assets[0] = _assetIn;
        assets[1] = _assetOut;

        IBalancer.BatchSwapStep[] memory swapStep = new IBalancer.BatchSwapStep[](1);
        swapStep[0] = IBalancer.BatchSwapStep(balancerViable[_assetIn], 0, 1, _amountIn, "");

        IBalancer.FundManagement memory funds = IBalancer.FundManagement(payable(msg.sender),false,payable(msg.sender),false);

        try balancer.queryBatchSwap(kind,swapStep,assets,funds) returns(int[] memory amounts) {
            balancerAmount = uint(amounts[1]);
        } catch {
            balancerAmount = 0;
        }
        
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

    function getRoute(address _inputToken, address _outputToken) internal pure returns(address[] memory route) {
        route = new address[](2);
        route[0] = _inputToken;
        route[1] = _outputToken;

        return route;
    }
}