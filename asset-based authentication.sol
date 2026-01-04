// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AssetAuth {
    mapping(address => uint256) private balances;

    // Events to notify the server
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // User deposits Ether as the asset
    function deposit() external payable {
        require(msg.value > 0, "Must deposit a positive amount");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // User withdraws ALL of their deposited Ether
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");

        // Set balance to zero before transfer (reentrancy-safe)
        balances[msg.sender] = 0;

        // Transfer all Ether back to user
        payable(msg.sender).transfer(amount);

        // Notify server via event
        emit Withdrawn(msg.sender, amount);
    }

    // Check user balance (for authentication logic on server side)
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
}
