pragma solidity ^0.4.18;

import './Ownable.sol';

contract PromiseCollection {
  bytes32[] internal keys;

  function PromiseCollection() public {}

  function addKey(bytes32 key) internal returns(uint length) {
    keys.push(key);
    return keys.length - 1;
  }

  function getCount() public constant returns(uint count) {
    return keys.length;
  }

}

contract PromiseManager is Ownable, PromiseCollection {

  enum PromiseStatus { Created, Accepted, Rejected, Disputed, Broken, Burned, Kept }
  PromiseStatus constant DEFAULT_PROMISE_STATUS = PromiseStatus.Created;

  address public coreAddress;

  function PromiseToken() public {
    coreAddress = msg.sender;
  }

  function setCoreAddress(address newAddress) onlyOwner public returns(bool) {
    coreAddress = newAddress;
  }

  struct Promise {
    bytes32 referenceCode;
    uint issueDate;
    uint expiryDate;
    address promiser;
    address promisee;
    uint amount;
    bytes32 description;
    PromiseStatus status;
    bool isValue;
  }

  /**
   * @dev Throws if called by any account other than the coreAddress (PromiseRegister)
   */
  modifier onlyCore() {
    require(msg.sender == coreAddress);
    _;
  }

  mapping (bytes32 => Promise) private promises;

  function exists(bytes32 key) onlyCore public constant returns(bool) {
    if (keys.length == 0) {
      return false;
    }
      return (promises[key].isValue);
    }

  function insert(bytes32 referenceCode, uint issueDate, uint expiryDate, address promiser, address promisee, uint amount, bytes32 description) onlyCore public returns(uint index) {
    require(!exists(referenceCode));

    Promise memory promise = Promise({
      referenceCode: referenceCode,
      issueDate: issueDate,
      expiryDate: expiryDate,
      promiser: promiser,
      promisee: promisee,
      amount: amount,
      description: description,
      status: DEFAULT_PROMISE_STATUS,
      isValue: true
    });

    promises[referenceCode] = promise;
    return super.addKey(referenceCode);
  }

  function getByReferenceCode(bytes32 referenceCode) onlyCore public constant returns(bytes32, uint, uint, address, address, uint, bytes32, PromiseStatus) {
    require(exists(referenceCode));

    Promise memory promise;
    promise = promises[referenceCode];

    return(promise.referenceCode, promise.issueDate, promise.expiryDate, promise.promiser, promise.promisee, promise.amount, promise.description, promise.status);
  }

  function updateStatus(bytes32 referenceCode, PromiseStatus status) onlyCore public returns(bool done) {
    require(exists(referenceCode));

    Promise memory promise = promises[referenceCode];
    if (promise.status == PromiseManager.PromiseStatus.Created) {
      require(status == PromiseStatus.Accepted || status == PromiseStatus.Rejected);
      //todo: require answer within X hours, otherwise cancel promise.
    } else {
      if (promise.status == PromiseManager.PromiseStatus.Accepted) {
        require(status == PromiseStatus.Disputed || status == PromiseStatus.Kept);
        //todo: require disputed only before expiry, and kept only after expiry.
      } else {
        if (promise.status == PromiseManager.PromiseStatus.Disputed) {
          require(status == PromiseStatus.Burned || status == PromiseStatus.Kept);
          //todo: require resolutions wihtin X hours, otherwise burn promise.
        } else {
          assert(false);
        }
      }
    }

    promises[referenceCode].status = status;
    return true;
  }

  function remove() onlyOwner public {
    selfdestruct(owner);
  }

}
