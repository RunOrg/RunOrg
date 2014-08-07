// TYPE <form/short>

TEST("The form's data is returned.", function(Query) {

    var example = {
	"owner": "person",	
	"audience": { "fill": "anyone" },
	"label": "Personal information",
	"custom": [1,2,3],
	"fields": [ {
	    "id": "1",
	    "label": "Why did you join our group ?",
	    "kind": "text",
	    "required": true
	}, {
	    "id": "2",
	    "label": "How often do you log in ?",
	    "kind": "single",
            "choices" : [
		"Every day",
		"Once a week",
		"Once a month",
		"Less than once a month" ],
	    "required": false
	} ]
    };

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.post(["db/",db,"/forms"],example,auth).id().then(function(id) {

	var form = Query.get(["db/",db,"/forms"],auth).then(function(d,s,r) {
	    return d.list[0];
	});

	var expected = {
	    "id": id,
	    "label": example.label,
	    "owner": example.owner,
	    "fields": 2,
	    "access": ["admin","fill"]
	};
	
	return Assert.areEqual(expected,form);

    });

});

