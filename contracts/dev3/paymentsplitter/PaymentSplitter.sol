// SPDX-License-Identifier: MIT
pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender)
    external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function approve(address spender, uint256 value)
    external returns (bool);

  function transferFrom(address from, address to, uint256 value)
    external returns (bool);

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {

  using SafeMath for uint256;

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 value
  )
    internal
  {
    require(token.transfer(to, value));
  }

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 value
  )
    internal
  {
    require(token.transferFrom(from, to, value));
  }

  function safeApprove(
    IERC20 token,
    address spender,
    uint256 value
  )
    internal
  {
    // safeApprove should only be called when setting an initial allowance, 
    // or when resetting it to zero. To increase and decrease it, use 
    // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
    require((value == 0) || (token.allowance(msg.sender, spender) == 0));
    require(token.approve(spender, value));
  }

  function safeIncreaseAllowance(
    IERC20 token,
    address spender,
    uint256 value
  )
    internal
  {
    uint256 newAllowance = token.allowance(address(this), spender).add(value);
    require(token.approve(spender, newAllowance));
  }

  function safeDecreaseAllowance(
    IERC20 token,
    address spender,
    uint256 value
  )
    internal
  {
    uint256 newAllowance = token.allowance(address(this), spender).sub(value);
    require(token.approve(spender, newAllowance));
  }
}


/**
 * @title PaymentSplitter
 * @dev This contract can be used when payments need to be received by a group
 * of people and split proportionately to some number of shares they own.
 */
contract PaymentSplitter {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  event PayeeAdded(address account, uint256 shares);
  event PaymentReleased(address to, address token, uint256 amount);

  uint256 _totalShares;
  mapping(address => uint256) _totalReleased;

  mapping(address => uint256) _shares;
  mapping(address => mapping(address => uint256)) _released;
  address[] _payees;

  /**
   * @dev Constructor
   */
  constructor(address[] payees, uint256[] shares) public {
    require(payees.length == shares.length);
    require(payees.length > 0);

    for (uint256 i = 0; i < payees.length; i++) {
      _addPayee(payees[i], shares[i]);
    }
  }

  /**
   * @return the total shares of the contract.
   */
  function totalShares() external view returns(uint256) {
    return _totalShares;
  }

  /**
   * @return the total amount already released.
   */
  function totalReleased(address token) external view returns(uint256) {
    return _totalReleased[token];
  }

  /**
   * @return the shares of an account.
   */
  function shares(address account) external view returns(uint256) {
    return _shares[account];
  }

  /**
   * @return the amount already released to an account.
   */
  function released(address token, address account) external view returns(uint256) {
    return _released[token][account];
  }

  /**
   * @return the address of a payee.
   */
  function payee(uint256 index) external view returns(address) {
    return _payees[index];
  }

  /**
   * @dev Release one of the payee's proportional payment.
   * @param token Token to release from the contract.
   * @param account Whose payments will be released.
   */
  function release(address token, address account) external {
    require(_shares[account] > 0);

    uint256 totalReceived = IERC20(token).balanceOf(address(this)).add(_totalReleased[token]);
    uint256 payment = totalReceived.mul(
      _shares[account]).div(
        _totalShares).sub(
          _released[token][account]
    );

    require(payment != 0);

    _released[token][account] = _released[token][account].add(payment);
    _totalReleased[token] = _totalReleased[token].add(payment);

    IERC20(token).safeTransfer(account, payment);
    emit PaymentReleased(account, token, payment);
  }

  /**
   * @dev Add a new payee to the contract.
   * @param account The address of the payee to add.
   * @param shares_ The number of shares owned by the payee.
   */
  function _addPayee(address account, uint256 shares_) private {
    require(account != address(0));
    require(shares_ > 0);
    require(_shares[account] == 0);

    _payees.push(account);
    _shares[account] = shares_;
    _totalShares = _totalShares.add(shares_);
    emit PayeeAdded(account, shares_);
  }
}
