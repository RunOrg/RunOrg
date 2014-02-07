// JSON <clock>
// Types / Vector Clock
//
// The RunOrg server keeps a queue of commands to be processed. A vector clock 
// represents a position within that queue. 
//
// The primary purpose of vector clocks is [synchronization](/docs/#/concept/synchronization.md): 
// telling RunOrg to wait until a request has finished processing before running
// the next one. 
// 
// ### Example vector clock
//     [[2,83],[3,117]]
// 
// This example illustrates that there are in fact **several queues** rather
// than just one. The vector clock above means: 
//   - every event in queue 2 up to and including event 83 has been processed
//   - every event in queue 3 up to and including event 117 has been processed
// 
// The queue identifier and the event number are always positive integers. 
//
// The vector clock is passed as the `at` query parameter to API requests. Since 
// query parameters are strings, the clock needs to be serialized to JSON first. 
// 
// ### Example serialization
//
//     var url = '/db/' + db + '/contacts/' + id + '?at=' + JSON.stringify(clock);
//
// # Merging clocks
//
// After running two separate requests, the client holds two different vector clocks,
// one for each request: 
// 
//     Req. A: [[2,83],[3,117]]
//     Req. B: [[1,12],[2,85]]
//
// To build a vector clock representing "both requests are done", the client needs to 
// merge the two vector clocks by selecting, for each queue, the highest event number:
//
//     [[1,12],[2,85],[3,117]]
// 
// ### Example javascript code (naïve implementation)
// 
//     function merge(ca, cb) {
//       ca = ca.slice(0);
//       
//       for (i = 0; i < cb.length; ++i) {
//         for (j = 0; j < ca.length && ca[j][0] != cb[i][0]; ++j);
//         if (j == ca.length) ca.push(cb[i]);
//         else if (ca[j][1] < cb[i][1]) ca[j][1] = cb[i][1]; 
//       }
//         
//       return ca;
//     }
