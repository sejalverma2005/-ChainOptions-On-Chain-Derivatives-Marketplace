// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract ChainOptions {
    address public owner;

    enum OptionType { Call, Put }

    struct Option {
        address buyer;
        address seller;
        address asset;
        uint256 strikePrice;
        uint256 premium;
        uint256 expiry;
        uint256 amount;
        OptionType optionType;
        bool exercised;
    }

    uint256 public optionCounter;
    mapping(uint256 => Option) public options;

    event OptionCreated(uint256 indexed optionId, address indexed buyer, address indexed seller);
    event OptionExercised(uint256 indexed optionId, address exerciser);
    event OptionExpired(uint256 indexed optionId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createOption(
        address asset,
        uint256 strikePrice,
        uint256 premium,
        uint256 expiry,
        uint256 amount,
        OptionType optionType
    ) external returns (uint256) {
        require(expiry > block.timestamp, "Expiry must be in future");
        require(premium > 0 && amount > 0, "Invalid premium/amount");

        optionCounter++;
        options[optionCounter] = Option({
            buyer: msg.sender,
            seller: address(0),
            asset: asset,
            strikePrice: strikePrice,
            premium: premium,
            expiry: expiry,
            amount: amount,
            optionType: optionType,
            exercised: false
        });

        return optionCounter;
    }

    function sellOption(uint256 optionId) external {
        Option storage opt = options[optionId];
        require(opt.seller == address(0), "Already sold");
        require(opt.buyer != msg.sender, "Cannot sell to self");

        // Seller accepts and receives premium
        IERC20(opt.asset).transferFrom(msg.sender, address(this), opt.amount);
        IERC20(opt.asset).transfer(opt.seller, opt.premium);

        opt.seller = msg.sender;

        emit OptionCreated(optionId, opt.buyer, msg.sender);
    }

    function exerciseOption(uint256 optionId) external {
        Option storage opt = options[optionId];
        require(msg.sender == opt.buyer, "Not buyer");
        require(!opt.exercised, "Already exercised");
        require(block.timestamp <= opt.expiry, "Expired");

        opt.exercised = true;

        if (opt.optionType == OptionType.Call) {
            // Buyer pays strike price, receives asset
            IERC20(opt.asset).transferFrom(msg.sender, opt.seller, opt.strikePrice * opt.amount);
            IERC20(opt.asset).transfer(msg.sender, opt.amount);
        } else {
            // Buyer sends asset, receives strike price
            IERC20(opt.asset).transferFrom(msg.sender, opt.seller, opt.amount);
            IERC20(opt.asset).transfer(msg.sender, opt.strikePrice * opt.amount);
        }

        emit OptionExercised(optionId, msg.sender);
    }

    function expireOption(uint256 optionId) external {
        Option storage opt = options[optionId];
        require(block.timestamp > opt.expiry, "Not expired");
        require(!opt.exercised, "Already exercised");
        require(msg.sender == opt.seller || msg.sender == opt.buyer, "Not participant");

        opt.exercised = true;
        emit OptionExpired(optionId);
    }
}
