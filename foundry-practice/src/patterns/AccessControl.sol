// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TokenWithRoles
 * @dev Implementasi Role-Based Access Control (RBAC) menggunakan standar OpenZeppelin.
 * Kontrak ini mendemonstrasikan cara memisahkan hak akses (seperti minting, burning, pausing)
 * ke berbagai entitas yang berbeda untuk meningkatkan keamanan.
 */
contract TokenWithRoles is AccessControl, Pausable {

    /// @notice Hash identitas untuk role pencetak token (Minting).
    bytes32 public constant MINTER_ROLE  = keccak256("MINTER_ROLE");
    
    /// @notice Hash identitas untuk role penghancur token (Burning).
    bytes32 public constant BURNER_ROLE  = keccak256("BURNER_ROLE");
    
    /// @notice Hash identitas untuk role pengendali jeda kontrak (Pausing).
    bytes32 public constant PAUSER_ROLE  = keccak256("PAUSER_ROLE");

    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    uint256 public maxSupply;

    /// @dev Diemitkan saat token baru dicetak.
    event Minted(address indexed to,   uint256 amount);
    /// @dev Diemitkan saat token dihancurkan.
    event Burned(address indexed from, uint256 amount);

    /// @dev Error jika pencetakan melebihi kapasitas maksimum.
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    /// @dev Error jika saldo tidak mencukupi untuk pembakaran.
    error InsufficientBalance(uint256 available, uint256 requested);

    /**
     * @notice Inisialisasi kontrak dengan batas pasokan token.
     * @param _maxSupply Batas maksimal token yang dapat dibuat seumur hidup kontrak.
     */
    constructor(uint256 _maxSupply) {
        maxSupply = _maxSupply;

        // DEFAULT_ADMIN_ROLE adalah admin utama yang bisa mengatur semua role lainnya.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Secara default, deployer diberikan semua hak akses untuk kemudahan setup awal.
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @notice Mencetak token baru ke alamat penerima.
     * @dev Syarat: Pemanggil harus memiliki MINTER_ROLE dan kontrak tidak dalam keadaan Pause.
     * @param _to Alamat dompet tujuan pengiriman token.
     * @param _amount Jumlah token yang ingin dicetak.
     */
    function mint(address _to, uint256 _amount)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        uint256 available = maxSupply - totalSupply;
        if (_amount > available) revert ExceedsMaxSupply(_amount, available);

        balances[_to] += _amount;
        totalSupply    += _amount;

        emit Minted(_to, _amount);
    }

    /**
     * @notice Menghancurkan token dari alamat tertentu.
     * @dev Syarat: Pemanggil harus memiliki BURNER_ROLE.
     * @param _from Alamat dompet yang tokennya akan dikurangi.
     * @param _amount Jumlah token yang akan dibakar.
     */
    function burn(address _from, uint256 _amount)
        public
        onlyRole(BURNER_ROLE)
    {
        if (balances[_from] < _amount) {
            revert InsufficientBalance(balances[_from], _amount);
        }

        balances[_from] -= _amount;
        totalSupply     -= _amount;

        emit Burned(_from, _amount);
    }

    /**
     * @notice Menghentikan sementara fungsi-fungsi sensitif (minting).
     * @dev Syarat: Pemanggil harus memiliki PAUSER_ROLE.
     */
    function pause() public onlyRole(PAUSER_ROLE) { _pause(); }

    /**
     * @notice Mengaktifkan kembali fungsi-fungsi kontrak.
     * @dev Syarat: Pemanggil harus memiliki PAUSER_ROLE.
     */
    function unpause() public onlyRole(PAUSER_ROLE) { _unpause(); }

    /**
     * @notice Menghitung sisa pasokan yang masih bisa dicetak.
     * @return Sisa unit token yang tersedia.
     */
    function remainingSupply() public view returns (uint256) {
        return maxSupply - totalSupply;
    }

    /**
     * @notice Fungsi pembantu untuk memverifikasi apakah akun memiliki akses minter.
     * @param _account Alamat yang akan diverifikasi.
     * @return true jika memiliki akses, false jika tidak.
     */
    function hasRoleMinter(address _account) public view returns (bool) {
        return hasRole(MINTER_ROLE, _account);
    }
}
