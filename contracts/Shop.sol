pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Marketplace.sol";

contract Shop is Ownable {

    using SafeMath for uint256;

    struct data {
      string mamRoot;
      uint256 time;
      bool valid;
    }

    address public supervisor;
    uint256 public singlePurchasePrice = 30 wei;
    uint256 public subscribePerTimePrice = 100 wei;
    uint256 public timeUnit = 1 hours;
    bool public openForPurchase = false;

    data[] public dataList;
    mapping (address => uint256) private subscribedUserList;

    modifier supervised {
        assert(msg.sender == supervisor);
        _;
    }

    modifier subscribed(address account) {
        assert(subscribedUserList[account] != 0);
        _;
    }

    modifier subscriptionValid {
        assert(block.timestamp <= subscribedUserList[msg.sender]);
        _;
    }

    modifier isPurchasable {
        require(openForPurchase == true);
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
    event DataUpdate(string mamRoot);
  
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
    
    function setPrice(uint256 _price) onlyOwner public {
        singlePurchasePrice = _price;
    }
    
    function updateData(string memory mamRoot, uint256 time) onlyOwner public {
        require(bytes(mamRoot).length == 81);
        dataList.push(data({mamRoot: mamRoot, time: time, valid: true}));
        emit DataUpdate(mamRoot);
    }
    
    function getData(uint256 idx) public view returns (string memory, uint256) {
        return (dataList[idx].mamRoot, dataList[idx].time);
    }

    function purchase(
        address buyer, 
        string memory mamRoot, 
        uint256 amount,
        bytes32 scriptHash
    ) 
        supervised 
        isPurchasable
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
      uint256 totalTime = timeInHours.mul(3600);
      require(amount == totalPayAmount);

      subscribedUserList[buyer] = block.timestamp;
      subscribedUserList[buyer] = subscribedUserList[buyer].add(totalTime);
      
      emit Subscribe(buyer, subscribedUserList[buyer]);
    }

    function getSubscribedData(
        address buyer,
        string memory mamRoot,
        bytes32 scriptHash
    )
        subscribed(buyer)
        subscriptionValid 
        isPurchasable
        public 
    {
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
