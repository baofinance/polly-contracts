// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Interfaces/IERC20.sol";
import "./Interfaces/ILendingLogic.sol";

interface IsKLIMA {
    function rebase( uint256 klimaProfit_, uint epoch_) external returns (uint256);

    function circulatingSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function gonsForBalance( uint amount ) external view returns ( uint );

    function balanceForGons( uint gons ) external view returns ( uint );

    function index() external view returns ( uint );
}

interface IKlimaStaking {
    function stake(uint amount, address recipient) external returns (uint256);

    function unstake(uint amount, bool trigger) external view returns (uint256);
}


contract LendingLogicKLIMA is ILendingLogic {

    IKlimaStaking klimaStakingPool;

    constructor(address _klimaStakingPool) {
        IKlimaStaking klimaStakingPool = IKlimaStaking(_klimaStakingPool)
    }

    function getAPRFromWrapped(address _token) external view override returns(uint256) {
        return getAPRFromUnderlying(_token);
    }

    function getAPRFromUnderlying(address _token) public view override returns(uint256) {
        //ToDo: Calc APR from Staking contract info
        return(0)
    }

    function lend(address _underlying,uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        IERC20 underlying = IERC20(_underlying);

        targets = new address[](3);
        data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(underlying.approve.selector, address(klimaStakingPool), 0);

        // Set approval
        targets[1] = _underlying;
        data[1] = abi.encodeWithSelector(underlying.approve.selector, address(klimaStakingPool), _amount);

        // Stake KLIMA
        targets[2] = address(klimaStakingPool);
        data[2] =  abi.encodeWithSelector(klimaStakingPool.stake.selector, _underlying, _tokenHolder);

        return(targets, data);
    }

    function unlend(address _wrapped, uint256 _amount,address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        IERC20 wrapped = IERC20(_wrapped);

        targets = new address[](3);
        data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _wrapped;
        data[0] = abi.encodeWithSelector(wrapped.approve.selector, address(klimaStakingPool), 0);

        // Set approval
        targets[1] = _wrapped;
        data[1] = abi.encodeWithSelector(wrapped.approve.selector, address(klimaStakingPool), _amount);

        //Unstake sKLIMA
        targets[2] = address(klimaStakingPool);
        data[2] =  abi.encodeWithSelector(klimaStakingPool.unstake.selector, _wrapped, false);

        return(targets, data);
    }

    function exchangeRate(address) external pure override returns(uint256) {
        return 10**9;
    }

    function exchangeRateView(address) external pure override returns(uint256) {
        return 10**9;
    }

}