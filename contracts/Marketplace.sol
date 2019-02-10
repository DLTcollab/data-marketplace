pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Shop.sol";


contract Marketplace is Ownable{

    using SafeMath for uint256;

    enum Status {FUNDED, RELEASED, SUSPEND}

    struct Transaction {
        uint256 value;
        uint256 lastModified; // time txn was last modified (in seconds)
        Status status;
        uint32 timeoutHours;
        address buyer;
        address seller;
        address moderator;
        mapping(address => bool) isOwner; // to keep track of owners.
        mapping(address => bool) voted; // to keep track of who all voted
        bytes32 txHash;
    }

    struct Account {
        string uuid;
        bytes32[] transactions;
    }

    mapping (address => address) public allSellers; // traversing from 0x0
    mapping (address => Shop) public sellerData;
    mapping (address => Account) public userAccounts;
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
            transactions[scriptHash].value != 0, "Transaction does not exist"
        );
        _;
    }

    modifier transactionDoesNotExist(bytes32 scriptHash) {
        require(transactions[scriptHash].value == 0, "Transaction exists");
        _;
    }

    modifier inFundedState(bytes32 scriptHash) {
        require(
            transactions[scriptHash].status == Status.FUNDED,
            "Transaction is not in FUNDED state"
        );
        _;
    }

    modifier shopExists(address shopHolder) {
        require(
            address(sellerData[shopHolder]) != address(0),
            "Shop does not exist"
        );
        _;
    }
        
    modifier shopDoesNotExist(address shopHolder) {
        require(
            address(sellerData[shopHolder]) == address(0),
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

    function registerShop(address seller) 
        onlyOwner 
        nonZeroAddress(seller)
        hasRegistered(seller)
        shopDoesNotExist(seller)
        external 
    {
        listAdd(seller);
        sellerData[seller] = new Shop(seller);
    }

    function removeShop(address seller) 
        onlyOwner 
        nonZeroAddress(seller)
        shopExists(seller)
        external 
    {
        sellerData[seller].kill();
        listRemove(seller);
        delete sellerData[seller];
    }

    function buyData(address seller, string calldata mamRoot)
        hasRegistered(msg.sender)
        nonZeroAddress(seller)
        external 
        payable 
    {
        uint32 timeoutHours = 48;


        bytes32 scriptHash = addTransaction(
            msg.sender,
            seller,
            owner(),
            timeoutHours,
            mamRoot,
            msg.value,
            uniqueTxid
        );

        uniqueTxid++;
        emit Funded(scriptHash, msg.sender, msg.value);
    }

    function subscribeShop(address seller, uint256 time) 
        hasRegistered(msg.sender) 
        external 
        payable 
    {

        sellerData[seller].subscribe(msg.sender, time, msg.value);
    }

    function listRemove(address addr) internal {
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

    function listAdd(address addr) internal {
      allSellers[addr] = allSellers[address(0)];
      allSellers[address(0)] = addr;
    }

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
            seller  == transactions[scriptHash].seller,
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

        transactions[scriptHash].txHash = txHash;
        transactions[scriptHash].lastModified = block.timestamp;

        emit Fulfilled(scriptHash, buyer, txHash);
    }

    function addTransaction(
        address buyer,
        address seller,
        address moderator,
        uint32 timeoutHours,
        string memory mamRoot,
        uint256 value,
        uint256 uniqueId
    )
        nonZeroAddress(buyer)
        nonZeroAddress(seller)
        private
        returns (bytes32)
    {
        require(buyer != seller, "Buyer and seller are same");

        //value passed should be greater than 0
        require(value > 0, "Value passed is 0");

        bytes32 scriptHash = calculateScriptHash(
            buyer,
            seller,
            moderator,
            timeoutHours,
            value,
            uniqueId
        );

        require(transactions[scriptHash].value == 0, "Transaction exist");

        // imform seller
        sellerData[seller].purchase(seller, mamRoot, value, scriptHash);

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

        return scriptHash;
    }


    function execute(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        bytes32 scriptHash,
        address payable destination,
        uint256 amount
    )
        transactionExists(scriptHash)
        inFundedState(scriptHash)
        nonZeroAddress(destination)
        // temporary workaround to solve 
        // TypeError: Data location must be "calldata" for parameter in external function, but "memory" was given.
        public 
    {

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
        require(
            _transferFunds(scriptHash, destination, amount) == transactions[scriptHash].value,
            "Total value to be released must be equal to the transaction value"
        );

        emit Executed(scriptHash, destination, amount);
    }

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

        _verifySignatures(
            sigV,
            sigR,
            sigS,
            scriptHash,
            destination,
            amount
        );

        // not used now, may use to promote buyer executing contract
        bool timeLockExpired = _isTimeLockExpired(
            transactions[scriptHash].timeoutHours,
            transactions[scriptHash].lastModified
        );
    }

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

    function calculateScriptHash(
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

