// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../lib/ds-test/src/test.sol";
import "../src/Bet.sol";
import "./utils/Cheats.sol";

contract BetTest is DSTest {
    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);
    BetContract bet;
    address public dealer;
    address public addr1;
    address public addr2;

    function setUp() public {
        bet = new BetContract();
        dealer = cheats.addr(1);
        addr1 = cheats.addr(2);
        addr2 = cheats.addr(3);
        cheats.deal(dealer, 1 ether);
        cheats.deal(addr1, 1 ether);
        cheats.deal(addr2, 1 ether);
    }

    function testCreateBet(
        string memory betName,
        string memory option1Name,
        string memory option2Name
    ) public {
        bet.createBet(betName, option1Name, option2Name);
        assertEq(bet.getBestListLength(), 1);
    }

    function testJoinBet(
        string memory betName,
        string memory option1Name,
        string memory option2Name
    ) public payable {
        cheats.prank(dealer);
        bet.createBet(betName, option1Name, option2Name);
        cheats.prank(addr1);
        bet.joinBet{value: 0.5 ether}(0, 1);
        assertEq(bet.getBestListLength(), 1);
        assertEq(bet.playersToBetAmount(addr1, 0), 0.5 ether);
        assertEq(bet.playerBetCount(addr1), 1);
    }
}
