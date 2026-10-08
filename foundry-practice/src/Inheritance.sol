// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Inheritance (Pewarisan)
 * @dev Belajar cara menurunkan sifat kontrak ke kontrak lain.
 * Konsep: Virtual, Override, dan Parent-Child relationship.
 */

contract Animal {
    string public name;

    constructor(string memory _name) {
        name = _name;
    }

    // virtual = fungsi ini BOLEH diubah (di-override) oleh kontrak anaknya.
    function speak() public virtual returns (string memory) {
        return "...";
    }

    // pure = fungsi ini tidak baca data 'name', cuma balikin teks statis.
    function breathe() public pure returns (string memory) {
        return "inhale... exhale...";
    }
}

/**
 * @dev Dog mewarisi (is) Animal.
 */
contract Dog is Animal {
    // Memanggil constructor parent (Animal) dengan 'Animal(_name)'
    constructor(string memory _name) Animal(_name) {}

    // override = fungsi ini menggantikan logika speak() milik Animal.
    function speak() public pure override returns (string memory) {
        return "Woof!";
    }

    function fetch() public pure returns (string memory) {
        return "fetching ball...";
    }
}

/**
 * @dev GuideDog mewarisi Dog (artinya dia punya sifat Dog dan Animal sekaligus).
 */
contract GuideDog is Dog {
    constructor(string memory _name) Dog(_name) {}

    function guide() public pure returns (string memory) {
        return "guiding owner safely...";
    }
}
