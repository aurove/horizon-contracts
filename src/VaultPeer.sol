// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IVaultPeer} from "./interfaces/IVaultPeer.sol";

/// @title VaultPeer
/// @notice Mintable ERC-20 representation of a Horizon vault share on a Wormhole NTT spoke.
/// @dev The NTT Manager is the only account that can mint or burn. Users burn by bridging through
///      the manager; there is no public burn function that could break hub/spoke supply accounting.
contract VaultPeer is ERC20, Ownable, IVaultPeer {
    address public minter;

    /// @param name_ ERC-20 name matching the canonical Mezo vault share.
    /// @param symbol_ ERC-20 symbol matching the canonical Mezo vault share.
    /// @param initialOwner_ Temporary setup authority that sets the NTT Manager minter once.
    constructor(string memory name_, string memory symbol_, address initialOwner_)
        ERC20(name_, symbol_)
        Ownable(initialOwner_)
    {}

    /// @inheritdoc IVaultPeer
    /// @dev This is a one-time handoff. Ownership is renounced in the same transaction, so no
    ///      account can replace the NTT Manager or regain token administration afterward.
    function setMinter(address newMinter) external {
        if (minter != address(0)) revert MinterAlreadySet();
        _checkOwner();
        if (newMinter == address(0)) revert InvalidMinterZeroAddress();

        minter = newMinter;
        emit NewMinter(address(0), newMinter);
        _transferOwnership(address(0));
    }

    /// @inheritdoc IVaultPeer
    function mint(address account, uint256 amount) external onlyMinter {
        _mint(account, amount);
    }

    /// @inheritdoc IVaultPeer
    function burn(uint256 amount) external onlyMinter {
        _burn(msg.sender, amount);
    }

    modifier onlyMinter() {
        if (msg.sender != minter) revert CallerNotMinter(msg.sender);
        _;
    }
}
