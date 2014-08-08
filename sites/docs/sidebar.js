/* Extend the layout to automatically render the sidebar. */
(function() {

    function sidebar(R) {
	window.$sidebar = R.$;

	Fixture.root.then(function(root) { 

	    // The identifier of the currently opened fixture
	    var current = document.location.hash.toString().replace(/^#\//,'');

	    // Returns the status class (running, failed, ok, unknown) based on
	    // the current execution stats of a fixture (or fixture group)
	    function statusOfStats(stats) {
		return stats.running > 0 ? 'running' :
   		       stats.failed  > 0 ? 'failed'  : 
		       stats.ran     > 0 ? 'ok'      : 'unknown' 
	    }

	    // Turn a fixture into a renderable node, which should contain: 
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
	    function prepare(fixture) {

		var stats = fixture.stats();
		var failed = fixture.failed().map(function(test) {
		    return {
			name: test.name,
			failure: test.failure()
		    };
		});

		return {
		    verb: fixture.verb,
		    path: fixture.path,
		    file: fixture.file, 
		    status: statusOfStats(stats),
		    count: stats.tests,
		    running: stats.running,
		    done: ((stats.tests - stats.running) / stats.tests * 100).toFixed(2),
		    failed: failed.length > 0,
		    tests: failed
		};
	    }

	    // The list of all fixtures
	    var allFixtures = (function() {
		
		var stats = root.stats();
		return {
		    status: statusOfStats(stats),
		    running: stats.running,
		    count: stats.tests,
		    done: ((stats.tests - stats.running) / stats.tests * 100).toFixed(2),
		    fixtures: root.all.map(prepare)
		};

	    })();

	    R.sidebar(allFixtures);
	    R.show();

	    // Test buttons

	    $sidebar.off();
	    $sidebar.on('click','button.test',function(ev){
		var file = $(ev.target).closest('button')[0].dataset.file;
		Fixture.root.then(function(root) {
		    var tested = root.byFile[file] || root;
		    return tested.run(function(){
			sidebar(new Renderer($sidebar))
		    });
		});
	    });
	    
	});
    }

    Renderer.fill('layout',{ sidebar: sidebar, body: function(R){ R.show(); }});

})();
