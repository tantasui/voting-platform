module vote::vote;
use sui::vec_map::VecMap;
use std::string::String;
use sui::event;
use std::option::Option;
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

//election created event













//Candidate registered event

//Vote casted event

//Voter registered event 

//election ended event

//election started event




// create_election() function

// register_candidate() function

// register_voter() function

// cast_vote() function

//end_election() function

//start_election() function

//Helper functions


//calculate_results() function

//get_election() function

//get_candidate() function

//get_voter() function

//get_all_voters_for_a_candidate() function

//get_all_voters_for_an_election() function

//get_election_results() functionn

//delete_candidate() / remove_candidate()



//deregister_voter()


//withdraw_vote() (optional)


//extend_election_time()


//pause_election() (optional)

