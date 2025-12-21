// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title AssetBackedAuthEscrow with Withdraw Signal
/// @notice Users deposit ETH to meet authentication requirements.
///         They can withdraw their funds and signal the server that withdrawal occurred.
contract AssetBackedAuthEscrow {
    struct Deposit {
        uint256 amount;     // total wei deposited
        uint256 lockUntil;  // timestamp until which funds are locked
    }

    mapping(address => Deposit) private deposits;

    // Simple reentrancy guard
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private status = NOT_ENTERED;

    // Events
    event Deposited(address indexed user, uint256 amount, uint256 lockUntil);
    event Withdrawn(address indexed user, uint256 amount); // server can watch this event
    event DepositTopUp(address indexed user, uint256 addedAmount, uint256 newTotal);

    modifier nonReentrant() {
        require(status == NOT_ENTERED, "Reentrant call");
        status = ENTERED;
        _;
        status = NOT_ENTERED;
    }

    /// @notice Deposit ETH with optional lock period
    function deposit(uint256 lockSeconds) external payable {
        require(msg.value > 0, "Must send ETH");

        Deposit storage d = deposits[msg.sender];


        if (d.amount == 0) {
            d.amount = msg.value;
            d.lockUntil = lockSeconds > 0 ? block.timestamp + lockSeconds : 0;
            emit Deposited(msg.sender, msg.value, d.lockUntil);
        } else {
            d.amount += msg.value;
            if (lockSeconds > 0) {
                uint256 candidateLock = block.timestamp + lockSeconds;
                if (candidateLock > d.lockUntil) {
                    d.lockUntil = candidateLock;
                }
            }
            emit DepositTopUp(msg.sender, msg.value, d.amount);
        }
    }

    /// @notice Check if an account meets the required amount and lock condition
    function isEligible(address account, uint256 requiredAmount, bool requireLocked) external view returns (bool eligible) {
        Deposit storage d = deposits[account];
        if (d.amount < requiredAmount) return false;
        if (requireLocked && d.lockUntil <= block.timestamp) return false;
        return true;
    }

    /// @notice Withdraw deposited funds and signal the server
    function withdraw() external nonReentrant {
        Deposit storage d = deposits[msg.sender];
        require(d.amount > 0, "No deposit found");
        require(d.lockUntil == 0 || block.timestamp >= d.lockUntil, "Funds are still locked");

        uint256 payout = d.amount;

        // Clear deposit before sending funds
        d.amount = 0;
        d.lockUntil = 0;

        // Transfer funds to user
        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        require(ok, "ETH transfer failed");

        // Emit Withdrawn event which acts as a signal to the server
        emit Withdrawn(msg.sender, payout);
    }

    /// @notice View deposit details
    function getDeposit(address account) external view returns (uint256 amount, uint256 lockUntil) {
        Deposit storage d = deposits[account];
        return (d.amount, d.lockUntil);
    }
}
