// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFv2DirectFundingConsumer} from "./VRFv2DirectFundingConsumer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Coinflip is Ownable{
    // A map of the player and their corresponding random number request
    mapping(address => uint256) public playerRequestID;
    // A map that stores the users coinflip guess
    mapping(address => uint8) public bets;
    // An instance of the random number requestor, client interface
    VRFv2DirectFundingConsumer private vrfRequestor;

    ///@dev we no longer use the seed, instead each coinflip should spawn its own VRF instance
    ///@notice This programming pattern is a factory model - a contract creating other contracts 
    constructor() Ownable(msg.sender) {
        vrfRequestor = new VRFv2DirectFundingConsumer();
    }

    ///@notice Fund the VRF instance with **2** LINK tokens.
    ///@return A boolean of whether funding the VRF instance with link tokens was successful or not
    ///@dev use the address of LINK token contract provided. Do not change the address!
    ///@custom:attention In order for this contract to fund another contract, which tokens does it require to have before calling this function?
    ///                  What **additional** functions does this contract need to receive these tokens itself?

    // Two methods - 1 - directly transfer tokens to the VRF instance from the sender
    function fundOracledirect() external returns(bool){
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        // directly transfer 2 LINK tokens to the VRF instance from the sender
        IERC20(Link_addr).transferFrom(msg.sender, address(vrfRequestor), 2 * 10**18);
        // Check if the VRF instance has received the tokens
        return IERC20(Link_addr).balanceOf(address(vrfRequestor)) >= 2 * 10**18;
        }
        
    /// OR

    // 2. - let the Coinflip contract hold/receive tokens, and then fund the VRF instance to use when required
    function fundCoinflip(uint8 amount) external {
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        IERC20(Link_addr).transferFrom(msg.sender, address(this), amount);
    }
    function fundOracle() external returns(bool){
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        // directly transfer 2 LINK tokens to the VRF instance from the sender
        IERC20(Link_addr).transferFrom(address(this), address(vrfRequestor), 2 * 10**18);
        // Check if the VRF instance has received the tokens (or already has them)
        return IERC20(Link_addr).balanceOf(address(vrfRequestor)) >= 2 * 10**18;
        }
    
        //check the balance of the VRF instance
    function checkOracleBalance() external view returns(uint256){
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        return IERC20(Link_addr).balanceOf(address(vrfRequestor));
    }

    ///@notice user guess only ONE flip either  1 or  0.
    ///@param Guess int8 which is required to be 1 or 0
    ///@dev After validating the user input, store the user input in global mapping and fire off a request to the VRF instance
    ///@dev Then, store the requestid in global mapping
    function userInput(uint8 Guess) external {
        require(Guess == 1 || Guess == 0, "Invalid guess");
        bets[msg.sender] = Guess;
        // this is the requestid of the random word request
        playerRequestID[msg.sender] = vrfRequestor.requestRandomWords();
    }

    ///@notice due to the fact that a blockchain does not deliver data instantaneously, in fact quite slowly under congestion, allow
    ///        users to check the status of their request.
    ///@return a boolean of whether the request has been fulfilled or not
    function checkStatus() external view returns(bool){
        (uint256 paid, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(playerRequestID[msg.sender]);
        return fulfilled;
    }

    ///@notice once the request is fulfilled, return the random result and check if user won
    ///@return a boolean of whether the user won or not based on their input
    ///@dev request the randomWord that is returned. Here you need to check the VRFcontract to understand what type the random word is returned in
    ///@dev simply take the first result, or you can configure the VRF to only return 1 number, and check if it is even or odd. 
    ///     if it is even, the randomly generated flip is 0 and if it is odd, the random flip is 1
    ///@dev compare the user guess with the generated flip and return if these two inputs match.
    function determineFlip() external view returns(bool){
        (uint256 paid, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(playerRequestID[msg.sender]);
        require(fulfilled, "Request not fulfilled yet");
        require(randomWords.length > 0, "No random words returned");
        // I've amended the VRF contract to return only 1 random number, if it still returned two, then I would use the first one
        // randomWords = randomWords[0];
        // using modulo to get a 0 or 1
        uint256 flip = randomWords[randomWords.length - 1] % 2;
        // did the user win?
        return bets[msg.sender] == flip;
    }
}
