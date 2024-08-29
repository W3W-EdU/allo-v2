// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IAllocationExtension {
    /// @dev Error thrown when the allocation timestamps are invalid
    error INVALID_ALLOCATION_TIMESTAMPS();

    /// @dev Error thrown when trying to call the function when the allocation has started
    error ALLOCATION_HAS_STARTED();

    /// @dev Error thrown when trying to call the function when the allocation is not active
    error ALLOCATION_NOT_ACTIVE();

    /// @dev Error thrown when trying to call the function when the allocation has ended
    error ALLOCATION_NOT_ENDED();

    /// @notice Emitted when the allocation timestamps are updated
    /// @param allocationStartTime The start time for the allocation period
    /// @param allocationEndTime The end time for the allocation period
    /// @param sender The sender of the transaction
    event AllocationTimestampsUpdated(uint64 allocationStartTime, uint64 allocationEndTime, address sender);

    /// @notice The start time for the allocation period
    function allocationStartTime() external view returns (uint64);

    /// @notice The end time for the allocation period
    function allocationEndTime() external view returns (uint64);

    /// @notice Defines if the strategy is sending Metadata struct in the data parameter
    function isUsingAllocationMetadata() external view returns (bool);

    /// @notice Returns TRUE if the token is allowed, FALSE otherwise
    function allowedTokens(address _token) external view returns (bool);

    /// @notice Sets the start and end dates for allocation.
    /// @param _allocationStartTime The start time for the allocation
    /// @param _allocationEndTime The end time for the allocation
    function updateAllocationTimestamps(uint64 _allocationStartTime, uint64 _allocationEndTime) external;
}
