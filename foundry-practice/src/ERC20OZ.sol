// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Import library standar industri dari OpenZeppelin
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";

/**
 * @title AldiToken (OpenZeppelin version)
 * @dev Kontrak token profesional yang mewarisi berbagai fitur keamanan OpenZeppelin.
 */
contract AldiToken is ERC20, ERC20Burnable, Ownable, Pausable {
    // Batas maksimal koin yang boleh diciptakan seumur hidup
    uint256 public maxSupply;

    // Event untuk mencatat perubahan batas supply
    event MaxSupplyUpdated(uint256 oldMax, uint256 newMax);

    // Custom Error untuk efisiensi gas saat melebihi batas supply
    error ExceedsMaxSupply(uint256 requested, uint256 available);

    /**
     * @dev Constructor menginisialisasi nama, simbol, dan jatah awal.
     * Ownable(msg.sender) menetapkan pen-deploy sebagai pemilik (Owner).
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _maxSupply
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        // decimals() mengembalikan angka 18 secara default di OpenZeppelin
        maxSupply = _maxSupply * 10 ** decimals();
        _mint(msg.sender, _initialSupply * 10 ** decimals());
    }

    /**
     * @dev Mencetak token baru (Hanya Owner).
     * Ada pengecekan agar tidak melampaui maxSupply.
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        uint256 available = maxSupply - totalSupply();
        if(_amount > available) {
          revert ExceedsMaxSupply(_amount, available);
        }
        _mint(_to, _amount);
    }

    /**
     * @dev Fungsi internal _update() adalah inti dari OpenZeppelin v5.x.
     * Semua transfer, mint, dan burn akan melewati fungsi ini.
     * Kita tambahkan modifier 'whenNotPaused' agar semua aktivitas token berhenti saat jeda.
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    /**
     * @dev Menghentikan semua aktivitas transfer/mint/burn (Hanya Owner).
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Mengaktifkan kembali aktivitas token (Hanya Owner).
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Mengubah batas maksimal supply (Hanya Owner).
     * Tidak boleh lebih rendah dari jumlah token yang sudah beredar saat ini.
     */
    function updateMaxSupply(uint256 _newMax) public onlyOwner {
        uint256 newMaxWei = _newMax * 10 ** decimals();
        require(newMaxWei >= totalSupply(), 'Below current supply');

        emit MaxSupplyUpdated(maxSupply, newMaxWei);
        maxSupply = newMaxWei;
    }
}
