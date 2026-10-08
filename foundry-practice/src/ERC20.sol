// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title AldiToken (ERC20 Standard)
 * @dev Implementasi standar token ERC20 dengan fitur tambahan Mint & Burn.
 * Menggunakan Custom Errors untuk penghematan Gas yang signifikan.
 */
contract ERC20 {
    // --- State Variables (Data yang disimpan di Blockchain) ---

    string  public name;     // Nama Token (contoh: AldiToken)
    string  public symbol;   // Simbol Token (contoh: ALDI)
    uint8   public decimals = 18; // Standar desimal (18 angka di belakang koma, seperti ETH)
    uint256 public totalSupply;   // Total koin yang beredar di seluruh dunia

    address public owner;    // Pemilik kontrak (yang punya hak akses mint)

    // Buku besar (Ledger): Mapping dari Alamat Dompet ke Jumlah Saldo
    mapping(address => uint256) public balances;

    // Izin Pengeluaran: Owner memberi izin ke Spender (misal: DEX) untuk memakai koinnya
    // Struktur: Owner -> Spender -> Jumlah Izin
    mapping(address => mapping(address => uint256)) public allowances;

    // --- Events (Log aktivitas yang bisa dibaca oleh UI/Frontend) ---

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // --- Custom Errors (Hemat Gas dibandingkan string require) ---

    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error NotOwner(address caller);

    // --- Modifiers (Filter fungsi) ---

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    /**
     * @dev Constructor dijalankan sekali saat deploy.
     * @param _initialSupply Jumlah token awal (dalam unit besar, akan dikali 10^18).
     */
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name   = _name;
        symbol = _symbol;
        owner  = msg.sender;
        // Kita langsung buatkan token awal untuk si pembuat kontrak
        mint(msg.sender, _initialSupply * 10 ** decimals);
    }

    /**
     * @dev Fungsi cek saldo (Read-only).
     */
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    /**
     * @dev Kirim token dari dompet sendiri ke dompet lain.
     */
    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Beri izin ke pihak lain (spender) untuk membelanjakan token kita.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Cek sisa izin yang diberikan owner ke spender.
     */
    function allowance(address _owner, address spender) public view returns (uint256) {
        return allowances[_owner][spender];
    }

    /**
     * @dev Fungsi kirim token oleh pihak ketiga (yang sudah di-approve).
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];

        // Cek apakah izinnya cukup?
        if (currentAllowance < amount) {
            revert InsufficientAllowance(currentAllowance, amount);
        }

        // Update sisa izin (kurangi)
        allowances[from][msg.sender] -= amount;

        // Jalankan transfer inti
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Logika transfer internal (private) agar tidak duplikasi kode.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        if (balances[from] < amount) {
            revert InsufficientBalance(balances[from], amount);
        }

        balances[from] -= amount;
        balances[to]   += amount;

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Tambah token baru (Hanya Owner).
     */
    function mint(address to, uint256 amount) public onlyOwner {
        totalSupply += amount;
        balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev Musnahkan token dari dompet sendiri.
     */
    function burn(uint256 amount) public {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(balances[msg.sender], amount);
        }

        totalSupply -= amount;
        balances[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
