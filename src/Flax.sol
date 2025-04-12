// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import "@oz_reflax/contracts/access/Ownable.sol";
contract Flax is ERC20, Ownable {

    mapping(address => bool) public authorizedMinters;
    uint256 public maxFlaxMintedPerDay;

struct MintEvent {
    uint256 amount;
    uint256 timestamp;
}

MintEvent[] public mintEvents;
uint256 public totalMintedToday;
uint256 public lastCheckedTimestamp;

event AuthorizedMinterSet(address indexed minter, bool status);
event MaxFlaxMintedPerDayUpdated(uint256 newMax);
event FlaxMinted(address indexed to, uint256 amount);

constructor() ERC20("Flax", "FLX")Ownable(msg.sender) {
    maxFlaxMintedPerDay = 1000 * 10**18; // Example: 1000 FLX per day
    lastCheckedTimestamp = block.timestamp;
}

function setAuthorizedMinter(address minter, bool status) external onlyOwner {
    authorizedMinters[minter] = status;
    emit AuthorizedMinterSet(minter, status);
}

function setMaxFlaxMintedPerDay(uint256 max) external onlyOwner {
    maxFlaxMintedPerDay = max;
    emit MaxFlaxMintedPerDayUpdated(max);
}

function updateMintTracking() internal {
    if (block.timestamp < lastCheckedTimestamp + 1 days) {
        return;
    }

    uint256 newTotal = 0;
    uint256 cutoff = block.timestamp - 1 days;

    for (uint256 i = 0; i < mintEvents.length; ) {
        if (mintEvents[i].timestamp >= cutoff) {
            newTotal += mintEvents[i].amount;
            i++;
        } else {
            mintEvents[i] = mintEvents[mintEvents.length - 1];
            mintEvents.pop();
        }
    }

    totalMintedToday = newTotal;
    lastCheckedTimestamp = block.timestamp;
}

function mint(address to, uint256 amount) external {
    require(authorizedMinters[msg.sender], "Not authorized to mint");
    updateMintTracking();
    require(totalMintedToday + amount <= maxFlaxMintedPerDay, "Exceeds daily mint limit");
    mintEvents.push(MintEvent(amount, block.timestamp));
    totalMintedToday += amount;
    _mint(to, amount);
    emit FlaxMinted(to, amount);
}

}

