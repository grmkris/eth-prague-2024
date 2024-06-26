// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {MemeCCRToken} from "./Tokens/MemeCCRToken.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenSubmission {
    struct TokenIdea {
        string name;
        string symbol;
        uint256 votes;
    }

    address public owner;
    uint256 public targetAmount;
    uint256 public totalCollected;
    TokenIdea[] public tokenIdeas;
    mapping(address => bool) public hasSubmitted;

    address public WETH;

    constructor(uint256 _targetAmount, address _WETH) {
        owner = msg.sender;
        targetAmount = _targetAmount;
        WETH = _WETH;
    }

    function submitTokenIdea(string calldata _name, string calldata _symbol) external {
        require(!hasSubmitted[msg.sender], "Already submitted");
        tokenIdeas.push(TokenIdea({name: _name, symbol: _symbol, votes: 0}));
        hasSubmitted[msg.sender] = true;
    }

    function contributeAndVote(uint256 _ideaIndex, uint256 amount) external {
        require(_ideaIndex < tokenIdeas.length, "Invalid index");
        require(amount > 0, "Must contribute Ether");
        require(ERC20(WETH).allowance(msg.sender, address(this)) >= amount, "Error");

        ERC20(WETH).transferFrom(msg.sender, address(this), amount);

        totalCollected += amount;
        tokenIdeas[_ideaIndex].votes += amount;
    }

    function createTokenAndAddLiquidity(address manager, IHooks hook, PoolModifyLiquidityTest poolModifyLiqTest, PoolSwapTest poolSwapTest) external {
        require(totalCollected >= targetAmount, "Target not met");

        // Token creation
        TokenIdea memory winningIdea = getWinningIdea();

        uint256 tokenAmount = totalCollected;

        MemeCCRToken newToken = new MemeCCRToken(winningIdea.name, winningIdea.symbol, tokenAmount);

        newToken.approve(manager, tokenAmount);
        // approve the tokens to the routers
        newToken.approve(address(poolModifyLiqTest), type(uint256).max);
        newToken.approve(address(poolSwapTest), type(uint256).max);

        IERC20 weth = IERC20(WETH);
        weth.approve(address(poolModifyLiqTest), type(uint256).max);
        weth.approve(address(poolSwapTest), type(uint256).max);
        weth.approve(address(manager), type(uint256).max);

        // LP Creation
        // initialize the pool
        int24 tickSpacing = 60;
        bytes memory ZERO_BYTES = new bytes(0);

        PoolKey memory poolKey =
            PoolKey(Currency.wrap(address(newToken)), Currency.wrap(WETH), 3000, tickSpacing, hook);
        IPoolManager(manager).initialize(poolKey, Constants.SQRT_PRICE_1_1, ZERO_BYTES);

        // add full range liquidity to the pool
        poolModifyLiqTest.modifyLiquidity(
             poolKey,
             IPoolManager.ModifyLiquidityParams(-60, 60, 1000, 0),
             ZERO_BYTES
         );
    }

    function getWinningIdea() internal view returns (TokenIdea memory) {
        TokenIdea memory winningIdea;
        uint256 maxVotes = 0;

        for (uint256 i = 0; i < tokenIdeas.length; i++) {
            if (tokenIdeas[i].votes > maxVotes) {
                winningIdea = tokenIdeas[i];
                maxVotes = tokenIdeas[i].votes;
            }
        }

        return winningIdea;
    }
}
