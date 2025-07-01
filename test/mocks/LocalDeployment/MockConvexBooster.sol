// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import "./IMockERC20.sol";

contract MockConvexBooster {
    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    PoolInfo[] public poolInfo;
    mapping(uint256 => address) public rewardPools;
    mapping(address => uint256) public lpTokenToPid;
    
    // Booster state
    bool public isShutdown = false;
    uint256 public lockIncentive = 825; // 8.25%
    uint256 public stakerIncentive = 825; // 8.25%
    uint256 public earmarkIncentive = 50; // 0.5%
    uint256 public platformFee = 0; // 0%
    uint256 public constant MaxFees = 2000; // 20%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    address public owner;
    address public feeManager;
    address public poolManager;
    address public immutable crv;
    address public immutable minter;
    
    event Deposited(address indexed user, uint256 indexed poolid, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed poolid, uint256 amount);

    constructor(address _crv, address _minter) {
        crv = _crv;
        minter = _minter;
        owner = msg.sender;
        feeManager = msg.sender;
        poolManager = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!auth");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function addPool(
        address _lptoken,
        address _gauge,
        uint256 _stashVersion
    ) external returns (bool) {
        require(msg.sender == poolManager, "!auth");
        require(!isShutdown, "shutdown");
        
        // Create reward pool
        address rewardPool = address(new MockConvexRewardPool(_lptoken, crv, address(this)));
        
        // Add pool info
        poolInfo.push(PoolInfo({
            lptoken: _lptoken,
            token: _lptoken, // Simplified: token == lptoken
            gauge: _gauge,
            crvRewards: rewardPool,
            stash: address(0), // Simplified: no stash
            shutdown: false
        }));
        
        uint256 pid = poolInfo.length - 1;
        rewardPools[pid] = rewardPool;
        lpTokenToPid[_lptoken] = pid;
        
        return true;
    }

    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns (bool) {
        require(!isShutdown, "shutdown");
        require(_pid < poolInfo.length, "invalid pool");
        
        PoolInfo storage pool = poolInfo[_pid];
        require(!pool.shutdown, "pool is closed");
        
        // Transfer LP token from user
        IERC20(pool.lptoken).transferFrom(msg.sender, address(this), _amount);
        
        if (_stake) {
            // Stake in reward pool
            address rewardPool = rewardPools[_pid];
            IERC20(pool.lptoken).approve(rewardPool, _amount);
            MockConvexRewardPool(rewardPool).stake(msg.sender, _amount);
        } else {
            // Just hold the tokens
            // In real Convex, this would deposit to Curve gauge
        }
        
        emit Deposited(msg.sender, _pid, _amount);
        return true;
    }

    function depositAll(uint256 _pid, bool _stake) external returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 balance = IERC20(pool.lptoken).balanceOf(msg.sender);
        return this.deposit(_pid, balance, _stake);
    }

    function withdraw(uint256 _pid, uint256 _amount) external returns (bool) {
        require(_pid < poolInfo.length, "invalid pool");
        
        PoolInfo storage pool = poolInfo[_pid];
        address rewardPool = rewardPools[_pid];
        
        // Withdraw from reward pool
        MockConvexRewardPool(rewardPool).withdraw(msg.sender, _amount);
        
        // Transfer LP token back to user
        IERC20(pool.lptoken).transfer(msg.sender, _amount);
        
        emit Withdrawn(msg.sender, _pid, _amount);
        return true;
    }

    function withdrawAll(uint256 _pid) external returns (bool) {
        address rewardPool = rewardPools[_pid];
        uint256 balance = MockConvexRewardPool(rewardPool).balanceOf(msg.sender);
        return this.withdraw(_pid, balance);
    }

    function earmarkRewards(uint256 _pid) external returns (bool) {
        require(_pid < poolInfo.length, "invalid pool");
        
        // Simplified: just mint some CRV as rewards
        // In real Convex, this would claim from Curve gauge and distribute
        uint256 rewardAmount = 1000 * 1e18; // 1000 CRV
        IMockERC20(crv).mint(address(this), rewardAmount);
        
        // Distribute to reward pool
        address rewardPool = rewardPools[_pid];
        IERC20(crv).transfer(rewardPool, rewardAmount);
        MockConvexRewardPool(rewardPool).queueNewRewards(rewardAmount);
        
        return true;
    }

    function shutdownPool(uint256 _pid) external onlyOwner returns (bool) {
        require(_pid < poolInfo.length, "invalid pool");
        poolInfo[_pid].shutdown = true;
        return true;
    }

    function shutdownSystem() external onlyOwner {
        isShutdown = true;
    }

    // Fee management
    function setFees(
        uint256 _lockFees,
        uint256 _stakerFees,
        uint256 _callerFees,
        uint256 _platform
    ) external {
        require(msg.sender == feeManager, "!auth");
        
        uint256 total = _lockFees + _stakerFees + _callerFees + _platform;
        require(total <= MaxFees, "!>MaxFees");
        
        lockIncentive = _lockFees;
        stakerIncentive = _stakerFees;
        earmarkIncentive = _callerFees;
        platformFee = _platform;
    }

    // View functions
    function getPoolInfo(uint256 _pid) external view returns (PoolInfo memory) {
        return poolInfo[_pid];
    }

    function isValidPool(address _lpToken) external view returns (bool) {
        uint256 pid = lpTokenToPid[_lpToken];
        return pid < poolInfo.length && poolInfo[pid].lptoken == _lpToken;
    }
}

contract MockConvexRewardPool {
    using SafeMath for uint256;
    
    address public immutable rewardToken;
    address public immutable stakingToken;
    address public immutable booster;
    
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    uint256 public constant newRewardRatio = 830;
    uint256 private _totalSupply = 0;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;
    
    // Additional reward tokens (CVX, etc.)
    address[] public extraRewards;
    
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _stakingToken,
        address _rewardToken,
        address _booster
    ) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        booster = _booster;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function stake(address _account, uint256 _amount) external updateReward(_account) {
        require(msg.sender == booster, "!authorized");
        require(_amount > 0, "RewardPool : Cannot stake 0");
        
        _totalSupply = _totalSupply.add(_amount);
        _balances[_account] = _balances[_account].add(_amount);
        
        emit Staked(_account, _amount);
    }

    function withdraw(address _account, uint256 _amount) external updateReward(_account) {
        require(msg.sender == booster, "!authorized");
        require(_amount > 0, "RewardPool : Cannot withdraw 0");
        
        _totalSupply = _totalSupply.sub(_amount);
        _balances[_account] = _balances[_account].sub(_amount);
        
        emit Withdrawn(_account, _amount);
    }

    function getReward() external updateReward(msg.sender) returns (bool) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20(rewardToken).transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
        
        // Get rewards from extra reward pools
        for (uint256 i = 0; i < extraRewards.length; i++) {
            MockExtraRewardPool(extraRewards[i]).getReward(msg.sender);
        }
        
        return true;
    }

    function queueNewRewards(uint256 _rewards) external returns (bool) {
        require(msg.sender == booster, "!authorized");
        
        _rewards = _rewards.add(queuedRewards);
        
        if (block.timestamp >= periodFinish) {
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
            return true;
        }
        
        uint256 elapsedTime = periodFinish.sub(block.timestamp);
        uint256 currentAtNow = rewardRate.mul(elapsedTime);
        uint256 queuedRatio = currentAtNow.mul(1000).div(_rewards);
        
        if (queuedRatio < newRewardRatio) {
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
        } else {
            queuedRewards = _rewards;
        }
        
        return true;
    }

    function notifyRewardAmount(uint256 reward) internal updateReward(address(0)) {
        historicalRewards = historicalRewards.add(reward);
        
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(7 days);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            reward = reward.add(leftover);
            rewardRate = reward.div(7 days);
        }
        
        currentRewards = reward;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(7 days);
        emit RewardAdded(reward);
    }

    function addExtraReward(address _reward) external {
        require(msg.sender == booster, "!authorized");
        extraRewards.push(_reward);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
}

contract MockExtraRewardPool {
    address public rewardToken;
    address public mainRewardPool;
    uint256 public rewardRate = 0;
    uint256 public periodFinish = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    
    constructor(address _rewardToken, address _mainPool) {
        rewardToken = _rewardToken;
        mainRewardPool = _mainPool;
    }

    function getReward(address _account) external {
        // Simplified extra reward distribution
        uint256 balance = MockConvexRewardPool(mainRewardPool).balanceOf(_account);
        if (balance > 0) {
            uint256 reward = balance / 100; // 1% of staked amount
            IMockERC20(rewardToken).mint(_account, reward);
        }
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}