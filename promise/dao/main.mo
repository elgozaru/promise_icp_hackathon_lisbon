import Result "mo:base/Result";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Hash "mo:base/Hash";
import Types "types";
//import tokenCanister "canister:promise_token";
//import webpageCanister "canister:promise_webpage";

import { now } = "mo:base/Time";
import { setTimer; recurringTimer } = "mo:base/Timer";

actor Reminder {

  let solarYearSeconds = 356_925_216;

  private func remind() : async () {
    print("End of the challenge!");
  };

  ignore setTimer<system>(#seconds (solarYearSeconds - abs(now() / 1_000_000_000) % solarYearSeconds),
    func () : async () {
      ignore recurringTimer<system>(#seconds solarYearSeconds, remind);
      await remind();
  });
}

actor {

        type Result<A, B> = Result.Result<A, B>;
        type Member = Types.Member;
        type ProposalContent = Types.ProposalContent;
        type ProposalId = Types.ProposalId;
        type Proposal = Types.Proposal;
        type Role = Types.Role;
        type Vote = Types.Vote;
        type DAOStats = Types.DAOStats;
        type HttpRequest = Types.HttpRequest;
        type HttpResponse = Types.HttpResponse;

        // The principal of the Webpage canister associated with this DAO canister (needs to be updated with the ID of your Webpage canister)
        stable let canisterIdWebpage : Principal = Principal.fromText("u72sn-7aaaa-aaaab-qadkq-cai");
        
        stable var manifesto : Text = "This is the incentive pool for people taking on pushup challenges";
        stable let name = "Promise";

        var incentives : Buffer.Buffer<Text> = Buffer.Buffer<Text>(2); 
        incentives.add("#1 : Do 10 pushups and get 10 points");
        incentives.add("#2 : Do 30 pushups in a row and get 50 points");
        incentives.add("#3 : DO 15 pushups on one hand and get 60 points");
        incentives.add("#4 : Do 100 pushups within 3min and get 80 points");
        

        let logo : Text = "";

        let members = HashMap.HashMap<Principal, Types.Member>(1, Principal.equal, Principal.hash);

        // Add Initial mentor for DAO
        let initialAdmin : Types.Member = { 
                                                name = "motoko_bootcamp"; 
                                                role = #Admin; 
                                           };
        members.put( Principal.fromText("nkqop-siaaa-aaaaj-qa3qq-cai"), initialAdmin );

        var nextProposalId : ProposalId = 0;
        let proposals = HashMap.HashMap<ProposalId, Proposal>(0, Nat.equal, Hash.hash );
        
        let tokenCanister = actor("jaamb-mqaaa-aaaaj-qa3ka-cai") : actor { // actor("jaamb-mqaaa-aaaaj-qa3ka-cai") : actor {
                mint : shared (owner : Principal, amount : Nat) -> async Result<(), Text>;
                burn : shared (owner : Principal, amount : Nat) -> async Result<(), Text>;
                balanceOf : shared (owner : Principal) -> async Nat;
        };

        let webpageCanister = actor("6mce5-laaaa-aaaab-qacsq-cai") : actor {
                setManifesto : shared (newManifesto : Text) -> async Result<(), Text>;
        };

        // Returns the name of the DAO
        public shared query func getName() : async Text {
                return name;
        };

        // Returns the manifesto of the DAO
        public shared query func getManifesto() : async Text {
                return manifesto;
        };

        // Returns the Principal ID of the Webpage canister associated with this DAO canister
        public query func getIdWebpage() : async Principal {
                return canisterIdWebpage;
        };

        public query func getStats() : async DAOStats {

                return ({
                        name;
                        manifesto;
                        incentives = Buffer.toArray(incentives);
                        members = Iter.toArray(Iter.map<Member, Text>(members.vals(), func(member : Member) { member.name }));
                        logo;
                        numberOfMembers = members.size();
                });
        };

        // Returns the incentives of the DAO
        public shared query func getIncentives() : async [Text] {
                return Buffer.toArray<Text>(incentives);
        };

        // Register a new member in the DAO with the given name and principal of the caller
        // Airdrop 10 MBC tokens to the new member
        // New members are always Challenger
        // Returns an error if the member already exists
        public shared ({ caller }) func registerMember(member : Member) : async Result<(), Text> {
                if(Principal.isAnonymous(caller)){
                // We don't want to register the anonymous identity
                        return #err("Cannot register member with the anonymous identity");
                };

                let optFoundMember : ?Member = members.get(caller);
                switch(optFoundMember) {
                // Check if n is null
                case(null){
                        members.put(caller, member);
                        // TODO : mint 10 MBT for new member
                        let mintResult = await tokenCanister.mint(caller, 10); 

                        // TODO : Get a deposit address for the new member and store it for future withdrawal
                        return mintResult;
                };
                case(? optFoundMember){ return #err("Member already exists"); };
                }
        };

        
        // Code to get AccountID from external ID
        public shared(msg) func getDepositAddress(): async Blob {
                Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(msg.caller));
        };


        // Code to get AccountID from external ID
        public func getDepositAddress(caller : Principal): async Blob {
                Account.accountIdentifier(Principal.fromActor(this), Account.principalToSubaccount(caller));
        };

        // Pool Address 
        // Account.accountIdentifier(Principal.fromActor(this), Account.defaultSubaccount());


        public shared(caller) func claimBounty(): async Blob {
                // TODO : Verify member is registered and holds assets, then get his account_id
                let account_id : Blob = getDepositAddress(caller)

                // TODO : Calculate amount according to pool distribution result
                let amount : Nat32 = 0;

                withdrawIcp(caller, amount, account_id);
        }

        private func withdrawIcp(caller: Principal, amount: Nat, account_id: Blob) : async T.WithdrawReceipt {
                Debug.print("Withdraw...");

                // remove withdrawal amount from book
                switch (book.removeTokens(caller, ledger, amount+icp_fee)){
                    case(null){
                        return #Err(#BalanceLow)
                    };
                    case _ {};
                };

                // Transfer amount back to user
                let icp_reciept =  await Ledger.transfer({
                    memo: Nat64    = 0;
                    from_subaccount = ?Account.defaultSubaccount();
                    to = account_id;
                    amount = { e8s = Nat64.fromNat(amount + icp_fee) };
                    fee = { e8s = Nat64.fromNat(icp_fee) };
                    created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(Time.now())) };
                });

                switch icp_reciept {
                    case (#Err e) {
                        // add tokens back to user account balance
                        book.addTokens(caller,ledger,amount+icp_fee);
                        return #Err(#TransferFailure);
                    };
                    case _ {};
                };
                #Ok(amount)
    };

        // Get the member with the given principal
        // Returns an error if the member does not exist
        public query func getMember(p : Principal) : async Result<Member, Text> {
                switch( members.get(p) ) {
                        // Check if n is null
                        case(null){ return #err("Member not found"); };
                        case(? optFoundMember){ return #ok(optFoundMember); };
                }
        };    
        
        // this function takes no parameters and returns the list of members of your DAO as an Array
        public query func getAllMembers() : async [Member] {
                return Iter.toArray<(Member)>(members.vals());
        };

        // this function takes no parameters and returns the number of members of your DAO as a Nat.
        public query func numberOfMembers() : async Nat {
                return members.size();
        };

        func _verifyMemberRole(principal : Principal, role : Role) : Result<Member, Text> {
                switch( members.get(principal) ) {
                        // Check if n is null
                        case(null){ 
                                Debug.print("member not found"); 
                                return #err("Member not found");
                        };
                        case(? optFoundMember){
                                if(optFoundMember.role != role) {
                                        Debug.print("unauthorized member role"); 
                                        return #err("unauthorized member role");
                                };
                                return #ok(optFoundMember); 
                        };
                }
        };

        // Create a new proposal and returns its id
        // Returns an error if the caller is not a mentor or doesn't own at least 1 MBC token
        public shared ({ caller }) func createProposal(content : ProposalContent) : async Result<ProposalId, Text> {
                let resultVerifiedMember : Result<Member, Text> = _verifyMemberRole(caller, #Admin);
                //assertOk( resultVerifiedMember );
                if( Result.isErr(resultVerifiedMember) ) {
                        return #err("The caller is not a Admin - cannot create a proposal");
                };

                switch( members.get(caller) ) {
                case(null) { return #err("The caller does not have enough tokens to create a proposal"); };
                case(? member) {
                        //let balance = await tokenCanister.balanceOf(caller);
                        if ( Result.isErr( await tokenCanister.burn(caller, 1) ) ) {
                                return #err("The caller does not have enough tokens to create a proposal");
                        };
                        // Create the proposal and burn the tokens
                        let proposal : Proposal = {
                                id = nextProposalId;
                                content;
                                creator = caller;
                                created = Time.now();
                                executed = null;
                                votes = [];
                                voteScore = 0;
                                status = #Open;
                        };
                        proposals.put(nextProposalId, proposal);
                        nextProposalId += 1;
                        
                        return #ok(nextProposalId - 1);
                };
                };
        };

        // Get the proposal with the given id
        // Returns an error if the proposal does not exist
        public query func getProposal(id : ProposalId) : async Result<Proposal, Text> {
                switch(proposals.get(id)) {
                        case(null) { return #err("Proposal doesn't exist"); };
                        case(? proposal) { return #ok(proposal); };
                };
        };

        // Returns all the proposals
        public query func getAllProposal() : async [Proposal] {
                return Iter.toArray(proposals.vals());
        };

        // Vote for the given proposal
        // Returns an error if the proposal does not exist or the member is not allowed to vote
        public shared ({ caller }) func voteProposal(proposalId : ProposalId, vote : Vote) : async Result<(), Text> {

                // Check if the caller is a member of the DAO
                switch (members.get(caller)) {
                case (null) {
                        return #err("The caller is not a member - cannot vote one proposal");
                };
                case (?member) {
                        if( member.role == #Challenger ) {
                                return #err("The caller is unathorized - cannot vote one proposal");
                        };
                        
                        // Check if the proposal exists
                        switch (proposals.get(proposalId)) {
                        case (null) {
                                return #err("The proposal does not exist");
                        };
                        case (?proposal) {
                                // Check if the proposal is open for voting
                                if (proposal.status != #Open) {
                                return #err("The proposal is not open for voting");
                                };
                                // Check if the caller has already voted
                                if (_hasVoted(proposal, caller)) {
                                return #err("The caller has already voted on this proposal");
                                };
                                let balance = await tokenCanister.balanceOf(caller);
                                let multiplierVote = switch (vote.yesOrNo) {
                                        case (true) { 1 };
                                        case (false) { -1 };
                                };
                                let multiplierRole = switch (member.role) {
                                        case (#AssetHolder) { 1 };
                                        case (#Admin) { 5 };
                                        case (#Challenger) { 0 };
                                };
                                let votingPower = balance * multiplierVote * multiplierRole;
                                let newVoteScore = proposal.voteScore + votingPower;
                                var newExecuted : ?Time.Time = null;
                                let newVote : Vote = {
                                                        member = caller;
                                                        votingPower = Int.abs(votingPower);
                                                        yesOrNo = vote.yesOrNo;
                                                };
                                var newVotes : Buffer.Buffer<Vote> = Buffer.fromArray<Vote>(proposal.votes);//.append( Buffer.fromArray<Vote>([newVote]) );
                                newVotes.add(newVote);

                                let newStatus = if (newVoteScore >= 100) {
                                        #Accepted;
                                } else if (newVoteScore <= -100) {
                                        #Rejected;
                                } else {
                                        #Open;
                                };
                                switch (newStatus) {
                                        case (#Accepted) {
                                                let resultExec : Result<(), Text> = await _executeProposal(proposal.content);
                                                if( Result.isErr( resultExec ) ) {
                                                        return resultExec;
                                                };
                                                newExecuted := ?Time.now();
                                        };
                                        case (_) { return #ok(); };
                                };
                                
                                let newProposal : Proposal = {
                                        id = proposal.id;
                                        content = proposal.content;
                                        creator = proposal.creator;
                                        created = proposal.created;
                                        executed = newExecuted;
                                        votes = Buffer.toArray(newVotes);
                                        voteScore = newVoteScore;
                                        status = newStatus;
                                };
                                proposals.put(proposal.id, newProposal);
                                return #ok();
                        };
                        };
                };
                };
        };

        func _hasVoted(proposal : Proposal, member : Principal) : Bool {
                return Array.find<Vote>(
                proposal.votes,
                func(vote : Vote) {
                        return vote.member == member;
                },
                ) != null;
        };

        func _executeProposal(content : ProposalContent) : async Result<(), Text> {
                switch (content) {
                case (#ChangeManifesto(newManifesto)) {
                        manifesto := newManifesto;
                        return await webpageCanister.setManifesto(newManifesto);
                        //return #ok();
                };
                case (#AddGoal(newGoal)) {
                        incentives.add(newGoal);
                        return #ok();
                };
                case (#AddAdmin(principal)) {
                        switch( members.get(principal) ) {
                        // Check if n is null
                        case(null){ return #err("Admin member not found - cannot execute proposal"); };
                        case(? optFoundMember){
                                if(optFoundMember.role == #AssetHolder) {
                                        let mentorMember : Member = { 
                                                                        name = optFoundMember.name; 
                                                                        role = #Admin; 
                                                                    };
                                        members.put(principal, mentorMember );
                                        return #ok();
                                };
                                return #err("Member is not graduate or already has mentor role - cannot execute proposal");
                        };
                        }
                };
                };
        };

};
