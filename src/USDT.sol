// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    constructor() ERC20("USDT Token", "USDT") {
        _mint(msg.sender, 1_000_000_000 * 10 ** 18);
    }
}