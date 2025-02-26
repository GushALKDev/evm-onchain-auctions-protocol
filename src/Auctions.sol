// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Auctions is Ownable, ReentrancyGuard {
    
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint256 private constant MAX_FEE_P = 10; // Maximum fee percentage (10%)

    /*//////////////////////////////////////////////////////////////
                            STRUCTS AND ENUMS
    //////////////////////////////////////////////////////////////*/

    struct Auction {
        string name;
        string description;
        uint256 id;
        address seller;
        uint256 startingPrice;
        uint256 endingPrice;
        address winner;
        Bid[] bids;
        uint256 duration;
        uint256 startedAt;
        AuctionStatus status;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    enum AuctionStatus {
        Created,
        Cancelled,
        Withdrawn
    }


    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error Auctions__StartingPriceMustBeGreaterThanZero();
    error Auctions__DurationMustBeOneHourMinimum();
    error Auctions__AuctionDoesNotExist();
    error Auctions__AuctionHasEnded();
    error Auctions__AuctionHasNotEnded();
    error Auctions__WinnerCannotGetRefund();
    error Auctions__AmountMustBeGreaterThanLastBid();
    error Auctions__AmountMustBeStartingPrice();
    error Auctions__NoBidToRefund();
    error Auctions__OnlySellerCanCancelAuction();
    error Auctions__OnlySellerCanWithdrawAuction();
    error Auctions__AuctionIsNotWithdrawable();
    error Auctions__FeePercentageTooHigh();


    /*//////////////////////////////////////////////////////////////
                            STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // The next auction ID
    uint256 private s_nextAuctionId = 1;
    
    // Protocol fee percentage (0-100, max 10%)
    uint public s_feePercentage;


    /*//////////////////////////////////////////////////////////////
                            MAPPING VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Mapping of auction ID to auction info
    mapping(uint256 => Auction) private auctionInfo;

    // Mapping of user bid amount on auction
    mapping(address => mapping(uint256 => uint256)) private userBidAmount;

    // The address of the token for payment
    IERC20 public USDT;


    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event AuctionCreated(uint256 id, address seller, uint256 startingPrice, uint256 endingPrice, uint256 duration, uint256 startedAt);

    event AuctionBid(uint256 auctionId, address bidder, uint256 amount, uint256 timestamp);

    event AuctionCancelled(uint256 auctionId, uint256 timestamp);

    event AuctionWithdraw(uint256 auctionId, uint256 timestamp);


    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _USDT, uint _feePercentage) Ownable(msg.sender) {
        if (_feePercentage > MAX_FEE_P) revert Auctions__FeePercentageTooHigh();
        USDT = IERC20(_USDT);
        s_feePercentage = _feePercentage;
    }


    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createAuction(string memory _name, string memory _description, uint256 _startingPrice, uint256 _duration /* Seconds */) external {
        if (_startingPrice == 0) revert Auctions__StartingPriceMustBeGreaterThanZero();
        if (_duration < 3600) revert Auctions__DurationMustBeOneHourMinimum();

        Auction storage auction = auctionInfo[s_nextAuctionId];
        auction.name = _name;
        auction.description = _description;
        auction.id = s_nextAuctionId;
        auction.seller = msg.sender;
        auction.startingPrice = _startingPrice;
        auction.endingPrice = 0;
        auction.winner = address(0);
        auction.duration = _duration; // Seconds
        auction.startedAt = block.timestamp;
        auction.status = AuctionStatus.Created;

        s_nextAuctionId++;

        emit AuctionCreated(auction.id, auction.seller, auction.startingPrice, auction.endingPrice, auction.duration, auction.startedAt);
    }

    function cancelAuction(uint256 _auctionId) external {
        Auction storage auction = auctionInfo[_auctionId];
        if (auction.id == 0) revert Auctions__AuctionDoesNotExist();
        if (auction.seller != msg.sender) revert Auctions__OnlySellerCanCancelAuction();
        if (block.timestamp >= auction.startedAt + auction.duration) revert Auctions__AuctionHasEnded();

        for (uint i = 0; i < auction.bids.length; i++) {
            if (userBidAmount[auction.bids[i].bidder][_auctionId] > 0) {
                USDT.transfer(auction.bids[i].bidder, userBidAmount[auction.bids[i].bidder][_auctionId]);
                userBidAmount[auction.bids[i].bidder][_auctionId] = 0;
            }
        }

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(_auctionId, block.timestamp);
    }

    function bid(uint256 _auctionId, uint256 _amount) external nonReentrant {
        Auction storage auction = auctionInfo[_auctionId];
        if (auction.id == 0) revert Auctions__AuctionDoesNotExist();
        if (block.timestamp >= auction.startedAt + auction.duration) revert Auctions__AuctionHasEnded();
        if (_amount <= auction.endingPrice) revert Auctions__AmountMustBeGreaterThanLastBid();
        if (_amount < auction.startingPrice) revert Auctions__AmountMustBeStartingPrice();
        
        // if the user has a lower bid refund it before accepting the new bid
        if (userBidAmount[msg.sender][_auctionId] > 0) {
            USDT.transfer(msg.sender, userBidAmount[msg.sender][_auctionId]);
        }

        auction.bids.push(Bid({
            bidder: msg.sender,
            amount: _amount
        }));
        auction.winner = msg.sender;
        auction.endingPrice = _amount;

        USDT.transferFrom(msg.sender, address(this), _amount);

        userBidAmount[msg.sender][_auctionId] = _amount;

        emit AuctionBid(_auctionId, msg.sender, _amount, block.timestamp);
    }

    function bidRefund(uint256 _auctionId) external nonReentrant {
        Auction memory auction = auctionInfo[_auctionId];

        if (auction.id == 0) revert Auctions__AuctionDoesNotExist();
        if (block.timestamp >= auction.startedAt + auction.duration) revert Auctions__AuctionHasEnded(); // Cambiado de < a >=
        if (auction.winner == msg.sender) revert Auctions__WinnerCannotGetRefund();
        if (userBidAmount[msg.sender][_auctionId] == 0) revert Auctions__NoBidToRefund();

        USDT.transfer(msg.sender, userBidAmount[msg.sender][_auctionId]);
        userBidAmount[msg.sender][_auctionId] = 0;
    }

    function withdrawAuction(uint256 _auctionId) external nonReentrant {
        Auction storage auction = auctionInfo[_auctionId];

        if (auction.id == 0) revert Auctions__AuctionDoesNotExist();
        if (auction.seller != msg.sender) revert Auctions__OnlySellerCanWithdrawAuction();
        if (block.timestamp < auction.startedAt + auction.duration) revert Auctions__AuctionHasNotEnded();
        if (auction.status != AuctionStatus.Created) revert Auctions__AuctionIsNotWithdrawable();

        uint fee = (auction.endingPrice * s_feePercentage) / 100; // Changed from 10000 to 100
        USDT.transfer(msg.sender, auction.endingPrice - fee);

        auction.status = AuctionStatus.Withdrawn;

        emit AuctionWithdraw(_auctionId, block.timestamp);
        
    }


    /*//////////////////////////////////////////////////////////////
                              SETTERS
    //////////////////////////////////////////////////////////////*/

    function setFeePercentage(uint _feePercentage) external onlyOwner {
        if (_feePercentage > MAX_FEE_P) revert Auctions__FeePercentageTooHigh();
        s_feePercentage = _feePercentage;
    }


    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/
    
    function getAuction(uint256 _auctionId) external view returns (Auction memory) {
        return auctionInfo[_auctionId];
    }

    function getBids(uint256 _auctionId) external view returns (Bid[] memory) {
        return auctionInfo[_auctionId].bids;
    }
}
