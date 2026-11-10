// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Minimal Slipstream SwapRouter surface (tickSpacing replaces Uniswap V3 fee).
interface ISlipstreamSwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        int24 tickSpacing;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

/// @title HorizonDestinationExecutor
/// @notice Wave 2 P2 stretch: destination-side swap (and future LP) after NTT mint-to-executor.
/// @dev Holds Slipstream router/NPM/MUSD/peer config. Does not implement Wormhole Executor auto-redeem (P1).
contract HorizonDestinationExecutor is Ownable {
    using SafeERC20 for IERC20;

    address public swapRouter;
    address public npm;
    address public musd;

    mapping(address => bool) public isPeerToken;

    event SwapExecuted(
        address indexed caller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient,
        int24 tickSpacing
    );
    event ConfigUpdated(address swapRouter, address npm, address musd);
    event PeerTokenUpdated(address indexed token, bool allowed);

    error ZeroAddress();
    error TokenNotAllowed(address token);

    constructor(address initialOwner_) Ownable(initialOwner_) {}

    /// @notice Set Slipstream router, NPM, and MUSD addresses.
    function setConfig(address swapRouter_, address npm_, address musd_) external onlyOwner {
        if (swapRouter_ == address(0) || npm_ == address(0) || musd_ == address(0)) {
            revert ZeroAddress();
        }
        swapRouter = swapRouter_;
        npm = npm_;
        musd = musd_;
        emit ConfigUpdated(swapRouter_, npm_, musd_);
    }

    /// @notice Allow or revoke a vault-share peer token for swaps.
    function setPeerToken(address token, bool allowed) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        isPeerToken[token] = allowed;
        emit PeerTokenUpdated(token, allowed);
    }

    function isAllowedToken(address token) public view returns (bool) {
        return token == musd || isPeerToken[token];
    }

    /// @notice Swap exact input via Slipstream `exactInputSingle`.
    /// @dev Prefers in-contract balance (mint-to-executor custody); pulls the shortfall from `msg.sender`.
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut,
        address recipient,
        int24 tickSpacing
    ) external returns (uint256 amountOut) {
        if (recipient == address(0) || swapRouter == address(0)) revert ZeroAddress();
        if (!isAllowedToken(tokenIn)) revert TokenNotAllowed(tokenIn);
        if (!isAllowedToken(tokenOut)) revert TokenNotAllowed(tokenOut);

        IERC20 inToken = IERC20(tokenIn);
        uint256 held = inToken.balanceOf(address(this));
        if (held < amountIn) {
            inToken.safeTransferFrom(msg.sender, address(this), amountIn - held);
        }

        inToken.forceApprove(swapRouter, amountIn);

        amountOut = ISlipstreamSwapRouter(swapRouter).exactInputSingle(
            ISlipstreamSwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                tickSpacing: tickSpacing,
                recipient: recipient,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            })
        );

        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut, recipient, tickSpacing);
    }

    /// @notice LP mint via NPM — Wave 2 stretch stub.
    function mintLp() external pure {
        revert("not implemented");
    }
}
