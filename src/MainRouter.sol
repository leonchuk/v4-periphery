// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {V4Router} from "./V4Router.sol";
import {MultiOwnable} from "./base/MultiOwnable.sol";
import {ReentrancyLock} from "./base/ReentrancyLock.sol";

/// @title MainRouter
/// @notice Concrete entry point for working exclusively with `V4Router`.
/// @dev Actions can be executed only by one of the owners (see `MultiOwnable`). Owners can add/remove other owners.
///      An owner is recognised by `msg.sender` or `tx.origin` (see `MultiOwnable.onlyOwner`).
///      `ReentrancyLock` stores `msg.sender` transiently for the duration of the call and `msgSender()` returns it,
///      so payer/recipient mapping (`MSG_SENDER`, `payerIsUser`) refers to the account that called the router.
///      `params` is the abi encoding of (bytes actions, bytes[] params), see `Actions.sol` and `V4Router`.
///      `unlockCallback` is inherited from `SafeCallback` (only callable by the PoolManager) and dispatches
///      to `BaseActionsRouter._unlockCallback`, so it does not need to be re-implemented here.
contract MainRouter is V4Router, MultiOwnable, ReentrancyLock {
    using SafeTransferLib for address;

    constructor(IPoolManager _poolManager)
        V4Router(_poolManager)
        MultiOwnable()
    {}

    /// @notice Executes a batch of `V4Router` actions
    /// @param params abi.encode(bytes actions, bytes[] params)
    function executeActions(bytes calldata params) external payable onlyOwner isNotLocked {
        _executeActions(params);
    }

    /// @notice Executes a batch of `V4Router` actions and returns any ETH left on this contract to the owner
    /// @param params abi.encode(bytes actions, bytes[] params)
    function executeActionsAndSweepExcessETH(bytes calldata params) external payable onlyOwner isNotLocked {
        _executeActions(params);

        uint256 balance = address(this).balance;
        if (balance > 0) {
            msgSender().safeTransferETH(balance);
        }
    }

    /// @notice The account considered the executor of the actions (payer for `payerIsUser`, `MSG_SENDER` recipient)
    /// @dev `msg.sender` cannot be used here: during `unlockCallback` it is the PoolManager.
    ///      Returns the caller stored by `ReentrancyLock.isNotLocked` (zero address outside of an execution).
    function msgSender() public view override returns (address) {
        return _getLocker();
    }

    /// @notice Transfers `amount` of `token` from `payer` to the PoolManager (the "settle" step of an action)
    /// @dev Called by `DeltaResolver._settle` for SETTLE/SETTLE_ALL/SETTLE_PAIR actions and swaps that owe tokens.
    ///      The PoolManager does not pull tokens by itself: it only measures its balance change in `settle()`,
    ///      so the router must first move the tokens to it. If `payer` is this contract the tokens are sent directly,
    ///      otherwise they are pulled from `payer` (requires an ERC20 allowance to this contract).
    function _pay(Currency token, address payer, uint256 amount) internal override {
        if (payer == address(this)) {
            token.transfer(address(poolManager), amount);
        } else {
            ERC20(Currency.unwrap(token)).safeTransferFrom(payer, address(poolManager), amount);
        }
    }

    /// @dev Accepts ETH from the PoolManager (take) and from the owners
    receive() external payable {}
}
