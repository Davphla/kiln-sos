// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/ReserveFactory.sol";
import "forge-std/Test.sol";

contract ReserveFactoryTest is Test {
    ReserveFactory public reserveFactory;

    function setUp() public {
        reserveFactory = new ReserveFactory();
    }

    function testCreateReserve() public {
        // Define the parameters for creating a new reserve
        ReserveContract.reserveParams memory params = ReserveContract.reserveParams({
            id: 1,
            amount: 1000,
            lockedExchangeRate: 1.12 ether,
            endDate: block.timestamp + 90 days,
            oracleSpot: address(this),
            oracleForward: address(this)

        });

        // Define a salt for the CREATE2 deployment
        bytes32 salt = keccak256(abi.encodePacked("test-salt"));

        // Call the createReserve function
        address newReserveAddress = reserveFactory.createReserve(params, salt);

        // Check that the new reserve address is not zero
        assert(newReserveAddress != address(0));

        // Check that the new reserve is added to the deployedReserves array
        //assertEq(reserveFactory.deployedReserves(0), newReserveAddress);

        // Check that the ReserveCreated event is emitted
        vm.expectEmit(true, true, true, true);
        //emit ReserveFactory.ReserveCreated(newReserveAddress, "New Reserve");
    }
}