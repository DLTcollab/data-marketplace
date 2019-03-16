pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Marketplace.sol";

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
    uint256 public singlePurchasePrice = 30 wei;
    uint256 public subscribePerTimePrice = 100 wei;
    uint256 public timeUnit = 1 hours;
    bool public openForPurchase = false;

    /* TODO: make it a linked list */
    data[] public dataList;

    /* TypeError: Dynamically-sized keys for public mappings are not supported */
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

    function setPurchaseOpen() 
        onlyOwner 
        external
    {
        openForPurchase = true;
    }

    function setPurchaseClose() 
        onlyOwner 
        external
    {
        openForPurchase = false;
    }
    
    function setPrice(uint256 price) onlyOwner public {
        singlePurchasePrice = price;
    }

    function getDataListSize() public view returns (uint256) {
        return dataList.length;
    }

    function getDataAvailability(string memory mamRoot) 
        public 
        view 
        returns (bool) 
    {
        return dataAvailability[mamRoot].valid;
    }
    
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
    
    function getData(uint256 idx) public view returns (string memory, string memory) {
        return (dataList[idx].mamRoot, dataList[idx].metadata);
    }

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

    function getSubscribedData(
        address buyer,
        string memory mamRoot,
        bytes32 scriptHash
    )
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

    function kill() supervised public {
        address payable payAddress = address(uint160(owner()));
        selfdestruct(payAddress);
    }
}
