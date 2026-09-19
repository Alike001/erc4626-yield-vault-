// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC4626YieldVault.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount);
        require(allowance[from][msg.sender] >= amount);
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ERC4626YieldVaultTest is Test {
    ERC4626YieldVault vault;
    MockERC20 token;

    address owner   = makeAddr("owner");
    address alice   = makeAddr("alice");
    address bob     = makeAddr("bob");
    address yielder = makeAddr("yielder");

    function setUp() public {
        token = new MockERC20();

        vm.prank(owner);
        vault = new ERC4626YieldVault(
            address(token),
            "Vault Share",
            "vTKN",
            200
        );

        token.mint(alice, 10000);
        token.mint(bob, 10000);
        token.mint(yielder, 10000);

        vm.prank(alice);
        token.approve(address(vault), 10000);

        vm.prank(bob);
        token.approve(address(vault), 10000);

        vm.prank(yielder);
        token.approve(address(vault), 10000);
    }

    function test_firstDeposit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000, alice);

        assertEq(shares, 1000);
        assertEq(vault.sharesOf(alice), 1000);
        assertEq(vault.totalAssets(), 1000);
        assertEq(vault.totalShares(), 1000);
    }

    function test_multipleDepositors() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(bob);
        vault.deposit(1000, bob);

        assertEq(vault.sharesOf(alice), 1000);
        assertEq(vault.sharesOf(bob), 1000);
        assertEq(vault.totalAssets(), 2000);
    }

    function test_sharesIncreaseInValueAfterYield() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(yielder);
        vault.addYield(1000);

        uint256 assetsForAlice = vault.convertToAssets(vault.sharesOf(alice));
        assertGt(assetsForAlice, 1000);
    }

    function test_redeemAfterYield() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(yielder);
        vault.addYield(1000);

        uint256 shares = vault.sharesOf(alice);

        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice);

        assertGt(assets, 1000);
        assertGt(token.balanceOf(alice), 9000);
    }

    function test_withdraw() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(alice);
        vault.withdraw(500, alice);

        assertEq(token.balanceOf(alice), 9500);
    }

    function test_rejectExcessiveWithdraw() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(alice);
        vm.expectRevert(ERC4626YieldVault.ExcessiveWithdraw.selector);
        vault.withdraw(2000, alice);
    }

    function test_rejectZeroDeposit() public {
        vm.prank(alice);
        vm.expectRevert(ERC4626YieldVault.ZeroAmount.selector);
        vault.deposit(0, alice);
    }

    function test_feeAccumulatesOnYield() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(yielder);
        vault.addYield(1000);

        assertGt(vault.accumulatedFees(), 0);
    }

    function test_ownerCollectsFees() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(yielder);
        vault.addYield(1000);

        uint256 fees = vault.accumulatedFees();
        uint256 ownerBefore = token.balanceOf(owner);

        vm.prank(owner);
        vault.collectFees();

        assertEq(token.balanceOf(owner), ownerBefore + fees);
        assertEq(vault.accumulatedFees(), 0);
    }

    function test_rejectUnauthorizedFeeCollection() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(yielder);
        vault.addYield(1000);

        vm.prank(alice);
        vm.expectRevert(ERC4626YieldVault.NotOwner.selector);
        vault.collectFees();
    }

    function test_roundingProtectsVault() public {
        vm.prank(alice);
        vault.deposit(1000, alice);

        vm.prank(yielder);
        vault.addYield(1);

        vm.prank(bob);
        uint256 bobShares = vault.deposit(1000, bob);

        assertLe(vault.convertToAssets(bobShares), 1000);
    }
}
