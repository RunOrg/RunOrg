// GET /db/{db}/mail/{id}/to/{to}
// Mail / View or preview e-mail
//
// Alpha @ 0.1.52
// 
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Person [`{as}`](/docs/#/concept/as.md) views e-mail draft `{id}` as it will
// be sent, or has been sent, to person `{to}`. 
// 
// This is intended both as a **preview** tool for e-mail authors and as to 
// let the recipient **view** an online version of the e-mail they received.  
// 
// ### Response format
//     { "status" : "preview" | "scheduled" | "sent", 
//       "sent"   : <time> | null,
//       "view"   : {
//         "from"    : <string>,
//         "to"      : <string>,
//         "subject" : <string>,
//         "text"    : <string> | null,
//         "html"    : <string> | null 
//       } }
// - `status` describes whether the e-mail was `"sent"`, the sending
//   was `"scheduled"` but RunOrg was too busy to send it, or the sending
//   was not requested yet and this is just a `"preview"`. 
// - `sent` is the time when RunOrg sent the e-mail, only set when `status` 
//   is `"sent"`.
// - `view` is the actual e-mail data, it includes: 
// - `view.from` is the contents of the `From:` header. 
// - `view.to` is the contents of the `To:` header.
// - `view.subject` is the contents of the `Subject:` header.
// - `view.text` is the text body of the e-mail, if provided. 
// - `view.html` is the HTML body of the e-mail, if provided. 
//
// When previewing an unsent e-mail, RunOrg will show the data that will be
// actually sent to the recipient if [sending](/docs/#/mail/send.js) is 
// requested, with a few exceptions: 
// 
// - If data (the sender's or recipient's name or e-mail, or the e-mail draft
//   itself) are changed after the preview was generated.  
// - The URLs in the preview version are used as they were provided in the 
//   draft. URLs in the sent version contain a tracking token that is only 
//   created once the e-mail is actually sent. 
// 

function Example(cid) {
    return {
	"from": cid,
	"subject": "Hello, world",
	"text": { 
	    "script": "$0;to.label;$1;self",
	    "inline": ["Hello, ", ".\n\nPlease click on this link:\n"]
	},
	"html": { 
	    "script": "$0;to.label;$1;self;$2",
	    "inline": ["Hello, <b>", "</b>. Please <a href='", "'>click here</a>"]
	},
	"audience": {},
	"urls": [],
	"self": "https://example.com/view/{id}",
	"custom": { "a": "b" }
    };
}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
   
    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
	
    return Query.get(["db/",db,"/mail/",id,"/to/",auth.id],auth)
	.assertStatus(200).assertIsJson();

});

TEST("Template previewing shows correct data.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
    return id.then(function(id) {

	return Query.get(["db/",db,"/mail/",id,"/to/",auth.id],auth).then(function(d,s,r) {

	    var self = "https://example.com/view/" + id;
	    var expected = {
		"status": "preview",
		"sent"  : null,
		"view"  : {
		    "from"   : "test@runorg.com",
		    "to"     : "test@runorg.com",
		    "subject": "Hello, world",
		    "text"   : "Hello, test@runorg.com.\n\nPlease click on this link:\n" + self,
		    "html"   : "Hello, <b>test@runorg.com</b>. Please <a href='" + self + "'>click here</a>"
		}
	    };

	    return Assert.areEqual(expected, d);

	});

    });

});

TEST("Correct content number after sending ends.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db,true,"test@runorg.com");
   
    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
	
    var count = 0;

    function loop() {

	if (count++ > 5) return Assert.fail("Mail is not being sent.");

	return Query.get(["db/",db,"/mail/",id,"/to/",auth.id],auth).then(function(d,s,r) {

	    if (d.status != "sent") return Async.sleep(1000).then(loop);

	    return db.then(function(db) {
		var expected = "https://" + document.location.host + "/db/" + db + "/link/";
		var link = d.view.text.split("\n")[3].substring(0,expected.length);
		return Assert.areEqual(expected,link);	    
	    });
	});

    }
    
    return Query.post(["db/",db,"/mail/",id,"/send"],{"group":"admin"},auth).then(loop);

});


// 
//
// ### Example request
//     GET /db/0vJlA00726W/mail/0vJlA00A26W/to/0vJlA00826W?as=0vJlA00826W
//
// ### Example response
//     200 OK
//     Content-Type: application/json 
//
//     { "status": "sent",
//       "sent"  : "2014-04-21T19:31:44Z",
//       "view"  : {
//         "from"   : "Victor Nicollet <vnicollet@runorg.com>",
//         "to"     : "postmaster@example.com",
//         "subject": "Greetings",
//         "text"   : null,
//         "html"   : "Hello, postmaster@example.com !" 
//       } }
//
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist.

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.get("db/00000000000/mail/00000000001/to/00000000002").assertStatus(404);

});

// - ... if draft `{id}` does not exist in database `{db}`. 

TEST("Returns 404 when draft does not exist.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.get(["db/",db,",/mail/00000000001/to/000000000002"],auth).assertStatus(404);

});

// - ... if person `{as}` does not have **view** access to draft `{id}`,
//   to ensure[absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). Important exception: 
//   a recipient is always able to view any e-mail they received, even if they
//   cannot view the original draft.   

TEST("Returns 404 when draft cannot be viewed.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var id = Query.post(["db/",db,"/mail"],Example(auth.id),auth).id();
    var peon = Query.auth(db, false, "peon@runorg.com");
	
    return Query.get(["db/",db,"/mail/",id,"/to",peon.id],peon)
	.assertStatus(404);

});

// ## Returns `403 Forbidden` 
// - ... if `{as}` and `{to}` are not the same person, and `{as}` does not have
//   **admin** access to the draft. In other words, you cannot view other people's
//   e-mail.

TEST("Returns 403 when viewing someone else's mail.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    var example = Example(auth.id);
    example.audience = { "view": "anyone" };

    var id = Query.post(["db/",db,"/mail"],example,auth).id();
    var peon = Query.auth(db, false, "peon@runorg.com");
	
    return Query.get(["db/",db,"/mail/",id,"/to/",auth.id],peon)
	.assertStatus(403);

});


// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match person `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    return Query.get(["db/",db,"/mail/00000000001/to/00000000002"],{token:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});

// # Access restrictions
//
// Person `{as}` is the same as person `{to}`, they must have 
// received draft `{id}` (viewing received mail) or have at 
// least **view** access to draft `{id}` (previewing their own mail).
//
// If person `{as}` view a different person `{to}`, they must have
// **admin** access to draft `{id}`. 
