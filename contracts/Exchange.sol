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

    /// @notice Deposit ETH and Tokens (token) at current ratio to mint UNI tokens.
    /// @dev _minLiquidity does nothing when total UNI supply is 0.
    /// @param _minLiquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
    /// @param _maxTokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @return The amount of UNI minted.
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

    /// @dev Burn UNI tokens to withdraw ETH and Tokens at current ratio.
    /// @param _amount Amount of UNI burned.
    /// @param _minEth Minimum ETH withdrawn.
    /// @param _minTokens Minimum Tokens withdrawn.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @return The amount of ETH and Tokens withdrawn.
    function removeLiquidity(
        uint256 _amount,
        uint256 _minEth,
        uint256 _minTokens,
        uint256 _deadline
    ) external returns (uint256, uint256) {
        require(_amount > 0);
        require(_deadline > block.timestamp);
        require(_minEth > 0);
        require(_minTokens > 0);

        uint256 totalLiquidity = totalSupply;
        require(totalLiquidity > 0);

        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 ethAmount = (_amount.mul(address(this).balance)).div(totalLiquidity);
        uint256 tokenAmount = (_amount.mul(tokenReserve)).div(totalLiquidity);

        require(ethAmount >= _minEth);
        require(tokenAmount >= _minTokens);

        balances[msg.sender] -= _amount;
        totalSupply = totalLiquidity - _amount;

        (bool success, ) = payable(msg.sender).call{ value: ethAmount }('');
        require(success, 'ERROR: FAILED SENDING ETHER');
        require(IExchange(token).transfer(msg.sender, tokenAmount));

        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
        emit Transfer(msg.sender, ZERO_ADDRESS, _amount);

        return (ethAmount, tokenAmount);
    }

    /// @notice Convert ETH to Tokens.
    /// @dev User specifies exact input (msg.value) and minimum output.
    /// @param _minTokens Minimum Tokens bought.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @return Amount of Tokens bought.
    function ethToTokenSwapInput(uint256 _minTokens, uint256 _deadline)
        external
        payable
        returns (uint256)
    {
        return ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, msg.sender);
    }

    /// @notice Convert ETH to Tokens and transfers Tokens to recipient.
    /// @dev User specifies exact input (msg.value) and minimum output
    /// @param _minTokens Minimum Tokens bought.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output Tokens.
    /// @return Amount of Tokens bought.
    function ethToTokenTransferInput(
        uint256 _minTokens,
        uint256 _deadline,
        address _recipient
    ) external payable returns (uint256) {
        require(_recipient != address(this));
        require(_recipient != ZERO_ADDRESS);
        return ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, _recipient);
    }

    /// @notice Convert ETH to Tokens.
    /// @dev User specifies maximum input (msg.value) and exact output.
    /// @param _tokensBought Amount of tokens bought.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @return Amount of ETH sold.
    function ethToTokenSwapOutput(uint256 _tokensBought, uint256 _deadline)
        external
        payable
        returns (uint256)
    {
        return
            ethToTokenOutput(_tokensBought, msg.value, _deadline, msg.sender, msg.sender);
    }

    /// @notice Convert ETH to Tokens and transfers Tokens to recipient.
    /// @dev User specifies maximum input (msg.value) and exact output.
    /// @param _tokensBought Amount of tokens bought.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output Tokens.
    /// @return Amount of ETH sold.
    function ethToTokenTransferOutput(
        uint256 _tokensBought,
        uint256 _deadline,
        address _recipient
    ) external payable returns (uint256) {
        require(_recipient != address(this));
        require(_recipient != ZERO_ADDRESS);
        return
            ethToTokenOutput(_tokensBought, msg.value, _deadline, msg.sender, _recipient);
    }

    /// @notice Convert Tokens to ETH.
    /// @dev User specifies exact input and minimum output.
    /// @param _tokensSold Amount of Tokens sold.
    /// @param _minEth Minimum ETH purchased.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @return Amount of ETH bought.
    function tokenToEthSwapInput(
        uint256 _tokensSold,
        uint256 _minEth,
        uint256 _deadline
    ) external returns (uint256) {
        return tokenToEthInput(_tokensSold, _minEth, _deadline, msg.sender, msg.sender);
    }

    /// @notice Convert Tokens to ETH and transfers ETH to recipient.
    /// @dev User specifies exact input and minimum output.
    /// @param _tokensSold Amount of Tokens sold.
    /// @param _minEth Minimum ETH purchased.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output ETH.
    /// @return Amount of ETH bought.
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

    /// @notice Convert Tokens to ETH.
    /// @dev User specifies maximum input and exact output.
    /// @param _ethBought Amount of ETH purchased.
    /// @param _maxTokens Maximum Tokens sold.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @return Amount of Tokens sold.
    function tokenToEthSwapOutput(
        uint256 _ethBought,
        uint256 _maxTokens,
        uint256 _deadline
    ) external returns (uint256) {
        return
            tokenToEthOutput(_ethBought, _maxTokens, _deadline, msg.sender, msg.sender);
    }

    /// @notice Convert Tokens to ETH and transfers ETH to recipient.
    /// @dev User specifies maximum input and exact output.
    /// @param _ethBought Amount of ETH purchased.
    /// @param _maxTokens Maximum Tokens sold.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output ETH.
    /// @return Amount of Tokens sold.
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

    /// @notice Convert Tokens (token) to Tokens (_token).
    /// @dev User specifies exact input and minimum output.
    /// @param _tokensSold Amount of Tokens sold.
    /// @param _minTokensBought Minimum Tokens (_token) purchased.
    /// @param _minEthBought Minimum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _token The address of the token being purchased.
    /// @return Amount of Tokens (_token) bought.
    function tokenToTokenSwapInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _token
    ) external returns (uint256) {
        address exchange = IFactory(factory).getExchange(_token);
        return
            tokenToTokenInput(
                _tokensSold,
                _minTokensBought,
                _minEthBought,
                _deadline,
                msg.sender,
                msg.sender,
                exchange
            );
    }

    /// @notice Convert Tokens (self.token) to Tokens (token_addr) and transfers
    ///         Tokens (token_addr) to recipient.
    /// @dev User specifies exact input and minimum output.
    /// @param _tokensSold Amount of Tokens sold.
    /// @param _minTokensBought Minimum Tokens (token_addr) purchased.
    /// @param _minEthBought Minimum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output ETH.
    /// @param _token The address of the token being purchased.
    /// @return Amount of Tokens (token_addr) bought.
    function tokenToTokenTransferInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _recipient,
        address _token
    ) external returns (uint256) {
        address exchange = IFactory(factory).getExchange(_token);
        return
            tokenToTokenInput(
                _tokensSold,
                _minTokensBought,
                _minEthBought,
                _deadline,
                msg.sender,
                _recipient,
                exchange
            );
    }

    /// @notice Convert Tokens (self.token) to Tokens (token_addr).
    /// @dev User specifies maximum input and exact output.
    /// @param _tokensBought Amount of Tokens (token_addr) bought.
    /// @param _maxTokensSold Maximum Tokens (self.token) sold.
    /// @param _maxEthSold Maximum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _token The address of the token being purchased.
    /// @return Amount of Tokens (self.token) sold.
    function tokenToTokenSwapOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _token
    ) external returns (uint256) {
        address exchange = IFactory(factory).getExchange(_token);
        return
            tokenToTokenOutput(
                _tokensBought,
                _maxTokensSold,
                _maxEthSold,
                _deadline,
                msg.sender,
                msg.sender,
                exchange
            );
    }

    /// @notice Convert Tokens (self.token) to Tokens (token_addr) and transfers
    ///         Tokens (token_addr) to recipient.
    /// @dev User specifies maximum input and exact output.
    /// @param _tokensBought Amount of Tokens (token_addr) bought.
    /// @param _maxTokensSold Maximum Tokens (self.token) sold.
    /// @param _maxEthSold Maximum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output ETH.
    /// @param _token The address of the token being purchased.
    /// @return Amount of Tokens (self.token) sold.
    function tokenToTokenTransferOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _recipient,
        address _token
    ) external returns (uint256) {
        address exchange = IFactory(factory).getExchange(_token);
        return
            tokenToTokenOutput(
                _tokensBought,
                _maxTokensSold,
                _maxEthSold,
                _deadline,
                msg.sender,
                _recipient,
                exchange
            );
    }

    /// @notice Convert Tokens (self.token) to Tokens (exchange_addr.token).
    /// @dev Allows trades through contracts that were not deployed from the same factory.
    /// @dev User specifies exact input and minimum output.
    /// @param _tokensSold Amount of Tokens sold.
    /// @param _minTokensBought Minimum Tokens (token_addr) purchased.
    /// @param _minEthBought Minimum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _exchange The address of the exchange for the token being purchased.
    /// @return Amount of Tokens (exchange_addr.token) bought.
    function tokenToExchangeSwapInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _exchange
    ) external returns (uint256) {}

    /// @notice Convert Tokens (self.token) to Tokens (exchange_addr.token) and transfers
    ///         Tokens (exchange_addr.token) to recipient.
    /// @dev Allows trades through contracts that were not deployed from the same factory.
    /// @dev User specifies exact input and minimum output.
    /// @param _tokensSold Amount of Tokens sold.
    /// @param _minTokensBought Minimum Tokens (token_addr) purchased.
    /// @param _minEthBought Minimum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output ETH.
    /// @param _exchange The address of the exchange for the token being purchased.
    /// @return Amount of Tokens (exchange_addr.token) bought.
    function tokenToExchangeTransferInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _recipient,
        address _exchange
    ) external returns (uint256) {
        require(_recipient != address(this));
        return
            tokenToTokenInput(
                _tokensSold,
                _minTokensBought,
                _minEthBought,
                _deadline,
                msg.sender,
                _recipient,
                _exchange
            );
    }

    /// @notice Convert Tokens (self.token) to Tokens (exchange_addr.token).
    /// @dev Allows trades through contracts that were not deployed from the same factory.
    /// @dev User specifies maximum input and exact output.
    /// @param _tokensBought Amount of Tokens (token_addr) bought.
    /// @param _maxTokensSold Maximum Tokens (self.token) sold.
    /// @param _maxEthSold Maximum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _exchange The address of the exchange for the token being purchased.
    /// @return Amount of Tokens (self.token) sold.
    function tokenToExchangeSwapOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _exchange
    ) external returns (uint256) {
        return
            tokenToTokenOutput(
                _tokensBought,
                _maxTokensSold,
                _maxEthSold,
                _deadline,
                msg.sender,
                msg.sender,
                _exchange
            );
    }

    /// @notice Convert Tokens (self.token) to Tokens (exchange_addr.token) and transfers
    ///         Tokens (exchange_addr.token) to recipient.
    /// @dev Allows trades through contracts that were not deployed from the same factory.
    /// @dev User specifies maximum input and exact output.
    /// @param _tokensBought Amount of Tokens (token_addr) bought.
    /// @param _maxTokensSold Maximum Tokens (self.token) sold.
    /// @param _maxEthSold Maximum ETH purchased as intermediary.
    /// @param _deadline Time after which this transaction can no longer be executed.
    /// @param _recipient The address that receives output ETH.
    /// @param _exchange The address of the token being purchased.
    /// @return Amount of Tokens (self.token) sold.
    function tokenToExchangeTransferOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _recipient,
        address _exchange
    ) external returns (uint256) {
        require(_recipient != address(this));
        return
            tokenToTokenOutput(
                _tokensBought,
                _maxTokensSold,
                _maxEthSold,
                _deadline,
                msg.sender,
                _recipient,
                _exchange
            );
    }

    /// ============ Private Methods ============

    /// @dev Pricing function for converting between ETH and Tokens.
    /// @param _inputAmount Amount of ETH or Tokens being sold.
    /// @param _inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
    /// @param _outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
    /// @return Amount of ETH or Tokens bought.
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

    /// @dev Pricing function for converting between ETH and Tokens.
    /// @param _outputAmount Amount of ETH or Tokens being bought.
    /// @param _inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
    /// @param _outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
    /// @return Amount of ETH or Tokens sold.
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

    function ethToTokenInput(
        uint256 _ethSold,
        uint256 _minTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        require(_deadline >= block.timestamp);
        require(_ethSold > 0);
        require(_minTokens > 0);

        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 _inputReserve = address(this).balance.sub(_ethSold);
        uint256 tokensBought = getInputPrice(_ethSold, _inputReserve, tokenReserve);

        require(tokensBought > _minTokens);
        require(
            IExchange(token).transfer(_recipient, tokensBought),
            'ERROR: FAILED TOKEN TRANSFER'
        );

        emit TokenPurchase(_buyer, _ethSold, tokensBought);

        return tokensBought;
    }

    function ethToTokenOutput(
        uint256 _tokensBought,
        uint256 _maxEth,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        require(_deadline >= block.timestamp);
        require(_tokensBought > 0);
        require(_maxEth > 0);

        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 _inputReserve = address(this).balance.sub(_maxEth);
        uint256 ethSold = getOutputPrice(_tokensBought, _inputReserve, tokenReserve);
        uint256 ethRefund = _maxEth.sub(ethSold);

        if (ethRefund > 0) {
            (bool success, ) = payable(_buyer).call{ value: ethRefund }('');
            require(success, 'ERROR: FAILED SENDING ETHER REFUND');
        }

        require(
            IExchange(token).transfer(_recipient, _tokensBought),
            'ERROR: FAILED TOKEN TRANSFER'
        );

        emit TokenPurchase(_buyer, ethSold, _tokensBought);

        return ethSold;
    }

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

        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 ethBought = getInputPrice(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );
        require(ethBought >= _minEth);

        (bool success, ) = payable(_recipient).call{ value: ethBought }('');
        require(success, 'ERROR: FAILED SENDING ETHER');
        require(
            IExchange(token).transferFrom(_buyer, address(this), _tokensSold),
            'ERROR: FAILED TOKEN TRANSFER'
        );

        emit EthPurchase(_buyer, _tokensSold, ethBought);

        return ethBought;
    }

    function tokenToEthOutput(
        uint256 _ethBought,
        uint256 _maxTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {
        require(_deadline >= block.timestamp);
        require(_ethBought > 0);
        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(
            _ethBought,
            tokenReserve,
            address(this).balance
        );
        require(_maxTokens >= tokensSold);

        (bool success, ) = payable(_recipient).call{ value: _ethBought }('');
        require(success, 'ERROR: FAILED SENDING ETHER');
        require(
            IExchange(token).transferFrom(_buyer, address(this), tokensSold),
            'ERROR: FAILED TOKEN TRANSFER'
        );

        emit EthPurchase(_buyer, tokensSold, _ethBought);

        return tokensSold;
    }

    function tokenToTokenInput(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        uint256 _minEthBought,
        uint256 _deadline,
        address _buyer,
        address _recipient,
        address _exchange
    ) private returns (uint256) {
        require(_deadline >= block.timestamp);
        require(_tokensSold > 0);
        require(_minTokensBought > 0);
        require(_minEthBought > 0);
        require(_exchange != address(this));
        require(_exchange != ZERO_ADDRESS);

        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 ethBought = getInputPrice(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        require(ethBought >= _minEthBought);
        require(
            IExchange(token).transferFrom(_buyer, address(this), _tokensSold),
            'ERROR: FAILED TOKEN TRANSFER'
        );

        uint256 tokensBought = IExchange(_exchange).ethToTokenTransferInput{
            value: ethBought
        }(_minTokensBought, _deadline, _recipient);

        emit EthPurchase(_buyer, _tokensSold, ethBought);

        return tokensBought;
    }

    function tokenToTokenOutput(
        uint256 _tokensBought,
        uint256 _maxTokensSold,
        uint256 _maxEthSold,
        uint256 _deadline,
        address _buyer,
        address _recipient,
        address _exchange
    ) private returns (uint256) {
        require(_deadline >= block.timestamp);
        require(_tokensBought > 0);
        require(_maxEthSold > 0);
        require(_exchange != address(this));
        require(_exchange != ZERO_ADDRESS);

        uint256 ethBought = IExchange(_exchange).getEthToTokenOutputPrice(_tokensBought);
        uint256 tokenReserve = IExchange(token).balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(
            ethBought,
            tokenReserve,
            address(this).balance
        );

        require(_maxTokensSold > tokensSold);
        require(_maxEthSold >= ethBought);
        require(
            IExchange(token).transferFrom(_buyer, address(this), tokensSold),
            'ERROR: FAILED TOKEN TRANSFER'
        );

        // uint256 ethSold = IExchange(_exchange).ethToTokenTransferOutput{
        //     value: ethBought
        // }(_tokensBought, _deadline, _recipient);

        emit EthPurchase(_buyer, tokensSold, ethBought);

        return tokensSold;
    }

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
