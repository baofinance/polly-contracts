pragma solidity 0.8.1;

import "./Interfaces/IRecipe.sol";
import "./Interfaces/IUniRouter.sol";
import "./Interfaces/ILendingRegistry.sol";
import "./Interfaces/ILendingLogic.sol";
import "./Interfaces/IPieRegistry.sol";
import "./Interfaces/IPie.sol";
import "./Interfaces/IERC20Metadata.sol";
import "./Interfaces/IPollyToken.sol";
import "./Interfaces/IBentoBoxV1.sol";
import "./OpenZeppelin/SafeERC20.sol";
import "./OpenZeppelin/Context.sol";
import "./OpenZeppelin/Ownable.sol";
import "hardhat/console.sol";

contract UniPieRecipeV2 is IRecipe, Ownable {
    using SafeERC20 for IERC20;

    IERC20 immutable WETH;
    IUniRouter immutable sushiRouter;
    ILendingRegistry immutable lendingRegistry;
    IPieRegistry immutable pieRegistry;
    
    uint256 public baoFee = 0;
    address public baoAddress = 0xc81278a52AD0e1485B7C3cDF79079220Ddd68b7D;
    address public feeRecipient = 0x000000000000000000000000000000000000dEaD;
    

    event HopUpdated(address indexed _token, address indexed _hop);

    // Adds a custom hop before reaching the destination token
    mapping(address => CustomHop) public customHops;

    struct CustomHop {
        address hop;
        // DexChoice dex;
    }

    enum DexChoice {Uni, Sushi}

    constructor(
        address _weth,
        address _sushiRouter,
        address _lendingRegistry,
        address _pieRegistry,
        address _bentoBox,
        address _masterKontract
    ) { 
        require(_weth != address(0), "WETH_ZERO");
        require(_sushiRouter != address(0), "SUSHI_ROUTER_ZERO");
        require(_lendingRegistry != address(0), "LENDING_MANAGER_ZERO");
        require(_pieRegistry != address(0), "PIE_REGISTRY_ZERO");

        WETH = IERC20(_weth);
        sushiRouter = IUniRouter(_sushiRouter);
        lendingRegistry = ILendingRegistry(_lendingRegistry);
        pieRegistry = IPieRegistry(_pieRegistry);
        
        _bentoBox.call{ value: 0 }(abi.encodeWithSelector(IBentoBoxV1.setMasterContractApproval.selector,address(this),_masterKontract,true,0,0x0000000000000000000000000000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000));
    }

    function bake(
        address _inputToken,
        address _outputToken,
        uint256 _maxInput,
        bytes memory _data
    ) external override returns(uint256 inputAmountUsed, uint256 outputAmount) {
        IERC20 inputToken = IERC20(_inputToken);
        IERC20 outputToken = IERC20(_outputToken);

        inputToken.safeTransferFrom(_msgSender(), address(this), _maxInput);

        (uint256 mintAmount) = abi.decode(_data, (uint256));

        outputAmount = _bake(_inputToken, _outputToken, _maxInput, mintAmount);

        uint256 remainingInputBalance = inputToken.balanceOf(address(this));
        
        uint256 feeAmount = ((_maxInput - remainingInputBalance) * baoFee) / (1e18 + 1);
        
        if(remainingInputBalance > 0 && feeAmount != 0) {
            IPollyToken baoToken = IPollyToken(baoAddress);
            WETH.approve(address(sushiRouter), 0);
            WETH.approve(address(sushiRouter), type(uint256).max);
            address[] memory route = getRoute(address(WETH), baoAddress, address(0));
            uint256 estimatedAmount = sushiRouter.getAmountsOut(feeAmount, route)[1];
            sushiRouter.swapExactTokensForTokens(feeAmount, estimatedAmount, route, address(this), block.timestamp + 1);
            baoToken.burn(baoToken.balanceOf(address(this)));
        }
        
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
        console.log("Buying", _outputToken, "with", _inputToken);

        if(_inputToken == _outputToken) {
            return;
        }

        // if input is not WETH buy WETH
        if(_inputToken != address(WETH)) {
            uint256 wethAmount = getPrice(address(WETH), _outputToken, _outputAmount);
            swapUniOrSushi(_inputToken, address(WETH), wethAmount);
            swap(address(WETH), _outputToken, _outputAmount);
            return;
        }

        if(pieRegistry.inRegistry(_outputToken)) {
            // console.log("Swapping to PIE", _outputToken);
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

        // else normal swap
        swapUniOrSushi(_inputToken, _outputToken, _outputAmount);
    }

    function swapPie(address _pie, uint256 _outputAmount) internal {
        IPie pie = IPie(_pie);
        (address[] memory tokens, uint256[] memory amounts) = pie.calcTokensForAmount(_outputAmount);

        for(uint256 i = 0; i < tokens.length; i ++) {
            swap(address(WETH), tokens[i], amounts[i]+1);
            IERC20 token = IERC20(tokens[i]);
            token.approve(_pie, 0);
            token.approve(_pie, amounts[i]+1);
            //console.log("BentoBalance: ",IBentoBoxV1(0x0319000133d3AdA02600f0875d2cf03D442C3367).balanceOf(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,address(this)));
            //console.log("TokenBalance: ",token.balanceOf(address(this)));
            console.log("Token Amount: ",amounts[i]);
            require(amounts[i] <= token.balanceOf(address(this)), "We are trying to deposit more then we have");
        }
        pie.joinPool(_outputAmount);
    }

    function swapUniOrSushi(address _inputToken, address _outputToken, uint256 _outputAmount) internal {

        IERC20 inputToken = IERC20(_inputToken);

        CustomHop memory customHop = customHops[_outputToken];

        if(address(_inputToken) == _outputToken) {
            return;
        }

        if(customHop.hop != address(0)) {
            hopSwapSushi(_inputToken, customHop.hop, _outputToken, _outputAmount);
            return;
        }
        
        address[] memory route = getRoute(_inputToken, _outputToken, address(0));

        inputToken.approve(address(sushiRouter), 0);
        inputToken.approve(address(sushiRouter), type(uint256).max);
        sushiRouter.swapTokensForExactTokens(_outputAmount, type(uint256).max, route, address(this), block.timestamp + 1);

    }
    
    function hopSwapSushi(address _inputToken,address _hopToken, address _outputToken, uint256 _outputAmount) internal {
        IERC20 inputToken = IERC20(_inputToken);
        
        address[] memory route = getRoute(_inputToken, _outputToken, _hopToken);
        
        inputToken.approve(address(sushiRouter), 0);
        inputToken.approve(address(sushiRouter), type(uint256).max);
        sushiRouter.swapTokensForExactTokens(_outputAmount, type(uint256).max, route, address(this), block.timestamp + 1);
    }

    function setCustomHop(address _token, address _hop) external onlyOwner {
        customHops[_token] = CustomHop({
            hop: _hop
            // dex: _dex
        });
    }

    function saveToken(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }
  
    function saveEth(address payable _to, uint256 _amount) external onlyOwner {
        _to.call{value: _amount}("");
    }
    
    function setBaoFee(uint256 _newFee) external onlyOwner{
        require(_newFee <= 10**18);
        baoFee = _newFee;
    }
    
    function setFeeToken(address _newFeeToken) external onlyOwner {
        baoAddress = _newFeeToken;
    }
    
    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        feeRecipient = _newFeeRecipient;
    }

    function getPrice(address _inputToken, address _outputToken, uint256 _outputAmount) public returns(uint256)  {
        if(_inputToken == _outputToken) {
            return _outputAmount;
        }

        // CustomHop memory customHop = customHops[_outputToken];
        // if(customHop.hop != address(0)) {
        //     //get price for hop
        //     uint256 hopAmount = getPrice(customHop.hop, _outputToken, _outputAmount);
        //     return getPrice(_inputToken, _outputToken, hopAmount);
        // }

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

        // if input and output are not WETH (2 hop swap)
        if(_inputToken != address(WETH) && _outputToken != address(WETH)) {
            (uint256 middleInputAmount,) = getBestPriceSushiUni(address(WETH), _outputToken, _outputAmount);
            (uint256 inputAmount,) = getBestPriceSushiUni(_inputToken, address(WETH), middleInputAmount);

            return inputAmount;
        }

        // else single hop swap
        (uint256 inputAmount,) = getBestPriceSushiUni(_inputToken, _outputToken, _outputAmount);

        return inputAmount;
    }

    function getBestPriceSushiUni(address _inputToken, address _outputToken, uint256 _outputAmount) internal returns(uint256, DexChoice) {
        uint256 sushiAmount = getPriceUniLike(_inputToken, _outputToken, _outputAmount, sushiRouter);

        return (sushiAmount, DexChoice.Sushi);
    }

    function getRoute(address _inputToken, address _outputToken, address _hop) internal returns(address[] memory route) {
        // if both input and output are not WETH
        if(_inputToken != address(WETH) && _outputToken != address(WETH)) {
            route = new address[](3);
            route[0] = _inputToken;
            route[1] = address(WETH);
            route[2] = _outputToken;
            return route;
        }
        
        if(_hop != address(0)){
            route = new address[](3);
            route[0] = _inputToken;
            route[1] = _hop;
            route[2] = _outputToken;
            return route;
        }

        route = new address[](2);
        route[0] = _inputToken;
        route[1] = _outputToken;

        return route;
    }

    function getPriceUniLike(address _inputToken, address _outputToken, uint256 _outputAmount, IUniRouter _router) internal returns(uint256) {
        if(_inputToken == _outputToken) {
            return(_outputAmount);
        }
        
        try _router.getAmountsIn(_outputAmount, getRoute(_inputToken, _outputToken, address(0))) returns(uint256[] memory amounts) {
            return amounts[0];
        } catch {
            return type(uint256).max;
        }
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

    function encodeData(uint256 _outputAmount) external pure returns(bytes memory){
        return abi.encode((_outputAmount));
    }
}