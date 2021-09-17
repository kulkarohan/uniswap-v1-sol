// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// ============ Imports ============

import './interfaces/IExchange.sol';
import './interfaces/IFactory.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Exchange {
    using SafeMath for uint256;
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    /// ============ Exchange Info ============

    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public totalSupply;
    address private token;
    address private factory;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    /// ============ Events ============

    event TokenPurchase(
        address indexed buyer,
        uint256 indexed ethSold,
        uint256 indexed tokensBought
    );

    event EthPurchase(
        address indexed buyer,
        uint256 indexed tokensSold,
        uint256 indexed ethBought
    );

    event AddLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /// ============ Initializer ============

    function setup(address _token) external {
        require(factory == ZERO_ADDRESS);
        require(token == ZERO_ADDRESS);
        require(_token != ZERO_ADDRESS);

        factory = msg.sender;
        token = _token;
        name = 'Uniswap V1';
        symbol = 'UNI-V1';
        decimals = 18;
    }

    /// ============ View Methods ============

    function tokenAddress() external view returns (address) {
        return token;
    }

    function factoryAddress() external view returns (address) {
        return factory;
    }

    function getEthToTokenInputPrice(uint256 _ethSold) external view returns (uint256) {
        require(_ethSold > 0);
        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        return getInputPrice(_ethSold, address(this).balance, tokenReserve);
    }

    function getEthToTokenOutputPrice(uint256 _tokensBought)
        external
        view
        returns (uint256)
    {
        require(_tokensBought > 0);
        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 ethSold = getOutputPrice(
            _tokensBought,
            address(this).balance,
            tokenReserve
        );
        return ethSold;
    }

    function getTokenToEthInputPrice(uint256 _tokensSold)
        external
        view
        returns (uint256)
    {
        require(_tokensSold > 0);
        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 ethBought = getInputPrice(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );
        return ethBought;
    }

    function getTokenToEthOutputPrice(uint256 _ethBought)
        external
        view
        returns (uint256)
    {
        require(_ethBought > 0);
        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        return getOutputPrice(_ethBought, tokenReserve, address(this).balance);
    }

    /// ============ Exchange Methods ============

    function addLiquidity(
        uint256 _minLiquidity,
        uint256 _maxTokens,
        uint256 _deadline
    ) external payable returns (uint256) {
        require(_deadline > block.timestamp);
        require(_maxTokens > 0);
        require(msg.value > 0);

        uint256 totalLiquidity = totalSupply;

        if (totalLiquidity > 0) {
            require(_minLiquidity > 0);

            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = IExchange(token).balanceOf(address(this));
            uint256 tokenAmount = (msg.value.mul(tokenReserve)).div((ethReserve.add(1)));
            uint256 liquidityMinted = (msg.value.mul(totalLiquidity)).div(ethReserve);

            require(_maxTokens > tokenAmount);
            require(liquidityMinted >= _minLiquidity);

            balances[msg.sender] += liquidityMinted;
            totalSupply = totalLiquidity + liquidityMinted;

            require(
                IExchange(token).transferFrom(msg.sender, address(this), tokenAmount),
                'ERROR: FAILED TOKEN TRANSFER'
            );

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(ZERO_ADDRESS, msg.sender, liquidityMinted);

            return liquidityMinted;
        } else {
            require(factory != ZERO_ADDRESS);
            require(token != ZERO_ADDRESS);
            require(msg.value >= 1000000000);
            require(IFactory(factory).getExchange(token) == address(this));

            uint256 tokenAmount = _maxTokens;
            uint256 initialLiquidity = address(this).balance;

            totalSupply = initialLiquidity;
            balances[msg.sender] = initialLiquidity;

            require(
                IExchange(token).transferFrom(msg.sender, address(this), tokenAmount)
            );

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(ZERO_ADDRESS, msg.sender, initialLiquidity);

            return initialLiquidity;
        }
    }

    // TODO
    function removeLiquidity(
        uint256 _amount,
        uint256 _minEth,
        uint256 _minTokens,
        uint256 _deadline
    ) external returns (uint256, uint256) {}

    // TODO
    function ethToTokenSwapInput(uint256 _minTokens, uint256 _deadline)
        external
        payable
        returns (uint256)
    {}

    // TODO
    function ethToTokenTransferInput(
        uint256 _minTokens,
        uint256 _deadline,
        address _recipient
    ) external payable returns (uint256) {}

    // TODO
    function ethToTokenSwapOutput(uint256 _tokensBought, uint256 _deadline)
        external
        payable
        returns (uint256)
    {}

    // TODO
    function ethToTokenTransferOutput(
        uint256 _tokensBought,
        uint256 _deadline,
        address _recipient
    ) external payable returns (uint256) {}

    function tokenToEthSwapInput(
        uint256 _tokensSold,
        uint256 _minEth,
        uint256 _deadline
    ) external returns (uint256) {
        return tokenToEthInput(_tokensSold, _minEth, _deadline, msg.sender, msg.sender);
    }

    function tokenToEthTransferInput(
        uint256 _tokensSold,
        uint256 _minEth,
        uint256 _deadline,
        address _recipient
    ) external returns (uint256) {
        require(_recipient != address(this));
        require(_recipient != ZERO_ADDRESS);
        return tokenToEthInput(_tokensSold, _minEth, _deadline, msg.sender, _recipient);
    }

    function tokenToEthSwapOutput(
        uint256 _ethBought,
        uint256 _maxTokens,
        uint256 _deadline
    ) external returns (uint256) {
        return
            tokenToEthOutput(_ethBought, _maxTokens, _deadline, msg.sender, msg.sender);
    }

    function tokenToEthTransferOutput(
        uint256 _ethBought,
        uint256 _maxTokens,
        uint256 _deadline,
        address _recipient
    ) external returns (uint256) {
        require(_recipient != address(this));
        require(_recipient != ZERO_ADDRESS);
        return
            tokenToEthOutput(_ethBought, _maxTokens, _deadline, msg.sender, _recipient);
    }

    // TODO
    function tokenToTokenSwapInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _token
    ) external returns (uint256) {}

    // TODO
    function tokenToTokenTransferInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _recipient,
        address _token
    ) external returns (uint256) {}

    // TODO
    function tokenToTokenSwapOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _token
    ) external returns (uint256) {}

    // TODO
    function tokenToTokenTransferOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _recipient,
        address _token
    ) external returns (uint256) {}

    // TODO
    function tokenToExchangeSwapInput() external returns (uint256) {}

    // TODO
    function tokenToExchangeTransferInput() external returns (uint256) {}

    // TODO
    function tokenToExchangeSwapOutput() external returns (uint256) {}

    // TODO
    function tokenToExchangeTransferOutput() external returns (uint256) {}

    /// ============ Private Methods ============

    function getInputPrice(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve
    ) private pure returns (uint256) {
        require(_inputReserve > 0);
        require(_outputReserve > 0);

        uint256 inputAmountWithFee = _inputAmount.mul(997);
        uint256 numerator = inputAmountWithFee.mul(_outputReserve);
        uint256 denominator = (_inputReserve.mul(1000)).add(inputAmountWithFee);

        return numerator.div(denominator);
    }

    function getOutputPrice(
        uint256 _outputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve
    ) private pure returns (uint256) {
        require(_inputReserve > 0);
        require(_outputReserve > 0);

        uint256 numerator = (_inputReserve.mul(_outputAmount)).mul(1000);
        uint256 denominator = (_outputReserve.sub(_outputAmount)).mul(997);

        return (numerator.div(denominator)).add(1);
    }

    // TODO
    function ethToTokenInput(
        uint256 _ethSold,
        uint256 _minTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {}

    // TODO
    function tokenToEthInput(
        uint256 _tokensSold,
        uint256 _minEth,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        require(_deadline >= block.timestamp);
        require(_tokensSold > 0);
        require(_minEth > 0);

        uint256 tokenReserve = IExchange(token).balanceOf(address(this)); // TODO: check if this is right?
        uint256 ethBought = getInputPrice(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );
        // uint256 weiBought =
    }

    // TODO
    function tokenToEthOutput(
        uint256 _ethBought,
        uint256 _maxTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {}

    // TODO
    function tokenToTokenInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {}

    // TODO
    function tokenToTokenOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _buyer,
        address _recipient,
        address _exchange
    ) private returns (uint256) {}

    /// ============ ERC20 ============

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    /// ============ Fallback ============

    fallback() external payable {
        ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    /// ============ Receive ============

    receive() external payable {} // solhint-disable-line no-empty-blocks
}
