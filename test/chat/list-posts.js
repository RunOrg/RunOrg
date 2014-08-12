// GET /chat/{id}/posts

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    return Query.get(["db/",db,"/chat/",id,"/posts"],auth)
	.assertStatus(200).assertIsJson();

});

TEST("Initially empty.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    return Query.get(["db/",db,"/chat/",id,"/posts"],auth).then(function(data) {
	return Assert.areEqual({ posts: [], people: [], count: 0 }, data);
    });

});

TEST("With single post.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    return Query.post(["db/",db,"/chat/",id,"/posts"],{ body: "Hi" },auth).id().then(function(pid) {
	return Query.get(["db/",db,"/chat/",id,"/posts"],auth).then(function(data) {
	    delete data.posts[0].time;
	    return Assert.areEqual({ 
		posts: [{
		    id: pid,
		    author: auth.id,
		    body: "<p>Hi</p>",
		    tree: { count: 0, top: [] },
		    track: false
		}], 
		people: [{
		    id: auth.id,
		    label: "test@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
		}], 
		count: 1 
	    }, data);
	});
    });

});

TEST("With two posts, single author.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    var url = ["db/",db,"/chat/",id,"/posts"];
    return Query.post(url,{ body: "Hi" },auth).id().then(function(pid1) {
	return Async.sleep(1000).then(function() {
	    return Query.post(url,{ body: "<strong>Hello</strong>" },auth).id().then(function(pid2) {
		return Query.get(url,auth).then(function(data) {
		    delete data.posts[0].time;
		    delete data.posts[1].time;
		    return Assert.areEqual({ 
			posts: [{
			    id: pid2,
			    author: auth.id,
			    body: "<p><strong>Hello</strong></p>",
			    tree: { count: 0, top: [] },
			    track: false
			},{
			    id: pid1,
			    author: auth.id,
			    body: "<p>Hi</p>",
			    tree: { count: 0, top: [] },
			    track: false
			}], 
			people: [{
			    id: auth.id,
			    label: "test@…",
			    gender: null,
			    pic: "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
			}], 
			count: 2 
		    }, data);
		});
	    });
	});
    });

});

TEST("With nested posts.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,true,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    var url = ["db/",db,"/chat/",id,"/posts"];

    var pid1 = Query.post(url,{ body: "Hi" },auth).id();

    var pid2 = pid1.then(function() {
	return Async.sleep(1000).then(function() { 
	    return Query.post(url,{ body: "<strong>Hello</strong>" },auth2).id();
	});
    });

    var pid3 = pid2.then(function() {
	return Query.post(url,{ body: "Child", reply: pid1 },auth2).id();
    });

    return $.when(pid1,pid2,pid3).then(function() {	

	var all = Query.get(url,auth).then(function(data) {

	    delete data.posts[0].time;
	    delete data.posts[1].tree.top[0].time;
	    delete data.posts[1].time;
	    data.people.sort(function(a,b) { return a.label < b.label ? -1 : 1 });

	    return Assert.areEqual({ 
		posts: [{
		    id: pid2,
		    author: auth2.id,
		    body: "<p><strong>Hello</strong></p>",
		    track: false,
		    tree: { count: 0, top: [] }
		},{
		    id: pid1,
		    author: auth.id,
		    body: "<p>Hi</p>",
		    track: false,
		    tree: { count: 1, top: [ {
			id: pid3,
			author: auth2.id,
			body: '<p>Child</p>',
			track: false,
			tree: { count: 0, top: [] }
		    } ] }
		}], 
		people: [{
		    id: auth2.id,
		    label: "test+2@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
		},{
		    id: auth.id,
		    label: "test@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
		}], 
		count: 2 
	    }, data);
	});

	var first = Query.get(url.concat("?limit=1"),auth).then(function(data) {

	    delete data.posts[0].time;

	    return Assert.areEqual({ 
		posts: [{
		    id: pid2,
		    author: auth2.id,
		    body: "<p><strong>Hello</strong></p>",
		    track: false,
		    tree: { count: 0, top: [] }
		}], 
		people: [{
		    id: auth2.id,
		    label: "test+2@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
		}], 
		count: 2 
	    }, data);
	});

	var last = Query.get(url.concat("?offset=1"),auth).then(function(data) {

	    delete data.posts[0].tree.top[0].time;
	    delete data.posts[0].time;
	    data.people.sort(function(a,b) { return a.label < b.label ? -1 : 1 });

	    return Assert.areEqual({ 
		posts: [{
		    id: pid1,
		    author: auth.id,
		    body: "<p>Hi</p>",
		    track: false,
		    tree: { count: 1, top: [ {
			id: pid3,
			author: auth2.id,
			body: '<p>Child</p>',
			track: false,
			tree: { count: 0, top: [] }
		    } ] }
		}], 
		people: [{
		    id: auth2.id,
		    label: "test+2@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
		},{
		    id: auth.id,
		    label: "test@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
		}], 
		count: 2 
	    }, data);
	});

	return $.when(all, first, last);

    });

});

TEST("With nested posts, reading child.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var auth2 = Query.auth(db,true,"test+2@runorg.com");
    var id = Query.post(["db/",db,"/chat"],{audience:{}},auth).id();
    var url = ["db/",db,"/chat/",id,"/posts"];

    var pid1 = Query.post(url,{ body: "Hi" },auth).id();

    var pid2 = pid1.then(function() {
	return Async.sleep(1000).then(function() { 
	    return Query.post(url,{ body: "<strong>Hello</strong>" },auth2).id();
	});
    });

    var pid3 = pid2.then(function() {
	return Query.post(url,{ body: "Child", reply: pid1 },auth2).id();
    });

    return $.when(pid1,pid2,pid3).then(function() {	

	var all = Query.get(url.concat("?under=",pid1),auth).then(function(data) {

	    delete data.posts[0].time;
	    data.people.sort(function(a,b) { return a.label < b.label ? -1 : 1 });

	    return Assert.areEqual({ 
		posts: [{
		    id: pid3,
		    author: auth2.id,
		    body: '<p>Child</p>',
		    track: false,
		    tree: { count: 0, top: [] }		    
		}], 
		people: [{
		    id: auth2.id,
		    label: "test+2@…",
		    gender: null,
		    pic: "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
		}], 
		count: 1 
	    }, data);
	});

	var missing = Query.get(url.concat("?under=",pid2),auth).then(function(data) {
	    return Assert.areEqual({ posts: [], people: [], count: 0 }, data);
	});

	return $.when(all, missing);

    });

});

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/chat/00000000001/posts"]).assertStatus(404);
});

TEST("Returns 404 when chat does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/chat/00000000001/posts"],auth).assertStatus(404);
});

TEST("Returns 403 when not allowed to read.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: { view: "anyone" } },auth).id();
    var peon = Query.auth(db, false, "test+peon@runorg.com");
    return Query.get(["db/",db,"/chat/",id,"/posts"],peon).assertStatus(403);    
});

TEST("Returns 404 when not allowed to view.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/chat"],{ audience: {} },auth).id();
    var peon = Query.auth(db, false, "test+peon@runorg.com");
    return Query.get(["db/",db,"/chat/",id,"/posts"],peon).assertStatus(404);    
});

