pragma solidity ^0.8.1;

import "../interfaces/IERC20.sol";
import "../interfaces/IBasketFacet.sol";
import "../OpenZeppelin/Ownable.sol";

contract swapper is Ownable {

    IERC20[] inTokens;
    IERC20[] outTokens;
    uint[] inTokenAmounts;
    uint[] outTokenAmounts;
    IBasketFacet nest;

    constructor(address _nest) {
        nest = IBasketFacet(_nest);
    }

    //Need to give this contract approval for moving the InTokens before calling this function
    function swapTokenForToken() public onlyOwner{
        
        for (uint256 i = 0; i < outTokens.length; i++) {
            //Send tokens out of this contract
            outTokens[i].transfer(address(nest),outTokenAmounts[i]);
        }

        for (uint256 i = 0; i < inTokens.length; i++) {
            //Send tokens into this contract
            inTokens[i].transferFrom(address(nest), address(this), inTokenAmounts[i]);

            //Remove tokens from basket
            nest.removeToken(address(inTokens[i]));
        }
        
    }

    function setInToken(IERC20[] memory _newInTokens, uint[] memory _tokenAmounts) external onlyOwner{
        inTokens = _newInTokens;
        inTokenAmounts = _tokenAmounts;
    }

    function setOutToken(IERC20[] memory _newOutTokens, uint[] memory _tokenAmounts) external onlyOwner{
        outTokens = _newOutTokens;
        outTokenAmounts = _tokenAmounts;
    }

    function setNest(address _nest) external onlyOwner{
        nest = IBasketFacet(_nest);
    }
    
    function withdrawAssets(address[] memory _tokens, uint[] memory _amounts) external onlyOwner{
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20(_tokens[i]).transfer(owner(),_amounts[i]);
        }
    }
}

