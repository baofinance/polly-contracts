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

    struct Epoch {
        uint length;
        uint number;
        uint endBlock;
        uint distribute;
    }

    //Not actually a function but a struct
    function epoch() external view returns(uint256,uint256,uint256,uint256);

    function stake(uint amount, address recipient) external returns (uint256);

    function unstake(uint amount, bool trigger) external view returns (uint256);
}

interface IKlimaStakingHelper{
    function stake(uint amount) external returns (uint256);
}

contract LendingLogicKLIMA is ILendingLogic {

    //using base 1e9
    uint blockTime = 22e8; //2.2 seconds per block
    uint secondsPerYear = 31536000e9;
    IKlimaStakingHelper klimaStakingHelper = IKlimaStakingHelper(0x4D70a031Fc76DA6a9bC0C922101A05FA95c3A227);
    IKlimaStaking klimaStakingPool = IKlimaStaking(0x25d28a24Ceb6F81015bB0b2007D795ACAc411b4d);
    IERC20 klima = IERC20(0x4e78011Ce80ee02d2c3e649Fb657E45898257815);
    

    function getAPRFromWrapped(address _token) external view override returns(uint256) {
        return getAPRFromUnderlying(_token);
    }

    function getAPRFromUnderlying(address _token) public view override returns(uint256) {       
        (uint epoch, , ,uint distribute) = klimaStakingPool.epoch();
        epoch = epoch*1e9;
        uint secondsPerEpoch = fmul(epoch,blockTime,1e9);
        uint epochsPerYear = fdiv(secondsPerYear,secondsPerEpoch,1e9);
        uint distributionPerEpoch = fdiv(distribute,klima.balanceOf(address(klimaStakingPool)),1e9); 
        //Returning value with base 1e18
        return(fmul(distributionPerEpoch,epochsPerYear,1e9)*1e9);
    }

    function lend(address _underlying,uint256 _amount, address _tokenHolder) external view override returns(address[] memory targets, bytes[] memory data) {
        IERC20 underlying = IERC20(_underlying);

        targets = new address[](3);
        data = new bytes[](3);

        // zero out approval to be sure
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(underlying.approve.selector, address(klimaStakingHelper), 0);

        // Set approval
        targets[1] = _underlying;
        data[1] = abi.encodeWithSelector(underlying.approve.selector, address(klimaStakingHelper), _amount);

        // Stake KLIMA
        targets[2] = address(klimaStakingHelper);
        data[2] =  abi.encodeWithSelector(klimaStakingHelper.stake.selector, _amount, _tokenHolder);

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
        data[2] =  abi.encodeWithSelector(klimaStakingPool.unstake.selector, _amount, false);

        return(targets, data);
    }

    function exchangeRate(address) external pure override returns(uint256) {
        return 10**9;
    }

    function exchangeRateView(address) external pure override returns(uint256) {
        return 10**9;
    }

    function fmul(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256 z) {
        assembly {
            if iszero(eq(div(mul(x,y),x),y)) {revert(0,0)}
            z := div(mul(x,y),baseUnit)
        }
    }

    function fdiv(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256 z) {
        assembly {
            if iszero(eq(div(mul(x,baseUnit),x),baseUnit)) {revert(0,0)}
            z := div(mul(x,baseUnit),y)
        }
    }

}