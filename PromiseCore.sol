pragma solidity ^0.4.2;

//
// Defines an owned contract.
//
contract Owned {

    // The contract owner (who has permission to destroy this contract)
    address internal owner;

    // Constructor
    function Owned() public {
        owner = msg.sender;
    }

    function remove() onlyOwner public {
        selfdestruct(owner);
    }

    modifier onlyOwner() {
        if (msg.sender == owner)
        _;
    }

    //
    // A restricted modifier that restricts access to the owner of this contract -OR- that the sender is the given address.
    //
    modifier restricted(address entityOwner) {
		require (msg.sender == owner || msg.sender == entityOwner);
        _;
	}

    function transferOwnership(address newOwner) onlyOwner public {
        if (newOwner != address(0)) owner = newOwner;
    }
}

//
// Defines the base class for a collection of promises keyed by a bytes32 (fixed-length string) type.
//
contract PromiseStorage {

    // Keys
    bytes32[] internal keys;

    function PromiseStorage() public {
    }

    // Add a key to the dictionary
    function addKey(bytes32 key) internal
    returns(uint length)
    {
        keys.push(key);
        return keys.length - 1;
    }

    // Gets the number of keys
    function getCount() public constant
        returns(uint count)
    {
        return keys.length;
    }
}

//
// Defines the contract for promises.
//
contract PromiseManager is Owned, PromiseStorage {

    enum PromiseStatus { Proposed, Accepted, Rejected, Disputed, Broken, Burned, Kept }
    PromiseStatus constant DEFAULT_PROMISE_STATUS = PromiseStatus.Proposed;

    struct Promise {
        bytes32 referenceCode;
        uint issueDate;
        PromiseStatus status;
        address promiser;
        address promisee;
        uint promiseAmount;
        uint promiseExpiry;
        bytes32 promiseDescription;
        bool isValue;
    }

    // Promises by reference code
    mapping (bytes32 => Promise) private promises;

    function exists(bytes32 key) public constant
        returns(bool)
    {
        if (keys.length == 0) {
            return false;
        }
        return (promises[key].isValue);
    }

    function insert(bytes32 referenceCode, uint issueDate, address promiser, address promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription) public
        returns(uint index)
    {
        require(!exists(referenceCode));

        Promise memory promise = Promise({
            referenceCode: referenceCode,
            issueDate: issueDate,
            status: DEFAULT_PROMISE_STATUS,
            promiser: promiser,
            promisee: promisee,
            promiseAmount: promiseAmount,
            promiseExpiry: promiseExpiry,
            promiseDescription: promiseDescription,
            isValue: true
        });
        promises[referenceCode] = promise;

        return super.addKey(referenceCode);
    }

    function getByIndex(uint index) public constant
        returns(bytes32, uint, PromiseStatus, address, address, uint, uint, bytes32)
    {
        require(index >= 0 && index < keys.length);

        return getByReferenceCode(keys[index]);
    }

    function getByReferenceCode(bytes32 referenceCode) public constant
        returns(bytes32, uint, PromiseStatus, address, address, uint, uint, bytes32)
    {
        require(exists(referenceCode));

        Promise memory promise;
        promise = promises[referenceCode];

        return(promise.referenceCode, promise.issueDate, promise.status, promise.promiser, promise.promisee, promise.promiseAmount, promise.promiseExpiry, promise.promiseDescription);
    }

    function updateStatus(bytes32 referenceCode, PromiseStatus status) public
    {
        require(exists(referenceCode));

        Promise memory promise = promises[referenceCode];

        if (promise.status == PromiseManager.PromiseStatus.Proposed) {
            require(status == PromiseStatus.Accepted || status == PromiseStatus.Rejected);
        } else {
            if (promise.status == PromiseManager.PromiseStatus.Accepted) {
                require(status == PromiseStatus.Disputed || status == PromiseStatus.Broken || status == PromiseStatus.Kept);
            } else {
                if (promise.status == PromiseManager.PromiseStatus.Disputed) {
                    require(status == PromiseStatus.Burned || status == PromiseStatus.Broken || status == PromiseStatus.Kept);
                } else {
                  // Anything else is invalid
                  assert(false);
                }
            }
        }

        promises[referenceCode].status = status;
    }
}

// Tracks relationships between accounts and promises.
// This is really just a convenient way to look-up those related accounts
// (in an efficient/indexed mannger, as opposed to iterating through all promises etc.)
contract Promises is Owned {

    struct PromiseAssociation {
        // These arrays represent "keys" to look-up in each respective set
        // e.g. for address: 0xABC: ['abc', 'def', 'hij']
        // You can query, how many "things" does 0xABC have: 3
        // Then you can get the key of each "thing" by index [0, 1, 2]
        // And you can use the index to look-up "things" via their respective contract/manager
        // So to that effect:
        // addMethods takes an address and "key"
        // getMethods take an address an index (which gives you back a key)
        bytes32[] sentPromises;
        bytes32[] receivedPromises;
    }

    mapping(address => PromiseAssociation) promiseAssociations;

    function addSentPromise(address account, bytes32 referenceCode) public
    {
        promiseAssociations[account].sentPromises.push(referenceCode);
    }

    function getSentPromise(address account, uint index) public constant
    returns (bytes32)
    {
        require(account != 0x0 && index >= 0 && index < promiseAssociations[account].sentPromises.length);

        return promiseAssociations[account].sentPromises[index];
    }

    function addReceivedPromise(address account, bytes32 referenceCode) public
    {
        promiseAssociations[account].receivedPromises.push(referenceCode);
    }

    function getReceivedPromise(address account, uint index) public constant
    returns (bytes32)
    {
        require(account != 0x0 && index >= 0 && index < promiseAssociations[account].receivedPromises.length);

        return promiseAssociations[account].receivedPromises[index];
    }

    function getCounts(address account) public constant
        returns (uint sentPromisesCount, uint receivedPromisesCount)
    {
        PromiseAssociation memory promiseAssociation = promiseAssociations[account];

        return (promiseAssociation.sentPromises.length,
            promiseAssociation.receivedPromises.length);
    }
}

//
// Defines the Promise Register contract. This is the entry point to rergister promises.
//
contract PromiseRegister is Owned {

    // Depends on these guys contracts
    address private promises;
    address private promiseManager;

    function PromiseRegister() Owned() public {
        promises = new Promises();
        promiseManager = new PromiseManager();
    }

    modifier requirePromisers(address promiser, address promisee) {
        require(promiser != 0x0 && promisee != 0x0);
        _;
    }

    function getPromisesByAddress(address promiser)
        restricted(promiser)
        public constant returns(bytes32[] sentPromiseIds, bytes32[] receivedPromiseIds)
    {
        var (sentPromisesCount, receivedPromisesCount) = Promises(promises).getCounts(promiser);

        uint i;

        // Sent and received promises
        sentPromiseIds = new bytes32[](sentPromisesCount);
        for (i = 0; i < sentPromisesCount; ++i) {
            sentPromiseIds[i] = Promises(promises).getSentPromise(promiser, i);
        }
        receivedPromiseIds = new bytes32[](receivedPromisesCount);
        for (i = 0; i < receivedPromisesCount; ++i) {
            receivedPromiseIds[i] = Promises(promises).getReceivedPromise(promiser, i);
        }

        return (sentPromiseIds, receivedPromiseIds);
    }

    event PromiseRegistered(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);
    event promiseAccepted(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);
    event PromiseRejected(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);
    event PromiseKept(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);
    event PromiseDisputed(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);
    event PromiseBroken(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);
    event PromiseBurned(bytes32 referenceCode, uint issueDate, PromiseManager.PromiseStatus status, address indexed promiser, address indexed promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription);

    function createPromise(bytes32 referenceCode, uint issueDate, address promiser, address promisee, uint promiseAmount, uint promiseExpiry, bytes32 promiseDescription)
        restricted(promiser) // The promiser starts...
        requirePromisers(promiser, promisee)
        public
        returns(uint index)
    {
        index = PromiseManager(promiseManager).insert(referenceCode, issueDate, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);

        Promises(promises).addSentPromise(promiser, referenceCode);
        Promises(promises).addReceivedPromise(promisee, referenceCode);

        PromiseRegistered(referenceCode, issueDate, PromiseManager.PromiseStatus.Accepted, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);

        return index;
    }

    function acceptPromiseAspromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, , promiser, promisepromisee, promiseAmount, promiseExpiry, promiseDescription) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);
        // todo: limit to 24 hours after proposed...

        PromiseManager(promiseManager).updateStatus(referenceCode, PromiseManager.PromiseStatus.Accepted);

        promiseAccepted(referenceCode, issueDate, PromiseManager.PromiseStatus.Accepted, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);
    }

    function rejectPromiseAsPromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, , promiser, promisepromisee, promiseAmount, promiseExpiry, promiseDescription) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);
        // todo: limit to 24 hours after proposed...

        PromiseManager(promiseManager).updateStatus(referenceCode, PromiseManager.PromiseStatus.Rejected);

        PromiseRejected(referenceCode, issueDate, PromiseManager.PromiseStatus.Accepted, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);
    }

    function disputePromiseAsPromisee(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, , promiser, promisepromisee, promiseAmount, promiseExpiry, promiseDescription) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);
        require(now < promiseExpiry);

        PromiseManager(promiseManager).updateStatus(referenceCode, PromiseManager.PromiseStatus.Disputed);

        PromiseDisputed(referenceCode, issueDate, PromiseManager.PromiseStatus.Disputed, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);
    }

    function brakePromiseAsPromiser(bytes32 referenceCode, address promiser)
    restricted(promiser)
    public {
        var (, issueDate, , promiserpromiser, promisee, promiseAmount, promiseExpiry, promiseDescription) = getPromiseByReferenceCode(referenceCode);
        require(promiserpromiser == promiser);
        require(now < promiseExpiry);

        PromiseManager(promiseManager).updateStatus(referenceCode, PromiseManager.PromiseStatus.Broken);

        PromiseBroken(referenceCode, issueDate, PromiseManager.PromiseStatus.Broken, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);
    }

    function keepPromise(bytes32 referenceCode, address promiser)
    restricted(promiser)
    public {
        var (, issueDate, , promisepromiser, promisee, promiseAmount, promiseExpiry, promiseDescription) = getPromiseByReferenceCode(referenceCode);
        require(promisepromiser == promiser);
        require(now > promiseExpiry);

        PromiseManager(promiseManager).updateStatus(referenceCode, PromiseManager.PromiseStatus.Broken);

        PromiseKept(referenceCode, issueDate, PromiseManager.PromiseStatus.Broken, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);
    }

    function burnPromise(bytes32 referenceCode, address promisee)
    restricted(promisee)
    public {
        var (, issueDate, , promiser, promisepromisee, promiseAmount, promiseExpiry, promiseDescription) = getPromiseByReferenceCode(referenceCode);
        require(promisepromisee == promisee);
        // todo: require this be after 7 days of being disputed...
        // todo: decide if both sides can burn, or only promisee

        PromiseManager(promiseManager).updateStatus(referenceCode, PromiseManager.PromiseStatus.Burned);

        PromiseBurned(referenceCode, issueDate, PromiseManager.PromiseStatus.Burned, promiser, promisee, promiseAmount, promiseExpiry, promiseDescription);
    }

    function getPromiseByReferenceCode(bytes32 referenceCode) public constant
        returns(bytes32, uint, PromiseManager.PromiseStatus, address, address, uint, uint, bytes32)
    {
        return PromiseManager(promiseManager).getByReferenceCode(referenceCode);
    }

    function getPromiseByIndex(uint index) public constant
        returns(bytes32, uint, PromiseManager.PromiseStatus, address, address, uint, uint, bytes32)
    {
        return PromiseManager(promiseManager).getByIndex(index);
    }

    function getPromiseCount() public constant
        returns(uint count)
    {
        return PromiseManager(promiseManager).getCount();
    }
}
