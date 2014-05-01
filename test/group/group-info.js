// JSON <group-info>
// Groups / A short representation of a group's information
//
// [Viewer-dependent](/docs/#/concept/viewer-dependent.md). 
//
// Returned by most API methods that involve groups. It is intended to 
// provide data relevant for displaying the group: its label and count.
// 
// Typical examples: [listing groups](/docs/#/group/list.js) or 
// [groups participating in a chat](/docs/#/chat/get.js). 
//
// ### JSON format
//     { id : <id>, 
//       label : <label> | null, 
//       access : [ <access>, .. ],
//       count : <int> | null }
// 
// - `id` is the [unique 11-character identifier](/docs/#/types/id.js) for this 
//   contact

TEST("The groups's identifier is returned.", function(Query) {

    var example = {};

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    var id2 = Query.get(["db/",db,"/groups/",id,"/info"],auth).id();

    return Assert.areEqual(id,id2);

});

// - `label` is a [human-readable name](/docs/#/types/label.js). Not all groups
//   have one, because it is not a mandatory property when creating a group.

TEST("The group's label is returned if available.", function(Query) {

    var example = { "label" : "Associates" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    var label = Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d) { return d.label; });

    return Assert.areEqual(example.label,label);

});

// - `access` is the list of [access levels](/docs/#/group/audience.js) available to 
//  the viewer.

TEST("The group's access levels are returned.", function(Query) {

    var example = { "audience" : { "moderate" : "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    var access = Query.get(["db/",db,"/groups/",id,"/info"]).then(function(d) { return d.access; });

    return Assert.areEqual([ "view", "list", "moderate" ], access);

});

// - `count` is the number of group members (people currently in the group). This field is
//   only available if the viewer has **list** access to the group.

TEST("The group's member count is returned.", function(Query) {

    var example = { "label" : "Associates" };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    
    return Query.post(["db/",db,"/groups/",id,"/add"],[auth.id],auth).then(function(){	
	return Query.get(["db/",db,"/groups/",id,"/info"],auth).then(function(d,s,r) {	    
	    return Assert.areEqual(1, d.count);	    
	});
    });

});

TEST("The group's member count requires 'list' access.", function(Query) {

    var example = { "label" : "Associates", "audience" : { "view" : "anyone" } };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/groups"],example,auth).id();
    
    return Query.post(["db/",db,"/groups/",id,"/add"],[auth.id],auth).then(function(){	
	return Query.get(["db/",db,"/groups/",id,"/info"]).then(function(d,s,r) {	    
	    return Assert.areEqual(null, d.count);	    
	});
    });

});

// ### Example value
//     { "id" : "0Et9j0026rO",
//       "label" : "Team members",
//       "access" : [ "list", "view" ],
//       "count": 16 }
