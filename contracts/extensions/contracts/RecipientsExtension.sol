// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IRecipientsExtension} from "../interfaces/IRecipientsExtension.sol";
import {CoreBaseStrategy} from "../../strategies/CoreBaseStrategy.sol";
import {Metadata} from "../../core/libraries/Metadata.sol";
import {Errors} from "../../core/libraries/Errors.sol";

abstract contract RecipientsExtension is CoreBaseStrategy, Errors, IRecipientsExtension {
    /// @notice Flag to indicate whether to use the registry anchor or not.
    bool public useRegistryAnchor;

    /// @notice Flag to indicate whether metadata is required or not.
    bool public metadataRequired;

    /// @notice The timestamps in seconds for the start and end times.
    uint64 public registrationStartTime;
    uint64 public registrationEndTime;

    /// @notice The total number of recipients.
    uint256 public recipientsCounter;

    /// @notice This is a packed array of booleans, 'statuses[0]' is the first row of the bitmap and allows to
    /// store 256 bits to describe the status of 256 projects. 'statuses[1]' is the second row, and so on
    /// Instead of using 1 bit for each recipient status, we will use 4 bits for each status
    /// to allow 7 statuses:
    /// 0: none
    /// 1: pending
    /// 2: accepted
    /// 3: rejected
    /// 4: appealed
    /// 5: in review
    /// 6: canceled
    /// Since it's a mapping the storage it's pre-allocated with zero values, so if we check the
    /// status of an existing recipient, the value is by default 0 (none).
    /// If we want to check the status of a recipient, we take its index from the `recipients` array
    /// and convert it to the 2-bits position in the bitmap.
    mapping(uint256 => uint256) public statusesBitMap;

    /// @notice 'recipientId' => 'statusIndex'
    /// @dev 'statusIndex' is the index of the recipient in the 'statusesBitMap' bitmap.
    mapping(address => uint256) public recipientToStatusIndexes;

    /// @notice 'recipientId' => 'Recipient' struct.
    mapping(address => Recipient) internal _recipients;

    /// @notice Modifier to check if the registration is active
    /// @dev This will revert if the registration has not started or if the registration has ended.
    modifier onlyActiveRegistration() {
        _checkOnlyActiveRegistration();
        _;
    }

    /// @notice Get a recipient with a '_recipientId'
    /// @param _recipientId ID of the recipient
    /// @return recipient The recipient details
    function getRecipient(address _recipientId) external view returns (Recipient memory recipient) {
        return _getRecipient(_recipientId);
    }

    /// @notice Get recipient status
    /// @dev This will return the 'Status' of the recipient, the 'Status' is used at the strategy
    ///      level and is different from the 'Status' which is used at the protocol level
    /// @param _recipientId ID of the recipient
    /// @return Status of the recipient
    function _getRecipientStatus(address _recipientId) internal view returns (Status) {
        return Status(_getUintRecipientStatus(_recipientId));
    }

    // TODO: remove once this function is implemented on the CoreBase
    function _isProfileMember(address _anchor, address _sender) internal view returns (bool) {
        return true;
    }

    /// @notice Sets recipient statuses.
    /// @dev The statuses are stored in a bitmap of 4 bits for each recipient. The first 4 bits of the 256 bits represent
    ///      the status of the first recipient, the second 4 bits represent the status of the second recipient, and so on.
    ///      'msg.sender' must be a pool manager.
    /// Statuses:
    /// - 0: none
    /// - 1: pending
    /// - 2: accepted
    /// - 3: rejected
    /// - 4: appealed
    /// - 5: in review
    /// - 6: canceled
    /// Emits the RecipientStatusUpdated() event.
    /// @param statuses new statuses
    /// @param refRecipientsCounter the recipientCounter the transaction is based on
    function reviewRecipients(ApplicationStatus[] memory statuses, uint256 refRecipientsCounter)
        external
        onlyPoolManager(msg.sender)
    {
        if (refRecipientsCounter != recipientsCounter) revert INVALID();
        // Loop through the statuses and set the status
        uint256 length = statuses.length;
        for (uint256 i; i < length;) {
            uint256 rowIndex = statuses[i].index;
            uint256 fullRow = statuses[i].statusRow;

            statusesBitMap[rowIndex] = fullRow;

            // Emit that the recipient status has been updated with the values
            emit RecipientStatusUpdated(rowIndex, fullRow, msg.sender);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Sets the start and end dates.
    /// @dev The timestamps are in seconds for the start and end times. The 'msg.sender' must be a pool manager.
    ///      Emits a 'TimestampsUpdated()' event.
    /// @param _registrationStartTime The start time for the registration
    /// @param _registrationEndTime The end time for the registration
    function updatePoolTimestamps(uint64 _registrationStartTime, uint64 _registrationEndTime)
        external
        onlyPoolManager(msg.sender)
    {
        // If the timestamps are invalid this will revert - See details in '_isPoolTimestampValid'
        _isPoolTimestampValid(_registrationStartTime, _registrationEndTime);

        // Set the updated timestamps
        registrationStartTime = _registrationStartTime;
        registrationEndTime = _registrationEndTime;

        // Emit that the timestamps have been updated with the updated values
        emit TimestampsUpdated(registrationStartTime, registrationEndTime, msg.sender);
    }

    /// @notice Checks if the registration is active and reverts if not.
    /// @dev This will revert if the registration has not started or if the registration has ended.
    function _checkOnlyActiveRegistration() internal view {
        if (registrationStartTime > block.timestamp || block.timestamp > registrationEndTime) {
            revert REGISTRATION_NOT_ACTIVE();
        }
    }

    /// @notice Checks if the timestamps are valid.
    /// @dev This will revert if any of the timestamps are invalid. This is determined by the strategy
    /// and may vary from strategy to strategy. Checks if '_registrationStartTime' is greater than the '_registrationEndTime'
    /// @param _registrationStartTime The start time for the registration
    /// @param _registrationEndTime The end time for the registration
    function _isPoolTimestampValid(uint64 _registrationStartTime, uint64 _registrationEndTime) internal pure {
        if (_registrationStartTime > _registrationEndTime) {
            revert INVALID();
        }
    }

    /// @notice Checks whether a pool is active or not.
    /// @dev This will return true if the current 'block timestamp' is greater than or equal to the
    /// 'registrationStartTime' and less than or equal to the 'registrationEndTime'.
    /// @return 'true' if pool is active, otherwise 'false'
    function _isPoolActive() internal view returns (bool) {
        if (registrationStartTime <= block.timestamp && block.timestamp <= registrationEndTime) {
            return true;
        }
        return false;
    }

    /// @notice Submit recipient to pool and set their status.
    /// @param _data The data to be decoded.
    /// @custom:data if 'useRegistryAnchor' is 'true' (address recipientId, address recipientAddress, Metadata metadata)
    /// @custom:data if 'useRegistryAnchor' is 'false' (address registryAnchor, address recipientAddress, Metadata metadata)
    /// @param _sender The sender of the transaction
    /// @return recipientId The ID of the recipient
    function _registerRecipient(bytes memory _data, address _sender)
        internal
        onlyActiveRegistration
        returns (address recipientId)
    {
        if (msg.value != 0) revert NON_ZERO_VALUE();

        bool isUsingRegistryAnchor;
        address recipientAddress;
        address registryAnchor;
        Metadata memory metadata;

        // decode data custom to this strategy
        if (useRegistryAnchor) {
            (recipientId, recipientAddress, metadata) = abi.decode(_data, (address, address, Metadata));

            // If the sender is not a profile member this will revert
            if (!_isProfileMember(recipientId, _sender)) {
                revert UNAUTHORIZED();
            }
        } else {
            (registryAnchor, recipientAddress, metadata) = abi.decode(_data, (address, address, Metadata));

            // Set this to 'true' if the registry anchor is not the zero address
            isUsingRegistryAnchor = registryAnchor != address(0);

            // If using the 'registryAnchor' we set the 'recipientId' to the 'registryAnchor', otherwise we set it to the 'msg.sender'
            recipientId = isUsingRegistryAnchor ? registryAnchor : _sender;

            // Checks if the '_sender' is a member of the profile 'anchor' being used and reverts if not
            if (isUsingRegistryAnchor && !_isProfileMember(recipientId, _sender)) {
                revert UNAUTHORIZED();
            }
        }

        // If the metadata is required and the metadata is invalid this will revert
        if (metadataRequired && (bytes(metadata.pointer).length == 0 || metadata.protocol == 0)) {
            revert INVALID_METADATA();
        }

        // If the recipient address is the zero address this will revert
        if (recipientAddress == address(0)) {
            revert RECIPIENT_ERROR(recipientId);
        }

        // Get the recipient
        Recipient storage recipient = _recipients[recipientId];

        // update the recipients data
        recipient.recipientAddress = recipientAddress;
        recipient.metadata = metadata;
        recipient.useRegistryAnchor = useRegistryAnchor ? true : isUsingRegistryAnchor;

        if (recipientToStatusIndexes[recipientId] == 0) {
            // recipient registering new application
            recipientToStatusIndexes[recipientId] = recipientsCounter;
            _setRecipientStatus(recipientId, uint8(Status.Pending));

            bytes memory extendedData = abi.encode(_data, recipientsCounter);
            emit Registered(recipientId, extendedData);

            recipientsCounter++;
        } else {
            uint8 currentStatus = _getUintRecipientStatus(recipientId);
            if (currentStatus == uint8(Status.Accepted) || currentStatus == uint8(Status.InReview)) {
                // recipient updating accepted application
                _setRecipientStatus(recipientId, uint8(Status.Pending));
            } else if (currentStatus == uint8(Status.Rejected)) {
                // recipient updating rejected application
                _setRecipientStatus(recipientId, uint8(Status.Appealed));
            }
            emit UpdatedRegistration(recipientId, _data, _sender, _getUintRecipientStatus(recipientId));
        }
    }

    /// @notice Get the recipient details.
    /// @param _recipientId Id of the recipient
    /// @return Recipient details
    function _getRecipient(address _recipientId) internal view returns (Recipient memory) {
        return _recipients[_recipientId];
    }

    /// @notice Set the recipient status.
    /// @param _recipientId ID of the recipient
    /// @param _status Status of the recipient
    function _setRecipientStatus(address _recipientId, uint256 _status) internal {
        // Get the row index, column index and current row
        (uint256 rowIndex, uint256 colIndex, uint256 currentRow) = _getStatusRowColumn(_recipientId);

        // Calculate the 'newRow'
        uint256 newRow = currentRow & ~(15 << colIndex);

        // Add the status to the mapping
        statusesBitMap[rowIndex] = newRow | (_status << colIndex);
    }

    /// @notice Get recipient status
    /// @param _recipientId ID of the recipient
    /// @return status The status of the recipient
    function _getUintRecipientStatus(address _recipientId) internal view returns (uint8 status) {
        if (recipientToStatusIndexes[_recipientId] == 0) return 0;
        // Get the column index and current row
        (, uint256 colIndex, uint256 currentRow) = _getStatusRowColumn(_recipientId);

        // Get the status from the 'currentRow' shifting by the 'colIndex'
        status = uint8((currentRow >> colIndex) & 15);

        // Return the status
        return status;
    }

    /// @notice Get recipient status 'rowIndex', 'colIndex' and 'currentRow'.
    /// @param _recipientId ID of the recipient
    /// @return (rowIndex, colIndex, currentRow)
    function _getStatusRowColumn(address _recipientId) internal view returns (uint256, uint256, uint256) {
        uint256 recipientIndex = recipientToStatusIndexes[_recipientId] - 1;

        uint256 rowIndex = recipientIndex / 64; // 256 / 4
        uint256 colIndex = (recipientIndex % 64) * 4;

        return (rowIndex, colIndex, statusesBitMap[rowIndex]);
    }
}