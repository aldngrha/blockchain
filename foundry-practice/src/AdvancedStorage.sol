// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title AdvancedStorage
 * @dev Belajar struktur data kompleks: Struct dan Mapping dari Mapping.
 */
contract AdvancedStorage {
    address public owner;
    bool    public paused;
    uint256 public entryCount;

    // Struct = Tipe data buatan sendiri (objek) yang mengelompokkan beberapa variabel.
    struct Entry {
        uint256 id;
        string  data;
        address creator;
        uint256 timestamp;
    }

    // Mapping = Kamus (Key-Value pair).
    // uint256 (ID) -> Entry (Data Objek)
    mapping(uint256 => Entry)    public entries;

    // Mapping ke Array: address -> Daftar ID yang pernah dibuat user ini
    mapping(address => uint256[]) public userEntries;

    // Indexed parameter di Event memudahkan pencarian (filter) data di sisi frontend.
    event EntryCreated(uint256 indexed id, address indexed creator, string data);
    event EntryDeleted(uint256 indexed id, address indexed deletedBy);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    // Custom Error untuk efisiensi Gas
    error NotOwner(address caller);
    error NotCreator(address caller, uint256 entryId);
    error ContractIsPaused();
    error EmptyData();
    error EntryNotFound(uint256 id);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractIsPaused();
        _;
    }

    // Modifier dengan parameter: Cek apakah data ada sebelum diproses
    modifier entryExists(uint256 _id) {
        if (entries[_id].creator == address(0)) revert EntryNotFound(_id);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Membuat entry baru.
     * Menggunakan block.timestamp untuk mencatat waktu (detik sejak 1 Jan 1970).
     */
    function createEntry(string memory _data) public whenNotPaused {
        if (bytes(_data).length == 0) revert EmptyData();

        uint256 newId = ++entryCount;

        // Mengisi Struct Entry
        entries[newId] = Entry({
            id: newId,
            data: _data,
            creator: msg.sender,
            timestamp: block.timestamp
        });

        // Simpan ID ke daftar milik user
        userEntries[msg.sender].push(newId);

        emit EntryCreated(newId, msg.sender, _data);
    }

    /**
     * @dev Menghapus entry.
     * Hanya boleh dilakukan oleh Creator asli atau Owner kontrak.
     */
    function deleteEntry(uint256 _id) public entryExists(_id) {
        if (entries[_id].creator != msg.sender && msg.sender != owner) {
            revert NotCreator(msg.sender, _id);
        }

        emit EntryDeleted(_id, msg.sender);

        // 'delete' mengosongkan data (reset ke default value), bukan menghapus slot memorinya.
        delete entries[_id];
    }

    // memory = data ini disalin ke RAM sementara (tidak permanen di blockchain)
    function getEntry(uint256 _id) public view entryExists(_id) returns (Entry memory) {
        return entries[_id];
    }

    function getUserEntries(address _user) public view returns (uint256[] memory) {
        return userEntries[_user];
    }

    function pause() public onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }
}
