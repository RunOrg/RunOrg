// GET /db/{db}/mail/{id}
// Mail / Read a draft
//
// Beta @ 0.9.0
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Viewer-dependent](/docs/#/concept/viewer-dependent.md).
//
// Person [`{as}`](/docs/#/concept/as.md) retrieves all information it can view about 
// a draft e-mail. Different firleds have a different access level, and will be missing 
// unless the person has that access level.
// 
// ### Response format
//     { "id"      : <id>,
//       "from"    : <person>,
//       "subject" : <template>,
//       "text"    : <template> | null,
//       "html"    : <template> | null,
//       "urls"    : [ <url>, .. ],
//       "self"    : <url> | null,
//       "custom"  : <json>,
//       "access"  : [ <access>, .. ],
//       "audience": <audience> }
// - `id` is the identifier of the form.
// - `from` is the [short profile](/docs/#/person/person.js) 
//   for the sender of this e-mail.
// - `subject` is the [text template](/docs/#/mail/template.js) from which the
//   `Subject:` header of the sent e-mail is generated.
// - `text` is the optional [text template](/docs/#/mail/template.js) used to 
//   create the text body of the e-mail.
// - `html` is the optional [HTML template](/docs/#/mail/template.js) used to 
//   create the HTML body of the e-mail.
// - `urls` is the list of URLs intended to appear in the e-mail, and will be 
//   made available to all [templates](/docs/#/mail/template.js). 
// - `self` is the optional URL for "if this e-mail does not display properly,
//   click here" functionality. 
// - `custom` is an arbitrary piece of JSON that will be stored and returned
//   by RunOrg as-is. 
// - `access` is the list of access leveles the person `{as}` has over the
//   draft. See [audience and access](/docs/#/concept/audience.md) for more 
//   information.
// - `audience` (**admin**-only) determines the [access 
//   levels](/docs/#/mail/access.js) to the draft.
 
function Example(cid) {
    return {
	"from": cid,
	"subject": "Hello, world",
	"text": { 
	    "script": "$0;to.firstname;$1;self",
	    "inline": ["Hello, ", ".\n\nPlease click on this link:\n"]
	},
	"html": { 
	    "script": "$0;to.firstname;$1;self;$2",
	    "inline": ["Hello, <b>", "</b>. Please <a href='", "'>click here</a>"]
	},
	"audience": {},
	"urls": [ "https://example.com/url1" ],
	"self": "https://example.com/view/{id}",
	"custom": { "a": "b" }
    };
}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
   
    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
	
    return Query.get(["db/",db,"/mail/",id],auth)
	.assertStatus(200).assertIsJson();

});

TEST("The 'view'-level data is present.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var example = Example(auth.id);
    example.audience = {"view": "anyone"};

    var id = Query.post(["db/",db,"/mail"],example,auth).id();

    return id.then(function(id) {

	var expected = example;
	expected.id = id;
	expected.from = { 
	    "id": auth.id, 
	    "label": "test@…",
	    "gender": null,
	    "pic": "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon" };
	expected.audience = null; // No server-side support for missing fields
	expected.access = [ "view" ];
	expected.self = "https://example.com/view/" + id;

	var peon = Query.auth(db, false, "peon@runorg.com");

	return Query.get(["db/",db,"/mail/",id],peon).then(function(d,s,r) {
	    return Assert.areEqual(expected,d);
	});
    });

});


TEST("The 'admin'-level data is present.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var example = Example(auth.id);
    example.audience = {"view": "anyone"};

    var id = Query.post(["db/",db,"/mail"],example,auth).id();

    return id.then(function(id) {

	var expected = example;
	expected.id = id;
	expected.from = { 
 	    "id": auth.id, 
	    "label": "test@…",
	    "gender": null,
	    "pic": "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon" };
	expected.access = [ "view", "admin" ];
	expected.self = "https://example.com/view/" + id;

	return Query.get(["db/",db,"/mail/",id],auth).then(function(d,s,r) {
	    return Assert.areEqual(expected,d);
	});
    });

});


// 
//
// ### Example request
//     GET /db/0vJlA00726W/mail/0vJlA00A26W
//
// ### Example response
//     200 OK
//     Content-Type: application/json 
//
//     { "id": "0vJlA00A26W"",
//       "from": {
//         "id": "0vJlA00826W",
//         "label": "vnicollet@…",
//         "gender": null,
//         "pic": "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon" },
//       "subject": "Hello, world",
//       "text": null,
//       "html": { "script": "$0;to.firstname;$1;self;$2",
//                 "inline": ["Hello, ", ". Please <a href='", "'>click here</a>"] },
//       "access": [ "view" ]
//       "urls": [],
//       "self": "https://example.com/view/{id}",
//       "custom": null }
//
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist.

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.get("db/00000000000/mail/00000000001").assertStatus(404);

});

// - ... if draft `{id}` does not exist in database `{db}`. 

TEST("Returns 404 when draft does not exist.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.get(["db/",db,",/mail/00000000001"],auth).assertStatus(404);

});

// - ... if person `{as}` does not have **view** access to draft `{id}`,
//   to ensure[absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when draft cannot be viewed.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
    var peon = Query.auth(db, false, "peon@runorg.com");
	
    return Query.get(["db/",db,"/mail/",id],peon)
	.assertStatus(404);

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
// Person `{as}` must have at least **view** access to draft `{id}`.
