pragma solidity ^0.4.18;

/**
 * OpenZeppelin contracts (Mintable & Burnable + dependenices)
 */
import './Ownable.sol';

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

contract MintableToken is StandardToken, Ownable {
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  bool public mintingFinished = false;

  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(address(0), _to, _amount);
    return true;
  }

  function finishMinting() onlyOwner canMint public returns (bool) {
    mintingFinished = true;
    MintFinished();
    return true;
  }
}

contract BurnableToken is StandardToken {

    event Burn(address indexed burner, uint256 value);

    function burn(uint256 _value) public {
        require(_value > 0);
        require(_value <= balances[msg.sender]);

        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }
}

/**
 * Promise (WORD) Token Code:
 */
contract PromiseToken is MintableToken, BurnableToken {
  string public name = 'Promise';
  string public symbol = 'WORD';
  uint public decimals = 0;
  uint public INITIAL_SUPPLY = 10000000;

  address public coreAddress;
  address public genieAddress;

  uint public mintPercent = 50;
  uint public burnPercent = 10;

  function PromiseToken() public {
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    coreAddress = msg.sender;
    genieAddress = msg.sender;
  }

  function setCoreAddress(address newAddress) onlyOwner public returns(bool) {
    coreAddress = newAddress;
  }

  function getCoreAddress() public view returns(address) {
    return coreAddress;
  }

  function setGenieAddress(address newAddress) onlyOwner public returns(bool) {
    genieAddress = newAddress;
  }

  function getGenieAddress() public view returns(address) {
    return genieAddress;
  }

  function setMintPercent(uint newMintPercent) onlyOwner public returns(bool) {
    mintPercent = newMintPercent;
  }

  function setBurnPercent(uint newBurnPercent) onlyOwner public returns(bool) {
    burnPercent = newBurnPercent;
  }

  /**
   * @dev Throws if called by any account other than the coreAddress (PromiseRegister)
   */
  modifier onlyCore() {
    require(msg.sender == coreAddress);
    _;
  }

  function promiseProposed(address _from, uint _value) onlyCore public returns (bool) {
    require(_value <= balances[_from]);

    balances[_from] = balances[_from].sub(_value);
    balances[genieAddress] = balances[genieAddress].add(_value);
    return true;
  }

  function promiseRejected(address _from, uint _value) onlyCore public returns (bool) {
    balances[_from] = balances[_from].add(_value);
    balances[genieAddress] = balances[genieAddress].sub(_value);
    return true;
  }

  function promiseBroken(address _to, uint _value) onlyCore public returns (bool) {
    balances[_to] = balances[_to].add(_value/100*(100-burnPercent));
    balances[genieAddress] = balances[genieAddress].sub(_value/100*(100-burnPercent));
    totalSupply = totalSupply.sub(_value/100*burnPercent);
    Burn(genieAddress, _value/100*burnPercent);
    return true;
  }

  function promiseKept(address promiser, address promisee, uint _value) onlyCore public returns (bool) {
    balances[promiser] = balances[promiser].add(_value);
    balances[genieAddress] = balances[genieAddress].sub(_value);
    promiseMint(promiser, _value/50*mintPercent);
    promiseMint(promisee, _value/50*mintPercent);
    return true;
  }

  function promiseMint(address _to, uint _amount) onlyCore public returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    return true;
  }

  function promiseBurned(uint _value) onlyCore public returns (bool) {
    balances[genieAddress] = balances[genieAddress].sub(_value);
    totalSupply = totalSupply.sub(_value);
    Burn(genieAddress, _value);
  }

  function remove() onlyOwner public {
    selfdestruct(owner);
  }

}
