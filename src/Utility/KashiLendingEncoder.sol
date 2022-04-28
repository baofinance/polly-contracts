// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "../Strategies/KashiLending/Interfaces/IBentoBoxV1.sol";

contract KashiLendingEncoder{
    
    function encodeDataForKashiLending(address _nest, address _masterKontract) public view returns(bytes memory){
        return abi.encodeWithSelector(IBentoBoxV1.setMasterContractApproval.selector,_nest,_masterKontract,true,0,0x0000000000000000000000000000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000);
    }
    
    function encodeUnLendLending(address _nest, uint256 _amount) public view returns(bytes memory){
            return abi.encodeWithSelector(IBentoBoxV1.withdraw.selector, 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, _nest, _nest, 0, _amount);
    }

}