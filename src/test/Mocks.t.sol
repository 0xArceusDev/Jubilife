// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../CantoFarmer.sol";

contract MinterERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}
    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}

contract MockComptroller is IComptroller {
    MinterERC20 public rewards;
    constructor(address _r) public {
        rewards = MinterERC20(_r);
    }
    function claimComp(address owner, address[] calldata) public {
        rewards.mint(1e18);
        rewards.transfer(owner, 1e18);
    }
}

interface VM {
    // Set block.timestamp
    function warp(uint256) external;
}

contract ContractTest is DSTest {

    VM public vm;

    MinterERC20 public tReward;
    MinterERC20 public tAsset;
    CantoFarmer public farmer;
    MockComptroller public comp;

    function setUp() public {
        vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        tReward = new MinterERC20("test reward", "R", 18);
        tAsset = new MinterERC20("test asset", "A", 18);
        comp = new MockComptroller(address(tReward));
        farmer = new CantoFarmer(IComptroller(comp), tReward, tAsset, "test staking", "S");
    }

    function assertApproxEqual(
        uint256 expected,
        uint256 actual,
        uint256 tolerance
    ) public {
        uint256 leftBound = (expected * (1000 - tolerance)) / 1000;
        uint256 rightBound = (expected * (1000 + tolerance)) / 1000;
        assertTrue(leftBound <= actual && actual <= rightBound);
    }

    function testNewLot() public {
        tReward.mint(100e18);
        tReward.transfer(address(farmer), 100e18);
        farmer.newLot();
        (uint256 x, uint256 y, uint256 z, uint256 i) = farmer.lot();
        assertEq(x, 100e18);
        assertEq(y, block.timestamp);
        assertEq(z, 20e18);
        assertEq(i, 0);

        vm.warp(block.timestamp + 2 hours);
        uint256 price = farmer.price();

        assertApproxEqual(price, z/2, 1);

        vm.warp(block.timestamp + 1 hours);
        price = farmer.price();

        assertApproxEqual(price, z/4, 1);
        tAsset.mint(price * 100000000e18);
        tAsset.approve(address(farmer), 100000000e18);

        farmer.buy(1e18);
        (x,y,z,i) = farmer.lot();

        assertEq(x, 99e18);
        assertEq(tReward.balanceOf(address(this)), 1e18);
        assertEq(tAsset.balanceOf(address(farmer)), price);

        farmer.buy(99e18);
        (x,y,z,i) = farmer.lot();
        assertEq(x, 0);
        assertEq(i, price);

        tReward.mint(10e18);
        tReward.transfer(address(farmer), 10e18);
        farmer.newLot();

        (x,y,z,i) = farmer.lot();
        assertEq(x, 10e18);
        assertEq(y, block.timestamp);
        assertEq(z, price * 2);
        assertEq(i, 0);

        vm.warp(block.timestamp + 2 hours);

        price = farmer.price();
        assertApproxEqual(z/2, price, 1);
    }

    function testFail_lotNotOver() public {
        tReward.mint(100e18);
        tReward.transfer(address(farmer), 100e18);
        farmer.newLot();

        farmer.newLot();
    }

    function testFail_incorrectAmount() public {
        tReward.mint(100e18);
        tReward.transfer(address(farmer), 100e18);
        farmer.newLot();

        tAsset.mint(100000000e18);
        tAsset.approve(address(farmer), 100000000e18);

        farmer.buy(1e17);
    }

    function testFail_noNewLot() public {
        farmer.newLot();
    }

}
