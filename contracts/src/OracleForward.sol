// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract ChainlinkHttpExample is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // Variables
    uint256 public apiData;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    // Events
    event RequestFulfilled(bytes32 indexed requestId, uint256 indexed data);

    constructor(address _link, address _oracle) ConfirmedOwner(msg.sender) {
        setChainlinkToken(_link);
        oracle = _oracle;
        jobId = "b7283d075a5b4dbabb814c5b3bc351c6"; // Example Job ID (Replace with real one)
        fee = 0.1 * 10**18; // 0.1 LINK fee
    }

    // Function to request data from an API
    function requestAPIData() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Example API: Replace with a real API URL and Path
        request.add("get", "https://api.coindesk.com/v1/bpi/currentprice/ETH.json");
        request.add("path", "bpi.ETH.rate_float"); // JSON response path

        return sendChainlinkRequestTo(oracle, request, fee);
    }

    // Callback function for Chainlink node
    function fulfill(bytes32 _requestId, uint256 _data) public recordChainlinkFulfillment(_requestId) {
        apiData = _data;
        emit RequestFulfilled(_requestId, _data);
    }

    // Withdraw LINK tokens from the contract
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Transfer failed");
    }
}
