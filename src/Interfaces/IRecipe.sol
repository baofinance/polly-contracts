//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.1;

interface IRecipe {
    function bake(
        address _inputToken,
        address _outputToken,
        uint256 _maxInput,
        bytes memory _data
    ) external returns (uint256 inputAmountUsed, uint256 outputAmount);

    function toPie(address _pie, uint256 _outputAmount) external payable;

    function calcToPie(address _pie, uint256 _poolAmount) external returns(uint256);
}