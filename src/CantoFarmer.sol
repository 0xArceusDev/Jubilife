// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "solmate/mixins/ERC4626.sol";

interface ICToken {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
}

interface IComptroller {
    function claimComp(address owner, address[] calldata ctokens) external;
}

contract CantoFarmer is ERC4626 {

    event NewLot(uint256 amount, uint256 startTime, uint256 startPrice);
    event Buy(address indexed buyer, uint256 amount, uint256 paid);

    ERC20 public immutable reward;
    ICToken public immutable ctoken;
    IComptroller public immutable comptroller;

    struct Lot {
        uint256 amount;
        uint256 startTime;
        uint256 startPrice;
        uint256 clearingPrice;
    }

    Lot public lot;

    constructor(
        IComptroller _comp,
        ERC20 _reward,
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) 
        ERC4626(_asset, _name, _symbol) 
    {
        comptroller = _comp;
        reward = _reward;
        ctoken = ICToken(address(_asset));
        lot.clearingPrice = 10e18;
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function beforeWithdraw(uint256, uint256) internal override {}

    function afterDeposit(uint256, uint256) internal override {}

    function newLot() public {
        require(reward.balanceOf(address(this)) >= 1e18, "too smmall");
        require(lot.amount == 0, "still another lot");

        lot.amount = reward.balanceOf(address(this)) - (reward.balanceOf(address(this)) % 1e18);
        lot.startTime = block.timestamp;
        lot.startPrice = lot.clearingPrice == 0 ? 100e18 : lot.clearingPrice * 2;
        lot.clearingPrice = 0;

        emit NewLot(lot.amount, lot.startTime, lot.startPrice);
    }

    function buy(uint256 _amount) public {
        require(_amount % 1e18 == 0, "must buy full numbers");
        require(lot.amount >= _amount, "buying too much");
        uint256 due = price() * _amount / 1e18;
        asset.transferFrom(msg.sender, address(this), due);
        reward.transfer(msg.sender, _amount);
        lot.amount -= _amount;
        if (lot.amount == 0) {
            lot.clearingPrice = price();
        }

        emit Buy(msg.sender, _amount, due);
    }

    function price() public view returns(uint256 price) {
        uint256 decayRate = lot.startPrice / 4 hours;
        price = lot.startPrice - (decayRate * (block.timestamp - lot.startTime));
    }

    function claimWCanto() public {
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(asset);
        comptroller.claimComp(address(this), cTokens);
    }

}
