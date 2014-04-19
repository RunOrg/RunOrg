/* Extend the layout to automatically render the sidebar. */
(function() {

    function sidebar(R) {
	window.$sidebar = R.$;

	Fixture.root.then(function(root) { 

	    // The identifier of the currently opened fixture
	    var current = document.location.hash.toString().replace(/^#\//,'');

	    // Turn the fixture tree into the kind of tree expected by 
	    // the template. That is, each node should contain: 
	    // - name: the text to be displayed
	    // - verb: an API verb, if any
	    // - path: an API path, if any 
	    // - url: the url for the corresponding page
	    // - current: is this the currently opened fixture ?
	    // - active: is the current fixture a descendant of this fixture ? 
	    // - status: 'running', 'ok', 'fail', 'unknown'
	    // - count: number of tests	
	    // - running: the number of tests not finished yet
	    // - done: the percentage of tests not running
	    // - sub: a list of child nodes to be displayed
	    // - catPath: the category path of the node
	    function prepare(fixture) {

		var stats     = fixture.stats();
		var sub       = fixture.children().map(prepare);
		var isCurrent = fixture.file === current;
		var subF      = sub.filter(function(f) { return f.active; });

		var active    = isCurrent || subF.length > 0;

		// The rule for a node being displayed: 
		//  - they are the current node
		//  - they are a parent of the current node, and it has no children
		//  - they are a child of the current node
		//  - they are an ascendant of the current node

		sub = ( isCurrent || active && subF[0].current && subF[0].sub.length == 0 ) ? sub : subF; 

		return {
		    name: fixture.description || "RunOrg API documentation",
		    verb: fixture.verb,
		    path: fixture.path,
		    current: isCurrent,
		    url: '/docs/#/' + fixture.file,
		    status: (stats.running > 0 ? 'running' :
			     stats.failed  > 0 ? 'failed'  : 
			     stats.ran     > 0 ? 'ok'      : 'unknown' ),
		    count: stats.tests,
		    running: stats.running,
		    active: active, 
		    done: ((stats.tests - stats.running) / stats.tests * 100).toFixed(2),
		    sub: sub,
		    catPath: fixture.catPath()
		};
	    }

	    R.sidebar(prepare(root));
	    R.show();

	    // Test buttons

	    $sidebar.on('click','button.test',function(ev){
		var catPath = $(ev.target).closest('button')[0].dataset.catpath;
		Fixture.root.then(function(root) {
		    var tested = root.findByCatPath(catPath);
		    if (tested) return tested.run(function(){
			sidebar(new Renderer($sidebar))
		    });
		});
	    });
	    
	});
    }

    Renderer.fill('layout',{ sidebar: sidebar, body: function(R){ R.show(); }});

})();
