// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {GovernorContract} from "../src/GovernorContract.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";

/// @title DeployGovernance - full governance stack deployment (roadmap Sen 28 Sep).
/// @notice Production parameters from the SPEC: quorum 4%, voting delay 1 day
///         (7200 blocks at 12 s/block), voting period 1 week (50400 blocks), timelock
///         min delay 1 day. Order matters because of a chicken-and-egg problem: the
///         timelock wants the governor as PROPOSER/CANCELER, but the governor needs
///         the timelock address in its constructor. The way out: deploy the timelock
///         with the deployer as temporary DEFAULT_ADMIN, deploy the governor against
///         it, wire the roles, then renounce the admin role so that from then on
///         NOTHING can be changed except through a passed proposal.
contract DeployGovernance is Script {
    // Roadmap parameters (SPEC section 4).
    uint256 public constant QUORUM_PERCENTAGE = 4;
    uint256 public constant VOTING_DELAY = 7200; // blocks, 1 day at 12 s/block
    uint256 public constant VOTING_PERIOD = 50400; // blocks, 1 week at 12 s/block
    uint256 public constant MIN_DELAY = 1 days; // seconds, timelock delay

    /// @notice ETH sent to the Treasury at deploy time. The deployer must hold it.
    uint256 public constant TREASURY_FUNDING = 0.1 ether;

    function run()
        external
        returns (GovernanceToken token, TimelockController timelock, GovernorContract governor, Treasury treasury)
    {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        // msg.sender in a script context is the default sender cheatcode, NOT the
        // address derived from PRIVATE_KEY. Derive for accurate deployment metadata.
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Token: fixed 1M GT to the deployer.
        token = new GovernanceToken();

        // 2. Timelock: empty proposers/executors (governor does not exist yet),
        //    deployer as temporary admin.
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(MIN_DELAY, proposers, executors, deployer);

        // 3. Governor against the token + timelock.
        governor = new GovernorContract(token, timelock, QUORUM_PERCENTAGE, VOTING_DELAY, VOTING_PERIOD);

        // 4. Wiring: governor proposes and cancels on the timelock; execution is open.
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        // 5. Renounce every timelock role the deployer holds. After this block the
        //    timelock is fully autonomous: only passed proposals can act on it.
        //    (CANCELLER_ROLE has a double L in OZ v5, a common typo trap.)
        _renounceIfHeld(timelock, timelock.DEFAULT_ADMIN_ROLE(), deployer);
        _renounceIfHeld(timelock, timelock.PROPOSER_ROLE(), deployer);
        _renounceIfHeld(timelock, timelock.CANCELLER_ROLE(), deployer);
        _renounceIfHeld(timelock, timelock.EXECUTOR_ROLE(), deployer);

        // 6. Treasury under timelock control, funded with ETH.
        treasury = new Treasury(address(timelock));
        (bool funded,) = payable(address(treasury)).call{value: TREASURY_FUNDING}("");
        require(funded, "treasury funding failed");

        // 7. The deployer activates his own voting weight. Demo simplification: with
        //    the whole 1M supply delegated to one address that address alone passes
        //    any quorum. Distribute and delegate for real before treating this as a
        //    live DAO.
        token.delegate(deployer);

        vm.stopBroadcast();

        // Post-deploy sanity: the wiring must hold or the deployment is broken.
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)), "governor lacks PROPOSER_ROLE");
        require(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)), "governor lacks CANCELLER_ROLE");
        require(!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer), "deployer still admin");
        require(address(treasury).balance == TREASURY_FUNDING, "treasury balance mismatch");
        require(token.totalSupply() == token.INITIAL_SUPPLY(), "token supply mismatch");

        _writeDeploymentJson(deployer, address(token), address(timelock), address(governor), address(treasury));

        console.log("GovernanceToken:", address(token));
        console.log("Timelock:        ", address(timelock));
        console.log("Governor:        ", address(governor));
        console.log("Treasury:        ", address(treasury));
        console.log("Deployer:        ", deployer);
        console.log("Quorum:          ", QUORUM_PERCENTAGE, "percent");
        console.log("Voting delay:    ", VOTING_DELAY, "blocks");
        console.log("Voting period:   ", VOTING_PERIOD, "blocks");
    }

    /// @dev Renouncing an unheld role reverts, so check first. Covers both spellings
    ///      because CANCELLER_ROLE is the one actually used by TimelockController v5.
    function _renounceIfHeld(TimelockController timelock_, bytes32 role, address account) internal {
        if (timelock_.hasRole(role, account)) {
            timelock_.renounceRole(role, account);
        }
    }

    /// @dev Writes deployments/<chainId>.json, the source of addresses for the frontend.
    function _writeDeploymentJson(
        address deployer,
        address tokenAddr,
        address timelockAddr,
        address governorAddr,
        address treasuryAddr
    ) internal {
        vm.createDir("deployments", true);

        string memory json = "root";
        vm.serializeUint(json, "chainId", block.chainid);
        // Epoch milliseconds (Solidity has no ISO formatter; the frontend does not
        // depend on the format).
        vm.serializeString(json, "deployedAt", vm.toString(vm.unixTime()));
        vm.serializeAddress(json, "deployer", deployer);

        string memory contracts = "contracts";
        vm.serializeAddress(contracts, "GovernanceToken", tokenAddr);
        vm.serializeAddress(contracts, "Timelock", timelockAddr);
        vm.serializeAddress(contracts, "Governor", governorAddr);
        string memory contractsJson = vm.serializeAddress(contracts, "Treasury", treasuryAddr);
        string memory finalJson = vm.serializeString(json, "contracts", contractsJson);

        vm.writeFile(string.concat("deployments/", vm.toString(block.chainid), ".json"), finalJson);
    }
}
