// POST /db/{db}/keys

var Example = { "hash": "SHA-1", "key": "74e6f7298a9c2d168935f58c001bad88", "encoding": "hex" };

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    return Query.post(["db/",db,"/keys"],Example,auth)
	.assertStatus(202).assertIsJson();

});

TEST("Creation works.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var idlen = Query.post(["/db/",db,"/keys"],Example,auth)
	.then(function(d,s,r) { return d.id.length });

    return Assert.areEqual(11,idlen);
    
});

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.post("/db/00000000001/keys",Example).assertStatus(404);

});

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db,false);

    return Query.post(["db/",db,"/keys"],Example,auth).assertStatus(403);

});

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    return Query.post(["db/",db,"/keys"],Example,{token:"0123456789a",id:"0123456789a"})
	.assertStatus(401);
});
