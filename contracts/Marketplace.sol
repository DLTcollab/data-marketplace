pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Shop.sol";

/**
*@dev Marketplace contract integrate with TangleID for 
* user identification, provides a decentralized data marketplace
* with full transaction transparency that allows data consumers
* to place bids on auctions for high-value sensor/IoT devices to compensate for invaluable data.
*/
contract Marketplace is Ownable{

    using SafeMath for uint256;

    enum Status {FUNDED, FULFILLED, RELEASED, SUSPENDED, REVERTED}

    struct Transaction {
        uint256 value;
        uint256 lastModified;
        Status  status;
        uint32  timeoutHours;
        address buyer;
        address seller;
        address moderator;
        mapping (address => bool) isOwner;
        mapping (address => bool) voted;
        bytes32 txHash;
    }

    struct Account {
        string uuid;
        bytes32[] transactions;
    }

    struct Info {
        address seller;
        Shop instance;
        string info;
    }

    mapping (address => address)     public allSellers; // traversing from 0x0
    mapping (address => Info)        public sellerData;
    mapping (address => Account)     public userAccounts;
    mapping (bytes32 => Transaction) public transactions;

    uint256 uniqueTxid;

    modifier hasRegistered(address user) {
        require(bytes(userAccounts[user].uuid).length > 0, 
            "User not registered"
        );
        _;
    }

    modifier notRegistered(address user) {
        require(bytes(userAccounts[user].uuid).length == 0, 
            "User has registered"
        );
        _;
    }

    modifier nonZeroAddress(address addressToCheck) {
        require(addressToCheck != address(0), "Zero address passed");
        _;
    }

    modifier transactionExists(bytes32 scriptHash) {
        require(
            transactions[scriptHash].value != 0, 
            "Transaction does not exist"
        );
        _;
    }

    modifier transactionDoesNotExist(bytes32 scriptHash) {
        require(
            transactions[scriptHash].value == 0, 
            "Transaction exists"
        );
        _;
    }

    modifier inFundedState(bytes32 scriptHash) {
        require(
            transactions[scriptHash].status == Status.FUNDED,
            "Transaction is not in FUNDED state"
        );
        _;
    }

    modifier inFulfilledState(bytes32 scriptHash) {
        require(
            transactions[scriptHash].status == Status.FULFILLED,
            "Transaction is not in FULFILLED state"
        );
        _;
    }

    modifier shopExists(address shopHolder) {
        require(
            address(sellerData[shopHolder].instance) != address(0),
            "Shop does not exist"
        );
        _;
    }
        
    modifier shopDoesNotExist(address shopHolder) {
        require(
            address(sellerData[shopHolder].instance) == address(0),
            "Shop exists"
        );
        _;
    }

    event Funded(
        bytes32 indexed scriptHash,
        address indexed from,
        uint256 value
    );

    event Fulfilled(
        bytes32 indexed scriptHash,
        address indexed to,
        bytes32 txHash
    );

    event Executed(
        bytes32 indexed scriptHash,
        address destination,
        uint256 amount
    );

    constructor () public {
    }

    /**
    *@dev This method is used to register user
    *in order to use data marketplace service
    *@param user User account address
    *@param uuid The uuid of user on TangleID
    */
    function registerUser(address user, string calldata uuid) 
        onlyOwner 
        nonZeroAddress(user)
        notRegistered(user)
        external 
    {
        string memory _uuid = uuid;
        require(bytes(_uuid).length == 26, "Uuid length does not match");

        userAccounts[user].uuid = uuid;
    }

    /**
    *@dev This method is used to register a shop for a registered user
    *@param seller Seller account address
    *@param info Information about the shop
    */
    function registerShop(address seller, string calldata info)
        onlyOwner 
        nonZeroAddress(seller)
        hasRegistered(seller)
        shopDoesNotExist(seller)
        external 
    {
        _listInsert(seller);
        sellerData[seller] = Info({
            seller: seller,
            instance: new Shop(seller),
            info: info
        });
    }

    /**
    *@dev Remove a registered shop
    *@param seller shop holder account address
    */
    function removeShop(address seller) 
        onlyOwner 
        nonZeroAddress(seller)
        shopExists(seller)
        external 
    {
        sellerData[seller].instance.kill();
        _listRemove(seller);
        delete sellerData[seller];
    }

    /**
    *@dev User can use this method to initiate a transaction
    * to purchase data
    *@param seller shop holder account address
    *@param mamRoot the root of a data stream user wants to purchase
    */
    function purchaseData(address seller, string calldata mamRoot)
        hasRegistered(msg.sender)
        nonZeroAddress(seller)
        external 
        payable 
        returns (bytes32)
    {

        uint32 timeoutHours = 48;
        bytes32 scriptHash = _addTransaction(
            msg.sender,
            seller,
            owner(),
            timeoutHours,
            msg.value
        );

        // imform seller
        sellerData[seller].instance.purchase(msg.sender, mamRoot, msg.value, scriptHash);

        emit Funded(scriptHash, msg.sender, msg.value);

        return scriptHash;
    }

    /**
    *@dev Use this method to subscribe a data provider
    * for some specified timespan
    *@param seller shop holder account address
    *@param time subscription timespan
    */
    function subscribeShop(address seller, uint256 time) 
        hasRegistered(msg.sender) 
        nonZeroAddress(seller)
        external 
        payable 
    {
        uint32 timeoutHours = 48;
        bytes32 scriptHash = _addTransaction(
            msg.sender,
            seller,
            owner(),
            timeoutHours,
            msg.value
        );

        sellerData[seller].instance.subscribe(msg.sender, time, msg.value);
        transactions[scriptHash].status = Status.FULFILLED;
    }

    /**
    *@dev User can use this method to redeem data stream if
    * the subscription is valid
    *@param seller Shop holder account address
    *@param mamRoot the specified data stream root
    */
    function purchaseBySubscription(address seller, string calldata mamRoot)
        hasRegistered(msg.sender) 
        nonZeroAddress(seller)
        external
    {
        uint32 timeoutHours = 48;
        bytes32 scriptHash = _addTransaction(
            msg.sender,
            seller,
            owner(),
            timeoutHours,
            0
        );

        sellerData[seller].instance.getSubscribedData(msg.sender, mamRoot, scriptHash);

        emit Funded(scriptHash, msg.sender, 0);
    }


    function _listRemove(address addr) internal {
        address n = allSellers[address(0)];
        address p = address(0);

        while(n != address(0)) {
            if (n == addr) {
                allSellers[p] = allSellers[n];
                break;
            }
            p = n;
            n = allSellers[n];
        }
    }

    function _listInsert(address addr) internal {
      allSellers[addr] = allSellers[address(0)];
      allSellers[address(0)] = addr;
    }

    /**
    *@dev Callback used by Shop instance after data transfer 
    *@param sigV array containing V component of all the signatures
    *@param sigR array containing R component of all the signatures
    *@param sigS array containing S component of all the signatures
    *@param buyer the data buyer
    *@param scriptHash script hash of the transaction
    *@param txHash the transaction hash containing data which seller
    * send to buyer after the purchase
    */
    function fulfillPurchase(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        address buyer,
        bytes32 scriptHash,
        bytes32 txHash
    )
        transactionExists(scriptHash)
        inFundedState(scriptHash)
        public
    {
        address seller = Shop(msg.sender).owner();
        require(
            seller == transactions[scriptHash].seller,
            "Sender is not recognized as seller"
        );

        require(
            buyer == transactions[scriptHash].buyer,
            "Buyer does not involved in the transaction"
        );

        _verifySignatures(
            sigV, 
            sigR, 
            sigS, 
            scriptHash,
            seller,
            transactions[scriptHash].value
        );

        transactions[scriptHash].status = Status.FULFILLED;
        transactions[scriptHash].txHash = txHash;
        transactions[scriptHash].lastModified = block.timestamp;

        emit Fulfilled(scriptHash, buyer, txHash);
    }

    /**
    *@dev Method can be used by moderator to suspend a not released
    * transaction, in situation that the received data is not correct
    *@param buyer the data buyer
    *@param buyer the data seller
    *@param scriptHash script hash of the transaction
    */
    function suspendTransaction(
        address buyer,
        address seller,
        bytes32 scriptHash
    )
        transactionExists(scriptHash)
        external
    {
        Transaction storage t = transactions[scriptHash];

        require(
            t.moderator == msg.sender,
            "Operation is not allowed"
        );

        require(
            t.buyer == buyer && t.seller == seller,
            "Buyer or seller does not match with transaction"
        );

        require(
            t.status != Status.RELEASED,
            "Released transaction is not suspendable"
        );

        t.status = Status.SUSPENDED;
    }

    /**
    *@dev Method can be used by supervisor to revert a suspended
    * transaction and send the fund back to buyer
    *@param buyer the data buyer
    *@param buyer the data seller
    *@param scriptHash script hash of the transaction
    */
    function revertTransaction(
        address payable buyer,
        address seller,
        bytes32 scriptHash
    )
        onlyOwner
        transactionExists(scriptHash)
        external
    {
        Transaction storage t = transactions[scriptHash];

        require(
            t.buyer == buyer && t.seller == seller,
            "Buyer or seller does not match with transaction"
        );

        require(
            t.status == Status.SUSPENDED,
            "Cannot revert not suspended transaction"
        );

        t.status = Status.REVERTED;

        _transferFunds(scriptHash, buyer, t.value);
    }

    /**
    * @dev Private function to add new transaction in the contract
    * @param buyer The buyer of the transaction
    * @param seller The seller of the listing associated with the transaction
    * @param moderator Moderator for this transaction
    * favour by signing transaction unilaterally
    * @param timeoutHours Timelock to lock fund 
    * @param value Total value transferred
    */
    function _addTransaction(
        address buyer,
        address seller,
        address moderator,
        uint32 timeoutHours,
        uint256 value
    )
        nonZeroAddress(buyer)
        nonZeroAddress(seller)
        private
        returns (bytes32)
    {
        require(buyer != seller, "Buyer and seller are same");

        //value passed should be greater than 0
        //require(value > 0, "Value passed is 0");

        bytes32 scriptHash = _calculateScriptHash(
            buyer,
            seller,
            moderator,
            timeoutHours,
            value,
            uniqueTxid
        );

        require(transactions[scriptHash].value == 0, "Transaction exist");

        transactions[scriptHash] = Transaction({
            buyer: buyer,
            seller: seller,
            moderator: moderator,
            value: value,
            status: Status.FUNDED,
            lastModified: block.timestamp,
            timeoutHours: timeoutHours,
            txHash: bytes32(0)
        });

        transactions[scriptHash].isOwner[seller] = true;
        transactions[scriptHash].isOwner[buyer] = true;

        //check if buyer or seller are not passed as moderator
        require(
            !transactions[scriptHash].isOwner[moderator],
            "Either buyer or seller is passed as moderator"
        );

        transactions[scriptHash].isOwner[moderator] = true;

        userAccounts[buyer].transactions.push(scriptHash);
        userAccounts[seller].transactions.push(scriptHash);

        uniqueTxid++;

        return scriptHash;
    }

    /**
    *@dev This method will be used to release funds associated with
    * the transaction
    *@param sigV array containing V component of all the signatures
    *@param sigR array containing R component of all the signatures
    *@param sigS array containing S component of all the signatures
    *@param scriptHash script hash of the transaction
    *@param destination address who will receive funds
    *@param amounts amount released to destination
    */
    function execute(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        bytes32 scriptHash,
        address payable destination,
        uint256 amount
    )
        transactionExists(scriptHash)
        inFulfilledState(scriptHash)
        nonZeroAddress(destination)
        // temporary workaround to solve 
        // TypeError: Data location must be "calldata" for parameter in external function, but "memory" was given.
        public 
    {
        require(transactions[scriptHash].value == amount);

        _verifyTransaction(
            sigV,
            sigR,
            sigS,
            scriptHash,
            destination,
            amount
        );

        transactions[scriptHash].status = Status.RELEASED;
        transactions[scriptHash].lastModified = block.timestamp;

        if (amount > 0) {
            require(
                _transferFunds(scriptHash, destination, amount) == transactions[scriptHash].value,
                "Total value to be released must be equal to the transaction value"
            );
        }

        emit Executed(scriptHash, destination, amount);
    }

    /**
    *@dev Internal method used to verify transaction
    */
    function _verifyTransaction(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        bytes32 scriptHash,
        address destination,
        uint256 amount
    )
        private
    {
        require(
            transactions[scriptHash].voted[transactions[scriptHash].seller],
            "Seller did not sign"
        );

        // timeLock is used for locking fund from seller
        bool timeLockExpired = _isTimeLockExpired(
            transactions[scriptHash].timeoutHours,
            transactions[scriptHash].lastModified
        );

        if (timeLockExpired) {
            return;
        }

        _verifySignatures(
            sigV,
            sigR,
            sigS,
            scriptHash,
            destination,
            amount
        );

    }

    /**
    *@dev Internal method used to verify signatures
    */
    function _verifySignatures(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        bytes32 scriptHash,
        address destination,
        uint256 amount
    )
        private
    {

        // Follows ERC191 signature scheme: https://github.com/ethereum/EIPs/issues/191
        bytes32 txHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encodePacked(
                        byte(0x19),
                        byte(0),
                        address(this),
                        scriptHash,
                        destination,
                        amount
                    )
                )
            )
        );

        for (uint i = 0; i < sigR.length; i++) {

            address recovered = ecrecover(
                txHash,
                sigV[i],
                sigR[i],
                sigS[i]
            );

            require(
                transactions[scriptHash].isOwner[recovered],
                "Invalid signature"
            );
            require(
                !transactions[scriptHash].voted[recovered],
                "Same signature sent twice"
            );
            transactions[scriptHash].voted[recovered] = true;
        }
    }

    /**
    *@dev Internal method used to determine is transaction
    * time lock expired
    */
    function _isTimeLockExpired(
        uint32 timeoutHours,
        uint256 lastModified
    )
        private
        view
        returns (bool)
    {
        uint256 timeSince = now.sub(lastModified);
        return (
            timeoutHours == 0 ? false : timeSince > uint256(timeoutHours).mul(3600)
        );
    }

    function _transferFunds(
        bytes32 scriptHash,
        address payable destination,
        uint256 amount
    )
        private
        nonZeroAddress(destination)
        returns (uint256)
    {
        Transaction storage t = transactions[scriptHash];

        uint256 valueTransferred = 0;

        require(
            t.isOwner[destination],
            "Destination address is not one of the owners"
        );

        require(
            amount > 0,
            "Amount to be sent should be greater than 0"
        );

        valueTransferred = valueTransferred.add(amount);

        destination.transfer(amount);
        return valueTransferred;
    }

    function _calculateScriptHash(
        address buyer,
        address seller,
        address moderator,
        uint32 timeoutHours,
        uint256 value,
        uint256 uniqueId
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                buyer,
                seller,
                moderator,
                timeoutHours,
                value,
                uniqueId
            )
        );
    }
}

