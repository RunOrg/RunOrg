// POST /db/{db}/mail
// Mail / Create a new draft.
//
// Alpha @ 0.1.50
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
