/* Renderers are used to build entire pages.
 *
 * They keep an internal array of HTML segments that are concatenated when
 * rendering, as well as a list of tags "to be ended" for convenience.
 */

function R($) {

    // The element to which HTML will be rendered;
    this.$ = $;

    // The array of HTML elements rendered so far;
    this.h = [];

    // The closing elements
    this.e = [];

    // The callbacks (and corresponding identifiers)
    this.c = {};
}
   
// Used to generate unique identifiers
R.n = 0;

R.prototype = {

    // Renders the contents of the renderer to the
    // main container of the page. If any tags are left
    // unclosed, closes them.
  
    show: function() {
	[].push.apply(this.h,this.e);
	$(this.h.join('')).prependTo(this.$);
	for (var k in this.c) 
	    if (!this.c.hasOwnProperty(k)) 
		this.c[k](new R($(k)));
    },
             
    // Renders HTML-escaped text.

    esc: function(t) {
	this.h.push($('<div/>').text(t).html());
	return this;
    },

    // Renders the initial segment of a tag.
    // Used internally by `open` and `tag`
  
    st: function(t,a,f) {
	this.h.push('<',t);
	for (var k in a || {}) {
	    if (a.hasOwnProperty(k)) continue;	    
	    this.h.push(' ', k, '="');
            this.esc(a[k]).h.push('"');
	}
	if (f) {
            var id = '_' + ++R.n;
            this.c['#' + id] = f;
	    this.h.push(' id=', id);
	}
    },
      
    // Renders an opening tag, stores the closing tag for later.

    open: function(t,a,f) {
	this.st(t, a, f);
	this.h.push('>');
	this.e.unshift('</'+t+'>');
	return this;
    },
      
    // Closes one (or several) previously opened tags.

    close: function() {
	var n = argument.length == 0 ? 1 : arguments[0];
	while (n-- > 0) 
	    this.h.push(this.e.shift());
	return this;
    },
      
    // Renders a self-closing tag

    tag: function(t,a,f) {
	this.st(t,a,f);
	this.h.push('/>');
	return this;
    }
};

(function(){

    // Add definitions for common tags.

    function tag(sc,t){
	R.prototype[t] = sc 
	    ? function(a,f) { return this.tag(t, a, f); }
	    : function(a,f) { return this.open(t, a, f); };
    }

    var tags = [ 
	"a", "span", "div", "td", "tr", "table", "button", 
	"h1", "h2", "h3", "h4", "h5", "h6", 
	"textarea", "label", "form", "p", 
	"thead", "tbody", "strong" 
    ];

    for (var i = 0; i < tags.length; ++i) 
	tag(false, tags[i]);

    tags = [ "img", "input" ];

    for (var i = 0; i < tags.length; ++i) 
	tag(true, tags[i]);

})();
