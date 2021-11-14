pragma solidity 0.8.1;

import "./IERC20.sol";

interface IWETH is IERC20 {
    function withdraw(uint wad) external;
}