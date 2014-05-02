// POST /db/{db}/groups
// Groups / Create a group
// 
// Beta @ 0.9.0
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

var example = { "label" : "Board members" };

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth)
	.assertStatus(202).assertIsJson();

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
//     POST /db/0SNQc00211H/groups
//     Content-Type: application/json
// 
//     { "id": "board", 
//       "label": "Board members" }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "board",
//       "at" : [[2,218]] }

TEST("Group with forced id appears.", function(Query) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).then(function() {
	var get = Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d) { return d; });
	var expected = {
	    "id":id,
	    "label":"Board members",
	    "access":["view","list","admin","moderate"],
	    "count":0,
	    "audience": {}
	};
	return Assert.areEqual(expected, get);
    });

});

TEST("New group with forced id created after deletion.", function(Query) {

    var id = "board";
    var example = { "id" : id, "label" : "Broad members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).then(function() {

	return Query.del(["db/",db,"/groups/",id],auth).then(function(){

	    example.label = "Board members";

	    return Query.post(["db/",db,"/groups"],example,auth).then(function(){
		var get = Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d) { return d; });
		var expected = {
		    "id":id,
		    "label":"Board members",
		    "access":["view","list","admin","moderate"],
		    "count":0,
		    "audience": {}
		};
		return Assert.areEqual(expected, get);
	    });
	});
    });
});

// # Generate-id mode
// 
// RunOrg will create brand new group, with a brand new identifier. Running the
// request twice will create two groups.
// 
// ### Example request
//     POST /db/0SNQc00211H/groups
//     Content-Type: application/json
// 
//     { "label": "Members imported on Nov 1, 2013" }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
// 
//     { "id" : "0SNQe0032JZ",
//       "at" : [[2,219]] }

TEST("Multiple creations create multiple groups.", function(Query) {

    var example = { "label" : "Sample group" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id1 = Query.post(["db/",db,"/groups"],example,auth).id();
    var id2 = Query.post(["db/",db,"/groups"],example,auth).id();

    var get1 = Query.get(["db/",db,"/groups/",id1,"/info"],auth).then(function(d) { return d; });
    var get2 = Query.get(["db/",db,"/groups/",id2,"/info"],auth).then(function(d) { return d; });

    var expected1 = {
	"id":id1,
	"label":"Sample group",
	"access":["view","list","admin","moderate"],
	"count":0,
	"audience": {}
    };

    var expected2 = {
	"id":id2,
	"label":"Sample group",
	"access":["view","list","admin","moderate"],
	"count":0,
	"audience": {}
    };
    
    return $.when(
	Assert.notEqual(id1, id2),
	Assert.areEqual(expected1, get1),
	Assert.areEqual(expected2, get2)
    );
	    
});

// # Errors
//
// ## Returns `400 Bad Request`
// - ... if the provided identifier is not a valid [custom 
//   identifier](/docs/#/types/custom-id.js)

TEST("Returns 400 when custom id is invalid.", function(Query) {

    var ex1 = { "id": "a-b", "label" : "Invalid character" };
    var ex2 = { "id": "0123456789a", "label" : "Too long" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return $.when(
	Query.post(["db/",db,"/groups"],ex1,auth).assertStatus(400),
	Query.post(["db/",db,"/groups"],ex2,auth).assertStatus(400)
    );
    
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match the `as` contact.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups"],example,{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);
});

// ## Returns `403 Forbidden` 
// - ... if the provided token does not allow creating groups.

TEST("Returns 403 creating groups is not allowed.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db, false); 
    return Query.post(["db/",db,"/groups"],example,auth).assertStatus(403);
});
 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/01234567890/groups"],example).assertStatus(404);
});

// ## Returns `409 Conflict`
// - ... if a group already exists with the provided identifier.

TEST("Returns 409 when the group exists.", function(Query) {

    var id = "board";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).then(function() {
	return Query.post(["db/",db,"/groups"],example,auth).assertStatus(409);
    });
});

TEST("Returns 409 when re-creating the admin group.", function(Query) {

    var id = "admin";
    var example = { "id" : id, "label" : "Board members" };

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/groups"],example,auth).assertStatus(409);

});

// # Access restrictions
//
// Only [database administrators](/docs/#/group/admin.md) can create new groups.