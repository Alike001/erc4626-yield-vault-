// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library VaultMath {
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 c,
        bool roundUp
    ) internal pure returns (uint256 result) {
        result = a * b / c;
        if (roundUp && a * b % c > 0) {
            result += 1;
        }
    }
}

contract ERC4626YieldVault {
    using VaultMath for uint256;

    address public immutable asset;
    address public owner;

    string public name;
    string public symbol;

    uint256 public totalShares;
    mapping(address => uint256) public sharesOf;

    uint256 public totalAssets;

    uint256 public managementFeeBps;
    uint256 public accumulatedFees;

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event YieldAdded(uint256 amount);
    event FeesCollected(uint256 amount);

    error ZeroAmount();
    error ZeroAddress();
    error ZeroShares();
    error ExcessiveWithdraw();
    error NotOwner();
    error TransferFailed();
    error FeeTooHigh();

    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        uint256 _managementFeeBps
    ) {
        if (_asset == address(0)) revert ZeroAddress();
        if (_managementFeeBps > 1000) revert FeeTooHigh();
        asset = _asset;
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        managementFeeBps = _managementFeeBps;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (totalShares == 0 || totalAssets == 0) return assets;
        return VaultMath.mulDiv(assets, totalShares, totalAssets, false);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalShares == 0) return shares;
        return VaultMath.mulDiv(shares, totalAssets, totalShares, false);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();

        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), assets);
        if (!ok) revert TransferFailed();

        totalAssets += assets;
        totalShares += shares;
        sharesOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        assets = totalShares == 0
            ? shares
            : VaultMath.mulDiv(shares, totalAssets, totalShares, true);

        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), assets);
        if (!ok) revert TransferFailed();

        totalAssets += assets;
        totalShares += shares;
        sharesOf[receiver] += shares;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        shares = totalShares == 0
            ? assets
            : VaultMath.mulDiv(assets, totalShares, totalAssets, true);

        if (sharesOf[msg.sender] < shares) revert ExcessiveWithdraw();

        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssets -= assets;

        bool ok = IERC20(asset).transfer(receiver, assets);
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver) external returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        if (sharesOf[msg.sender] < shares) revert ExcessiveWithdraw();

        assets = convertToAssets(shares);
        if (assets == 0) revert ZeroAmount();

        sharesOf[msg.sender] -= shares;
        totalShares -= shares;
        totalAssets -= assets;

        bool ok = IERC20(asset).transfer(receiver, assets);
        if (!ok) revert TransferFailed();

        emit Withdraw(msg.sender, receiver, assets, shares);
    }

    function addYield(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        uint256 fee = (amount * managementFeeBps) / 10000;
        accumulatedFees += fee;
        totalAssets += amount - fee;

        emit YieldAdded(amount);
    }

    function collectFees() external {
        if (msg.sender != owner) revert NotOwner();

        uint256 fees = accumulatedFees;
        if (fees == 0) revert ZeroAmount();

        accumulatedFees = 0;

        bool ok = IERC20(asset).transfer(owner, fees);
        if (!ok) revert TransferFailed();

        emit FeesCollected(fees);
    }
}
