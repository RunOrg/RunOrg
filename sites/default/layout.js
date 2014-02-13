// Fill in the default components of a layout

Renderer.fill("layout",function(data) {
    return $.extend({
	menu: [
	    { url: "#/contacts", label: i18n.contacts.title },
	    { url: "#/groups", label: i18n.groups.title }
	],
	body: function(R) { R.show() }
    }, data);
});
