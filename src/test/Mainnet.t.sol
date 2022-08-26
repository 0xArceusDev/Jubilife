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

interface VM {
    // Set block.timestamp
    function warp(uint256) external;
    function prank(address) external;
}

contract MainnetTest is DSTest {

    VM public vm;

    ERC20 public reward = ERC20(0x826551890Dc65655a0Aceca109aB11AbDbD7a07B);
    ERC20 public asset = ERC20(0x3C96dCfd875253A37acB3D2B102b6f328349b16B);
    CantoFarmer public farmer;

    function setUp() public {
        vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        farmer = new CantoFarmer(IComptroller(0x5E23dC409Fc2F832f83CEc191E245A191a4bCc5C), reward, asset, "test staking", "S");
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

    function test_integration() public {
        vm.prank(0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA);
        asset.approve(address(farmer), 100000e18);
        vm.prank(0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA);
        farmer.deposit(100, address(0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA));
        vm.warp(block.timestamp + 1 days);
        farmer.claimWCanto();
        vm.prank(0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA);
        asset.transfer(address(farmer), 100);
        assertEq(farmer.maxWithdraw(0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA), 200);
        vm.prank(0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA);
        farmer.redeem(100, 0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA, 0x3B7E4C109c6c9c7f409AECC4eF9cd8864DAa0CDA);
    }
    
}
