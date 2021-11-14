pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../Interfaces/IUniRouter.sol";

contract Converter{
    
    IUniRouter sushiRouter;
    address WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    
    constructor(address _sushiRouter){
        sushiRouter = IUniRouter(_sushiRouter);
    }
    
    //string to bytes 
    function stringToBytes32(string memory source) public view returns (bytes memory result) {
        result = abi.encodePacked(source);
    }
    //encode: Sell _amount of _token0 for _token1 
    //NO WETH TRANSFERS
    function stringToHash(address _token0,address _token1, uint256 _amount)public view returns(bytes memory){
        require(_token0 != address(WETH) && _token1 != address(WETH)); 
        address[] memory route = new address[](3);
        route[0] = _token0;
        route[1] = address(WETH);
        route[2] = _token1;
        return abi.encodeWithSelector(sushiRouter.swapExactTokensForTokens.selector,_amount,type(uint256).max,route,address(this),block.timestamp + 1);
    }
}