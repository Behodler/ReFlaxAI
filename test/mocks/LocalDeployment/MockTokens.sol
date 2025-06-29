// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function mint(address to, uint256 amount) external virtual {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external virtual {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract MockUSDC is MockERC20 {
    constructor() MockERC20("USD Coin", "USDC", 6, 1000000000 * 10**6) {}
}

contract MockUSDT is MockERC20 {
    constructor() MockERC20("Tether USD", "USDT", 6, 1000000000 * 10**6) {}
}

contract MockWETH is MockERC20 {
    constructor() MockERC20("Wrapped Ether", "WETH", 18, 1000000 * 10**18) {
        // WETH can be deposited/withdrawn
    }
    
    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(amount);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    receive() external payable {
        this.deposit();
    }
}

contract MockCRV is MockERC20 {
    constructor() MockERC20("Curve DAO Token", "CRV", 18, 3030303030 * 10**18) {}
}

contract MockCVX is MockERC20 {
    constructor() MockERC20("Convex Token", "CVX", 18, 100000000 * 10**18) {}
}

contract MockFlax is MockERC20 {
    constructor() MockERC20("Flax", "FLAX", 18, 100000000 * 10**18) {}
}

contract MockSFlax is MockERC20 {
    address public vault;
    
    constructor() MockERC20("Staked Flax", "sFlax", 18, 0) {}
    
    function setVault(address _vault) external {
        vault = _vault;
    }
    
    function burn(uint256 amount) external override {
        require(msg.sender == vault || balanceOf[msg.sender] >= amount, "Unauthorized or insufficient balance");
        
        if (msg.sender == vault) {
            // Vault can burn from any account with sufficient balance
            // This should be called after proper authorization in the vault
            require(totalSupply >= amount, "Insufficient total supply");
            totalSupply -= amount;
            emit Transfer(address(0), address(0), amount); // Burn event
        } else {
            // Direct burn from user
            require(balanceOf[msg.sender] >= amount, "Insufficient balance");
            balanceOf[msg.sender] -= amount;
            totalSupply -= amount;
            emit Transfer(msg.sender, address(0), amount);
        }
    }
    
    function burnFrom(address account, uint256 amount) external {
        require(msg.sender == vault, "Only vault can burn from accounts");
        require(balanceOf[account] >= amount, "Insufficient balance");
        
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}

contract MockCurveLP is MockERC20 {
    address public pool;
    
    constructor(string memory _name, string memory _symbol) 
        MockERC20(_name, _symbol, 18, 0) 
    {}
    
    function setPool(address _pool) external {
        pool = _pool;
    }
    
    function mint(address to, uint256 amount) external override {
        require(msg.sender == pool || pool == address(0), "Only pool can mint");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function burn(uint256 amount) external override {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}

// Contract to deploy all tokens at once
contract TokenDeployer {
    struct DeployedTokens {
        address usdc;
        address usdt;
        address weth;
        address crv;
        address cvx;
        address flax;
        address sFlax;
        address curveLP;
    }
    
    function deployAllTokens() external returns (DeployedTokens memory tokens) {
        tokens.usdc = address(new MockUSDC());
        tokens.usdt = address(new MockUSDT());
        tokens.weth = address(new MockWETH());
        tokens.crv = address(new MockCRV());
        tokens.cvx = address(new MockCVX());
        tokens.flax = address(new MockFlax());
        tokens.sFlax = address(new MockSFlax());
        tokens.curveLP = address(new MockCurveLP("Curve USDC/USDT LP", "crvUSDCUSDT"));
        
        return tokens;
    }
    
    function fundAccount(address token, address account, uint256 amount) external {
        MockERC20(token).mint(account, amount);
    }
    
    function fundAccountWithETH(address payable account, uint256 amount) external payable {
        require(msg.value >= amount, "Insufficient ETH sent");
        account.transfer(amount);
    }
}