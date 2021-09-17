// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// ============ Imports ============

import './Exchange.sol';
import './InitializedProxy.sol';

contract Factory {
    /// ============ Storage ============

    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public exchangeTemplate;
    uint256 public tokenCount;

    mapping(address => address) private tokenToExchange;
    mapping(address => address) private exchangeToToken;
    mapping(uint256 => address) private idToToken;

    /// ============ Events ============

    event NewExchange(address indexed token, address indexed exchange);

    /// ============ View Methods ============

    function getExchange(address _token) external view returns (address) {
        return tokenToExchange[_token];
    }

    function getToken(address _exchange) external view returns (address) {
        return exchangeToToken[_exchange];
    }

    function getTokenWithId(uint256 _tokenId) external view returns (address) {
        return idToToken[_tokenId];
    }

    /// ============ Constructor ============

    constructor() {
        exchangeTemplate = address(new Exchange());
    }

    /// ============ Factory Methods ============

    function createExchange(address _token) external returns (address) {
        require(_token != ZERO_ADDRESS);
        require(tokenToExchange[_token] == ZERO_ADDRESS);

        bytes memory _initializationCalldata = abi.encodeWithSignature(
            'setup(address)',
            _token
        );
        address exchange = address(
            new InitializedProxy(exchangeTemplate, _initializationCalldata)
        );

        tokenToExchange[_token] = exchange;
        exchangeToToken[exchange] = _token;

        tokenCount++;
        idToToken[tokenCount] = _token;

        emit NewExchange(_token, exchange);

        return exchange;
    }
}
