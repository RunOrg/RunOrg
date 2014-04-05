// POST /db/{db}/groups/create
// Groups / Create a group
// 
// Alpha @ 0.1.23
//
// `202 Accepted`, 
// [Delayed](/docs/#/concept/delayed.md).
// sometimes [Idempotent](/docs/#/concept/idempotent.md).
//
// Creates a new group. Initially empty. 
// 
// ### Request format
//     { "id" : <customid> | null,
//       "label" : <label> | null }
//  - `id` is an optional [custom identifier](/docs/#/types/custom-id.js).
//  - `label` is an optional [human-readable name](/docs/#/types/label.js).
//
// ### Response format
//     { "id" : <id>,
//       "at" : <clock> }

TEST("The response has valid return code and content type.", function(next) {
    var example = { "label" : "Board members" };

    var db = Query.mkdb();
    var token = Query.auth(db);
    var response = Test.query("POST",["db/",db,"/groups/create"],example,token).response();

    [
	Assert.areEqual(202, response.map('status')),
	Assert.isTrue(response.map('responseJSON'), "Response type is JSON")
    ].then(next);

});

// 
// The behaviour of the request depends on whether an identifier was provided: 
// **force-id** mode or **generate-id** mode. 
//
// # Force-id mode
// 
// RunOrg will attempt to create a group with that identifier, and do nothing if 
// the group already exists ([idempotent](/docs/#/concept/idempotent.md)
// request). 
//
// ### Example request
//     POST /db/0SNQc00211H/groups/create
//     Content-Type: application/json
// 
//     { "id": "board", 
//       "label": "Board members" }
//
// ### Example request
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "board",
//       "at" : [[2,218]] }

TEST("Group with forced id appears.", function(next) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var token = Query.auth(db);
    
    Test.query("POST",["db/",db,"/groups/create"],example,token).response().then(function(){

	var get = Test.query("GET",["db/",db,"/groups/",id,"/info"],token).result();
	
	[
	    Assert.areEqual({"id":id,"label":"Board members",count:0}, get)
	].then(next);

    });

});

TEST("New group with forced id created after deletion.", function(next) {
    Assert.fail();
});

// # Generate-id mode
// 
// RunOrg will create brand new group, with a brand new identifier. Running the
// request twice will create two groups.
// 
// ### Example request
//     POST /db/0SNQc00211H/groups/create
//     Content-Type: application/json
// 
//     { "label": "Members imported on Nov 1, 2013" }
//
// ### Example request
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "0SNQe0032JZ",
//       "at" : [[2,219]] }

TEST("Multiple creations create multiple groups.", function(next) {
    Assert.fail();
});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Assert.fail();
});

// ## Returns `400 Bad Request`
// - ... if the provided identifier is not a valid [custom 
//   identifier](/docs/#/types/custom-id.js)

TEST("Returns 400 when custom id is invalid.", function(next) {
    Assert.fail();
});

// ## Returns `400 Conflict`
// - ... if a group already exists with the provided identifier.

TEST("Returns 409 when the group exists.", function(next) {
    Assert.fail();
});

TEST("Returns 409 when re-creating the admin group.", function(next) {
    Assert.fail();
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not allow group creation,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
    Assert.fail();
});

// # Access restrictions
//
// Currently, anyone can create a group with a token for the corresponding database. 
// This is subject to change in future versions.
