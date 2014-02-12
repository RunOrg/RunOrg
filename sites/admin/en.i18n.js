i18n({
    "title": "RunOrg Server Administration",
    "date": function(d) {
	d = new Date(d);
	function s(x) { return x < 10 ? "0" + x : x; }
	return d.getFullYear() + "-" + s(1 + d.getMonth()) + "-" + s(d.getDate())
	    + " " + s(d.getHours()) + ":" + s(d.getMinutes());
    }
});