// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// ============================================================================
// Minimal Interfaces
// ============================================================================

/// @dev Minimal ERC20 interface
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @dev Minimal ERC4626 vault interface (Euler EVault)
interface IEVault {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function maxDeposit(address) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    // Euler-specific borrowing
    function debtOf(address account) external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function borrow(uint256 amount, address receiver) external returns (uint256);
    function repay(uint256 amount, address receiver) external returns (uint256);
    function interestRate() external view returns (uint256);
    function creator() external view returns (address);
}

/// @dev Minimal EVC interface
interface IEVC {
    function getAccountOwner(address account) external view returns (address);
    function isAccountOperatorAuthorized(address account, address operator) external view returns (bool);
    function getCollaterals(address account) external view returns (address[] memory);
    function isCollateralEnabled(address account, address vault) external view returns (bool);
    function isControllerEnabled(address account, address vault) external view returns (bool);
    function enableCollateral(address account, address vault) external;
    function enableController(address account, address vault) external;
    function disableCollateral(address account, address vault) external;
    function disableController(address account) external;
    function getControllers(address account) external view returns (address[] memory);
    function getNonce(bytes19 addressPrefix, uint256 nonceNamespace) external view returns (uint256);
    function getOperator(bytes19 addressPrefix, address operator) external view returns (uint256);
    function setAccountOperator(address account, address operator, bool authorized) external;
    function getRawExecutionContext() external view returns (uint256);
    struct BatchItem {
        address onBehalfOfAccount;
        address targetContract;
        uint256 value;
        bytes data;
    }
    function batch(BatchItem[] calldata items) external;
    function permit(
        address signer,
        address sender,
        uint256 nonceNamespace,
        uint256 nonce,
        uint256 deadline,
        uint256 value,
        bytes calldata data,
        bytes calldata signature
    ) external;
}

/// @dev Minimal CoW Protocol Settlement interface
interface ICowSettlement {
    struct Trade {
        uint256 sellTokenIndex;
        uint256 buyTokenIndex;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        uint256 flags;
        uint256 executedAmount;
        bytes signature;
    }
    struct Interaction {
        address target;
        uint256 value;
        bytes callData;
    }
    function authenticator() external view returns (address);
    function vaultRelayer() external view returns (address);
    function domainSeparator() external view returns (bytes32);
    function setPreSignature(bytes calldata orderUid, bool signed) external;
    function settle(
        address[] calldata tokens,
        uint256[] calldata clearingPrices,
        Trade[] calldata trades,
        Interaction[][3] calldata interactions
    ) external;
}

/// @dev Minimal CoW Authentication interface
interface ICowAuthentication {
    function isSolver(address prospectiveSolver) external view returns (bool);
    function manager() external view returns (address);
    function addSolver(address solver) external;
    function removeSolver(address solver) external;
}

/// @dev Minimal CowWrapper interface (matches src/CowWrapper.sol ICowWrapper)
interface ICowWrapper {
    function name() external view returns (string memory);
    function SETTLEMENT() external view returns (address);
    function wrappedSettle(bytes calldata settleData, bytes calldata chainedWrapperData) external returns (bytes4);
    function validateWrapperData(bytes calldata wrapperData) external view;
}

/// @dev Minimal PreApprovedHashes interface
interface IPreApprovedHashes {
    function setPreApprovedHash(bytes32 hash, bool approved) external;
    function isHashPreApproved(address owner, bytes32 hash) external view returns (bool);
    function preApprovedHashes(address owner, bytes32 hash) external view returns (uint256);
}

/// @dev Minimal InboxFactory interface
interface IInboxFactory {
    function getInbox(address owner, address subaccount) external returns (address);
    function getInboxAddressAndDomainSeparator(address owner, address subaccount)
        external
        view
        returns (address creationAddress, bytes32 domainSeparator);
    function getInboxCreationCode() external pure returns (bytes memory);
}

// ============================================================================
// PoC Test Contract
// ============================================================================

contract PoCTest is Test {
    // ========================================================================
    // DIRECT ADDRESSES (not behind proxy)
    // ========================================================================

    // -- CoW Protocol --
    address constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    // -- Ethereum Vault Connector --
    address constant EVC = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383;

    // -- Euler Vaults --
    address constant EUSDS = 0x07F9A54Dc5135B9878d6745E267625BF0E206840; // EVault for USDS
    address constant EWETH = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2; // EVault for WETH
    address constant EWBTC = 0x998D761eC1BAdaCeb064624cc3A1d37A46C88bA4; // EVault for WBTC

    // -- Tokens --
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // ========================================================================
    // PROXY ADDRESSES (use these for PoC)
    // ========================================================================

    // USDS token is behind a TransparentUpgradeableProxy
    // Implementation: 0x1923DFEe706a8E78157416C29CbCCfDe7cdF4102
    address constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

    // CoW Protocol AllowListAuthentication is behind a proxy
    // Implementation: 0x9E7aE8BDBa9aA346739792D219A808884996Db67
    address constant COW_AUTHENTICATOR = 0x2c4c28DDBdAc9C5E7055b4C863b72eA0149D8aFE;

    // ========================================================================
    // Common external tokens (if needed for PoC)
    // ========================================================================
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // ========================================================================
    // CoW Allow List Manager (for adding solvers in tests)
    // ========================================================================
    address constant ALLOW_LIST_MANAGER = 0xA03be496e67Ec29bC62F01a428683D7F9c204930;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function test_PoC() public {
        // Write your exploit / PoC here
    }

}
