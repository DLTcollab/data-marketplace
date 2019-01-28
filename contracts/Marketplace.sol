pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Shop.sol";


contract Marketplace is Ownable{

    using SafeMath for uint256;

    // add arguments to make it more general
    modifier isAdded {
      require(added[msg.sender]);
      _;
    }

    modifier isRegistered {
      bytes memory tempString = bytes(userid[msg.sender]);
      require(tempString.length > 0);
      _;
    }

    mapping (address => address) public allSellers; // traversing from 0x0
    mapping (address => Shop) public sellerData;
    mapping (address => uint) private bank;
    mapping (address => bool) private added;
    mapping (address => string) public userid;
    
    event Receipt(address seller, address buyer, bytes32 txHash);

    constructor () public {
    }

    function register(address user, string memory uuid) onlyOwner public {
        require(user != address(0x0));
        require(bytes(uuid).length == 26);

        userid[user] = uuid;
    }

    function addSeller(address seller) onlyOwner public {
        require(!added[seller]);

        listAdd(seller);
        
        sellerData[seller] = new Shop(seller);
        added[seller] = true;
    }

    function rmSeller(address seller) onlyOwner public {
        require(added[seller]);

        sellerData[seller].kill();
        listRemove(seller);
        delete sellerData[seller];

        added[seller] = false;
    }

    function buyData(address seller, string memory mamRoot) isRegistered payable public {
        require(added[seller]);

        bank[seller] = bank[seller].add(msg.value);
        sellerData[seller].buy(msg.sender, mamRoot, msg.value);
    }

    function subscribeShop(address seller, uint256 time) isRegistered payable public {
        require(added[seller]);

        bank[seller] = bank[seller].add(msg.value);
        sellerData[seller].subscribe(msg.sender, time, msg.value);
    }
    
    // consider if the tx is not exist, or is not the same 
    function getReceipt(address buyer, bytes32 txHash) isAdded public {
        // do some examination
        emit Receipt(msg.sender, buyer, txHash);
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
}
