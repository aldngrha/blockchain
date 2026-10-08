// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleStorage {
    // State
    uint256 private s_favoriteNumber;
    mapping(address => uint256) public s_addressToNumber;
    uint256 public s_numberCount;

    // Events
    event NumberChanged(address indexed user, uint256 newNumber);
    event NumberStored(address indexed user, uint256 number);

    // Struct
    struct Person {
        uint256 favoriteNumber;
        string name;
    }
    Person[] public s_listOfPeople;
    mapping(string => bool) public s_nameExists;

    // Functions
    function store(uint256 _favoriteNumber) public virtual {
        s_favoriteNumber = _favoriteNumber;
        s_addressToNumber[msg.sender] = _favoriteNumber;
        s_numberCount++;
        emit NumberStored(msg.sender, _favoriteNumber);
    }

    function retrieve() public view returns (uint256) {
        return s_favoriteNumber;
    }

    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        s_listOfPeople.push(Person(_favoriteNumber, _name));
        s_nameExists[_name] = true;
        emit NumberChanged(msg.sender, _favoriteNumber);
    }

    function getPersonCount() public view returns (uint256) {
        return s_listOfPeople.length;
    }

    function getPerson(uint256 _index) public view returns (string memory, uint256) {
        require(_index < s_listOfPeople.length, "Index out of bounds");
        Person storage person = s_listOfPeople[_index];
        return (person.name, person.favoriteNumber);
    }
}
