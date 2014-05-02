// POST /db/{db}/mail
// Mail / Create a new draft.
//
// Beta @ 0.9.0
// 
// `202 Accepted`, [Delayed](/docs/#/concept/delayed.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) creates a new e-mail draft, ready to
// be sent. 
// 
// ### Request format
//     { "from"    : <contact>,
//       "subject" : <template>,
//       "text"    : <template> | null,
//       "html"    : <template> | null,
//       "audience": <audience>,
//       "urls"    : [ <url>, .. ],
//       "self"    : <url> | null,
//       "custom"  : <json> }
// - `from` is the identifier of the [contact](/docs/#/contact.md) who will 
//   be used as the sender (his or her name and e-mail address will appear 
//   in the `From:` header of the sent e-mail).
// - `subject` is a [text template](/docs/#/mail/template.js) from which the
//   `Subject:` header of the sent e-mail is generated.
// - `text` is an optional [text template](/docs/#/mail/template.js) used to 
//   create the text body of the e-mail.
// - `html` is an optional [HTML template](/docs/#/mail/template.js) used to 
//   create the HTML body of the e-mail.
// - `audience` determines the [access levels](/docs/#/mail/access.js) to
//   the draft.
// - `urls` is a list of URLs intended to appear in the e-mail, and will be 
//   made available to all [templates](/docs/#/mail/template.js). 
// - `self` is an optional URL for "if this e-mail does not display properly,
//   click here" functionality. 
// - `custom` is an arbitrary piece of JSON that will be stored and returned
//   by RunOrg as-is. 
// 
// ### Response format
//     { "id": <id>,
//       "at": <clock> }

function Example(cid) {
    return {
	"from": cid,
	"subject": "Hello, world",
	"text": null,
	"html": { 
	    "script": "$0;to.firstname;$1;self;$2",
	    "inline": ["Hello, <b>", "</b>. Please <a href='", "'>click here</a>"]
	},
	"audience": {},
	"urls": [],
	"self": "https://example.com/view/{id}",
	"custom": null
    };
}

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
   
    return Query.post(["db/",db,"/mail"],Example(auth.id),auth)
	.assertStatus(202).assertIsJson();

});

// 
// After creating e-mail, the next step is to [send it](/docs/#/send.js).
//
// ### Example request
//     POST /db/0vJlA00726W/mail 
//     Content-Type: application/json 
// 
//     { "from": "0vJlA00826W",
//       "subject": "Hello, world",
//       "text": null,
//       "html": { "script": "$0;to.firstname;$1;self;$2",
//                 "inline": ["Hello, ", ". Please <a href='", "'>click here</a>"] },
//       "audience": {},
//       "urls": [],
//       "self": "https://example.com/view/{id}",
//       "custom": null }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
//  
//     {"id":"0vJlA00A26W","at":[[7,3]]}
//
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.post("db/00000000000/mail",Example('00000000000')).assertStatus(404);

});

// - ... if contact `from` does not exist

TEST("Returns 404 when sender does not exist.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.post(["db/",db,",/mail"],Example('00000000000'),auth).assertStatus(404);

});

// ## Returns `403 Forbidden`
// - ... if contact `{as}` cannot create a form.

TEST("Returns 403 when contact cannot create a form.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db,false);
    
    return Query.post(["db/",db,"/mail"],Example(auth.id),auth).assertStatus(403);
    
});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match contact `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    return Query.post(["db/",db,"/mail"],Example('00000000000'),{token:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});

// # Access restrictions
//
// Contact `{as}` must be a [database administrator](/docs/#/group/admin.md). 
