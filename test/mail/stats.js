// GET /db/{db}/mail/{id}/stats
// Mail / Statistics about sending and opening
//
// Beta @ 0.9.0
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Person [`{as}`](/docs/#/concept/as.md) views sending statistics for e-mail `{id}`. 
// 
// ### Response format
//     { "scheduled" : <int>,
//       "sent"      : <int>,
//       "failed"    : <int>,
//       "opened"    : <int>,
//       "clicked"   : <int> }
// - `scheduled` is the number of copies which are scheduled for sending (after a 
//   [send request](/docs/#/mail/send.js)) but have not been sent by RunOrg yet. 
//   This correspond to a [status](/docs/#/mail/view.js) of `"scheduled"`. 
// - `sent` is the number of copies which were sent successfully, though they 
//   may have not been received. 
//   This correspond to a [status](/docs/#/mail/view.js) of `"sent"`. 
// - `failed` is the number of copies which could not be sent, either because of
//   an error while composing the e-mail or because of a sending failure. 
// - `opened` is the number of copies which were received and had any of their
//   links followed. 
// - `clicked` is the number of copies which were received and had any of their 
//   links followed, _except for the tracking link_. 
//
// The following relationships are true: 
//
// - `sent > opened` (each sent e-mail may only be opened once).
// - `opened > clicked` (each clicked e-mail counts as opened). 
// - `sent + scheduled + failed` remains constant in-between 
//   [sending requests](/docs/#/mail/send.js). 
//
 
function Example(cid) {
    return {
	"from": cid,
	"subject": "Hello, world",
	"text": { 
	    "script": "$0;to.email;$1;self",
	    "inline": ["Hello, ", ".\n\nPlease click on this link:\n"]
	},
	"self": "https://example.com/{id}",
	"audience": {},
	"urls": [],
    };
}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
   
    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
	
    return Query.get(["db/",db,"/mail/",id,"/stats"],auth)
	.assertStatus(200).assertIsJson();

});

TEST("Everything is zero before sending starts.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
   
    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
	
    return Query.get(["db/",db,"/mail/",id,"/stats"],auth).then(function(d,s,r) {

	var expected = {
	    scheduled: 0,
	    sent: 0,
	    failed: 0,
	    opened: 0,
	    clicked: 0
	};

	return Assert.areEqual(expected, d);

    });

});

TEST("Correct number after sending ends.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
   
    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
	
    var count = 0;

    function loop() {

	if (count++ > 20) return Assert.fail("Mail is not being sent");

	return Query.get(["db/",db,"/mail/",id,"/stats"],auth).then(function(d,s,r) {	    	    	    

	    var todo = Assert.areEqual(2, d.scheduled + d.sent);

	    if (d.scheduled != 0) 
		todo = todo.then(function(){
		    return Async.sleep(1000).then(loop);
		});
	    
	    return todo;	    
	    
	});

    }
    
    return Query.auth(db,true,"vnicollet+unittest@runorg.com").id.then(function(){
	return Query.post(["db/",db,"/mail/",id,"/send"],{"group":"admin"},auth).then(loop);
    });

});

TEST("Correct number after clicking links.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var example = Example(auth.id);
    example.html = { "script" : "track", "inline" : [] };
    example.text = { "script" : "self" , "inline" : [] };

    var id = Query.post(["db/",db,"/mail"],example,auth).id();
    var auth2 = Query.auth(db,true,"test+2@runorg.com"); 	

    var createAuth2 = auth2.id;

    // Request sending and wait until it is done.
    function send() {
	
	var count = 0;
	
	function waitUntilSent() {
	    
	    if (count++ > 20) return Assert.fail("Mail is not being sent");
	    
	    return Query.get(["db/",db,"/mail/",id,"/stats"],auth).then(function(d,s,r) {	    

		if (d.scheduled != 0) 
		    return Async.sleep(1000).then(waitUntilSent);
		   
		return true;	    
		
	    });
	    
	}
    
	return Query.post(["db/",db,"/mail/",id,"/send"],{"group":"admin"},auth).then(waitUntilSent);

    }

    // Click links 
    function click() {
	return $.when(
	    Query.get(["db/",db,"/mail/",id,"/to/",auth.id],auth).then(function(d,s,r) {
		// Ignore error
		var def = $.Deferred();
		$.ajax({url:d.view.html}).always(function() { def.resolve(true); });
		return def.promise();
	    }),
	    Query.get(["db/",db,"/mail/",id,"/to/",auth2.id],auth).then(function(d,s,r) {
		// Ignore error
		var def = $.Deferred();
		$.ajax({url:d.view.text}).always(function() { def.resolve(true); });
		return def.promise();
	    })
	);
    }

    // Wait for stats to be available and perform check
    var count = 0;

    function waitForStats()
    {
	if (count++ > 20) return Assert.fail("Stats are not computed");
	
	return Query.get(["db/",db,"/mail/",id,"/stats"],auth).then(function(d,s,r) {	    
	    
	    if (d.opened != 2) 
		return Async.sleep(1000).then(waitForStats);
	    
	    return Assert.areEqual(1, d.clicked);	    
	    
	});

    }

     return createAuth2.then(send).then(click).then(waitForStats);

});


// 
//
// ### Example request
//     GET /db/0vJlA00726W/mail/0vJlA00A26W/stats?as=0vJlA00826W
//
// ### Example response
//     200 OK
//     Content-Type: application/json 
//
//     { "scheduled": 8,
//       "sent"     : 1134,
//       "failed"   : 2,
//       "opened"   : 336,
//       "clicked"  : 137 }
//
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist.

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.get("db/00000000000/mail/00000000001/stats").assertStatus(404);

});

// - ... if draft `{id}` does not exist in database `{db}`. 

TEST("Returns 404 when draft does not exist.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.get(["db/",db,",/mail/00000000001/stats"],auth).assertStatus(404);

});

// - ... if person `{as}` does not have **view** access to draft `{id}`,
//   to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when draft cannot be viewed.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
    var peon = Query.auth(db, false, "peon@runorg.com");
	
    return Query.get(["db/",db,"/mail/",id,"/stats"],peon)
	.assertStatus(404);

});

// ## Returns `403 Forbidden`
// - ... if person `{as}` does not have **admin** access to draft `{id}`.

TEST("Returns 403 when not admin.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var example = Example(auth.id);
    example.audience = { "view" : "anyone" };

    var id = Query.post(["db/",db,"/mail"],example,auth).id();
    var peon = Query.auth(db, false, "peon@runorg.com");
	
    return Query.get(["db/",db,"/mail/",id,"/stats"],peon)
	.assertStatus(403);

});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match person `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    return Query.get(["db/",db,"/mail/00000000001"],{token:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});

// # Access restrictions
//
// Person `{as}` must have **admin** access to draft `{id}`.
