/* Extend the layout to automatically render the sidebar. */
(function() {

    var layout = R.prototype.layout;

    function sidebar(R) {
	window.$sidebar = R.$;

	Test.tree(function(tree) {
	    function clean(tree) {
		var out = { sub: [], tests: [], count: 0, ok: true, ran: true, rcount: 0 };
		for (var k in tree) {
		    var node = tree[k];
		    if (k == '__') continue;
		    if (node['__'] == 'cat') {
			var s = clean(node);
			s.name = k;
			out.sub.push(s);
			out.count += s.count;
			out.rcount += s.rcount;
			out.ok = out.ok && s.ok;			
		    } else {                
			out.tests.push({ 
			    name: k, 
			    ok:   !node.fixture.failed,
			    ran:  node.fixture.ran,
			    verb: node.fixture.verb,
			    path: node.fixture.path,
			    file: "/docs/#/" + node.fixture.file,
			    count: node.fixture.tests
			});
			out.count += node.fixture.tests;
			out.rcount += node.fixture.rcount;
			out.ok = out.ok && !node.fixture.failed;
			out.ran = out.ran && node.fixture.ran;
		    }
		}
		out.ran = out.ran && out.count > 0;
		return out;
	    }
	    
	    var data = clean(tree);
	    data.running = Test.running;
	    data.done = (data.rcount * 100 / data.count).toFixed(2);
	    data.root = true;

	    R.sidebar(data);
	    R.show();

	    var location = document.location.pathname + document.location.hash;
	    var $a = $sidebar.find('a[href="' + location + '"]').addClass('active');
	    while ($a.length > 0) $a = $a.parent().closest('ul').show();	    

	    if (!Test.running) {
		var $button = $sidebar.find('button').click(function(){
		    Test.run(function(fixture,test) {
			sidebar(new window.R($sidebar))
		    });
		});
	    }
	});
    }

    R.prototype.layout = function(data) {
	function body(R) { R.show() }
	layout.call(this,$.extend({ sidebar : sidebar, body : body }, data || {}));
    }

})();
