// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IExchange {
    /// ============ ERC20 Address ============

    function tokenAddress() external view returns (address);

    /// ============ Uniswap Factory Address ============

    function factoryAddress() external view returns (address);

    /// ============ Provide Liquidity ============

    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) external payable returns (uint256);

    function removeLiquidity(
        uint256 amount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
    ) external returns (uint256, uint256);

    /// ============ Get Prices ============

    function getEthToTokenInputPrice(uint256 ethSold) external view returns (uint256);

    function getEthToTokenOutputPrice(uint256 tokensBought)
        external
        view
        returns (uint256);

    function getTokenToEthInputPrice(uint256 tokensSold) external view returns (uint256);

    function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256);

    /// ============ Trade ETH to ERC20 ============

    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline)
        external
        payable
        returns (uint256);

    function ethToTokenTransferInput(
        uint256 minTokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline)
        external
        payable
        returns (uint256);

    function ethToTokenTransferOutput(
        uint256 tokensBought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    /// ============ Trade ERC20 to ETH ============

    function tokenToEthSwapInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline
    ) external returns (uint256);

    function tokenToEthTransferInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    function tokenToEthSwapOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline
    ) external returns (uint256);

    function tokenToEthTransferOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    /// ============ Trade ERC20 to ERC20 ============

    function tokenToTokenSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address token
    ) external returns (uint256);

    function tokenToTokenTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address recipient,
        address token
    ) external returns (uint256);

    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address token
    ) external returns (uint256);

    function tokenToTokenTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address token
    ) external returns (uint256);

    /// ============ Trade ERC20 to Custom Pool ============

    function tokenToExchangeSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address exchange
    ) external returns (uint256 tokensBought);

    function tokenToExchangeTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address recipient,
        address exchange
    ) external returns (uint256 tokensBought);

    function tokenToExchangeSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address exchange
    ) external returns (uint256);

    function tokenToExchangeTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address exchange
    ) external returns (uint256);

    /// ============ ERC20 compatibility for liquidity tokens ============

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 value
    ) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
