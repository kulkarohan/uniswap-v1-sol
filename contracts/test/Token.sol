// SPDX-License-Identifier: MIT
// FOR TEST PURPOSES ONLY. NOT PRODUCTION SAFE
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
    constructor() ERC20('Rohan Kulkarni', 'ROHAN') {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
