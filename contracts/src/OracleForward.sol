// SPDX-License-Identifier: MIT

// Oracle logic to call an external API
// This is a placeholder for the actual implementation
// You would need to use an oracle service like Chainlink to call an external API
// Example using Chainlink's request and response pattern
// Import ChainlinkClient

// This is unfinished, it just simulate a value of Oracle Forward.
// It should request URL of a bank, or any to get their forward tax
pragma solidity 0.8.22;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/ChainlinkClient.sol";

contract OracleForward is ChainlinkClient {
    /* -------------------------------------------------------------------------- */
    /*                                   ORACLE                                   */
    /* -------------------------------------------------------------------------- */
    using Chainlink for Chainlink.Request;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    string constant API_URL = "API_URL_HERE";
    string constant URL_PATH = "PATH";

    // Initialize Chainlink parameters
    //function setChainlinkParameters(
    //    address _oracle,
    //    bytes32 _jobId,
    //    uint256 _fee
    //) external {
    //    oracle = _oracle;
    //    jobId = _jobId;
    //    fee = _fee;
    //}
//
    //// Create a Chainlink request to retrieve API data
    //function _createOracleForward(uint256 forwardId) internal {
    //    Chainlink.Request memory request = _buildChainlinkRequest(
    //        jobId,
    //        address(this),
    //        this.fulfill.selector
    //    );
    //    // Set the URL to perform the GET request on
    //    request._add("get", API_URL);
    //    _sendChainlinkRequestTo(oracle, request, fee);
    //}
//
    //// Callback function to receive the API response
    //function fulfill(
    //    bytes32 _requestId,
    //    uint256 _oracleResult
    //) public recordChainlinkFulfillment(_requestId) {
    //    // Handle the oracle result
    //}

    function getOracleResult() public pure returns (uint64){
        return 112;
    }

    function getOracleSpot() pure public returns (uint64) {
        return 110;
    }
}
