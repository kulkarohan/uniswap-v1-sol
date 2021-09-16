// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// ============ Imports ============
import './Factory.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Exchange {
    using SafeMath for uint256;

    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    /// ============ Exchange Info ============

    string public name;
    string public symbol;

    uint256 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    address public token;
    address public factory;

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

    /// ============ Constructor ============

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

    /// ============ Public Methods ============

    // TODO
    function addLiquidity(
        uint256 _minLiquidity,
        uint256 _maxTokens,
        uint256 _deadline
    ) external payable returns (uint256) {}

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
        uint256 paddedInputReserve = _inputReserve.mul(1000);
        uint256 denominator = paddedInputReserve.add(inputAmountWithFee);

        return numerator.div(denominator);
    }

    // TODO
    function ethToTokenInput(
        uint256 _ethSold,
        uint256 _minTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private returns (uint256) {}

    /// ============ Fallback ============

    fallback() external payable {
        ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    /// ============ Receive ============

    receive() external payable {} // solhint-disable-line no-empty-blocks
}
