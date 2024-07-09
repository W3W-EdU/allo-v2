// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title QF Helper Library
/// @notice A helper library for Quadratic Funding
/// @dev Handles the donation and voting of recipients and calculates the matching amount
///      for each recipient using the Quadratic Funding formula
library QFHelper {
    /// Using EnumerableSet for EnumerableSet.AddressSet to store the recipients
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Error thrown when the number of recipients and amounts are not equal
    error QFHelper_LengthMissmatch();

    /// Struct that defines a donation
    /// @param amount The amount of the donation
    /// @param funder The address of the funder
    struct Donation {
        uint256 amount;
        address funder;
    }

    /// Struct that defines the state of the donations to recipients
    /// @param recipients The set of recipients
    /// @param donations The donations for each recipient
    struct State {
        EnumerableSet.AddressSet recipients;
        mapping(address => Donation[]) donations;
    }

    /// @notice Calculate the square root of a number (Babylonian method)
    /// @param _x The number
    /// @return _y The square root
    function _sqrt(uint256 _x) internal pure returns (uint256 _y) {
        uint256 _z = (_x + 1) / 2;
        _y = _x;
        while (_z < _y) {
            _y = _z;
            _z = (_x / _z + _z) / 2;
        }
    }

    /// @notice Votes for recipients by donating
    /// @param _state The state of the donations
    /// @param _recipients The recipients to donate to
    /// @param _amounts The amounts to donate to each recipient
    /// @param _funder The address of the funder
    /// @dev The number of recipients and amounts should be equal and the same index
    ///      should correspond to the same recipient and amount
    function fund(State storage _state, address[] memory _recipients, uint256[] memory _amounts, address _funder)
        internal
    {
        /// Check if the number of recipients and amounts are equal
        if (_recipients.length != _amounts.length) revert QFHelper_LengthMissmatch();

        for (uint256 i = 0; i < _recipients.length; i++) {
            /// Add the recipient to the set if it doesn't exist
            if (!_state.recipients.contains(_recipients[i])) {
                _state.recipients.add(_recipients[i]);
            }
            /// Add the donation to the recipient
            _state.donations[_recipients[i]].push(Donation({amount: _amounts[i], funder: _funder}));
        }
    }

    /// @notice Calculates the matching amount for each recipient using the Quadratic Funding formula
    /// @param _state The state of the donations
    /// @param _matchingAmount The total matching amount
    /// @return _recipients The recipients
    /// @return _amounts The matching amount for each recipient
    function calculateMatching(State storage _state, uint256 _matchingAmount)
        internal
        view
        returns (address[] memory _recipients, uint256[] memory _amounts)
    {
        /// Get the number of recipients
        uint256 _numRecipients = _state.recipients.length();
        /// Initialize the arrays
        _recipients = new address[](_numRecipients);
        _amounts = new uint256[](_numRecipients);

        uint256[] memory _donationsSum = new uint256[](_numRecipients);
        uint256 _totalContributions;
        uint256 _sumOfSquareRoots;
        /// Calculate the matching amount for each recipient
        for (uint256 i = 0; i < _numRecipients; i++) {
            /// Get the recipient
            address recipient = _state.recipients.at(i);
            /// Set the recipient in the array
            _recipients[i] = recipient;
            /// Get the donations for the recipient
            Donation[] memory _donations = _state.donations[recipient];
            /// Calculate the sum of the square roots of the donations
            _sumOfSquareRoots = 0;
            for (uint256 j = 0; j < _donations.length; j++) {
                _sumOfSquareRoots += _sqrt(_donations[j].amount);
            }

            /// Calculate the square of the sum
            uint256 _squareOfSum = _sumOfSquareRoots * _sumOfSquareRoots;

            /// Store the sum of square roots
            _donationsSum[i] = _squareOfSum;

            /// Calculate the total contributions
            _totalContributions += _squareOfSum;
        }

        /// Calculate the divisor
        uint256 _divisor = _matchingAmount / _totalContributions;

        /// Calculate the matching amount for each recipient
        for (uint256 i = 0; i < _numRecipients; i++) {
            /// Calculate the payout for the recipient
            _amounts[i] = _donationsSum[i] * _divisor;
        }
    }
}
