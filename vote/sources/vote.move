module vote::vote;
use sui::vec_map::VecMap;
use std::string::String;
use sui::event;
use std::option::Option;
use sui::address;
use sui::object;
 
const EAlreadyRegistered: u64 = 1;
const EVoterNotFound: u64 = 2;

//Election object
public struct Election has key {
    id: UID,
    name: String,
    description: String,
    start_time: u64,
    end_time: u64,
    is_active: bool,
    is_ended: bool,
    condidate_addresses: vector<address>,
    candidate_info: VecMap<address, Candidateinfo>,
    vote_counts: VecMap<address, bool>,
    voters: VecMap<address, bool>,
    total_votes: u64, 
    winner: Option<address>
     // candidate_id -> candidate_address
}


//candidate object
public struct Candidateinfo has copy, store, drop {
    
    name: String,
    description: String,
    pfp: String,
}
//voter object
public struct Voter has key, store {
    id: UID,
    voter_address: address,
    election_id: u64,
    has_voted: bool,
    voted_for: u64, // candidate_id
}
 
//vote object
public struct Vote has key, store {
    id: UID,
    candidate_id: u64,
    election_id: u64,
    voter_address: address,
    timestamp: u64,
}

//election result object
public struct ElectionResult has key, store {
    id: UID,
    election_id: u64,
    election_name: String,
    election_description: String,
    winner_address: address,
    winner_name: u64, // candidate_id
    winner_description: String,
    winner_votes: u64,
    winner_pfp: String,
    total_votes: u64,
    end_time: u64,
    all_results: VecMap<address, u64>
     // candidate_id -> vote_count
}


//election admin object
public struct ElectionAdminCap has key, store {
    id: UID,
    election_id: ID,
}

//initialize  function

//vote passobject 
public struct VotePass has key, store {
    id: UID,
    name: String,
    voter_address: address,
    election_id: u64,
    has_voted: bool,
    voted_for: u64, // candidate_id
}

//candidate pass object 
public struct CandidatePass has key, store {
    id: UID,
    name: String,
    candidate_address: address,
    election_id: u64,
    description: String,
    used: bool,
    pfp: String,
}

// Register a new voter for an election
public entry fun register_voter(
    _admin_cap: &ElectionAdminCap,
    election: &mut Election,
    voter_address: address,
    name: String,
    ctx: &mut TxContext
) {
    assert!(!election.voters.contains(&voter_address), EAlreadyRegistered);
    election.voters.insert(voter_address, false);

    let election_id_obj = object::id(election);
    let election_addr = object::id_to_address(&election_id_obj);
    let election_id_u64 = (address::to_u256(election_addr) as u64);

    let vote_pass = VotePass {
        id : object::new(ctx),
        name,
        voter_address,
        has_voted: false,
        voted_for: 0, // 0 indicates no vote cast yet
        election_id: election_id_u64, 
    };

    transfer::transfer(vote_pass, voter_address)
}

// Remove a voter from an election
public entry fun deregister_voter(
    _admin_cap: &ElectionAdminCap,
    election: &mut Election,
    voter_address: address,
) {
    assert!(election.voters.contains(&voter_address), EVoterNotFound);

    election.voters.remove(&voter_address);
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