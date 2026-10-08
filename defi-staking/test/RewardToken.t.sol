// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {MockStakingPool, IMintable} from "../src/mocks/MockStakingPool.sol";
import {IERC20} from "./interfaces/IERC20Events.sol";

/// @title Test suite RewardToken — ditulis DULU sebelum implementasi (TDD, Sab 12 Sep).
/// @notice Mapping ke SPEC §8: metadata, akses mint (E16), ERC-20 standar, events.
contract RewardTokenTest is Test {
    RewardToken internal token;
    MockStakingPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    string constant NAME = "Staking Reward Token";
    string constant SYMBOL = "SRT";
    uint256 constant AMOUNT = 100e18;

    function setUp() public {
        token = new RewardToken(NAME, SYMBOL, 0);
        pool = new MockStakingPool(IMintable(address(token)));
        token.setStakingPool(address(pool));
    }

    /*//////////////////////////////////
            METADATA (SPEC §8.1)
    //////////////////////////////////*/

    function test_Name() public view {
        assertEq(token.name(), NAME);
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), SYMBOL);
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    /*//////////////////////////////////
        DEPLOY & SET STAKING POOL
    //////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(token.totalSupply(), 0, "supply awal harus 0");
        assertEq(token.stakingPool(), address(pool));
        assertEq(token.owner(), address(this), "deployer = owner");
    }

    function test_ConstructorPremintsToDeployer() public {
        RewardToken preminted = new RewardToken(NAME, SYMBOL, 1_000_000e18);
        assertEq(preminted.totalSupply(), 1_000_000e18, "pre-mint ke deployer");
        assertEq(preminted.balanceOf(address(this)), 1_000_000e18);
    }

    function test_SetStakingPoolWorks() public {
        RewardToken fresh = new RewardToken(NAME, SYMBOL, 0);
        fresh.setStakingPool(address(0xBEEF));
        assertEq(fresh.stakingPool(), address(0xBEEF));
    }

    function test_SetStakingPoolTwiceReverts() public {
        vm.expectRevert(RewardToken.RewardToken__StakingPoolAlreadySet.selector);
        token.setStakingPool(address(0xBEEF));
    }

    function test_SetStakingPoolByNonOwnerReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setStakingPool(address(0xBEEF));
    }

    function test_SetStakingPoolEmitsEvent() public {
        RewardToken fresh = new RewardToken(NAME, SYMBOL, 0);
        vm.expectEmit(true, true, true, true);
        emit RewardToken.StakingPoolSet(address(0xBEEF));
        fresh.setStakingPool(address(0xBEEF));
    }

    /*//////////////////////////////////
            MINT GATING (E16)
    //////////////////////////////////*/

    function test_MintByPoolSucceeds() public {
        pool.mintReward(alice, AMOUNT);
        assertEq(token.balanceOf(alice), AMOUNT);
        assertEq(token.totalSupply(), AMOUNT);
    }

    function test_MintByNonPoolReverts_Unauthorized() public {
        vm.prank(alice);
        vm.expectRevert(RewardToken.RewardToken__Unauthorized.selector);
        token.mint(alice, AMOUNT);
    }

    function test_MintByOwnerJugaRevert() public {
        // Bahkan owner pun gak boleh mint langsung — satu-satunya minter = stakingPool.
        vm.expectRevert(RewardToken.RewardToken__Unauthorized.selector);
        token.mint(alice, AMOUNT);
    }

    function test_MintByPoolEmitsTransferEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), alice, AMOUNT);
        pool.mintReward(alice, AMOUNT);
    }

    function test_MintToZeroAddressReverts() public {
        vm.expectRevert(); // ERC20InvalidSender dari OZ
        pool.mintReward(address(0), AMOUNT);
    }

    /*//////////////////////////////////
        ERC-20 STANDAR (SPEC §8.3)
    //////////////////////////////////*/

    function test_TransferMovesBalance() public {
        pool.mintReward(alice, AMOUNT);
        vm.prank(alice);
        token.transfer(bob, 40e18);
        assertEq(token.balanceOf(alice), 60e18);
        assertEq(token.balanceOf(bob), 40e18);
    }

    function test_TransferInsufficientBalanceReverts() public {
        pool.mintReward(alice, 10e18);
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 11e18);
    }

    function test_TransferEmitsEvent() public {
        pool.mintReward(alice, AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(alice, bob, 40e18);
        vm.prank(alice);
        token.transfer(bob, 40e18);
    }

    function test_ApproveSetsAllowance() public {
        vm.prank(alice);
        token.approve(bob, 50e18);
        assertEq(token.allowance(alice, bob), 50e18);
    }

    function test_ApproveEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(alice, bob, 50e18);
        vm.prank(alice);
        token.approve(bob, 50e18);
    }

    function test_TransferFromUsesAllowance() public {
        pool.mintReward(alice, AMOUNT);
        vm.prank(alice);
        token.approve(bob, 50e18);
        vm.prank(bob);
        token.transferFrom(alice, bob, 50e18);
        assertEq(token.balanceOf(bob), 50e18);
        assertEq(token.allowance(alice, bob), 0, "allowance harus terpakai habis");
    }

    function test_TransferFromExceedingAllowanceReverts() public {
        pool.mintReward(alice, AMOUNT);
        vm.prank(alice);
        token.approve(bob, 50e18);
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, bob, 51e18);
    }

    /*//////////////////////////////////
            FUZZ (SPEC §8)
    //////////////////////////////////*/

    function testFuzz_MintByPoolIncreasesSupply(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, 1_000_000e18);

        pool.mintReward(to, amount);

        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_TransferRoundTrip(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, 1_000_000e18);
        transferAmount = bound(transferAmount, 0, mintAmount);

        pool.mintReward(alice, mintAmount);
        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.totalSupply(), mintAmount, "supply gak boleh berubah oleh transfer");
    }
}
