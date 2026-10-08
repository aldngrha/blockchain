// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Inheritance.sol";

contract InheritanceTest is Test {
    Animal public animal;
    Dog public dog;
    GuideDog public guideDog;

    function setUp() public {
        animal = new Animal("Generic");
        dog = new Dog("Buddy");
        guideDog = new GuideDog("Rex");
    }

    function test_Animal() public {
        assertEq(animal.name(), "Generic");
        assertEq(animal.speak(), "...");
        assertEq(animal.breathe(), "inhale... exhale...");
    }

    function test_Dog() public view {
        assertEq(dog.name(), "Buddy");
        assertEq(dog.speak(), "Woof!");
        assertEq(dog.breathe(), "inhale... exhale...");
        assertEq(dog.fetch(), "fetching ball...");
    }

    function test_GuideDog() public view {
        assertEq(guideDog.name(), "Rex");
        assertEq(guideDog.speak(), "Woof!");
        assertEq(guideDog.breathe(), "inhale... exhale...");
        assertEq(guideDog.fetch(), "fetching ball...");
        assertEq(guideDog.guide(), "guiding owner safely...");
    }
}
