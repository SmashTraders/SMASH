pragma solidity ^0.4.24;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

/**
 * @title SMASH TRC20 token
 * @dev Implementation of the TRC20 standard token.
*/
contract SMASH is IERC20, Pausable {

  string public constant symbol = "SMASH";
  uint8 public constant decimals = 6;
  uint256 initialSupply = 2100000000 * 10 ** uint256(decimals);
  string public constant name = "SMASH";

  using SafeMath for uint256;

  // Owner of this contract
  address public owner;

  //Balance per address
  mapping (address => uint256) private _balances;

  //Allowance amount 
  mapping (address => mapping (address => uint256)) private _allowed;

  //Total supply
  uint256 private _totalSupply;
  
  constructor() public {
        owner = msg.sender;
        _totalSupply = initialSupply;
        _balances[msg.sender] = _totalSupply;      // Give the creator all initial tokens
  }

  /**
  * @dev Total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }


  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256) {
    return _balances[_owner];
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner,address spender) public view returns (uint256) {
    return _allowed[_owner][spender];
  }

  /**
  * @dev Transfer token for a specified address
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
    require(spender != address(0));

    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param from address The address which you want to send tokens from
   * @param to address The address which you want to transfer to
   * @param value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address from,address to,uint256 value) public whenNotPaused returns (bool) {
    require(value <= _allowed[from][msg.sender]);

    _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }


  /**
  * @dev Transfer token for a specified addresses
  * @param from The address to transfer from.
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function _transfer(address from, address to, uint256 value) internal whenNotPaused {
    require(value <= _balances[from]);
    require(to != address(0));

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account.
   *  account The account whose tokens will be burnt.
   * @param value The amount that will be burnt.
   */
   
  function burn(uint256 value) public whenNotPaused {
    _burn(msg.sender, value);
  }
   
  function _burn(address account, uint256 value) internal whenNotPaused {
    require(account != 0);
    require(value <= _balances[account]);

    _totalSupply = _totalSupply.sub(value);
    _balances[account] = _balances[account].sub(value);
    emit Transfer(account, address(0), value);
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account, deducting from the sender's allowance for said account. Uses the
   * internal burn function.
   */
   
  function burnFrom(address from, uint256 value) public whenNotPaused {
    _burnFrom(from, value);
  }
  
  function _burnFrom(address account, uint256 value) internal whenNotPaused {
    require(value <= _allowed[account][msg.sender]);

    _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
    _burn(account, value);
  }
}
