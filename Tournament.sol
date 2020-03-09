pragma solidity ^0.4.24;

import "./IERC20.sol";
import "./Pausable.sol";
import "./TournamentLib.sol";
import "./ReentrancyGuard.sol";

/**
 * @title Smart Tournament Contract
 * Richard Liu, Feb 2019
 * @dev Implementation of Tournament Functions
  */

contract Tournament is Pausable, ReentrancyGuard {

  // Owner of this contract
  address public owner;
  
  TournamentLib.GlobalVars internal globalvars; // for temporary data

  /* EVENTS */
/*  event AddSMASH(uint datetime, address tokenaddress,address by);*/
  event TournamentAction(uint datetime, address user, uint tournamentid, string Action);
  event SetPlayerInfo(uint datetime,address by, address player, uint level, string field );
  event SetTournamentAdmin(uint datetime,address by,uint tournamentID, address moderator, string role);
  event SetTournamentStatus(uint datetime,address by,  uint tournamentID,  uint tournamentStatus);
  event SetDeveloperAccount(uint datetime,address by, address developeraccount, string accounttype);
  event TokenActions(uint datetime, address player, uint amount, uint tournamentid,string actionname);
  event Action(uint datetime, address to , uint amount, string actionname);
  
  TournamentLib.LibTournament internal libtournaments;
  
  TournamentLib.Libplayer internal libplayer;  

   // only human is allowed to call 
   modifier isHuman() {
       require((bytes32(msg.sender)) == (bytes32(tx.origin)));
       _;
   }
   
  /* CONSTRUCTOR */
  constructor() public {
      owner = msg.sender;
      globalvars.developerAccount = msg.sender;
      globalvars.tournamentSeedAccount = msg.sender;
      globalvars.allowanceAccount = msg.sender;
  }

  /* ========Tournament OPERATIONS \ Modified - Tournament ID validation========================== */ 
  modifier validTournament(uint _tournamentID) {
    require(_tournamentID > 0 , "Not a valid tournament Id.");
    require (libtournaments.allTournamentsMap[_tournamentID] == 1 ,"Not a valid tournament Id");
    _;
  }

 /* ========Tournament OPERATIONS \ Create new Tournament=========================== */      
 function createTournament(uint _tournamentID, uint _startdate, uint _enddate, uint _entryFee, uint _creationFee, bool _isGlobal, uint _seed) external whenNotPaused isHuman nonReentrant returns (bool) {
    require(libtournaments.allTournamentsMap[_tournamentID] == 0,"Tournament ID already exists");
    require( _enddate >= now, "End date should greater than current date time");
    require(now <_startdate + (_enddate - _startdate)/2, "The tournamnt is locked as the middle of tour duration");
    require(_entryFee >0, "The tournamnt entry fee must be greater than zero");
        
    if (_isGlobal){
        //only administrator can create global tournament
        require(isPauser(msg.sender));
        // require (_seed >0);
        uint totalpayout = _seed + _seed * 2/10 ;
        require(libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress >= totalpayout ,"tournament SeedAccount no enough tokens");
        require(_seed > 0 ,"tournament Seed must be greater than 0 for global tournament");        
    }else{
        require(_creationFee >0 ,"Tournament creation fee must be greater than 0 for non-global tournament");
        require(libplayer.player[msg.sender].tokenBalanceAddress >= _creationFee +_seed  ,"There is no enough tokens for this player");        
    }
    
    // libtournaments.tournaments[_tournamentID].status = TournamentLib.TournamentStatus.IN_PROGRESS;
    libtournaments.tournaments[_tournamentID].startDate = _startdate;
    libtournaments.tournaments[_tournamentID].endDate = _enddate;
    libtournaments.tournaments[_tournamentID].entryFee = _entryFee;
    libtournaments.tournaments[_tournamentID].prizeSeed = _seed;
    libtournaments.tournaments[_tournamentID].creationFee = _creationFee;
    libtournaments.tournaments[_tournamentID].isGlobal = _isGlobal;
  
    TournamentLib.createTournament(globalvars,libplayer,libtournaments, _tournamentID);
  
    emit TournamentAction(now,msg.sender, _tournamentID, "Create Tournament");
    return true;
 }


 /* ========Tournament OPERATIONS \ Add player for a given tournament=========================== */     
 function joinTournament(uint _tournamentID, bool isBuyBack) external whenNotPaused isHuman nonReentrant validTournament(_tournamentID) {
    require(libplayer.player[msg.sender].tokenBalanceAddress>=libtournaments.tournaments[_tournamentID].entryFee, "You don't have enough tokens to create this tournament" );
    //Player can only join/buyback before the middle of start/end date. 
    require(now <libtournaments.tournaments[_tournamentID].startDate + (libtournaments.tournaments[_tournamentID].endDate - libtournaments.tournaments[_tournamentID].startDate)/2, "The tournamnt is locked as the middle of tour duration");
    require (libtournaments.tournaments[_tournamentID].status !=2, "this tournament already Cancelled");
    require (libtournaments.tournaments[_tournamentID].status != 1, "This tournament prize already distributed");
    // require(libtournaments.tournaments[_tournamentID].status == TournamentLib.TournamentStatus.IN_PROGRESS, "Tournament is end.");
    
    uint enryFee = libplayer.player[msg.sender].tournamentEntryFee[_tournamentID];
    if (isBuyBack){
         require((enryFee > 0 || libtournaments.tournamentkeyusers[_tournamentID].creator == msg.sender), "This user not join this tournament yet.");
    }else{
         require(!(enryFee > 0 || libtournaments.tournamentkeyusers[_tournamentID].creator == msg.sender), "This user has already joined.");
    }
   
    
    TournamentLib._joinTournament(libplayer,libtournaments,_tournamentID,isBuyBack);
 }

 /* ========Tournament OPERATIONS \ Cancel a given tournament=========================== */     
 function cancelTournament(uint _tournamentID) external whenNotPaused isHuman nonReentrant validTournament(_tournamentID) {
    require (libtournaments.tournaments[_tournamentID].status !=2, "this tournament already Cancelled");
    require (libtournaments.tournaments[_tournamentID].status !=1, "This tournament prize already distributed");
    //only administrator can cencel global tournament
    require(isPauser(msg.sender),"only administrator can cencel tournament");  
    require(libtournaments.tournaments[_tournamentID].players.length<=50,"this tournament cannot be Cancelled since players is over 50");      

    TournamentLib._cancelTournament(globalvars,libplayer,libtournaments,_tournamentID);
 }   
 
 /* ========Tournament OPERATIONS \ get Tournament locked date/time=========================== */   
/* function getTournamentLockedDate(uint _tournamentID) external view validTournament(_tournamentID) returns (uint) {
    return libtournaments.tournaments[_tournamentID].startDate + (libtournaments.tournaments[_tournamentID].endDate - libtournaments.tournaments[_tournamentID].startDate)/2;
 }*/
/*Tournament OPERATIONS \ get Tournament info (Admin only - this retrieve tournament info a given tournament) */
 function getTournamentInfo(uint _tournamentID) external view validTournament(_tournamentID) returns (uint,uint,uint,address,uint8,uint) {
    uint lockdate= libtournaments.tournaments[_tournamentID].startDate + (libtournaments.tournaments[_tournamentID].endDate - libtournaments.tournaments[_tournamentID].startDate)/2;
    return(libtournaments.tournaments[_tournamentID].tokenBalanceForTournament,libtournaments.tournaments[_tournamentID].endDate,lockdate,libtournaments.tournamentkeyusers[_tournamentID].creator,libtournaments.tournaments[_tournamentID].status,libtournaments.tournaments[_tournamentID].entryFee);
 }
 
/*Tournament OPERATIONS \  this retrieve all players and others from a given tournament) */
 function getTournamentDetails(uint _tournamentID) external view validTournament(_tournamentID) returns (address[],uint,uint,uint,bool) {
    return(libtournaments.tournaments[_tournamentID].players,libtournaments.tournaments[_tournamentID].startDate,libtournaments.tournaments[_tournamentID].creationFee,libtournaments.tournaments[_tournamentID].prizeSeed,libtournaments.tournaments[_tournamentID].isGlobal);
 }
 
 /* ========Tournament OPERATIONS \ get all active Tournament IDs from this contract========================== */  
/* function getActiveTournamentst() external view returns (uint[]) {
    return libtournaments.activeTournaments;
 }*/

/* ========Tournament OPERATIONS \ set tournament administrator/moderator============================== */     
/* function setTournamentAdmin(uint _tournamentID, address _admin, bool _isadmin, bool _ismoderator) external whenNotPaused isHuman validTournament(_tournamentID) {
    require(_admin != address(0));
    require (_isadmin || _ismoderator);
    require(libtournaments.tournamentkeyusers[_tournamentID].creator == msg.sender || libtournaments.tournamentkeyusers[_tournamentID].administrator == msg.sender || libtournaments.tournamentkeyusers[_tournamentID].moderator == msg.sender, "Only tournament creator/moderator/administrator can set status.");
    // require(curTournament.status < TournamentStatus.END, "when the tournament ended, administrator cannot be changed.");
    
    if (_isadmin){
         libtournaments.tournamentkeyusers[_tournamentID].administrator = _admin;
         emit SetTournamentAdmin(now,msg.sender, _tournamentID, _admin,"Set Administrator");
    } else{
        libtournaments.tournamentkeyusers[_tournamentID].moderator = _admin;
        emit SetTournamentAdmin(now,msg.sender, _tournamentID, _admin,"Set Moderator");
    } 
}*/

/* ========Tournament OPERATIONS \ set tournament winners============================== */    
 function distributePrizeBatch(uint _tournamentID, address[] _players, uint[] _percent) external isHuman nonReentrant whenNotPaused validTournament(_tournamentID){
    //This will be triggered by background job and admin only
    require( now >= libtournaments.tournaments[_tournamentID].endDate , "Distribe prrize can only happens when end date is passsed");
    require(isPauser(msg.sender) || libtournaments.tournamentkeyusers[_tournamentID].creator == msg.sender, "Only tournament creator or contract owner can distribute prize.");
    require(libtournaments.tournaments[_tournamentID].players.length >0, "There is no partictpating player.");    
    require (libtournaments.tournaments[_tournamentID].status !=2, "this tournament already Cancelled");
    require (libtournaments.tournaments[_tournamentID].status != 1, "This tournament prize already distributed");
    // Jan 2020 - Add new condiftion and reject the distribution if winner is over 50 to avoid "reach gas limit" issue
    require(libtournaments.tournaments[_tournamentID].players.length <=50, "Maxinum winners must be less than 50.");    
    TournamentLib._distributePrizeBatch(libplayer,libtournaments, _tournamentID, _players, _percent);
 }
 
 /* ========Global OPERATIONS \ set developer account============================== */     
  function setadminAccounts(address _admin, uint _maxdailyallowance, uint accounttype) external onlyAdministrators () {
    //   0 - SMASH Token address 1 - developer 2 - allowancepool 3 - tournament seed pool  4 - set max daily allowance amount per player 5 - Set one-time-signup TRX amount
    TournamentLib._setadminAccounts(globalvars, _admin, _maxdailyallowance,accounttype);
 }
 
 function getAdminAccounts() external view returns(address,address,address,address,uint,uint,address,uint) {
      return (globalvars.tokenContract,globalvars.developerAccount,  globalvars.tournamentSeedAccount, globalvars.allowanceAccount, globalvars.dailyallowanceruntime, globalvars.maxdailyallowance,owner,globalvars.signupTRXamount);
 }

 function getTokensGlobal() external view returns(uint,uint,uint,uint,uint,uint) {
    //  Global - tournamenremaining
     uint isHealthy;
     uint tournamenremaining;
     IERC20 token = IERC20(globalvars.tokenContract);
     tournamenremaining =  libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress + token.balanceOf(globalvars.tournamentSeedAccount);
     
    //  Global - Allocation tournamenremaining
     uint allocationremaining;
     allocationremaining = libplayer.player[globalvars.allowanceAccount].tokenBalanceAddress + token.balanceOf(globalvars.allowanceAccount);
     ////////////////////////////////////////////rechecking this logic????
     if(globalvars.allocationPaid+globalvars.tournamentPaid+tournamenremaining+allocationremaining  == token.totalSupply()*9/10){
         isHealthy =1;
     }else{
         isHealthy =0;
     }
     return (globalvars.allocationPaid,globalvars.tournamentPaid,tournamenremaining,allocationremaining,isHealthy,token.totalSupply());
 }
 
 function getTokensMy(address _player) external view returns(uint,uint,uint,uint8) {
      IERC20 token = IERC20(globalvars.tokenContract);
     return (token.balanceOf(_player),libplayer.player[_player].tokenBalanceAddress,libplayer.player[_player].allowanceAmount,libplayer.player[_player].getsignupallowance);
 }

 function setTokensMy(address _player, uint _amount, uint8 _signupflag, uint8 _type) external onlyAdministrators {
     require(_player != address(0));
     TournamentLib._setplayerinfo(libplayer,_player,_amount, _signupflag,_type);
 }
 
/* function getMASHInPlay(address _player,uint _tournamentID) external view returns (uint) {
    // uint mashInPlay;
    for (uint i = 0; i < libtournaments.activeTournaments.length; i++){
        mashInPlay += libplayer.player[_player].tournamentEntryFee[libtournaments.activeTournaments[i]];
    }
    return libplayer.player[_player].tournamentEntryFee[_tournamentID];
  }*/
  

 /* ========Global OPERATIONS \ DEPOSIT AND WITHDRAWAL TOKEN============================== */    
 function depositToken(uint _amount) external whenNotPaused nonReentrant payable returns (bool){
    /* _type=1 (Token) 2 (TRX)*/
    // require (_type ==1 || _type ==2, "Invalid type");
        require(globalvars.tokenContract != address(0),"No specified SMASH Token yet");
        IERC20 token = IERC20(globalvars.tokenContract);
        require(token.transferFrom(msg.sender, address(this), _amount) == true);
        require(libplayer.player[msg.sender].tokenBalanceAddress + _amount >= libplayer.player[msg.sender].tokenBalanceAddress);
        libplayer.player[msg.sender].tokenBalanceAddress += _amount;
        emit TokenActions(now, msg.sender, _amount,0,"Deposit Tokens");        
    return true;
 }
 
/* function depositTRX() nonReentrant public payable {
        require(libplayer.player[msg.sender].trxBalanceAddress + msg.value >= libplayer.player[msg.sender].trxBalanceAddress);
        libplayer.player[msg.sender].trxBalanceAddress += msg.value;  
        emit TokenActions(now, msg.sender, msg.value,0,"Deposit TRX"); 
 }*/
    

function withdrawToken(uint _amount, uint8 _type) external whenNotPaused isHuman nonReentrant {
    /* _type=1 (Token) 2 (TRX)*/
    if(_type ==1){
        require(globalvars.tokenContract != address(0));
    
        IERC20 token = IERC20(globalvars.tokenContract);
    
        require(libplayer.player[msg.sender].tokenBalanceAddress - _amount >= 0);
        require(libplayer.player[msg.sender].tokenBalanceAddress - _amount <= libplayer.player[msg.sender].tokenBalanceAddress);
    
        libplayer.player[msg.sender].tokenBalanceAddress -= _amount;
        require(token.transfer(msg.sender, _amount) == true);
    
        emit TokenActions(now,msg.sender, _amount,0,"Withdraw Tokens");           
    }else{
        require(libplayer.player[msg.sender].trxBalanceAddress - _amount >= 0);
        require(libplayer.player[msg.sender].trxBalanceAddress - _amount <= libplayer.player[msg.sender].trxBalanceAddress);
        libplayer.player[msg.sender].trxBalanceAddress -= _amount;
        msg.sender.transfer(_amount);  
        emit TokenActions(now,msg.sender, _amount,0,"Withdraw TRX");   
    }      

 }

 function distributeAllowanceBatch(address[] _players, uint[] _amount, uint8 _isSignup, bool _isSetDailyRunningTime) external nonReentrant onlyAdministrators {
     //isSignup 1 - One time signup Others - Daily allowance (0- triggered by cron job 2 - triggered by admin manually)
      if (_isSetDailyRunningTime) {
          //This is the last players chun, set the daily running time
          globalvars.dailyallowanceruntime = now; 
          emit Action(now, _players[0], _amount[0], "distributeAllowanceBatch-SetDailyTime");
      }else{
        TournamentLib._distributeAllowanceBatch(globalvars,libplayer,_players, _amount,_isSignup);
      } 
 }
 
 function claimAllowance() external whenNotPaused isHuman nonReentrant returns (bool) {
    TournamentLib._claimAllowance(globalvars,libplayer);
 }

/* ========Global OPERATIONS \ DEPOSIT AND WITHDRAWAL TOKEN============================== */    


 /* ========Call back and allow to receive tokens============================== */    
  function() public payable {
    emit Action(now, msg.sender, msg.value, "Fallback");
  }

 /* ========//onlyOwner can kill this contract============================== */    
  function kill() external onlyAdministrators { 
    selfdestruct(owner);  // `owner` is the owners address
  }  
}