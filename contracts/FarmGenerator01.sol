// SPDX-License-Identifier: UNLICENSED

// Ideally this contract should not be interacted with directly. Use our front end Dapp to create a farm
// to ensure the most effeicient amount of tokens are sent to the contract

pragma solidity 0.6.12;

import "./Farm01.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";

interface IERCBurn {
    function burn(uint256 _amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external returns (uint256);
}

interface FarmFactoryI {
    function registerFarm (address _farmAddress) external;
}

contract FarmGenerator01 is Ownable {
    using SafeMath for uint256;
    
    FarmFactoryI public factory;
    
    address payable devaddr;
    
    struct FeeStruct {
        IERCBurn gasToken;
        bool useGasToken; // set to false to waive the gas fee
        uint256 gasFee; // the total amount of gas tokens to be burnt (if used)
        uint256 ethFee; // Small eth fee to prevent spam on the platform
        uint256 tokenFee; // Divided by 1000, fee on farm rewards
    }
    
    FeeStruct public gFees;
    
    struct FarmParameters {
        uint256 fee;
        uint256 amountMinusFee;
        uint256 bonusBlocks;
        uint256 totalBonusReward;
        uint256 numBlocks;
        uint256 endBlock;
        uint256 requiredAmount;
        uint256 amountFee;
    }
    
    constructor(FarmFactoryI _factory) public {
        factory = _factory;
        devaddr = msg.sender;
        gFees.useGasToken = false;
        gFees.gasFee = 1 * (10 ** 18);
        gFees.ethFee = 2e17;
        gFees.tokenFee = 10; // 1%
    }
    
    /**
     * @notice Below are self descriptive gas fee and general settings functions
     */
    function setGasToken (IERCBurn _gasToken) public onlyOwner {
        gFees.gasToken = _gasToken;
    }
    
    function setGasFee (uint256 _amount) public onlyOwner {
        gFees.gasFee = _amount;
    }
    
    function setEthFee (uint256 _amount) public onlyOwner {
        gFees.ethFee = _amount;
    }
    
    function setTokenFee (uint256 _amount) public onlyOwner {
        gFees.tokenFee = _amount;
    }
    
    function setRequireGasToken (bool _useGasToken) public onlyOwner {
        gFees.useGasToken = _useGasToken;
    }
    
    function setDev(address payable _devaddr) public onlyOwner {
        devaddr = _devaddr;
    }
    
    /**
     * @notice Determine the endBlock based on inputs. Used on the front end to show the exact settings the Farm contract will be deployed with
     */
    function determineEndBlock (uint256 _amount, uint256 _blockReward, uint256 _startBlock, uint256 _bonusEndBlock, uint256 _bonus) public view returns (uint256, uint256, uint256) {
        FarmParameters memory params;
        params.fee = _amount.mul(gFees.tokenFee).div(1000);
        params.amountMinusFee = _amount.sub(params.fee);
        params.bonusBlocks = _bonusEndBlock.sub(_startBlock);
        params.totalBonusReward = params.bonusBlocks.mul(_bonus).mul(_blockReward);
        params.numBlocks = params.amountMinusFee.sub(params.totalBonusReward).div(_blockReward);
        params.endBlock = params.numBlocks.add(params.bonusBlocks).add(_startBlock);
        
        uint256 nonBonusBlocks = params.endBlock.sub(_bonusEndBlock);
        uint256 effectiveBlocks = params.bonusBlocks.mul(_bonus).add(nonBonusBlocks);
        uint256 requiredAmount = _blockReward.mul(effectiveBlocks);
        return (params.endBlock, requiredAmount, requiredAmount.mul(gFees.tokenFee).div(1000));
    }
    
    /**
     * @notice Determine the blockReward based on inputs specifying an end date. Used on the front end to show the exact settings the Farm contract will be deployed with
     */
    function determineBlockReward (uint256 _amount, uint256 _startBlock, uint256 _bonusEndBlock, uint256 _bonus, uint256 _endBlock) public view returns (uint256, uint256, uint256) {
        uint256 fee = _amount.mul(gFees.tokenFee).div(1000);
        uint256 amountMinusFee = _amount.sub(fee);
        uint256 bonusBlocks = _bonusEndBlock.sub(_startBlock);
        uint256 nonBonusBlocks = _endBlock.sub(_bonusEndBlock);
        uint256 effectiveBlocks = bonusBlocks.mul(_bonus).add(nonBonusBlocks);
        uint256 blockReward = amountMinusFee.div(effectiveBlocks);
        uint256 requiredAmount = blockReward.mul(effectiveBlocks);
        return (blockReward, requiredAmount, requiredAmount.mul(gFees.tokenFee).div(1000));
    }
    
    /**
     * @notice Creates a new Farm contract and registers it in the FarmFactory.sol. All farming rewards are locked in the Farm Contract
     */
    function createFarm (IERC20 _rewardToken, uint256 _amount, IERC20 _farmToken, uint256 _blockReward, uint256 _startBlock, uint256 _bonusEndBlock, uint256 _bonus) public payable returns (address) {
        require(_startBlock > block.number, 'START'); // ideally at least 24 hours more to give farmers time
        require(_bonus > 0, 'BONUS');
        require(address(_rewardToken) != address(0), '_rewardToken');
        require(address(_farmToken) != address(0), '_farmToken');
        require(_blockReward > 1000, 'BR'); // minimum 1000 divisibility per block reward
        
        // sanity check
        _farmToken.totalSupply();

        FarmParameters memory params;
        (params.endBlock, params.requiredAmount, params.amountFee) = determineEndBlock(_amount, _blockReward, _startBlock, _bonusEndBlock, _bonus);
        
        require(msg.value == gFees.ethFee, 'Fee not met');
        devaddr.transfer(msg.value);
        
        if (gFees.useGasToken) {
            TransferHelper.safeTransferFrom(address(gFees.gasToken), address(msg.sender), address(this), gFees.gasFee);
            gFees.gasToken.burn(gFees.gasFee);
        }
        
        TransferHelper.safeTransferFrom(address(_rewardToken), address(msg.sender), address(this), params.requiredAmount.add(params.amountFee));
        Farm01 newFarm = new Farm01(address(factory), address(this));
        TransferHelper.safeApprove(address(_rewardToken), address(newFarm), params.requiredAmount);
        newFarm.init(_rewardToken, params.requiredAmount, _farmToken, _blockReward, _startBlock, params.endBlock, _bonusEndBlock, _bonus);
        
        TransferHelper.safeTransfer(address(_rewardToken), devaddr, params.amountFee);
        factory.registerFarm(address(newFarm));
        return (address(newFarm));
    }
    
}