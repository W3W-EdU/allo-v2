// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "contracts/core/libraries/QFHelper.sol";

/// @title Mock QF Helper
/// @notice A mock contract for testing Quadratic Funding Library
contract MockQFHelper {
    using QFHelper for QFHelper.State;

    QFHelper.State internal _state;

    function fund(address[] memory _recipients, uint256[] memory _amounts) public {
        _state.fund(_recipients, _amounts);
    }

    function getTotalContributions() public view returns (uint256 _totalContributions) {
        return _state.totalContributions;
    }

    function getCalcuateMatchingAmount(uint256 _matchingAmount, address _recipient)
        public
        returns (uint256 _amount)
    {
        return _state.calculateMatching(_matchingAmount, _recipient);
    }
}