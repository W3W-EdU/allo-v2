// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {StdStorage, Test, console, stdStorage} from 'forge-std/Test.sol';
import {MockStrategyMilestonesExtension} from "../../utils/MockStrategyMilestonesExtension.sol";
import {IMilestonesExtension} from "../../../contracts/extensions/interfaces/IMilestonesExtension.sol";
import {IAllo} from "../../../contracts/core/interfaces/IAllo.sol";
import {IBaseStrategy} from "../../../contracts/strategies/CoreBaseStrategy.sol";
import {Errors} from "../../../contracts/core/libraries/Errors.sol";
import {Metadata} from "../../../contracts/core/libraries/Metadata.sol";

abstract contract BaseMilestonesExtensionUnit is Test {
    event MaxBidIncreased(uint256 maxBid);
    event SetBid(address indexed bidderId, uint256 newBid);
    event MilestoneSubmitted(uint256 milestoneId);
    event MilestoneStatusChanged(uint256 indexed milestoneId, IMilestonesExtension.Status status);
    event MilestonesSet(uint256 milestonesLength);

    struct MilestoneWithoutEnums {
        uint256 amountPercentage;
        Metadata metadata;
        uint8 status;
    }

    uint256 public constant INITIAL_MAX_BID = 10;

    MockStrategyMilestonesExtension public MilestonesExtension;
    address public allo;
    uint256 public poolId;

    function setUp() public virtual {
        allo = makeAddr("allo");
        MilestonesExtension = new MockStrategyMilestonesExtension(allo);
        poolId = 1;
    }

    function _parseMilestones(MilestoneWithoutEnums[] memory _rawMilestones) internal view returns (IMilestonesExtension.Milestone[] memory _milestones) {
        _milestones = new IMilestonesExtension.Milestone[](_rawMilestones.length);
        for (uint256 i = 0; i < _milestones.length; i++) {
            _milestones[i].amountPercentage = bound(_rawMilestones[i].amountPercentage, 1, type(uint128).max);
            _milestones[i].metadata = _rawMilestones[i].metadata;
            _milestones[i].status = IMilestonesExtension.Status(bound(uint256(_rawMilestones[i].status), 0, 6));
        }
    }
}

contract MilestonesExtension__MilestonesExtension_init is BaseMilestonesExtensionUnit {
    function test_initializeMaxBid(uint256 _maxBid) public {
        vm.assume(_maxBid > 0);
        IMilestonesExtension.InitializeParams memory _initializeData = IMilestonesExtension
            .InitializeParams({maxBid: _maxBid});

        MilestonesExtension.expose__MilestonesExtension_init(_initializeData);

        assertEq(MilestonesExtension.maxBid(), _maxBid);
    }
}

contract MilestonesExtensionIncreaseMaxBid is BaseMilestonesExtensionUnit {
    function setUp() public override {
        super.setUp();
        vm.prank(allo);
        MilestonesExtension.initialize(
            poolId,
            abi.encode(
                IMilestonesExtension.InitializeParams({
                    maxBid: INITIAL_MAX_BID
                })
            )
        );
    }

    function test_increaseMaxBid(address _caller, uint256 _maxBid) public {
        vm.assume(_maxBid >= INITIAL_MAX_BID);
        vm.prank(_caller);
        vm.mockCall(
            allo,
            abi.encodeWithSelector(IAllo.isPoolManager.selector, poolId, _caller),
            abi.encode(true)
        );
        MilestonesExtension.increaseMaxBid(_maxBid);

        assertEq(MilestonesExtension.maxBid(), _maxBid);
    }

    function test_emitEventOnIncreaseMaxBid(address _caller, uint256 _maxBid) public {
        vm.assume(_maxBid >= INITIAL_MAX_BID);
        vm.prank(_caller);
        vm.mockCall(
            allo,
            abi.encodeWithSelector(IAllo.isPoolManager.selector, poolId, _caller),
            abi.encode(true)
        );
        vm.expectEmit(true, true, true, true, address(MilestonesExtension));
        emit MaxBidIncreased(_maxBid);
        MilestonesExtension.increaseMaxBid(_maxBid);
    }

    function test_Revert_unauthorizedIncreaseMaxBid(address _caller, uint256 _maxBid) public {
        vm.prank(_caller);
        vm.mockCall(
            allo,
            abi.encodeWithSelector(IAllo.isPoolManager.selector, poolId, _caller),
            abi.encode(false)
        );
        vm.expectRevert(IBaseStrategy.BaseStrategy_UNAUTHORIZED.selector);
        MilestonesExtension.increaseMaxBid(_maxBid);
    }

    function test_Revert_invalidValueIncreaseMaxBid(address _caller, uint256 _maxBid) public {
        vm.assume(_maxBid < INITIAL_MAX_BID);
        vm.mockCall(
            allo,
            abi.encodeWithSelector(IAllo.isPoolManager.selector, poolId, _caller),
            abi.encode(true)
        );
        vm.prank(_caller);
        vm.expectRevert(IMilestonesExtension.MilestonesExtension_AMOUNT_TOO_LOW.selector);
        MilestonesExtension.increaseMaxBid(_maxBid);
    }
}

contract MilestonesExtension_setProposalBid is BaseMilestonesExtensionUnit {
    function setUp() public override {
        super.setUp();
        vm.prank(allo);
        MilestonesExtension.initialize(
            poolId,
            abi.encode(
                IMilestonesExtension.InitializeParams({
                    maxBid: INITIAL_MAX_BID
                })
            )
        );
    }

    function test_Revert_maxBidExceeded(address _bidder, uint256 _bid) public {
        vm.assume(_bid > INITIAL_MAX_BID);

        vm.expectRevert(IMilestonesExtension.MilestonesExtension_EXCEEDING_MAX_BID.selector);
        MilestonesExtension.expose_setProposalBid(_bidder, _bid);
    }

    function test_emitEventOnSetProposalBid(address _bidder, uint256 _bid) public {
        vm.assume(_bid <= INITIAL_MAX_BID);
        
        uint256 _storedBid = _bid == 0 ? INITIAL_MAX_BID : _bid;

        vm.expectEmit(true, true, true, true, address(MilestonesExtension));
        emit SetBid(_bidder, _storedBid);
        MilestonesExtension.expose_setProposalBid(_bidder, _bid);
    }

    function test_updateStorageOnSetProposalBid(address _bidder, uint256 _bid) public {
        vm.assume(_bid <= INITIAL_MAX_BID);
        
        uint256 _storedBid = _bid == 0 ? INITIAL_MAX_BID : _bid;

        MilestonesExtension.expose_setProposalBid(_bidder, _bid);

        uint256 _currentBid = MilestonesExtension.bids(_bidder);
        assertEq(_currentBid, _storedBid, "Incorrect bid amount");
    }
}

contract MilestonesExtensionSetMilestones is BaseMilestonesExtensionUnit {
    function setUp() public override {
        super.setUp();
        vm.prank(allo);
        MilestonesExtension.initialize(
            poolId,
            abi.encode(
                IMilestonesExtension.InitializeParams({
                    maxBid: INITIAL_MAX_BID
                })
            )
        );
    }

    function test_Revert_unauthorizedSetMilestones(
        address _caller,
        MilestoneWithoutEnums[] memory _rawMilestones
    ) public {
        IMilestonesExtension.Milestone[] memory _milestones = _parseMilestones(_rawMilestones);
        vm.mockCall(
            allo,
            abi.encodeWithSelector(IAllo.isPoolManager.selector, poolId, _caller),
            abi.encode(false)
        );

        vm.prank(_caller);
        vm.expectRevert(IBaseStrategy.BaseStrategy_UNAUTHORIZED.selector);
        MilestonesExtension.setMilestones(_milestones);
    }

    function test_Revert_zeroAmountPercentageMilestone(
        address _caller,
        MilestoneWithoutEnums[] memory _rawMilestones,
        uint256 _zeroPercentageIndex
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _parseMilestones(_rawMilestones);
        _zeroPercentageIndex = bound(_zeroPercentageIndex, 0, _milestones.length - 1);
        _milestones[_zeroPercentageIndex].amountPercentage = 0;

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        vm.expectRevert(IMilestonesExtension.MilestonesExtension_INVALID_MILESTONE.selector);
        MilestonesExtension.setMilestones(_milestones);
    }

    function test_Revert_invalidAmountPercentagesSum(
        address _caller,
        MilestoneWithoutEnums[] memory _rawMilestones
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _parseMilestones(_rawMilestones);
        uint256 _sum;
        for (uint256 i = 0; i < _milestones.length; i++) {
            _sum += _milestones[i].amountPercentage;
        }
        if (_sum == 1e18) _milestones[0].amountPercentage += 1;

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        vm.expectRevert(IMilestonesExtension.MilestonesExtension_INVALID_MILESTONE.selector);
        MilestonesExtension.setMilestones(_milestones);
    }

    function test_emitEventOnSetMilestones(
        address _caller,
        MilestoneWithoutEnums[] memory _rawMilestones
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _parseMilestones(_rawMilestones);
        uint256 _requiredSum = 1e18;
        uint256 _sum;
        for (uint256 i = 0; i < _milestones.length - 1; i++) {
            _milestones[i].amountPercentage = bound(_milestones[i].amountPercentage, 1, _requiredSum + i - _milestones.length);
            _requiredSum -= _milestones[i].amountPercentage;
        }
        _milestones[_milestones.length - 1].amountPercentage = _requiredSum;

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        vm.expectEmit(true, true, true, true, address(MilestonesExtension));
        emit MilestonesSet(_milestones.length);
        MilestonesExtension.setMilestones(_milestones);
    }

    function test_setAndGetMilestones(
        address _caller,
        MilestoneWithoutEnums[] memory _rawMilestones
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _parseMilestones(_rawMilestones);
        uint256 _requiredSum = 1e18;
        uint256 _sum;
        for (uint256 i = 0; i < _milestones.length - 1; i++) {
            _milestones[i].amountPercentage = bound(_milestones[i].amountPercentage, 1, _requiredSum + i - _milestones.length);
            _requiredSum -= _milestones[i].amountPercentage;
        }
        _milestones[_milestones.length - 1].amountPercentage = _requiredSum;

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        MilestonesExtension.setMilestones(_milestones);

        for (uint256 i = 0; i < _milestones.length; i++) {
            IMilestonesExtension.Milestone memory _milestone = MilestonesExtension.getMilestone(i);
            assertEq(uint256(_milestone.status), uint256(IMilestonesExtension.Status.None), "Incorrect status");
            assertEq(_milestone.amountPercentage, _milestones[i].amountPercentage, "Incorrect amountPercentage");
            assertEq(_milestone.metadata.protocol, _milestones[i].metadata.protocol, "Incorrect metadata.protocol");
            assertEq(_milestone.metadata.pointer, _milestones[i].metadata.pointer, "Incorrect metadata.pointer");
            IMilestonesExtension.Status _status = MilestonesExtension.getMilestoneStatus(i);
            assertEq(uint256(_status), uint256(IMilestonesExtension.Status.None), "Incorrect status");
        }
    }
}

contract MilestonesExtension_validateSubmitUpcomingMilestone is BaseMilestonesExtensionUnit {
    using stdStorage for StdStorage;

    function test_Revert_invalidSubmitter(address _acceptedRecipientId, address _sender) public {
        vm.assume(_acceptedRecipientId != _sender);
        stdstore.target(address(MilestonesExtension)).sig('acceptedRecipientId()').depth(0).checked_write(_acceptedRecipientId);
        
        vm.expectRevert(IMilestonesExtension.MilestonesExtension_INVALID_SUBMITTER.selector);
        MilestonesExtension.expose_validateSubmitUpcomingMilestone(_sender);
    }
}

contract MilestonesExtensionSubmitUpcomingMilestone is BaseMilestonesExtensionUnit {
    using stdStorage for StdStorage;

    address internal _acceptedRecipientId = makeAddr("_acceptedRecipientId");

    function setUp() public override {
        super.setUp();
        vm.prank(allo);
        MilestonesExtension.initialize(
            poolId,
            abi.encode(
                IMilestonesExtension.InitializeParams({
                    maxBid: INITIAL_MAX_BID
                })
            )
        );
        StdStorage storage meStorage = stdstore.target(address(MilestonesExtension)).sig('acceptedRecipientId()');
        meStorage.depth(0).checked_write(_acceptedRecipientId);
    }

    function test_storageUpdatesOnSubmitUpcomingMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        IMilestonesExtension.Milestone memory _milestone = MilestonesExtension.getMilestone(0);
        assertEq(uint256(_milestone.status), uint256(IMilestonesExtension.Status.Pending), "Incorrect status");
        assertEq(_milestone.amountPercentage, _milestones[0].amountPercentage, "Incorrect amountPercentage");
        assertEq(_milestone.metadata.protocol, _metadata.protocol, "Incorrect metadata.protocol");
        assertEq(_milestone.metadata.pointer, _metadata.pointer, "Incorrect metadata.pointer");
    }

    function test_emitEventOnSubmitUpcomingMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        vm.expectEmit(true, true, true, true, address(MilestonesExtension));
        emit MilestoneSubmitted(0);
        MilestonesExtension.submitUpcomingMilestone(_metadata);
    }

    function test_Revert_cannotSubmitMilestoneTwice(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        _setMilestones(_rawMilestones);

        vm.startPrank(_acceptedRecipientId);

        MilestonesExtension.submitUpcomingMilestone(_metadata);

        vm.expectRevert(IMilestonesExtension.MilestonesExtension_MILESTONE_PENDING.selector);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        vm.stopPrank();
    }

    function _setMilestones(MilestoneWithoutEnums[] memory _rawMilestones) internal returns(IMilestonesExtension.Milestone[] memory _milestones) {
        _milestones = _parseMilestones(_rawMilestones);
        uint256 _requiredSum = 1e18;
        for (uint256 i = 0; i < _milestones.length - 1; i++) {
            _milestones[i].amountPercentage = bound(_milestones[i].amountPercentage, 1, _requiredSum + i - _milestones.length);
            _requiredSum -= _milestones[i].amountPercentage;
        }
        _milestones[_milestones.length - 1].amountPercentage = _requiredSum;

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        MilestonesExtension.setMilestones(_milestones);
    }
}

contract MilestonesExtensionReviewMilestone is BaseMilestonesExtensionUnit {
    using stdStorage for StdStorage;

    address internal _acceptedRecipientId = makeAddr("_acceptedRecipientId");

    function setUp() public override {
        super.setUp();
        vm.prank(allo);
        MilestonesExtension.initialize(
            poolId,
            abi.encode(
                IMilestonesExtension.InitializeParams({
                    maxBid: INITIAL_MAX_BID
                })
            )
        );
        StdStorage storage meStorage = stdstore.target(address(MilestonesExtension)).sig('acceptedRecipientId()');
        meStorage.depth(0).checked_write(_acceptedRecipientId);
    }

    function test_statusUpdatesOnReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata,
        uint256 _statusSeed
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        IMilestonesExtension.Status _status = IMilestonesExtension.Status(bound(_statusSeed, 1, 6));
        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        MilestonesExtension.reviewMilestone(_status);

        IMilestonesExtension.Milestone memory _milestone = MilestonesExtension.getMilestone(0);
        assertEq(uint256(_milestone.status), uint256(_status), "Incorrect status");
    }

    function test_upcomingMilestoneUpdatesOnReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        MilestonesExtension.reviewMilestone(IMilestonesExtension.Status.Accepted);

        assertEq(MilestonesExtension.upcomingMilestone(), uint256(1), "Incorrect upcoming milestone");
    }

    function test_upcomingMilestoneDoesNotUpdateOnReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata,
        uint256 _statusSeed
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        IMilestonesExtension.Status _status = IMilestonesExtension.Status(bound(_statusSeed, 1, 6));
        vm.assume(_status != IMilestonesExtension.Status.Accepted);
        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        MilestonesExtension.reviewMilestone(_status);

        assertEq(MilestonesExtension.upcomingMilestone(), uint256(0), "Incorrect upcoming milestone");
    }

    function test_emitEventOnReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata,
        uint256 _statusSeed
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        IMilestonesExtension.Status _status = IMilestonesExtension.Status(bound(_statusSeed, 1, 6));
        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        vm.expectEmit(true, true, true, true, address(MilestonesExtension));
        emit MilestoneStatusChanged(0, _status);
        MilestonesExtension.reviewMilestone(_status);
    }

    function test_Revert_NoneReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        vm.expectRevert(IMilestonesExtension.MilestonesExtension_INVALID_MILESTONE_STATUS.selector);
        MilestonesExtension.reviewMilestone(IMilestonesExtension.Status.None);
    }

    function test_Revert_unauthorizedReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.prank(_acceptedRecipientId);
        MilestonesExtension.submitUpcomingMilestone(_metadata);

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(false));
        vm.expectRevert(IBaseStrategy.BaseStrategy_UNAUTHORIZED.selector);
        MilestonesExtension.reviewMilestone(IMilestonesExtension.Status.None);
    }

    function test_Revert_notPendingReviewMilestone(
        MilestoneWithoutEnums[] memory _rawMilestones,
        Metadata memory _metadata
    ) public {
        vm.assume(_rawMilestones.length > 0);
        IMilestonesExtension.Milestone[] memory _milestones = _setMilestones(_rawMilestones);

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        vm.expectRevert(IMilestonesExtension.MilestonesExtension_MILESTONE_NOT_PENDING.selector);
        MilestonesExtension.reviewMilestone(IMilestonesExtension.Status.Accepted);
    }

    function _setMilestones(MilestoneWithoutEnums[] memory _rawMilestones) internal returns(IMilestonesExtension.Milestone[] memory _milestones) {
        _milestones = _parseMilestones(_rawMilestones);
        uint256 _requiredSum = 1e18;
        for (uint256 i = 0; i < _milestones.length - 1; i++) {
            _milestones[i].amountPercentage = bound(_milestones[i].amountPercentage, 1, _requiredSum + i - _milestones.length);
            _requiredSum -= _milestones[i].amountPercentage;
        }
        _milestones[_milestones.length - 1].amountPercentage = _requiredSum;

        vm.mockCall(allo, abi.encodeWithSelector(IAllo.isPoolManager.selector), abi.encode(true));
        MilestonesExtension.setMilestones(_milestones);
    }
}