// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import "./IMockERC20.sol";

contract MockCurvePool {
    address public lpToken;
    address[] public coins_array;
    uint256[] public balances_array;
    uint256 public numTokens;
    
    // Pool parameters
    uint256 public feeRate = 4; // 0.04% fee in basis points (4/10000)
    uint256 public adminFeeRate = 5000; // 50% of fees go to admin
    uint256 public A = 2000; // Amplification coefficient
    
    // Pool state
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    // Events
    event AddLiquidity(address indexed provider, uint256[4] token_amounts, uint256[4] fees, uint256 invariant, uint256 token_supply);
    event RemoveLiquidity(address indexed provider, uint256[4] token_amounts, uint256 token_supply);
    event RemoveLiquidityOne(address indexed provider, uint256 token_amount, uint256 coin_amount);

    constructor(address _lpToken, address[] memory _coins) {
        lpToken = _lpToken;
        coins_array = _coins;
        numTokens = _coins.length;
        
        // Initialize balances
        for (uint256 i = 0; i < numTokens; i++) {
            balances_array.push(0);
        }
    }

    function coins(uint256 i) external view returns (address) {
        if (i < coins_array.length) {
            return coins_array[i];
        }
        return address(0);
    }

    function balances(uint256 i) external view returns (uint256) {
        if (i < balances_array.length) {
            return balances_array[i];
        }
        return 0;
    }

    function get_virtual_price() external view returns (uint256) {
        if (totalSupply == 0) return 1e18;
        
        uint256 total_balance = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            total_balance += balances_array[i];
        }
        
        return (total_balance * 1e18) / totalSupply;
    }

    // Calculate the invariant (D) - simplified StableSwap invariant
    function get_D(uint256[4] memory xp, uint256 amp) internal pure returns (uint256) {
        uint256 S = 0;
        uint256 _x = 0;
        for (uint256 i = 0; i < 4; i++) {
            S += xp[i];
            if (xp[i] == 0) return 0;
        }
        if (S == 0) return 0;

        uint256 Dprev = 0;
        uint256 D = S;
        uint256 Ann = amp * 4;
        
        for (uint256 j = 0; j < 255; j++) {
            uint256 D_P = D;
            for (uint256 k = 0; k < 4; k++) {
                if (xp[k] > 0) {
                    D_P = D_P * D / (xp[k] * 4);
                }
            }
            Dprev = D;
            D = (Ann * S + D_P * 4) * D / ((Ann - 1) * D + 5 * D_P);
            
            if (D > Dprev) {
                if (D - Dprev <= 1) break;
            } else {
                if (Dprev - D <= 1) break;
            }
        }
        return D;
    }

    function _xp_mem(uint256[4] memory _balances) internal pure returns (uint256[4] memory result) {
        // For stable pools, we assume all tokens have the same precision
        result = _balances;
    }

    function calc_token_amount(uint256[2] calldata amounts, bool is_deposit) external view returns (uint256) {
        require(numTokens == 2, "Wrong number of tokens");
        uint256[4] memory _amounts;
        _amounts[0] = amounts[0];
        _amounts[1] = amounts[1];
        return _calc_token_amount(_amounts, is_deposit);
    }

    function calc_token_amount(uint256[3] calldata amounts, bool is_deposit) external view returns (uint256) {
        require(numTokens == 3, "Wrong number of tokens");
        uint256[4] memory _amounts;
        _amounts[0] = amounts[0];
        _amounts[1] = amounts[1];
        _amounts[2] = amounts[2];
        return _calc_token_amount(_amounts, is_deposit);
    }

    function calc_token_amount(uint256[4] calldata amounts, bool is_deposit) external view returns (uint256) {
        require(numTokens == 4, "Wrong number of tokens");
        return _calc_token_amount(amounts, is_deposit);
    }

    function _calc_token_amount(uint256[4] memory amounts, bool is_deposit) internal view returns (uint256) {
        uint256[4] memory _balances;
        for (uint256 i = 0; i < numTokens; i++) {
            _balances[i] = balances_array[i];
        }
        
        uint256[4] memory old_balances = _xp_mem(_balances);
        uint256 D0 = get_D(old_balances, A);
        
        for (uint256 i = 0; i < numTokens; i++) {
            if (is_deposit) {
                _balances[i] += amounts[i];
            } else {
                _balances[i] -= amounts[i];
            }
        }
        
        uint256[4] memory new_balances = _xp_mem(_balances);
        uint256 D1 = get_D(new_balances, A);
        
        uint256 token_amount = 0;
        if (totalSupply == 0) {
            token_amount = D1;
        } else {
            if (is_deposit) {
                token_amount = totalSupply * (D1 - D0) / D0;
            } else {
                token_amount = totalSupply * (D0 - D1) / D0;
            }
        }
        
        return token_amount;
    }

    // Add liquidity functions for different pool sizes
    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount) external returns (uint256) {
        require(numTokens == 2, "Wrong number of tokens");
        uint256[4] memory _amounts;
        _amounts[0] = amounts[0];
        _amounts[1] = amounts[1];
        return _add_liquidity(_amounts, min_mint_amount);
    }

    function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount) external returns (uint256) {
        require(numTokens == 3, "Wrong number of tokens");
        uint256[4] memory _amounts;
        _amounts[0] = amounts[0];
        _amounts[1] = amounts[1];
        _amounts[2] = amounts[2];
        return _add_liquidity(_amounts, min_mint_amount);
    }

    function add_liquidity(uint256[4] calldata amounts, uint256 min_mint_amount) external returns (uint256) {
        require(numTokens == 4, "Wrong number of tokens");
        return _add_liquidity(amounts, min_mint_amount);
    }

    function _add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) internal returns (uint256) {
        uint256[4] memory fees;
        uint256[4] memory old_balances;
        
        for (uint256 i = 0; i < numTokens; i++) {
            old_balances[i] = balances_array[i];
        }
        
        // Calculate D0
        uint256[4] memory old_balances_xp = _xp_mem(old_balances);
        uint256 D0 = get_D(old_balances_xp, A);
        
        // Transfer tokens from user
        for (uint256 i = 0; i < numTokens; i++) {
            if (amounts[i] > 0) {
                IERC20(coins_array[i]).transferFrom(msg.sender, address(this), amounts[i]);
                balances_array[i] += amounts[i];
            }
        }
        
        // Calculate D1
        uint256[4] memory new_balances;
        for (uint256 i = 0; i < numTokens; i++) {
            new_balances[i] = balances_array[i];
        }
        uint256[4] memory new_balances_xp = _xp_mem(new_balances);
        uint256 D1 = get_D(new_balances_xp, A);
        
        require(D1 > D0, "D1 must be greater than D0");
        
        // Calculate ideal balances for fee calculation
        uint256[4] memory ideal_balance;
        if (totalSupply > 0) {
            for (uint256 i = 0; i < numTokens; i++) {
                ideal_balance[i] = D1 * old_balances[i] / D0;
            }
        }
        
        // Calculate fees
        uint256 _fee = feeRate * numTokens / (4 * (numTokens - 1));
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 ideal_balance_i = ideal_balance[i];
            uint256 new_balance_i = new_balances[i];
            uint256 difference = 0;
            if (ideal_balance_i > new_balance_i) {
                difference = ideal_balance_i - new_balance_i;
            } else {
                difference = new_balance_i - ideal_balance_i;
            }
            fees[i] = _fee * difference / 10000;
            balances_array[i] -= fees[i] * adminFeeRate / 10000;
        }
        
        // Recalculate D with fees
        for (uint256 i = 0; i < numTokens; i++) {
            new_balances[i] = balances_array[i];
        }
        new_balances_xp = _xp_mem(new_balances);
        uint256 D2 = get_D(new_balances_xp, A);
        
        // Calculate mint amount
        uint256 mint_amount = 0;
        if (totalSupply == 0) {
            mint_amount = D1;
        } else {
            mint_amount = totalSupply * (D2 - D0) / D0;
        }
        
        require(mint_amount >= min_mint_amount, "Slippage screwed you");
        
        // Mint LP tokens
        totalSupply += mint_amount;
        balanceOf[msg.sender] += mint_amount;
        IMockERC20(lpToken).mint(msg.sender, mint_amount);
        
        emit AddLiquidity(msg.sender, amounts, fees, D1, totalSupply);
        
        return mint_amount;
    }

    // Remove liquidity one coin
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256) {
        require(uint128(i) < numTokens, "Invalid coin index");
        require(token_amount > 0, "Amount must be positive");
        require(balanceOf[msg.sender] >= token_amount, "Insufficient balance");
        
        uint256 coin_index = uint128(i);
        
        // Calculate withdrawal amount (simplified)
        uint256 total_balance = 0;
        for (uint256 j = 0; j < numTokens; j++) {
            total_balance += balances_array[j];
        }
        
        uint256 coin_amount = (token_amount * balances_array[coin_index]) / totalSupply;
        
        // Apply withdrawal fee
        uint256 fee = coin_amount * feeRate / 10000;
        coin_amount -= fee;
        
        require(coin_amount >= min_amount, "Withdrawal resulted in fewer coins than expected");
        
        // Update state
        balances_array[coin_index] -= (coin_amount + fee);
        totalSupply -= token_amount;
        balanceOf[msg.sender] -= token_amount;
        
        // Burn LP tokens from user
        IERC20(lpToken).transferFrom(msg.sender, address(this), token_amount);
        IMockERC20(lpToken).burn(token_amount);
        
        // Transfer coin to user
        IERC20(coins_array[coin_index]).transfer(msg.sender, coin_amount);
        
        emit RemoveLiquidityOne(msg.sender, token_amount, coin_amount);
        
        return coin_amount;
    }

    // Remove liquidity (balanced)
    function remove_liquidity(uint256 token_amount, uint256[4] calldata min_amounts) external returns (uint256[4] memory) {
        require(token_amount > 0, "Amount must be positive");
        require(balanceOf[msg.sender] >= token_amount, "Insufficient balance");
        
        uint256[4] memory amounts;
        
        for (uint256 i = 0; i < numTokens; i++) {
            amounts[i] = balances_array[i] * token_amount / totalSupply;
            require(amounts[i] >= min_amounts[i], "Withdrawal resulted in fewer coins than expected");
            
            // Update balances
            balances_array[i] -= amounts[i];
            
            // Transfer tokens
            IERC20(coins_array[i]).transfer(msg.sender, amounts[i]);
        }
        
        // Update state
        totalSupply -= token_amount;
        balanceOf[msg.sender] -= token_amount;
        
        // Burn LP tokens
        IERC20(lpToken).transferFrom(msg.sender, address(this), token_amount);
        IMockERC20(lpToken).burn(token_amount);
        
        emit RemoveLiquidity(msg.sender, amounts, totalSupply);
        
        return amounts;
    }

    // Exchange function for swaps
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256) {
        require(uint128(i) < numTokens && uint128(j) < numTokens, "Invalid coin indices");
        require(i != j, "Cannot exchange same coin");
        
        uint256 coin_i = uint128(i);
        uint256 coin_j = uint128(j);
        
        // Simple exchange calculation (not using the full StableSwap formula for simplicity)
        uint256 dy = dx * balances_array[coin_j] / (balances_array[coin_i] + dx);
        
        // Apply fee
        uint256 fee = dy * feeRate / 10000;
        dy -= fee;
        
        require(dy >= min_dy, "Exchange resulted in fewer coins than expected");
        
        // Transfer input token from user
        IERC20(coins_array[coin_i]).transferFrom(msg.sender, address(this), dx);
        
        // Update balances
        balances_array[coin_i] += dx;
        balances_array[coin_j] -= dy;
        
        // Transfer output token to user
        IERC20(coins_array[coin_j]).transfer(msg.sender, dy);
        
        return dy;
    }

    // Admin functions
    function set_fee_rate(uint256 _fee_rate) external {
        require(_fee_rate <= 100, "Fee rate too high"); // Max 1%
        feeRate = _fee_rate;
    }

    function set_A(uint256 _A) external {
        require(_A >= 1 && _A <= 10000, "A out of range");
        A = _A;
    }

    // Emergency functions
    function kill_me() external {
        // Emergency function - in reality this would be admin only
        selfdestruct(payable(msg.sender));
    }

    function set_balances(uint256[] calldata _balances) external {
        require(_balances.length == numTokens, "Wrong number of balances");
        for (uint256 i = 0; i < numTokens; i++) {
            balances_array[i] = _balances[i];
        }
    }
}