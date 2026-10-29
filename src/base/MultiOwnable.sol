// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract MultiOwnable {
    mapping(address => bool) private owners;

    constructor () {
        _addOwner(msg.sender);
    }

    modifier onlyOwner() {
        require(owners[tx.origin] == true || owners[msg.sender] == true,'NotOwner');
        _;
    }

    /// @dev Owner management checks only `msg.sender`: with `tx.origin` any contract called by an owner could add itself
    modifier onlyOwnerSender() {
        require(owners[msg.sender], 'NotOwner');
        _;
    }

    function addOwner(address user) external onlyOwnerSender {
        _addOwner(user);
    }

    function _addOwner(address user) private {
        owners[user] = true;
    }

    function removeOwner(address user) public onlyOwnerSender {
        owners[user] = false;
    }

    function isOwner(address user) external view returns (bool) {
        return owners[user] == true;
    }
}
