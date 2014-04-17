// JSON <time>
// Types / Date and time
//
// Represents a point in time as a JSON string in ISO-8601 format. 
//
// Times are always expressed in the UTC time zone: it is the
// responsibility of the client to display times in the viewer's 
// time zone.
//
// The **date-time** format is `yyyy-mm-ddThh:ii:ssZ`. RunOrg will 
// always generate timestamps in this format. 
//
// The **date** format is `yyyy-mm-dd`. While RunOrg will not generate 
// dates in this format (as they interact badly with time zones), it
// is possible for the client to provide such values, in which case
// RunOrg will return them untouched. 
//
// The **sub-second** date-time format is `yyyy-mm-ddThh:ii:ss.tttttZ`. 
// It is _not_ supported by RunOrg. When received by the API, the 
// `.ttttt` part will always be discarded (regardless of how many digits 
// after the dot). 
//
// The behaviour of the RunOrg API when ill-formatted dates are provided 
// is currently **unspecified**. In particular, we reserve the right to 
// support additional date formats in the future. 
//
// ### Example dates and times
//
//     2013-10-08T21:42:00Z
//     1985-04-19
