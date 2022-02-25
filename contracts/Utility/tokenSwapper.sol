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

    //Exchange tokens in nest for tokens deposited in this contract
    //(This function is called by the nest callFacet)
    //(Nest needs to give this contract approval to transfer tokens out of the nest)
    function swapTokenForToken() public onlyOwner{
        
        //Send all tokens saved in outTokens[] to the nest
        for (uint256 i = 0; i < outTokens.length; i++) {
            outTokens[i].transfer(address(nest),outTokenAmounts[i]);
        }

        //Transfer all tokens saved in inTokens[] from the nest to this contract
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

