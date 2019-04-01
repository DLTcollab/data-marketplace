pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Marketplace.sol";

/**
*@dev A interface for shop holder to set product information and prices
* in data marketplace
*/
contract Shop is Ownable {

    using SafeMath for uint256;

    struct data {
        string mamRoot;
        string metadata;
        uint256 time;
    }

    struct dataInfo {
        uint256 time;
        bool valid;
    }

    struct timePeriod {
        uint256 start;
        uint256 end;
    }


    address public supervisor;
    uint256 public singlePurchasePrice;
    uint256 public subscribePerTimePrice;
    uint256 public timeUnit = 1 hours;
    bool    public openForPurchase = false;

    /* TODO: make it a linked list */
    data[] public dataList;

    mapping (string => dataInfo)    private dataAvailability;
    mapping (address => timePeriod) private subscriptionList;

    modifier supervised {
        assert(msg.sender == supervisor);
        _;
    }

    modifier subscriptionValid(address account) {
        require(
            subscriptionList[account].start != 0 &&
            subscriptionList[account].end >= block.timestamp,
            "Subscription invalid"
        );
        _;
    }

    modifier isPurchasable {
        require(openForPurchase);
        _;
    }

    modifier isDataExist(string memory mamRoot) {
        require(dataAvailability[mamRoot].valid);
        _;
    }


    event Purchase(
        bytes32 indexed scriptHash,
        address indexed buyer, 
        string mamRoot
    );
    event Subscribe(
        address indexed buyer, 
        uint256 expirationTime
    );
  
    constructor (address owner) public {
        transferOwnership(owner);
        supervisor = msg.sender;
    }

    /**
    *@dev Enable buyer to purchase data from shop
    */
    function setPurchaseOpen() 
        onlyOwner 
        external
    {
        openForPurchase = true;
    }

    /**
    *@dev Disable buyer to purchase data from shop
    */
    function setPurchaseClose() 
        onlyOwner 
        external
    {
        openForPurchase = false;
    }
    
    /**
    *@dev Use this method to set single purchase price of the data
    *@param price The price of data
    */
    function setSinglePurchasePrice(
        uint256 price
    ) 
        onlyOwner 
        public 
    {
        singlePurchasePrice = price;
    }

    /**
    *@dev Use this method to set subscribe per time unit price of the data
    *@param price The price of subscribe per time unit
    */
    function setSubscribePrice(
        uint256 price
    ) 
        onlyOwner 
        public 
    {
        subscribePerTimePrice = price;
    }

    /**
    *@dev An api for user to get dataList size, since user cannot get it directly
    */
    function getDataListSize() 
        public 
        view 
        returns (uint256) 
    {
        return dataList.length;
    }

    function getDataAvailability(
        string memory mamRoot
    ) 
        public 
        view 
        returns (bool) 
    {
        return dataAvailability[mamRoot].valid;
    }
    
    /**
    *@dev Shop holder can use this method to set the availability of data
    *@param mamRoot The specified data root 
    *@param isValid The availability of data
    */
    function setDataAvailability(
        string memory mamRoot,
        bool isValid
    ) 
        onlyOwner
        public 
    {
        dataAvailability[mamRoot].valid = isValid;
    }

    /**
    *@dev Shop holder can use this method to add new data onto their shop
    *@param mamRoot The specified data root 
    *@param metadata The metadata of the data
    */
    function updateData(
        string memory mamRoot, 
        string memory metadata
    ) 
        onlyOwner 
        public 
    {
        require(bytes(mamRoot).length == 81);

        dataList.push(
            data({
                mamRoot: mamRoot, 
                metadata: metadata,
                time: block.timestamp
            })
        );

        dataAvailability[mamRoot].time = block.timestamp;
        dataAvailability[mamRoot].valid = true;
    }
    
    /**
    *@dev Method used to get metadata in data list
    *@param index The index of data in the dataList
    */
    function getData(
        uint256 index
    ) 
        public 
        view 
        returns (string memory, string memory) 
    {
        return (dataList[index].mamRoot, dataList[index].metadata);
    }

    /**
    *@dev An internel purchase function only used by supervisor
    */
    function purchase(
        address buyer, 
        string memory mamRoot, 
        uint256 amount,
        bytes32 scriptHash
    ) 
        supervised 
        isPurchasable
        isDataExist(mamRoot)
        public 
    {
        require(
            amount == singlePurchasePrice, 
            "Payment amount is not correct"
        );

        emit Purchase(scriptHash, buyer, mamRoot);
    }
    
    /**
    *@dev An internel subscribe function only used by supervisor
    */
    function subscribe(
        address buyer, 
        uint256 timeInHours, 
        uint256 amount
    ) 
        supervised 
        isPurchasable
        public 
    {
      uint256 totalPayAmount = subscribePerTimePrice.mul(timeInHours);
      uint256 totalTime = timeInHours.mul(timeUnit);
      require(amount == totalPayAmount);

      subscriptionList[buyer].start = block.timestamp;
      subscriptionList[buyer].end = subscriptionList[buyer].start.add(totalTime);
      
      emit Subscribe(buyer, subscriptionList[buyer].end);
    }

    /**
    *@dev An internel function to redeem data by valid subscription
    */
    function getSubscribedData(
        address buyer,
        string memory mamRoot,
        bytes32 scriptHash
    )
        supervised 
        subscriptionValid(buyer)
        isPurchasable
        isDataExist(mamRoot)
        public 
    {
        require(
            subscriptionList[buyer].start <= dataAvailability[mamRoot].time &&
            subscriptionList[buyer].end   >= dataAvailability[mamRoot].time,
            "Data not available for this subscription"
        );

        emit Purchase(scriptHash, buyer, mamRoot);
    }
     
    /**
    *@dev The method for shop holder to call after data transfer is finished,
    * it will set transaction status to FULFILLED
    */
    function txFinalize(
        uint8[] memory sigV,
        bytes32[] memory sigR,
        bytes32[] memory sigS,
        address buyer,
        bytes32 scriptHash,
        bytes32 txHash
    ) 
        onlyOwner 
        public 
    {
        Marketplace(supervisor).fulfillPurchase(
            sigV, 
            sigR, 
            sigS,
            buyer,
            scriptHash,
            txHash
        );
    }

    /**
    *@dev Internal function for supervisor to destruct the shop
    */
    function kill() supervised public {
        address payable payAddress = address(uint160(owner()));
        selfdestruct(payAddress);
    }
}
