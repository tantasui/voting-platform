module vote::vote {
  
    use sui::vec_map::{Self, VecMap};
    use std::string::String;
    use sui::event;
    use std::option;
    use sui::clock::{Self, Clock};

    // ==================== ERRORS ====================
    const EElectionNotActive: u64 = 1;
    const EElectionEnded: u64 = 2;
    const EAlreadyVoted: u64 = 3;
    const ECandidateNotFound: u64 = 4;
    const EElectionAlreadyStarted: u64 = 7;
    const EElectionAlreadyEnded: u64 = 8;
    const EVoterNotRegistered: u64 = 9;
    const ECandidateAlreadyRegistered: u64 = 10;
    const EVoterAlreadyRegistered: u64 = 11;
    const EInvalidTime: u64 = 12;

    // ==================== STRUCTS ====================
    
    // Election object 
    public struct Election has key {
        id: UID,
        name: String,
        description: String,
        start_time: u64,
        end_time: u64,
        is_active: bool,
        is_ended: bool,
        candidate_addresses: vector<address>,
        candidate_info: VecMap<address, CandidateInfo>,
        vote_counts: VecMap<address, u64>,
        voters: VecMap<address, bool>,
        total_votes: u64, 
        winner: option::Option<address>
    }

    // Candidate info
    public struct CandidateInfo has copy, store, drop {
        address: address,
        name: String,
        description: String,
        pfp: String,
    }

    // Vote pass object 
    public struct VotePass has key, store {
        id: UID,
        name: String,
        voter_address: address,
        election_id: ID,
        has_voted: bool,
        voted_for: address,
    }

    // Candidate pass object (kept for future use)
    #[allow(unused_field)]
    public struct CandidatePass has key, store {
        id: UID,
        name: String,
        candidate_address: address,
        election_id: ID,
        description: String,
        used: bool,
        pfp: String,
    }

    // Election admin capability
    public struct ElectionAdminCap has key, store {
        id: UID,
        election_id: ID,
    }

    // Vote object
    public struct Vote has key, store {
        id: UID,
        candidate_address: address,
        election_id: ID,
        voter_address: address,
        timestamp: u64,
    }

    // Election result object
    public struct ElectionResult has key, store {
        id: UID,
        election_id: ID,
        election_name: String,
        election_description: String,
        winner_address: address,
        winner_name: String,
        winner_description: String,
        winner_votes: u64,
        winner_pfp: String,
        total_votes: u64,
        end_time: u64,
        all_results: VecMap<address, u64>
    }

    // ==================== EVENTS ====================
    
    // Election created event
    public struct ElectionCreatedEvent has copy, drop {
        election_id: ID,
        creator: address,
        name: String,
        candidate_addresses: vector<address>,
        start_time: u64,
        end_time: u64,
        timestamp: u64,
    }

    // Candidate registered event
    public struct CandidateRegisteredEvent has copy, drop {
        election_id: ID,
        candidate_address: address,
        name: String,
        timestamp: u64,
    }

    // Vote casted event
    public struct VoteCastedEvent has copy, drop {
        election_id: ID,
        candidate_address: address,
        voter_address: address,
        timestamp: u64,
    }

    // Voter registered event 
    public struct VoterRegisteredEvent has copy, drop {
        election_id: ID,
        voter_address: address,
        timestamp: u64,
    }

    // Election ended event
    public struct ElectionEndedEvent has copy, drop {
        election_id: ID,
        winner_address: address,
        winner_name: String,
        winner_votes: u64,
        total_votes: u64,
        timestamp: u64,
    }

    // Election started event
    public struct ElectionStartedEvent has copy, drop {
        election_id: ID,
        name: String,
        description: String,
        start_time: u64,
        end_time: u64,
        timestamp: u64,
    }

    // ==================== MAIN FUNCTIONS ====================

    // Create election function
    #[allow(lint(public_entry))]
    public entry fun create_election(
        name: String,
        description: String,
        start_time: u64,
        end_time: u64,
        candidate_addresses: vector<address>,
        candidate_names: vector<String>,
        candidate_descriptions: vector<String>,
        candidate_pfps: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(end_time > start_time, EInvalidTime);
        
        let election_uid = object::new(ctx);
        let election_id = object::uid_to_inner(&election_uid);
        let current_time = clock::timestamp_ms(clock) / 1000;
        let is_active = current_time >= start_time;
        
        // Initialize candidate info and vote counts
      let mut candidate_info = vec_map::empty();
      let mut vote_counts = vec_map::empty();

        let len = candidate_addresses.length();
        let  mut i = 0;
        while (i < len) {
            let addr = *candidate_addresses.borrow(i);
            let info = CandidateInfo {
                address: addr,
                name: *candidate_names.borrow(i),
                description: *candidate_descriptions.borrow(i),
                pfp: *candidate_pfps.borrow(i),
            };
            vec_map::insert(&mut candidate_info, addr, info);
            vec_map::insert(&mut vote_counts, addr, 0);
            i = i + 1;
        };

        let election = Election {
            id: election_uid,
            name,
            description,
            start_time,
            end_time,
            is_active,
            is_ended: false,
            candidate_addresses,
            candidate_info,
            vote_counts,
            voters: vec_map::empty<address, bool>(),
            total_votes: 0,
            winner: option::none(),
        };

        // Create admin capability
        let admin_cap = ElectionAdminCap {
            id: object::new(ctx),
            election_id,
        };

        // Emit event
        event::emit(ElectionCreatedEvent {
            election_id,
            creator: ctx.sender(),
            name: election.name,
            candidate_addresses: election.candidate_addresses,
            start_time,
            end_time,
            timestamp: current_time,
        });
        
        transfer::transfer(admin_cap, ctx.sender());
        transfer::share_object(election);
    }

    // Register candidate function
    #[allow(lint(public_entry))]
    public entry fun register_candidate(
        election: &mut Election,
        _: &ElectionAdminCap,
        candidate_address: address,
        name: String,
        description: String,
        pfp: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(!election.is_ended, EElectionEnded);
        assert!(!vec_map::contains(&election.candidate_info, &candidate_address), ECandidateAlreadyRegistered);
        
        let candidate_info = CandidateInfo {
            name,
            description,
            pfp,
            address: candidate_address,
        };
        
        election.candidate_addresses.push_back(candidate_address);
        vec_map::insert(&mut election.candidate_info, candidate_address, candidate_info);
        vec_map::insert(&mut election.vote_counts, candidate_address, 0);
        
        let election_id = object::uid_to_inner(&election.id);
        
        event::emit(CandidateRegisteredEvent {
            election_id,
            candidate_address,
            name,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
    }

    // Register voter function
    #[allow(lint(public_entry))]
    public entry fun register_voter(
        election: &mut Election,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let voter_address = ctx.sender();
        assert!(!vec_map::contains(&election.voters, &voter_address), EVoterAlreadyRegistered);
        assert!(!election.is_ended, EElectionEnded);
        
        vec_map::insert(&mut election.voters, voter_address, false);
        
        let election_id = object::uid_to_inner(&election.id);
        
        // Create and transfer vote pass
        let vote_pass = VotePass {
            id: object::new(ctx),
            name: election.name,
            voter_address,
            election_id,
            has_voted: false,
            voted_for: @0x0,
        };
        
        event::emit(VoterRegisteredEvent {
            election_id,
            voter_address,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
        
        transfer::transfer(vote_pass, voter_address);
    }

    // Cast vote function
    #[allow(lint(public_entry))]
    public entry fun cast_vote(
        election: &mut Election,
        vote_pass: &mut VotePass,
        candidate_address: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let voter_address = ctx.sender();
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        assert!(election.is_active, EElectionNotActive);
        assert!(!election.is_ended, EElectionEnded);
        assert!(current_time >= election.start_time && current_time <= election.end_time, EElectionNotActive);
        assert!(vec_map::contains(&election.voters, &voter_address), EVoterNotRegistered);
        assert!(!vote_pass.has_voted, EAlreadyVoted);
        assert!(vec_map::contains(&election.candidate_info, &candidate_address), ECandidateNotFound);
        
        // Update vote count
        let current_votes = vec_map::get_mut(&mut election.vote_counts, &candidate_address);
        *current_votes = *current_votes + 1;
        
        // Mark voter as voted
        let voter_status = vec_map::get_mut(&mut election.voters, &voter_address);
        *voter_status = true;
        
        // Update vote pass
        vote_pass.has_voted = true;
        vote_pass.voted_for = candidate_address;
        
        // Increment total votes
        election.total_votes = election.total_votes + 1;
        
        let election_id = object::uid_to_inner(&election.id);
        
        // Create vote record
        let vote = Vote {
            id: object::new(ctx),
            candidate_address,
            election_id,
            voter_address,
            timestamp: current_time,
        };
        
        event::emit(VoteCastedEvent {
            election_id,
            candidate_address,
            voter_address,
            timestamp: current_time,
        });
        
        transfer::transfer(vote, voter_address);
    }

    // End election function
    #[allow(lint(public_entry))]
    public entry fun end_election(
        election: &mut Election,
        _admin_cap: &ElectionAdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!election.is_ended, EElectionAlreadyEnded);
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        election.is_ended = true;
        election.is_active = false;
        
 // Calculate winner
let mut winner_address = @0x0;
let mut max_votes = 0u64;

let len = election.candidate_addresses.length();
let mut i = 0;
while (i < len) {
    let addr = *election.candidate_addresses.borrow(i);
    let votes = *vec_map::get(&election.vote_counts, &addr);
    if (votes > max_votes) {
        max_votes = votes;
        winner_address = addr;
    };
    i = i + 1;
};

election.winner = option::some(winner_address);

// Copy winner_address to a new variable to avoid borrow conflict
let winner_addr_copy = winner_address;
let winner_info = vec_map::get(&election.candidate_info, &winner_addr_copy);
let election_id = object::uid_to_inner(&election.id);

// Create election result
let result = ElectionResult {
    id: object::new(ctx),
    election_id,
    election_name: election.name,
    election_description: election.description,
    winner_address: winner_info.address,
    winner_name: winner_info.name,
    winner_description: winner_info.description,
    winner_votes: max_votes,
    winner_pfp: winner_info.pfp,
    total_votes: election.total_votes,
    end_time: election.end_time,
    all_results: election.vote_counts,
};

event::emit(ElectionEndedEvent {
    election_id,
    winner_address: winner_info.address,  // Also use winner_info.address here
    winner_name: winner_info.name,
    winner_votes: max_votes,
    total_votes: election.total_votes,
    timestamp: current_time,
});
        
        transfer::share_object(result);
    }

    // Start election function
    #[allow(lint(public_entry))]
    public entry fun start_election(
        election: &mut Election,
        _admin_cap: &ElectionAdminCap,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        assert!(!election.is_active, EElectionAlreadyStarted);
        assert!(!election.is_ended, EElectionEnded);
        
        election.is_active = true;
        let current_time = clock::timestamp_ms(clock) / 1000;
        let election_id = object::uid_to_inner(&election.id);
        
        event::emit(ElectionStartedEvent {
            election_id,
            name: election.name,
            description: election.description,
            start_time: election.start_time,
            end_time: election.end_time,
            timestamp: current_time,
        });
    }

    // ==================== HELPER FUNCTIONS ====================

    // Get election info
    public fun get_election_info(election: &Election): (String, String, u64, u64, bool, bool, u64) {
        (
            election.name,
            election.description,
            election.start_time,
            election.end_time,
            election.is_active,
            election.is_ended,
            election.total_votes
        )
    }

    // Get candidate info
 public fun get_candidate_info(election: &Election, candidate_address: address): (address, String, String, String, u64) {
    assert!(vec_map::contains(&election.candidate_info, &candidate_address), ECandidateNotFound);
    
    let info = vec_map::get(&election.candidate_info, &candidate_address);
    let votes = vec_map::get(&election.vote_counts, &candidate_address);
    
    (info.address, info.name, info.description, info.pfp, *votes)
}

    // Get voter status
    public fun get_voter_status(election: &Election, voter_address: address): bool {
        if (vec_map::contains(&election.voters, &voter_address)) {
            *vec_map::get(&election.voters, &voter_address)
        } else {
            false
        }
    }

    // Get current results
    public fun get_results(election: &Election): (vector<address>, vector<u64>, u64) {
        let addresses = election.candidate_addresses;
        let mut votes = vector::empty<u64>();
        
        let len = addresses.length();
        let mut i = 0;
        while (i < len) {
            let addr = *addresses.borrow(i);
            let vote_count = *vec_map::get(&election.vote_counts, &addr);
            votes.push_back(vote_count);
            i = i + 1;
        };
        
        (addresses, votes, election.total_votes)
    }

    // Get winner
    public fun get_winner(election: &Election): option::Option<address> {
        election.winner
    }

    // Get all candidates
    public fun get_all_candidates(election: &Election): vector<address> {
        election.candidate_addresses
    }

    // Check if voter is registered
    public fun is_voter_registered(election: &Election, voter_address: address): bool {
        vec_map::contains(&election.voters, &voter_address)
    }

    // ==================== ADDITIONAL FUNCTIONS ====================

    // Extend election time
    #[allow(lint(public_entry))]
    public entry fun extend_election_time(
        election: &mut Election,
        _admin_cap: &ElectionAdminCap,
        new_end_time: u64,
        _ctx: &mut TxContext
    ) {
        assert!(!election.is_ended, EElectionEnded);
        assert!(new_end_time > election.end_time, EInvalidTime);
        
        election.end_time = new_end_time;
    }

    // Remove candidate (before election starts)
    #[allow(lint(public_entry))]
    public entry fun remove_candidate(
        election: &mut Election,
        _admin_cap: &ElectionAdminCap,
        candidate_address: address,
        _ctx: &mut TxContext
    ) {
        assert!(!election.is_active, EElectionAlreadyStarted);
        assert!(vec_map::contains(&election.candidate_info, &candidate_address), ECandidateNotFound);
        
        vec_map::remove(&mut election.candidate_info, &candidate_address);
        vec_map::remove(&mut election.vote_counts, &candidate_address);
        
        // Remove from candidate_addresses vector
        let (found, index) = election.candidate_addresses.index_of(&candidate_address);
        if (found) {
            election.candidate_addresses.remove(index);
        };
    }

    // Deregister voter (before voting)
    #[allow(lint(public_entry))]
    public entry fun deregister_voter(
        election: &mut Election,
        voter_address: address,
        _ctx: &mut TxContext
    ) {
        assert!(vec_map::contains(&election.voters, &voter_address), EVoterNotRegistered);
        let has_voted = *vec_map::get(&election.voters, &voter_address);
        assert!(!has_voted, EAlreadyVoted);
        
        vec_map::remove(&mut election.voters, &voter_address);
    }
}