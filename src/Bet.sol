// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract BetContract {
    event BetCreated(string title, uint256 id, string option1, string option2);
    event BetClosed(uint256 id);
    event BetCancelled(uint256 id);
    event BetEnded(string winnerOptionName, uint256 id);
    event RefundSent(address recipient, uint256 amount, bytes data);
    event PaymentSent(address recipient, uint256 amount, bytes data);
    event BetJoined(address indexed player, uint256 id, string optionTitle);
    event GainsSent(address indexed player, uint256 amount, bytes data);

    enum BetStatus {
        Open,
        Pending,
        Ended,
        Cancelled
    }

    struct Option {
        string title;
        uint256 totalAmount;
        address[] players;
        uint8 id;
    }

    struct Bet {
        address dealer;
        uint256 result;
        string title;
        Option option1;
        Option option2;
        BetStatus status;
    }

    mapping(address => mapping(uint256 => uint256)) public playersToBetAmount;
    Bet[] public betList;

    function createBet(
        string memory betName,
        string memory option1Name,
        string memory option2Name
    ) external {
        uint256 id = betList.length;
        Option memory option1;
        Option memory option2;
        option1.title = option1Name;
        option2.title = option2Name;
        option1.id = 1;
        option2.id = 2;

        betList.push(
            Bet(msg.sender, id, betName, option1, option2, BetStatus.Open)
        );

        emit BetCreated(betName, id, option1Name, option2Name);
    }

    function cancelBet(uint256 id) external {
        require(id <= betList.length, "Bet does not exist");
        require(betList[id].status == BetStatus.Open, "Bet is not open");

        betList[id].status = BetStatus.Cancelled;

        emit BetCancelled(id);
    }

    function getRefund(uint256 id) external {
        require(id <= betList.length, "Bet does not exist");
        require(
            betList[id].status == BetStatus.Cancelled,
            "Bet is not cancelled"
        );
        require(
            betList[id].option1.players.length +
                betList[id].option2.players.length >
                1,
            "Bet has no players"
        );
        require(msg.sender != betList[id].dealer, "Dealer can't refund");
        require(
            playersToBetAmount[msg.sender][id] > 0,
            "Player did not participate in this bet"
        );

        uint256 amount = playersToBetAmount[msg.sender][id];
        require(amount > 0, "You have no money to refund");

        (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit RefundSent(msg.sender, amount, data);
    }

    function joinBet(uint256 id, uint256 optionId) external payable {
        require(id <= betList.length, "Bet does not exist");
        require(
            betList[id].status == BetStatus.Open,
            "Bet is not open to participants"
        );
        require(optionId == 1 || optionId == 2, "Option does not exist");
        require(msg.sender != betList[id].dealer, "Cannot join own bet");

        if (optionId == 1) {
            betList[id].option1.players.push(msg.sender);
            betList[id].option1.totalAmount += msg.value;
            playersToBetAmount[msg.sender][id] = msg.value;
            emit BetJoined(msg.sender, id, betList[id].option1.title);
        } else {
            betList[id].option2.players.push(msg.sender);
            betList[id].option2.totalAmount += msg.value;
            playersToBetAmount[msg.sender][id] = msg.value;
            emit BetJoined(msg.sender, id, betList[id].option2.title);
        }
    }

    function closeBet(uint256 id) external {
        require(id <= betList.length, "Bet does not exist");
        require(
            betList[id].status == BetStatus.Open,
            "Bet is not open to participants"
        );
        require(
            betList[id].dealer == msg.sender,
            "Only the dealer can close the bet"
        );

        betList[id].status = BetStatus.Pending;

        emit BetClosed(id);
    }

    function endBet(uint256 id, uint256 optionId) external {
        require(id <= betList.length, "Bet does not exist");
        require(
            betList[id].status == BetStatus.Pending,
            "Result is not pending"
        );
        require(optionId == 1 || optionId == 2, "Option does not exist");
        require(
            msg.sender == betList[id].dealer,
            "Only the dealer can end the bet"
        );
        Bet storage bet = betList[id];
        bet.status = BetStatus.Ended;

        if (optionId == 1) {
            bet.result = 1;
            emit BetEnded(bet.option1.title, id);
        } else {
            bet.result = 2;
            emit BetEnded(bet.option2.title, id);
        }
    }

    function calculateGains(
        uint256 winnersOptionTotalAmount,
        uint256 losersOptionTotalAmount,
        uint256 playerBetAmount
    ) internal pure returns (uint256) {
        uint256 playerPercentage = (playerBetAmount /
            winnersOptionTotalAmount) * 100;
        uint256 playerGain = (playerPercentage * losersOptionTotalAmount) / 100;
        uint256 playerTotal = playerBetAmount + playerGain;
        return playerTotal;
    }

    function claimGains(uint256 id) external {
        require(id <= betList.length, "Bet does not exist");
        require(betList[id].status == BetStatus.Ended, "Bet is not over yet");
        require(
            betList[id].dealer == msg.sender,
            "Only the dealer can get gains"
        );
        require(
            playersToBetAmount[msg.sender][id] > 0,
            "Player did not participate in this bet"
        );

        Bet storage bet = betList[id];

        if (bet.result == 1) {
            uint256 winningAmountTotal = bet.option1.totalAmount;
            require(winningAmountTotal > 0, "No money to send");
            uint256 totalToSend = calculateGains(
                winningAmountTotal,
                bet.option2.totalAmount,
                playersToBetAmount[msg.sender][id]
            );
            require(totalToSend > 0, "No money to send");

            (bool sent, bytes memory data) = msg.sender.call{
                value: totalToSend
            }("");
            require(sent, "Failed to send Ether");

            emit GainsSent(msg.sender, totalToSend, data);

            bet.option1.totalAmount -= totalToSend;
        } else {
            uint256 winningAmountTotal = bet.option2.totalAmount;
            require(winningAmountTotal > 0, "No money to send");
            uint256 totalToSend = calculateGains(
                winningAmountTotal,
                bet.option1.totalAmount,
                playersToBetAmount[msg.sender][id]
            );
            require(totalToSend > 0, "No money to send");

            (bool sent, bytes memory data) = msg.sender.call{
                value: totalToSend
            }("");
            require(sent, "Failed to send Ether");

            emit GainsSent(msg.sender, totalToSend, data);

            bet.option2.totalAmount -= totalToSend;
        }
    }
}
