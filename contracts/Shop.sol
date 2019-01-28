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
    uint256 public singlePurchacePrice = 30 wei;
    uint256 public subscribePerTimePrice = 100 wei;
    uint256 public timeUnit = 1 hours;

    data[] public dataList;
    mapping (address => uint256) private subscribedUserList;

    modifier supervised {
        assert(msg.sender == supervisor);
        _;
    }

    modifier subscribed {
        assert(subscribedUserList[msg.sender] != 0);
        _;
    }

    modifier subscriptionValid {
      assert(block.timestamp <= subscribedUserList[msg.sender]);
      _;
    }

    event Purchase(address buyer, string mamRoot);
    event Subscribe(address buyer, uint256 time);
    event DataUpdate(string mamRoot);
  
    constructor (address owner) public {
        transferOwnership(owner);
        supervisor = msg.sender;
    }
    
    function setPrice(uint256 _price) onlyOwner public {
        singlePurchacePrice = _price;
    }
    
    function updateData(string memory mamRoot, uint256 time) onlyOwner public {
        require(bytes(mamRoot).length == 81);
        dataList.push(data({mamRoot: mamRoot, time: time, valid: true}));
        emit DataUpdate(mamRoot);
    }
    
    function getData(uint256 idx) public view returns (string memory, uint256) {
        return (dataList[idx].mamRoot, dataList[idx].time);
    }

    function buy(address buyer, string memory mamRoot, uint256 pay) supervised public {
        require(pay == singlePurchacePrice);
        emit Purchase(buyer, mamRoot);
    }
    
    function subscribe(address buyer, uint256 time, uint256 pay) supervised public {
      uint256 totalPayAmount = subscribePerTimePrice.mul(time);
      uint256 totalTime = timeUnit.mul(time);
      require(pay == totalPayAmount);

      subscribedUserList[buyer] = now;
      subscribedUserList[buyer] = subscribedUserList[buyer].add(totalTime);
      
      emit Subscribe(buyer, time);
    }

    function getSubscribedData(address buyer, string memory mamRoot) subscribed subscriptionValid public {
      emit Purchase(buyer, mamRoot);
    }

    
    function txFinished(address buyer, bytes32 txHash) onlyOwner public {
        Marketplace(supervisor).getReceipt(buyer, txHash); // here isn't using constructor
    }

    function kill() supervised public {
        address payable payAddress = address(uint160(owner()));
        selfdestruct(payAddress);
    }
}
