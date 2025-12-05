module vote::vote;
use sui::vec_map::VecMap;
use std::string::String;
use sui::event;
//Election object 
public struct Election has key {
    id: UID,
    name: String,
    description: String,
    start_time: u64,
    end_time: u64,
    is_active: bool,
    is_ended: bool,
}


//candidate object
public struct Candidate has key, store {
    id: UID,
    name: String,
    description: String,
    election_id: u64,
    candidate_address: address,
    pfp: u64,
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
    total_votes: u64,
    winner: u64, // candidate_id
    results: VecMap<u64, u64>,


     // candidate_id -> vote_count
}


//election admin object
public struct ElectionAdminCap has key {
    id: UID,
    admin_address: address,
}

//initialize  function

//vote passobject 
public struct VotePass has key {
    id: UID,
    voter_address: address,
    election_id: u64,
    has_voted: bool,
    voted_for: u64, // candidate_id
}

//candidate pass object 
public struct CandidatePass has key {
    id: UID,
    name: String,
    candidate_address: address,
    election_id: u64,
    pfp: u64,
    description: String,
    used: bool,


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

