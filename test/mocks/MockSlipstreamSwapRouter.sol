// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal SwapRouter stand-in: pulls tokenIn and pays 1:1 tokenOut.
contract MockSlipstreamSwapRouter {
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
        returns (uint256 amountOut)
    {
        amountOut = params.amountIn;
        require(amountOut >= params.amountOutMinimum, "minOut");
        require(IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn), "in");
        require(IERC20(params.tokenOut).transfer(params.recipient, amountOut), "out");
    }
}
