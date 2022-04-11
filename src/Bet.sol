// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract BetContract {
    event BetCreated(string title, uint256 id, string option1, string option2);
    event BetCancelled(uint256 id);
    event BetEnded(address title, string winnerOptionTitle, uint256 id);
    event RefundSent(address indexed recipient, uint256 amount, bytes data);

    enum BetStatus {
        Open,
        Pending,
        Done,
        Cancelled
    }

    struct Option {
        string title;
        uint256 totalAmount;
        address[] players;
    }

    struct Bet {
        address dealer;
        uint256 result;
        string title;
        uint256 duration;
        Option option1;
        Option option2;
        BetStatus status;
    }

    mapping(address => mapping(uint256 => uint256)) public playersToBetAmount;
    Bet[] public betList;

    function createBet(
        string memory betName,
        string memory option1Name,
        string memory option2Name,
        uint256 duration
    ) external {
        require(duration > 0, "Duration cannot be zero");

        uint256 id = betList.length;
        Option memory option1;
        Option memory option2;
        option1.title = option1Name;
        option2.title = option2Name;

        betList.push(
            Bet(
                msg.sender,
                id,
                betName,
                duration,
                option1,
                option2,
                BetStatus.Open
            )
        );

        emit BetCreated(betName, id, option1Name, option2Name);
    }

    function cancelBet(uint256 id) external {
        require(id < betList.length, "Bet does not exist");
        require(betList[id].status == BetStatus.Open, "Bet is not open");

        betList[id].status = BetStatus.Cancelled;
        Bet memory bet = betList[id];

        for (uint256 i = 0; i < bet.option1.players.length; i++) {
            address player = bet.option1.players[i];
            (bool sent, bytes memory data) = player.call{
                value: playersToBetAmount[player][id]
            }("");
            require(sent, "Failed to send Ether");
            emit RefundSent(player, playersToBetAmount[player][id], data);
        }

        for (uint256 i = 0; i < bet.option2.players.length; i++) {
            address player = bet.option2.players[i];
            (bool sent, bytes memory data) = player.call{
                value: playersToBetAmount[player][id]
            }("");
            require(sent, "Failed to send Ether");
            emit RefundSent(player, playersToBetAmount[player][id], data);
        }

        emit BetCancelled(id);
    }

    //TODO: add a join bet function, which will allow a player to join a bet
    //TODO: add a close bet function, which will allow the dealer to close a bet
}
