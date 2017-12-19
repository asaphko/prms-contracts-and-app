pragma solidity ^0.4.18;

import './PromiseToken.sol';
import './PromiseManager.sol';

contract PromiseGenie is Ownable {
  PromiseToken promiseToken;
  PromiseManager promiseManager;

  function PromiseGenie(address _promiseToken, address _promiseManager) Ownable() public {
    promiseManager = PromiseManager(_promiseManager);
    promiseToken = PromiseToken(_promiseToken);
  }

  modifier requirePromisers(address promiser, address promisee) {
    require(promiser != 0x0 && promisee != 0x0);
    _;
  }

  modifier restricted(address entityOwner) {
	require (msg.sender == owner || msg.sender == entityOwner);
    _;
  }

  event PromiseProposed(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  event promiseAccepted(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  event PromiseRejected(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  event PromiseKept(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  event PromiseDisputed(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  event PromiseBroken(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  event PromiseBurned(bytes32 referenceCode, uint issueDate, uint expiryDate, address indexed promiser, address indexed promisee, uint amount, bytes32 description);
  //todo: event PromiseCancelled

  function createPromise(bytes32 referenceCode, uint issueDate, uint expiryDate, address promiser, address promisee, uint amount, bytes32 description)
    restricted(promiser) // The promiser starts...
    requirePromisers(promiser, promisee)
    public
    returns(uint index)
  {
    promiseToken.promiseProposed(promiser, amount);
    index = promiseManager.insert(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    PromiseProposed(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    return index;
  }

    function acceptPromiseAspromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public
    returns(bool done) {
        var (, issueDate, expiryDate, promiser, promisepromisee, amount, description,) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);

        done = promiseManager.updateStatus(referenceCode, PromiseManager.PromiseStatus.Accepted);
        promiseAccepted(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
        return done;
    }

    function rejectPromiseAsPromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, expiryDate, promiser, promisepromisee, amount, description,) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);

        promiseToken.promiseRejected(promiser, amount);
        promiseManager.updateStatus(referenceCode, PromiseManager.PromiseStatus.Rejected);
        PromiseRejected(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    }

    function disputePromiseAsPromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, expiryDate, promiser, promisepromisee, amount, description,) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);

        promiseManager.updateStatus(referenceCode, PromiseManager.PromiseStatus.Disputed);
        PromiseDisputed(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    }

    function brakePromiseAsPromiser(bytes32 referenceCode, address promiser)
    restricted(promiser)
    public {
        var (, issueDate, expiryDate, promiserpromiser, promisee, amount, description,) = getPromiseByReferenceCode(referenceCode);
        require(promiserpromiser == promiser);

        promiseToken.promiseBroken(promisee, amount);
        promiseManager.updateStatus(referenceCode, PromiseManager.PromiseStatus.Broken);
        PromiseBroken(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    }

    function keepPromiseAsPromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, expiryDate, promiser, promisepromisee, amount, description,) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);

        promiseToken.promiseKept(promiser, promisee, amount);
        promiseManager.updateStatus(referenceCode, PromiseManager.PromiseStatus.Kept);
        PromiseKept(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    }

    function burnPromise(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, expiryDate, promiser, promisepromisee, amount, description,) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);

        promiseToken.promiseBurned(amount);
        promiseManager.updateStatus(referenceCode, PromiseManager.PromiseStatus.Burned);
        PromiseBurned(referenceCode, issueDate, expiryDate, promiser, promisee, amount, description);
    }

    function getPromiseByReferenceCode(bytes32 referenceCode) public constant
        returns(bytes32, uint, uint, address, address, uint, bytes32, PromiseManager.PromiseStatus)
    {
        return promiseManager.getByReferenceCode(referenceCode);
    }


    function getPromiseCount() public constant
        returns(uint count)
    {
        return promiseManager.getCount();
    }

    function remove() onlyOwner public {
        selfdestruct(owner);
    }
}
