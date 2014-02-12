/* A renderer object builds an HTML document and writes it to the DOM. 
   It is created from a target element (where the contents will be written).
   The functions of a renderer are called automatically from within templates. */

var Renderer = (function(){

    function R(el) { 

	// Public read-only member: the target of the renderer
	this.$ = $(el).addClass('load'); 

	// Private member: the current contents of the renderer
	this._ = []; 

	// Private member: all pending identifiers
	this._i = {};
    }

    // The next identifier
    R.i = 0;

    // Provide default values for a template
    R.fill = function(n,d) {
	var old = Renderer.prototype[n];
	R.prototype[n] = function(a) {
	    return old.call(this,$.extend(d,a||{}))
	}
    };

    R.prototype = {

	// Append raw HTML
	raw: function(s) { this._.push(s); }, 

	// Append escaped HTML
	esc: function(s) { 
	    this.raw(s.toString()
		     .replace(/&/g,'&amp;')
		     .replace(/</g,'&lt;')
		     .replace(/>/g,'&gt;')
		     .replace(/"/g,'&quot;')); 
	},
   
	// Output an identifier and store a post-render callback
	id: function(callback) { 
	    var i = '_id' + ++R.i;
	    this._i[i] = callback;
	    this.raw('id=' + i);
	},
	
	// Render the HTML
	show: function(s) { 

	    // Don't render if cancellation happened
	    if (!this.$) return;

	    this.$.removeClass('load').html(this._.join(''));
	    
	    var sub = [], r, i;
	    for (i in this._i) {
		sub.push(r = new Renderer('#'+i));
		this._i[i](r);
	    }
	    
	    if (sub.length > 0) {
		
		// Propagate cancellation to the sub-elements.
		(function(t,s){ 
		    t.cancel = function() { while (s.length) s.shift().cancel(); } 
		})(this,sub);
		
	    }
	},
	
	// Cancel the rendering. Any elements that are not yet rendered will
	// be prevented from appearing. User code may test 'r.$' to see if 
	// rendering is still allowed.
	cancel: function() {
	    this.$ = null;
	}
	
	/*{{ TEMPLATES }}*/
	
    };

    return R;

})();
