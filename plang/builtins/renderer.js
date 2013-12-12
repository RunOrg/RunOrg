/* A renderer object builds an HTML document and writes it to the DOM. 
   It is created from a target element (where the contents will be written).
   The functions of a renderer are called automatically from within templates. */

function R($) { 

    // Public read-only member: the target of the renderer
    this.$ = $.addClass('load'); 

    // Private member: the current contents of the renderer
    this._ = []; 

    // Private member: all pending identifiers
    this._i = {};
}

// The next identifier
R.i = 0;

R.prototype = {

    // Append raw HTML
    raw: function(s) { this._.push(s); }, 

    // Append escaped HTML
    esc: function(s) { this.raw($('<div/>').text(s).html()); },
   
    // Output an identifier and store a post-render callback
    id: function(callback) { 
	var i = '_id' + ++R.i;
	this._i[i] = callback;
	this.raw('id=' + i);
    },

    // Render the HTML
    out: function(s) { 
	this.$.removeClass('load').html(this._.join(''));
	for (var i in this._i) this._i[i](new R($('#' + i)));
    }

    /*{{ TEMPLATES }}*/
   
};
