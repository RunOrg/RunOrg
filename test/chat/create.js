// POST /chat

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat"],{ audience: {} },auth)
	.assertStatus(202).assertIsJson();

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/chat"],{}).assertStatus(404);
});

TEST("Returns 400 when no audience.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/chat"],{},auth).assertStatus(400);
});

TEST("Returns 403 when not allowed to create.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/chat"],{ audience: {} }).assertStatus(403);
});
