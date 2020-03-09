pragma solidity ^0.4.24;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Pausable.sol";
import "./ReentrancyGuard.sol";

/**
 * @title SMASH TRC20 token early sale contract
 * @dev Implementation of the Early Access Token Sale.
*/
contract SMASHEarlySale is Pausable, ReentrancyGuard {
  using SafeMath for uint256;
  
  // Owner of this contract
  address public owner;
  
  // The token being sold
  IERC20 private _token;

   //ICO variables
   struct ICOSettings {
       uint256 cap;
       uint256 basePrice;
       uint256 tokensSold;
       uint256 remainingTokens;
       uint256 trxRaised; 
   }
   ICOSettings icosettings; 
   
   //ICO Stages
   enum ICOStages {none,icoStart,icoEnd}
   ICOStages currentStage;
   
   event ICOAction(address indexed by,uint amount,string action);
   
   // only human is allowed to call 
   modifier isHuman() {
       require((bytes32(msg.sender)) == (bytes32(tx.origin)));
       _;
   }
   
   constructor(IERC20 token) public {
        require(address(token) != address(0));
        owner = msg.sender;
        currentStage = ICOStages.none;
        icosettings.cap =  token.totalSupply().div(10);   //10% of Total tokens that we want to sale.
        icosettings.tokensSold =0;   //the number of tokens that have been sold.
        icosettings.remainingTokens  =icosettings.cap ;  //number of tokens remaining that can be
        icosettings.basePrice = 25; // 2.5 tokens per 1 TRX
        _token = token;
   }

  //Start the Earlier Sale
  function startIco() external onlyAdministrators {
        require(currentStage != ICOStages.icoEnd);
        currentStage = ICOStages.icoStart;
        emit ICOAction(msg.sender,0,"Start ICO");
  }
  
  //End the Earlier Sale
  function endIco() external onlyAdministrators {
        require(currentStage != ICOStages.icoEnd);
        currentStage = ICOStages.icoEnd;
        
        // Reset the remaining tokens
        icosettings.remainingTokens = 0;
        
        // transfer any remaining TRX balance in the contract to the owner
        owner.transfer(address(this).balance);         

        emit ICOAction(msg.sender,0,"End ICO");
  }
    
  function buyTokens() external nonReentrant isHuman whenNotPaused payable {
        require(currentStage == ICOStages.icoStart, "ICO Not start yet");
        require(msg.value > 0,"TRX amount is zero");
        require(icosettings.remainingTokens > 0 ,"All tokens sold out");

        uint256 trxAmount = msg.value; 
        uint256 tokens = trxAmount.mul(icosettings.basePrice).div(10); // Calculate tokens to sell

        require(tokens <= icosettings.remainingTokens,"No enough remaining tokens");

        // Send TRX from buyer to owner before any status changes
        owner.transfer(trxAmount);        

        //Update ICO status 
        icosettings.tokensSold = icosettings.tokensSold.add(tokens); // Increment raised token amount
        icosettings.remainingTokens = icosettings.cap.sub(icosettings.tokensSold);
        icosettings.trxRaised =  icosettings.trxRaised.add(trxAmount);  // Increment raised trx amount
       
        //Process token purchase
        require(_token.transferFrom(owner, msg.sender, tokens) == true);
     
        emit ICOAction(msg.sender,tokens,"Buy Token");
  }      

  function getICOStatus() external view returns(uint256,uint256,uint256,uint256,ICOStages, address,address,uint256,uint) {
     uint isHealthy;
     if((icosettings.cap ==icosettings.tokensSold +icosettings.remainingTokens )){
        isHealthy=1; 
     }else{
        isHealthy=0;
     }
     return (icosettings.cap,icosettings.basePrice,icosettings.tokensSold,icosettings.remainingTokens,currentStage, _token,owner,icosettings.trxRaised,isHealthy);
  }
 
  function kill() external onlyAdministrators { //onlyOwner can kill this contract
    selfdestruct(owner);  // `owner` is the owners address
    // emit ICOAction(msg.sender,"Start ICO");
  }

  function () public payable {
        // nothing to do
  }
}
