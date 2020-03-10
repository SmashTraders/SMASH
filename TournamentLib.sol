
pragma solidity ^0.4.24;

library TournamentLib {

    /*  Global Vars  */
    struct GlobalVars{
        address developerAccount;
        address tournamentSeedAccount;
        address allowanceAccount; 
        address tokenContract;
        uint allocationPaid;
        uint tournamentPaid;   //Tournament Paidout for global tournaments
        uint dailyallowanceruntime;
        uint maxdailyallowance;
        uint signupTRXamount;
    }
  
      /* TOURNAMENT INFO */
    struct TournamentInfo {
        bool isGlobal;  
        uint startDate;
        uint endDate;
        uint entryFee;
        uint creationFee;
        uint prizeSeed;
        uint tokenBalanceForTournament;   //Prize pool per Tournament
        uint8 status; //1- Distributed 2 - Cancelled
        address[] players;   //add this array to keep players for a given tournament and this will be used to send entry fee back as part of cancellation        
    }

    /* TOURNAMENT key users */
    struct TournamentKeyUsers {
        address creator;
/*        address moderator;
        address administrator;*/
    } 

    struct LibTournament { 
        mapping(uint => TournamentInfo) tournaments; 
        mapping(uint => TournamentKeyUsers) tournamentkeyusers;
        mapping (uint => uint8) allTournamentsMap;
        // uint[] activeTournaments;
    }
    
    /* PLAYER */
    struct Player {
        mapping (uint => uint) tournamentEntryFee;  //entry fee per tournament --Pending to remove this field
        uint tokenBalanceAddress;  
        uint allowanceAmount;
        uint8 getsignupallowance;
        uint trxBalanceAddress;
    }
    struct Libplayer { mapping(address => Player) player; }    
 
    /* EVENTS */
 /*   event AddSMASH(uint datetime, address tokenaddress,address by);*/
    event TournamentAction(uint datetime, address user, uint tournamentid, string Action);
    event SetPlayerInfo(uint datetime,address by, address player, uint level, string field );
    event SetTournamentAdmin(uint datetime,address by,uint tournamentID, address moderator, string role);
    event SetTournamentStatus(uint datetime,address by,  uint tournamentID,  uint tournamentStatus);
    event SetDeveloperAccount(uint datetime,address by, address developeraccount, string accounttype);
    event TokenActions(uint datetime, address player, uint amount, uint tournamentid,string actionname);
    event Action(uint datetime, address to , uint amount, string actionname);
  

    /* ========Tournament OPERATIONS \ Create new Tournament=========================== */      
    function createTournament(GlobalVars storage globalvars,Libplayer storage libplayer,LibTournament storage libtournaments,uint _tournamentID) external returns (bool) {
        //Create new tournament
        libtournaments.tournamentkeyusers[_tournamentID].creator = msg.sender;
        
        //Assign 1 to this tournament ID which is used to Tournament ID validation
        libtournaments.allTournamentsMap[_tournamentID] = 1;
    
        if (libtournaments.tournaments[_tournamentID].isGlobal && libtournaments.tournaments[_tournamentID].prizeSeed >0){
            // created by admin and payout tokens from tournament seed pool
            //Transfer seed fee out from tournament seed pool
            uint seedtodeveloper = libtournaments.tournaments[_tournamentID].prizeSeed * 2/10 ;
            uint totalpayout = libtournaments.tournaments[_tournamentID].prizeSeed + seedtodeveloper;
            // require(libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress- totalpayout >= 0);
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress + seedtodeveloper >= libplayer.player[globalvars.developerAccount].tokenBalanceAddress);
            require(libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress - totalpayout <= libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress);
            require(libtournaments.tournaments[_tournamentID].tokenBalanceForTournament + libtournaments.tournaments[_tournamentID].prizeSeed >=libtournaments.tournaments[_tournamentID].tokenBalanceForTournament);
            require( globalvars.tournamentPaid + totalpayout >=globalvars.tournamentPaid);
            
            libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress -= totalpayout;
            libplayer.player[globalvars.developerAccount].tokenBalanceAddress += seedtodeveloper;
            //prize pool per tournament
            libtournaments.tournaments[_tournamentID].tokenBalanceForTournament += libtournaments.tournaments[_tournamentID].prizeSeed;
             //prize pool for Global tournaments
            globalvars.tournamentPaid += totalpayout;
            // tokenBalanceForTournament[ _tournamentID] += curTournament.prizeSeed;
        } else{
            //created by players, Player also need Join the tournament as tournament creator and deposit creation tokens
            PayoutTokens(libplayer,libtournaments.tournaments[_tournamentID].creationFee+libtournaments.tournaments[_tournamentID].prizeSeed+libtournaments.tournaments[_tournamentID].entryFee,_tournamentID);  
            
            //transfer creation fee to developer account
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress + libtournaments.tournaments[_tournamentID].creationFee >=libplayer.player[globalvars.developerAccount].tokenBalanceAddress);
            libplayer.player[globalvars.developerAccount].tokenBalanceAddress += libtournaments.tournaments[_tournamentID].creationFee;
            //prize seed and entry fee to tournament pool
            uint tournamentpool = libtournaments.tournaments[_tournamentID].prizeSeed + libtournaments.tournaments[_tournamentID].entryFee;
            require (libtournaments.tournaments[_tournamentID].tokenBalanceForTournament + tournamentpool >= libtournaments.tournaments[_tournamentID].tokenBalanceForTournament);
            libtournaments.tournaments[_tournamentID].tokenBalanceForTournament += tournamentpool;
            //Record player info
            libplayer.player[msg.sender].tournamentEntryFee[_tournamentID]= libtournaments.tournaments[_tournamentID].entryFee;
            //add player to the tournament player list
            libtournaments.tournaments[_tournamentID].players.push(msg.sender);               
        }
    
        // libtournaments.activeTournaments.push(_tournamentID);
        emit TournamentAction(now,msg.sender, _tournamentID, "Create Tournament");
        return true;
    }

    /* ========Tournament OPERATIONS \ Add player for a given tournament=========================== */     
    function _joinTournament(Libplayer storage libplayer,LibTournament storage libtournaments,uint _tournamentID,bool isBuyBack) external {
        PayoutTokens(libplayer,libtournaments.tournaments[_tournamentID].entryFee,_tournamentID);
    
        require(libtournaments.tournaments[_tournamentID].tokenBalanceForTournament + libtournaments.tournaments[_tournamentID].entryFee >= libtournaments.tournaments[_tournamentID].tokenBalanceForTournament);
        libtournaments.tournaments[_tournamentID].tokenBalanceForTournament += libtournaments.tournaments[_tournamentID].entryFee;
  
        require(libplayer.player[msg.sender].tournamentEntryFee[_tournamentID] +  libtournaments.tournaments[_tournamentID].entryFee >=libplayer.player[msg.sender].tournamentEntryFee[_tournamentID]);
        libplayer.player[msg.sender].tournamentEntryFee[_tournamentID] += libtournaments.tournaments[_tournamentID].entryFee;

        //add player to the tournament player list for "joinTournament" request
        if(!isBuyBack) libtournaments.tournaments[_tournamentID].players.push(msg.sender);    
            
        emit TournamentAction(now,msg.sender, _tournamentID, "Join Tournament");
    }
 
     /* ========Tournament OPERATIONS \ Cancel a given tournament=========================== */     
    function _cancelTournament(GlobalVars storage globalvars,Libplayer storage libplayer,LibTournament storage libtournaments,uint _tournamentID) external {
        // require (libtournaments.tournaments[_tournamentID].status !=2, "this tournament already Cancelled");
        //only creator, administrator and administrator can cancel 

        if (libtournaments.tournaments[_tournamentID].isGlobal){    
            //Global Tournament - Calcute tokens back to seed pool and from developer account
            uint seedtodeveloper = libtournaments.tournaments[_tournamentID].prizeSeed * 2/10 ;
            uint totalpayout = libtournaments.tournaments[_tournamentID].prizeSeed + seedtodeveloper;
            
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress>= seedtodeveloper);
            //Global Tournament - Transfer SMASH back to seed pool
            require(libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress + totalpayout>= libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress);
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress - seedtodeveloper <=libplayer.player[globalvars.developerAccount].tokenBalanceAddress);
            require(globalvars.tournamentPaid - totalpayout <= globalvars.tournamentPaid);
             
            libplayer.player[globalvars.tournamentSeedAccount].tokenBalanceAddress += totalpayout;
            
            //Global Tournament - withdraw SMASH from developer account
            libplayer.player[globalvars.developerAccount].tokenBalanceAddress -= seedtodeveloper;
            
             //prize pool for Global tournaments
            globalvars.tournamentPaid -= totalpayout;
            // tokenBalanceForTournament[ _tournamentID] += curTournament.prizeSeed;        
        }else{
            // require(libtournaments.tournamentkeyusers[_tournamentID].creator == msg.sender || libtournaments.tournamentkeyusers[_tournamentID].administrator == msg.sender || libtournaments.tournamentkeyusers[_tournamentID].moderator == msg.sender, "Only tournament creator/moderator/administrator can cancel tournament.");
            //Private tournament -withdraw creation fee from developer account
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress>= libtournaments.tournaments[_tournamentID].creationFee);
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress - libtournaments.tournaments[_tournamentID].creationFee <= libplayer.player[globalvars.developerAccount].tokenBalanceAddress);
            require (libplayer.player[libtournaments.tournamentkeyusers[_tournamentID].creator].tokenBalanceAddress + libtournaments.tournaments[_tournamentID].creationFee+libtournaments.tournaments[_tournamentID].prizeSeed >= libplayer.player[libtournaments.tournamentkeyusers[_tournamentID].creator].tokenBalanceAddress);
            
            libplayer.player[globalvars.developerAccount].tokenBalanceAddress -= libtournaments.tournaments[_tournamentID].creationFee;
            
            //Transfer the creation fee and prizeSeed back to creator
            libplayer.player[libtournaments.tournamentkeyusers[_tournamentID].creator].tokenBalanceAddress += libtournaments.tournaments[_tournamentID].creationFee+libtournaments.tournaments[_tournamentID].prizeSeed;
            //Since creator didn't pay the entry fee and following loop return entry fee also include creator. we reduce the entry fee here before that loop
            // libplayer.player[libtournaments.tournamentkeyusers[_tournamentID].creator].tokenBalanceAddress -= libtournaments.tournaments[_tournamentID].entryFee;
        }
        
        //Return entry fee back to participating players
        if(libtournaments.tournaments[_tournamentID].players.length >0){
            require(libtournaments.tournaments[_tournamentID].tokenBalanceForTournament >= libtournaments.tournaments[_tournamentID].entryFee * (libtournaments.tournaments[_tournamentID].players.length-1));
            for (uint p = 0; p<=libtournaments.tournaments[_tournamentID].players.length-1; p++){
                // if(libtournaments.tournaments[_tournamentID].players[p] !=libtournaments.tournamentkeyusers[_tournamentID].creator ){
                    //Since creator didn't pay the entry fee
                require(libplayer.player[libtournaments.tournaments[_tournamentID].players[p]].tokenBalanceAddress + libplayer.player[msg.sender].tournamentEntryFee[_tournamentID] >=libplayer.player[libtournaments.tournaments[_tournamentID].players[p]].tokenBalanceAddress);
                libplayer.player[libtournaments.tournaments[_tournamentID].players[p]].tokenBalanceAddress += libplayer.player[libtournaments.tournaments[_tournamentID].players[p]].tournamentEntryFee[_tournamentID];
                // }
            }    
        }

        //Remove this tournament from active list 
        // _removeFromActiveList(libtournaments, _tournamentID);
        // libtournaments.tournaments[_tournamentID].tokenBalanceForTournament = 0;
        
        libtournaments.tournaments[_tournamentID].status = 2;
        emit TournamentAction(now,msg.sender, _tournamentID, "Cancel Tournament");
    }
    
    /* ========Token OPERATIONS \ Deposit specified token to the Tournament based on Tournament ID=========================== */      
    function PayoutTokens(Libplayer storage libplayer,uint _amount, uint _tournamentID) internal returns (bool) {
             require(libplayer.player[msg.sender].tokenBalanceAddress - _amount >= 0);
             require (libplayer.player[msg.sender].tokenBalanceAddress - _amount <= libplayer.player[msg.sender].tokenBalanceAddress);
             libplayer.player[msg.sender].tokenBalanceAddress -= _amount;
    
            emit TokenActions(now, msg.sender, _amount, _tournamentID, "Pay Out");
            return true;
    }

    /* ========Global OPERATIONS \ set developer account============================== */     
    function _setadminAccounts(GlobalVars storage globalvars,address _admin, uint _maxdailyallowance,uint accounttype) external {
        //  0 - SMASH Token address  1 - developer 2 - allowancepool 3 - tournament seed pool 4 - set max daily allowance amount per player 5 - set one-time-signup TRX amount
       
        require (accounttype ==0 || accounttype ==1 || accounttype ==2 || accounttype ==3 || accounttype ==4 || accounttype ==5, "Invalid type");
        if(accounttype ==4){
            require(_maxdailyallowance>=0);
            globalvars.maxdailyallowance =  _maxdailyallowance; 
            emit Action(now, msg.sender, _maxdailyallowance, "Set Max Daily Allowance");
        } else if (accounttype ==5) {
             require(_maxdailyallowance>=0);
            globalvars.signupTRXamount =  _maxdailyallowance; 
            emit Action(now, msg.sender, _maxdailyallowance, "Set One-time-signup TRX amount");           
        }
        else{
            require(_admin != address(0));
            if (accounttype == 0){
               globalvars.tokenContract =  _admin; 
               emit SetDeveloperAccount(now,msg.sender, _admin ,"SMASH Token");
            } else if (accounttype == 1){
               globalvars.developerAccount =  _admin; 
               emit SetDeveloperAccount(now,msg.sender, _admin ,"Developer Account");
            } else if (accounttype == 2) {
               globalvars.allowanceAccount =  _admin;
               emit SetDeveloperAccount(now,msg.sender, _admin, "Allowance Pool Account");
            }else{
              globalvars.tournamentSeedAccount =  _admin;
              emit SetDeveloperAccount(now,msg.sender, _admin, "Tournament Seed Account");       
            }            
        }
    }

    /* ========Global OPERATIONS \ set developer account============================== */     
    function _setplayerinfo(Libplayer storage libplayer,address _player,uint _tokenamount, uint8 _getsignupallowance, uint8 _type) external {
        //  0 - tokenBalanceAddress;    1 - allowanceAmount; 2 - getsignupallowance;
        require (_type ==0 || _type ==1 || _type ==2, "Invalid type");
        if(_type ==0){
            /*adjust Player SMASH balance */
            require(_tokenamount>=0);
            libplayer.player[_player].tokenBalanceAddress = _tokenamount;
            emit Action(now, _player, _tokenamount, "Adjust SMASH Balance");
        }else if (_type ==1){
            /*adjust allowance amount*/
            require(_tokenamount>=0);
            libplayer.player[_player].allowanceAmount = _tokenamount;
            emit Action(now, _player, _tokenamount, "Adjust allowance amount");            
        }else{
            /*adjust allowance one-time-signup flag*/
            require (_getsignupallowance ==0 || _getsignupallowance ==1);
            libplayer.player[_player].getsignupallowance = _getsignupallowance;
            emit Action(now, _player, 0, "Adjust allowance one-time-signup flag");    
        }
    }
    
    function _distributeAllowanceBatch(GlobalVars storage globalvar,Libplayer storage libplayer,address[] _players, uint[] _amount, uint8 _isSignup) external {
        //isSignup 1 - One time signup Others - Daily allowance (0- triggered by cron job 2 - triggered by admin manually)        
        require (_players.length == _amount.length);
        uint amount;
       
        if (_isSignup ==1) {
            require(_players.length ==1,"For onetime signup, there should only have one player");
            require(_players[0] != address(0),"Invalid address");
            
            //Make sure this player can ONLY get one signup allowance - there is only one player at the array this time
            require(libplayer.player[_players[0]].getsignupallowance==0,"Sign up allowance already distributed to this player");            
            
            /* Maxinum allowance amount checking*/
            require(_amount[0]<=globalvar.maxdailyallowance,"Distributed allowance is too big");
            
            //make sure there is enough TRX at this contract - Owner account
            // require(address(this).balance>=globalvar.signupTRXamount,"no enough TRX remaining");
            // require(libplayer.player[msg.sender].trxBalanceAddress>=globalvar.signupTRXamount,"no enough TRX remaining");
      
            //Flag "getsignupallowance=1" for this player before the one-time-allowance distribution
            libplayer.player[_players[0]].getsignupallowance =1;
            
            libplayer.player[_players[0]].allowanceAmount = _amount[0]; 
            
 /*           //Send 10 TRX to this player from owner to active his account - TRX will be sent to new player via Javascript
            libplayer.player[msg.sender].trxBalanceAddress -= globalvar.signupTRXamount;  
            _players[0].transfer(globalvar.signupTRXamount);*/
            // libplayer.player[_players[0]].trxBalanceAddress = globalvar.signupTRXamount;  
        }else{
             /*make sure this cron schedule process only running one time every 24 hours*/
            if (_isSignup ==0){
                require (now >= globalvar.dailyallowanceruntime + 86400, "this process only running one time every 24 hours");            
                // globalvar.dailyallowanceruntime = now;   
                for (uint i = 0; i < _players.length; i++){
                    amount =  _amount[i];
                   /* Maxinum allowance amount checking*/
                    if (amount<=globalvar.maxdailyallowance && _players[i]!= address(0) ){
                       libplayer.player[_players[i]].allowanceAmount = amount; 
                    }
                 }                  
            } else{
                //manually distributed by admin
                require(_players[0] != address(0),"Invalid address");
                require(_players.length ==1,"For distribution manually, there should only have one player");
                require(_amount[0]<=globalvar.maxdailyallowance,"Distributed allowance is too big");
                libplayer.player[_players[0]].allowanceAmount = _amount[0]; 
            }
        }
 
         emit Action(now, _players[0], _amount[0], "distributeAllowanceBatch");
    }
 
    function _claimAllowance(GlobalVars storage globalvars,Libplayer storage libplayer) external returns (bool) {
        uint allowamount;
        allowamount =  libplayer.player[msg.sender].allowanceAmount;
    
        if (allowamount > 0 ) {
            uint todeveloper = allowamount * 2/10 ;
            uint totalamount = allowamount+ todeveloper;     
            
            require(libplayer.player[globalvars.allowanceAccount].tokenBalanceAddress - totalamount >= 0);
            require(libplayer.player[globalvars.allowanceAccount].tokenBalanceAddress - totalamount <= libplayer.player[globalvars.allowanceAccount].tokenBalanceAddress);
            require(libplayer.player[msg.sender].tokenBalanceAddress + allowamount >= libplayer.player[msg.sender].tokenBalanceAddress);
            require(libplayer.player[globalvars.developerAccount].tokenBalanceAddress + todeveloper >= libplayer.player[globalvars.developerAccount].tokenBalanceAddress);
            require(globalvars.allocationPaid + totalamount >=globalvars.allocationPaid);
            
            //reset allowance amount before the claim
             libplayer.player[msg.sender].allowanceAmount = 0;
             
            //Transfer from allowance pool to player account
            libplayer.player[globalvars.allowanceAccount].tokenBalanceAddress -= totalamount;
            globalvars.allocationPaid +=totalamount;
            
            libplayer.player[msg.sender].tokenBalanceAddress += allowamount; 
            
            //Transfer aditional 20% to developer account
            libplayer.player[globalvars.developerAccount].tokenBalanceAddress += todeveloper; 
            // tokenBalanceAddress[developerAccount]  += todeveloper; 
            // allowed[msg.sender].amount = 0;
        }
        emit Action(now, msg.sender , allowamount, "claimAllowance");
        return true;
    }

    /* ========Tournament OPERATIONS \ set tournament winners============================== */    
    function _distributePrizeBatch(Libplayer storage libplayer,LibTournament storage libtournaments,uint _tournamentID, address[] _players, uint[] _percent) internal {
        require (_players.length == _percent.length,"Invalid player/percent array");
        require (libtournaments.tournaments[_tournamentID].tokenBalanceForTournament >0, "There is no tokens at this tournament pool");
        // require (!libtournaments.tournaments[_tournamentID].isPrizeDistributed, "");
        
        // require(tournamentkeyusers[_tournamentID].creator == msg.sender || tournamentkeyusers[_tournamentID].administrator == msg.sender || tournamentkeyusers[_tournamentID].moderator == msg.sender, "Only tournament creator/moderator/administrator can set status.");
        // require(libtournaments.tournaments[_tournamentID].status >= TournamentLib.TournamentStatus.END, "Tournaent is NOT end yet.");
      
        uint totalPercent;
        bool isAnyInvalidAddress;
        for (uint k = 0; k < _percent.length; k++){
            totalPercent += _percent[k];
            if (_players[k]==address(0)){
                isAnyInvalidAddress = true;
                break;
            }
            
            if(!(libplayer.player[_players[k]].tournamentEntryFee[_tournamentID] > 0 || libtournaments.tournamentkeyusers[_tournamentID].creator == _players[k])){
                //This player is not at the participating player list of this tournament
                isAnyInvalidAddress = true;
                break;             
            }
        }    
        require(totalPercent ==100,"Total percent must be 100%");
        require (!isAnyInvalidAddress,"Found invalid address at the winner address list");
        
        uint  tokenBalanceForTournament = libtournaments.tournaments[_tournamentID].tokenBalanceForTournament;
        //Set the pool as 0 before the distribution - updated: keep the original pool amount
        // libtournaments.tournaments[_tournamentID].tokenBalanceForTournament =0;
        //Set status as 1 - Distributed
        libtournaments.tournaments[_tournamentID].status = 1;
        
        for (uint i = 0; i < _players.length; i++){
            uint amount = tokenBalanceForTournament * _percent[i]/100;
            // libplayer.player[_players[i]].allowanceAmount = amount;
            require(libplayer.player[_players[i]].tokenBalanceAddress + amount >= libplayer.player[_players[i]].tokenBalanceAddress);
            libplayer.player[_players[i]].tokenBalanceAddress += amount;
            // emit Action(now, _players[i] , amount, "distributePrize");
         }
         
        //Remove this tournament from active list 
        // _removeFromActiveList(libtournaments, _tournamentID);

         emit Action(now, msg.sender , 0, "distributePrizeBatch");
    }
 
  /* ========Tournament OPERATIONS \ remove tournament from active list============================== */      
/*    function _removeFromActiveList(LibTournament storage libtournaments,uint _tournamentID) internal {
        for (uint m = 0; m<=libtournaments.activeTournaments.length-1; m++){
           if (libtournaments.activeTournaments[m] == _tournamentID) {
               uint index = m;
               if (index < libtournaments.activeTournaments.length-1) {
                 libtournaments.activeTournaments[index] = libtournaments.activeTournaments[libtournaments.activeTournaments.length-1];
                 delete libtournaments.activeTournaments[libtournaments.activeTournaments.length-1];
                 libtournaments.activeTournaments.length--;              
               }else{
                  delete libtournaments.activeTournaments[libtournaments.activeTournaments.length-1]; 
                  if (libtournaments.activeTournaments.length > 1)  libtournaments.activeTournaments.length--; 
               }
           }
        }          
    }*/

}    
    