// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./Interfaces/IERC20.sol";
import "./Interfaces/ILendingLogic.sol";
import "./LendingRegistry.sol";
import "./Interfaces/IBentoBoxV1.sol";
import "./Interfaces/IKashiPair.sol";
import "hardhat/console.sol";

contract LendingLogicKashi is ILendingLogic {
    
    LendingRegistry public lendingRegistry;
    bytes32 public immutable protocolKey;
    IBentoBoxV1 public immutable bentoBox;

    constructor(address _lendingRegistry, bytes32 _protocolKey, address _bentoBox) {
        require(_lendingRegistry != address(0), "INVALID_LENDING_REGISTRY");
        lendingRegistry = LendingRegistry(_lendingRegistry);
        protocolKey = _protocolKey;
        bentoBox = IBentoBoxV1(_bentoBox);
    }

    function getAPRFromWrapped(address _token) public view override returns(uint256) {
        IKashiPair wrapped = IKashiPair(_token);
        return uint256(IKashiPair(wrapped).accrueInfo().interestPerSecond) * 3154e4;
    }

    function getAPRFromUnderlying(address _token) public view override returns(uint256) {
        address wrapped = lendingRegistry.underlyingToProtocolWrapped(_token, protocolKey);
        return getAPRFromWrapped(wrapped);
    }

    function lend(address _underlying, uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        
        address kaToken = lendingRegistry.underlyingToProtocolWrapped(_underlying, protocolKey);  

        targets = new address[](3);
        data = new bytes[](3);

        uint256[] memory actions = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory callData = new bytes[](2);

        //Depositing into BentoBox
        actions[0] = 20;
        values[0] = 0;
        callData[0] = abi.encode(IERC20(_underlying),_tokenHolder,_amount,0);
        //Add Assets in Kashi
        actions[1] = 1;
        values[1] = 0;
        callData[1] = abi.encode(int8(-2),_tokenHolder,false);

        // zero out approval to be sure
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(IERC20.approve.selector,  address(bentoBox), 0);

        // Set approval
        targets[1] = _underlying;
        data[1] = abi.encodeWithSelector(IERC20.approve.selector,  address(bentoBox), _amount);

        // Deposit into Kashi
        targets[2] = address(kaToken);
        data[2] =  abi.encodeWithSelector(IKashiPair.cook.selector,actions,values,callData);
        return(targets, data);
    }

    function unlend(address _wrapped, uint256 _amount,address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        
        address underlying = address(IKashiPair(_wrapped).asset());
        
        targets = new address[](1);
        data = new bytes[](1);

        uint256[] memory actions = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory callData = new bytes[](2);

        //Remove Assets from kashi
        actions[0] = 3;
        values[0] = 0;
        callData[0] = abi.encode(_amount,_tokenHolder);
        //Withdraw Assets from BentoBox
        actions[1] = 21;
        values[1] = 0;
        callData[1] = abi.encode(IERC20(underlying),_tokenHolder,0,int8(-1));

        // Withdraw from Kashi Lending
        targets[0] = address(_wrapped);
        data[0] =  abi.encodeWithSelector(IKashiPair.cook.selector,actions,values,callData);
        
        // return targets and call data
        return(targets, data);
    }

    function exchangeRate(address _kaToken) public override returns(uint256) {
        _kaToken.call{ value: 0 }(abi.encodeWithSelector(IKashiPair.accrue.selector));
        
        (uint128 aElastic, uint128 aBase) = IKashiPair(_kaToken).totalAsset();
        (uint128 bElastic, uint128 bBase) = IKashiPair(_kaToken).totalBorrow();
        address underlying = address(IKashiPair(_kaToken).asset());
        uint8 _decimal = IKashiPair(_kaToken).decimals();
        
        uint256 allShare = aElastic + bentoBox.toShare(IERC20(underlying), bElastic, true);

        uint256 share = ((1e18) * allShare) / aBase;

        return bentoBox.toAmount(IERC20(underlying),share,true);
    }


    function exchangeRateView(address _kaToken) public view override returns(uint256) {
        (uint128 aElastic, uint128 aBase) = IKashiPair(_kaToken).totalAsset();
        (uint128 bElastic, uint128 bBase) = IKashiPair(_kaToken).totalBorrow();
        address underlying = address(IKashiPair(_kaToken).asset());
        uint8 _decimal = IKashiPair(_kaToken).decimals();
        
        uint256 allShare = aElastic + bentoBox.toShare(IERC20(underlying), bElastic, true);

        uint256 share = ((1e18) * allShare) / aBase;

        return bentoBox.toAmount(IERC20(underlying),share,true);
    }
}