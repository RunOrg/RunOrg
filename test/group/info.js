// GET /db/{db}/groups/{id}/info
// Groups / Read group meta-data
// 
// Alpha @ 0.1.23
//
// `200 OK`,
// [Read-only](/docs/#/concept/read-only.md),
// [Viewer-dependent](/docs/#/concept/viewer-dependent.md).
//
// Returns all available meta-data about a group that can be viewed 
// by [`{as}`](/docs/#/concept/as.md).
// 
// ### Response format
//     { "id"       : <id>,
//       "label"    : <label> | null,
//       "access"   : [ <access>, ... ],
//       "count"    : <int> | null,
//       "audience" : <group-audience> }
// - `id` is the group [identifier](/docs/#/types/id.js) (that was passed in the URL).
// - `label` is an optional [human-readable name](/docs/#/types/label.js) for the group.
// - `access` is the list of access levels the person `{as}` has over
//   the group. See [audience and access](/docs/#/concept/audience.md) for more
//   information.
// - `count` (**list**-only) is the number of members in the group.
// - `audience` (**admin**-only) is the current audience of the group. See [audience and 
//   access](/docs/#/concept/audience.md) for more information.

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/groups/admin/info"],auth)
	.assertStatus(200).assertIsJson();    
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/groups/0SNQe0032JZ/info
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "id"       : "0SNQe0032JZ",
//       "label"    : "Team members",
//       "access"   : [ "view", "list", "moderate", "admin" ],
//       "count"    : 215,
//       "audience" : {} }

TEST("Returns correct count.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/groups/admin/info"],auth).then(function(d,s,r) {
	return Assert.areEqual(1, d.count);
    });
});

TEST("Returns correct group label.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"label":"My Group"},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {
	return Assert.areEqual("My Group", d.label);
    });
});

TEST("Returns correct access and audience.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"admin":"anyone"}},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {
	return Assert.areEqual({
	    "id": id,
	    "label": null,
	    "access": [ "view", "list", "admin", "moderate" ],
	    "count": 0,
	    "audience": { "admin": "anyone" }
	}, d);
    });
});

TEST("Do not include 'count' or 'audience' without list access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"view":"anyone"}},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {
	return Assert.areEqual({
	    "id" :      id,
	    "label":    null,
	    "access":   [ "view" ],
	    "count":    null, /* no server side support for missing fields */
	    "audience": null  /* no server side support for missing fields */
	}, d);
    });
});

TEST("Do not include 'audience' without admin access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"moderate":"anyone"}},auth).id();
    return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {
	return Assert.areEqual({
	    "id" :      id,
	    "label":    null,
	    "access":   [ "view", "list", "moderate" ],
	    "count":    0,
	    "audience": null  /* no server side support for missing fields */
	}, d);
    });
});

// # Errors
// 
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not allow acting as `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/groups/admin/info"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});
 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/groups/admin/info"]).assertStatus(404);
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/groups/00000000000/info"]).assertStatus(404);
});

// - ... if person `{as}` does not have at least **view** access
//   to group `{id}`, to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md).

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.get(["db/",db,"/groups/admin/info"],peon).assertStatus(404);
});

// # Access restrictions
//
// An [access level](/docs/#/group/audience.js) of **view** is required 
// to view group meta-data.