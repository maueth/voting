// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./ERC20.sol";


contract VoteToken is ERC20 {
    constructor(address distributor, uint256 initialValue) ERC20("Voting Token", "VT") {
        balanceOf[distributor]  = initialValue;
        totalSupply = initialValue;
    }
}