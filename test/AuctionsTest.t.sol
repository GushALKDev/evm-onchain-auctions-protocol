// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Auctions.sol";
import "../src/USDT.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AuctionsTest is Test {
    // Add fee constant at the top of contract
    uint256 private constant FEE_PERCENTAGE = 10;

    /*//////////////////////////////////////////////////////////////
                            TEST STATE
    //////////////////////////////////////////////////////////////*/
    
    // Contract instances
    Auctions public auctions;
    USDT public usdt;

    // Test addresses
    address public seller;
    address public user1;
    address public user2;
    address public user3;


    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Deploy new contracts
        usdt = new USDT();
        auctions = new Auctions(address(usdt), FEE_PERCENTAGE); // Use FEE_PERCENTAGE constant

        // Initialize test addresses
        seller = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        user3 = address(0x4);

        // Fund all test accounts with initial USDT
        usdt.transfer(seller, 1000 * 1e18);
        usdt.transfer(user1, 1000 * 1e18);
        usdt.transfer(user2, 1000 * 1e18);
        usdt.transfer(user3, 1000 * 1e18);
    }


    /*//////////////////////////////////////////////////////////////
                        CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateAuction() public {
        // Seller creates a new auction
        vm.startPrank(seller);
        usdt.approve(address(auctions), 100 * 1e18);
        auctions.createAuction("Auction 1", "Description 1", 1 * 1e18, 3600);
        vm.stopPrank();

        // Verify auction was created with correct parameters
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(auction.name, "Auction 1");
        assertEq(auction.description, "Description 1");
        assertEq(auction.startingPrice, 1 * 1e18);
        assertEq(auction.duration, 3600);
    }

    function testBid() public {
        // Create initial auction
        testCreateAuction();

        // Place first bid from user1
        vm.startPrank(user1);
        usdt.approve(address(auctions), 2 * 1e18);
        auctions.bid(1, 2 * 1e18);
        vm.stopPrank();

        // Verify bid was accepted and user1 is winner
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(auction.winner, user1);
        assertEq(auction.endingPrice, 2 * 1e18);
    }

    function testBidRefund() public {
        // Create initial auction
        testCreateAuction();

        // First bid from user1
        vm.startPrank(user1);
        usdt.approve(address(auctions), 2 * 1e18);
        auctions.bid(1, 2 * 1e18);
        vm.stopPrank();

        // Higher bid from user2
        vm.startPrank(user2);
        usdt.approve(address(auctions), 3 * 1e18);
        auctions.bid(1, 3 * 1e18);
        vm.stopPrank();

        // User1 requests refund after being outbid
        vm.startPrank(user1);
        auctions.bidRefund(1);
        vm.stopPrank();

        // Verify user1 received their refund
        assertEq(usdt.balanceOf(user1), 1000 * 1e18);
        
        // Verify user2 is now the highest bidder
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(auction.winner, user2);
        assertEq(auction.endingPrice, 3 * 1e18);
    }

    function testWithdrawAuction() public {
        // Setup auction with active bid
        testBid();

        // Advance time past auction end
        vm.warp(block.timestamp + 3601);

        // Seller withdraws auction proceeds
        vm.startPrank(seller);
        auctions.withdrawAuction(1);
        vm.stopPrank();

        // Verify auction status and seller received funds minus fee
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(uint(auction.status), uint(Auctions.AuctionStatus.Withdrawn));
        
        // Calculate 10% fee of 2 USDT bid
        uint fee = (2 * 1e18 * FEE_PERCENTAGE) / 100; // 0.2 USDT (10% of 2 USDT)
        uint expectedBalance = 1000 * 1e18 + (2 * 1e18 - fee); // Initial balance + (bid amount - fee)
        assertEq(usdt.balanceOf(seller), expectedBalance);
    }

    function testCancelAuction() public {
        // Create initial auction
        testCreateAuction();

        // Small time advance to simulate active auction
        vm.warp(block.timestamp + 1);

        // Seller cancels the auction
        vm.startPrank(seller);
        auctions.cancelAuction(1);
        vm.stopPrank();

        // Verify auction was cancelled
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(uint(auction.status), uint(Auctions.AuctionStatus.Cancelled));
    }


    /*//////////////////////////////////////////////////////////////
                        VALIDATION & ERROR TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateAuctionWithZeroPrice() public {
        vm.startPrank(seller);
        usdt.approve(address(auctions), 100 * 1e18);
        vm.expectRevert(Auctions.Auctions__StartingPriceMustBeGreaterThanZero.selector);
        auctions.createAuction("Invalid Auction", "Test", 0, 3600);
        vm.stopPrank();
    }

    function testCreateAuctionWithShortDuration() public {
        vm.startPrank(seller);
        usdt.approve(address(auctions), 100 * 1e18);
        vm.expectRevert(Auctions.Auctions__DurationMustBeOneHourMinimum.selector);
        auctions.createAuction("Short Auction", "Test", 1 * 1e18, 1800);
        vm.stopPrank();
    }

    function testBidBelowStartingPrice() public {
        // Create auction with 2 USDT starting price
        vm.startPrank(seller);
        usdt.approve(address(auctions), 100 * 1e18);
        auctions.createAuction("Auction", "Test", 2 * 1e18, 3600);
        vm.stopPrank();

        // Attempt to bid below starting price
        vm.startPrank(user1);
        usdt.approve(address(auctions), 1 * 1e18);
        vm.expectRevert(Auctions.Auctions__AmountMustBeStartingPrice.selector);
        auctions.bid(1, 1 * 1e18);
        vm.stopPrank();
    }

    function testSetFeePercentageTooHigh() public {
        vm.startPrank(auctions.owner());
        vm.expectRevert(Auctions.Auctions__FeePercentageTooHigh.selector);
        auctions.setFeePercentage(FEE_PERCENTAGE + 1); // Use FEE_PERCENTAGE + 1
        vm.stopPrank();
    }

    function testConstructorFeePercentageTooHigh() public {
        vm.expectRevert(Auctions.Auctions__FeePercentageTooHigh.selector);
        new Auctions(address(usdt), FEE_PERCENTAGE + 1); // Use FEE_PERCENTAGE + 1
    }

    function testMaxFeeCalculation() public {
        // Create and execute auction with max fee (10%)
        usdt = new USDT();
        auctions = new Auctions(address(usdt), FEE_PERCENTAGE); // Use FEE_PERCENTAGE constant
        
        // Fund accounts
        usdt.transfer(seller, 1000 * 1e18);
        usdt.transfer(user1, 1000 * 1e18);

        // Create and bid on auction
        vm.startPrank(seller);
        usdt.approve(address(auctions), 100 * 1e18);
        auctions.createAuction("Max Fee Test", "Test", 1 * 1e18, 3600);
        vm.stopPrank();

        vm.startPrank(user1);
        usdt.approve(address(auctions), 100 * 1e18);
        auctions.bid(1, 100 * 1e18);
        vm.stopPrank();

        // Advance time and withdraw
        vm.warp(block.timestamp + 3601);
        vm.startPrank(seller);
        auctions.withdrawAuction(1);
        vm.stopPrank();

        // Verify max fee calculation (10% of 100 = 10 USDT)
        uint expectedSellerBalance = 1000 * 1e18 + (100 * 1e18 * (100 - FEE_PERCENTAGE)) / 100; // Use FEE_PERCENTAGE in calculation
        assertEq(usdt.balanceOf(seller), expectedSellerBalance);
    }


    /*//////////////////////////////////////////////////////////////
                        COMPLEX SCENARIO TESTS
    //////////////////////////////////////////////////////////////*/

    function testMultipleBidsAndRefunds() public {
        testCreateAuction();

        // Series of increasing bids
        for (uint i = 0; i < 3; i++) {
            address bidder = address(uint160(i + 2)); // user1, user2, user3
            uint amount = (i + 2) * 1 * 1e18;
            
            vm.startPrank(bidder);
            usdt.approve(address(auctions), amount);
            auctions.bid(1, amount);
            vm.stopPrank();

            // Previous bidder requests refund
            if (i > 0) {
                address prevBidder = address(uint160(i + 1));
                vm.startPrank(prevBidder);
                auctions.bidRefund(1);
                vm.stopPrank();
                
                // Verify refund
                assertEq(usdt.balanceOf(prevBidder), 1000 * 1e18);
            }
        }

        // Verify final state
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(auction.winner, user3);
        assertEq(auction.endingPrice, 4 * 1e18);
    }

    function testWithdrawBeforeEnd() public {
        testBid();
        vm.startPrank(seller);
        vm.expectRevert(Auctions.Auctions__AuctionHasNotEnded.selector);
        auctions.withdrawAuction(1);
        vm.stopPrank();
    }

    function testCancelWithMultipleBids() public {
        testCreateAuction();

        // Multiple bids before cancellation
        vm.startPrank(user1);
        usdt.approve(address(auctions), 2 * 1e18);
        auctions.bid(1, 2 * 1e18);
        vm.stopPrank();

        vm.startPrank(user2);
        usdt.approve(address(auctions), 3 * 1e18);
        auctions.bid(1, 3 * 1e18);
        vm.stopPrank();

        // Cancel auction
        vm.startPrank(seller);
        auctions.cancelAuction(1);
        vm.stopPrank();

        // Verify all bidders got refunded
        assertEq(usdt.balanceOf(user1), 1000 * 1e18);
        assertEq(usdt.balanceOf(user2), 1000 * 1e18);
        
        // Verify auction status
        Auctions.Auction memory auction = auctions.getAuction(1);
        assertEq(uint(auction.status), uint(Auctions.AuctionStatus.Cancelled));
    }


    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testRefundAfterAuctionEnd() public {
        testBid();

        // Advance time past auction end
        vm.warp(block.timestamp + 3601);

        // Attempt refund after auction ends
        vm.startPrank(user1);
        vm.expectRevert(Auctions.Auctions__AuctionHasEnded.selector);
        auctions.bidRefund(1);
        vm.stopPrank();
    }

    function testNonExistentAuction() public {
        vm.startPrank(user1);
        usdt.approve(address(auctions), 1 * 1e18);
        vm.expectRevert(Auctions.Auctions__AuctionDoesNotExist.selector);
        auctions.bid(999, 1 * 1e18);
        vm.stopPrank();
    }

    function testWithdrawTwice() public {
        testBid();
        vm.warp(block.timestamp + 3601);

        // First withdrawal
        vm.startPrank(seller);
        auctions.withdrawAuction(1);

        // Attempt second withdrawal
        vm.expectRevert(Auctions.Auctions__AuctionIsNotWithdrawable.selector);
        auctions.withdrawAuction(1);
        vm.stopPrank();
    }
}
