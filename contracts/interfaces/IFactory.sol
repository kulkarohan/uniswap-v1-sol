// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IFactory {
    function getExchange(address token) external view returns (address exchange);

    function getToken(address exchange) external view returns (address token);

    function getTokenWithId(uint256 tokenId) external view returns (address token);

    function createExchange(address token) external returns (address exchange);
}
