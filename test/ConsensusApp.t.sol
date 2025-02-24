// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConsensusApp.sol";
import "../src/interfaces/INitroTypes.sol";

/**
 * @title ConsensusAppTest
 * @notice Demonstrates avoiding memory→storage copies by never storing struct arrays
 *         in contract storage.
 */
contract ConsensusAppTest is Test {
    // Only store references that do not trigger memory to storage copying.
    // We'll keep the deployed contract in storage, which is safe.
    ConsensusApp internal consensusApp;

    // Sample participants
    address internal participantA = address(0xAAA1);
    address internal participantB = address(0xBBB2);
    address internal participantC = address(0xCCC3);

    /**
     * @dev Runs once before all tests, deploying a new instance of the contract
     *      and setting up references.
     */
    function setUp() public {
        // Deploy the ConsensusApp
        consensusApp = new ConsensusApp();
    }

    /**
     * @dev Builds a sample FixedPart in memory.
     */
    function buildFixedPart() internal view returns (INitroTypes.FixedPart memory) {
        address[] memory participants = new address[](3);
        participants[0] = participantA;
        participants[1] = participantB;
        participants[2] = participantC;

        return INitroTypes.FixedPart({
            participants: participants,
            channelNonce: 8, // from TS example
            appDefinition: address(consensusApp),
            challengeDuration: 0x100
        });
    }

    /**
     * @dev Builds a sample VariablePart in memory.
     */
    function buildVariablePart() internal pure returns (INitroTypes.VariablePart memory) {
        // Minimal outcome array for demonstration
        Outcome.SingleAssetExit[] memory emptyOutcome =
            new Outcome.SingleAssetExit[](0);

        return INitroTypes.VariablePart({
            outcome: emptyOutcome,
            appData: new bytes(0), // empty bytes for appData
            turnNum: 5,
            isFinal: false
        });
    }

    /**
     * @dev Test: a single state signed by everyone is considered supported.
     *      The TS had 0b111 => decimal 7 => all participants.
     */
    function testSingleStateSignedByAllIsSupported() public {
        // Build everything in memory.
        INitroTypes.FixedPart memory fixedPart = buildFixedPart();
        INitroTypes.VariablePart memory varPart = buildVariablePart();

        // Empty proof
        INitroTypes.RecoveredVariablePart[] memory emptyProof =
            new INitroTypes.RecoveredVariablePart[](0);

        // Candidate with bitmask=7 => all participants.
        INitroTypes.RecoveredVariablePart memory candidate = INitroTypes.RecoveredVariablePart({
            variablePart: varPart,
            signedBy: 7
        });

        // If it reverts, the test fails.
        vm.prank(participantA);
        consensusApp.stateIsSupported(fixedPart, emptyProof, candidate);
    }

    /**
     * @dev Test: a non-empty proof array => revert.
     */
    function testProofArrayIsNonEmptyShouldRevert() public {
        vm.expectRevert();

        INitroTypes.FixedPart memory fixedPart = buildFixedPart();
        INitroTypes.VariablePart memory varPart = buildVariablePart();

        // 1-element proof
        INitroTypes.RecoveredVariablePart[] memory invalidProof =
            new INitroTypes.RecoveredVariablePart[](1);
        invalidProof[0] = INitroTypes.RecoveredVariablePart({
            variablePart: varPart,
            signedBy: 7 // all participants
        });

        INitroTypes.RecoveredVariablePart memory candidate = INitroTypes.RecoveredVariablePart({
            variablePart: varPart,
            signedBy: 7
        });

        consensusApp.stateIsSupported(fixedPart, invalidProof, candidate);
    }

    /**
     * @dev Test: a single state signed by fewer than all participants => revert.
     */
    function testSingleStateSignedByLessThanAllIsNotSupported() public {
        vm.expectRevert();

        INitroTypes.FixedPart memory fixedPart = buildFixedPart();
        INitroTypes.VariablePart memory varPart = buildVariablePart();

        // bitmask=3 => only 2 participants.
        INitroTypes.RecoveredVariablePart memory candidate = INitroTypes.RecoveredVariablePart({
            variablePart: varPart,
            signedBy: 3
        });

        INitroTypes.RecoveredVariablePart[] memory emptyProof =
            new INitroTypes.RecoveredVariablePart[](0);

        consensusApp.stateIsSupported(fixedPart, emptyProof, candidate);
    }
}
