(* © 2014 RunOrg *)

include Ssl 
  
let trace_errors = false
  
(** A string representing an [Ssl_error] *)
let string_of_error = Ssl.(function 
  | Error_none -> "No error happened. This is never raised and should disappear in future versions."
  | Error_ssl -> "Error_ssl" 
  | Error_want_read -> "The read operation did not complete; the same TLS/SSL I/O function should be called again later."
  | Error_want_write -> "The write operation did not complete; the same TLS/SSL I/O function should be called again later."
  | Error_want_x509_lookup -> "The operation did not complete because an application callback set by [set_client_cert_cb] has asked to be called again.  The TLS/SSL I/O function should be called again later. Details depend on the application."
  | Error_syscall -> "Some I/O error occurred.  The OpenSSL error queue may contain more information on the error."
  | Error_zero_return -> "The TLS/SSL connection has been closed.  If the protocol version is SSL 3.0 or TLS 1.0, this result code is returned only if a closure alert has occurred in the protocol, i.e. if the connection has been closed cleanly. Note that in this case [Error_zero_return] does not necessarily indicate that the underlying transport has been closed."
  | Error_want_connect -> "The operation did not complete; the same TLS/SSL I/O function should be called again later."
  | Error_want_accept -> "The operation did not complete; the same TLS/SSL I/O function should be called again later..")

(** A string representation (remote IP and port) of a socket. *)
let string_of_socket socket = 
  let inner = Ssl.file_descr_of_socket socket in
  let peer = Unix.getpeername inner in 
  match peer with 
  | Unix.ADDR_UNIX str -> str
  | Unix.ADDR_INET (inet,port) -> (Unix.string_of_inet_addr inet) ^ ":" ^ string_of_int port 
    
let read = 
  if not trace_errors then read else
    fun socket buffer offset length -> 
      try read socket buffer offset length with 
      | (Ssl.Read_error inner) as exn -> 
	Log.trace "Ssl.read(%s) : %s" (string_of_socket socket) (string_of_error inner) ; 
	raise exn
      | exn -> 
	Log.trace "Ssl.read(%s) : %s" (string_of_socket socket) (Printexc.to_string exn) ; 
	raise exn 
	  
let output_string = 
  if not trace_errors then output_string else
    fun socket buffer -> 
      try output_string socket buffer with 
      | (Ssl.Write_error inner) as exn -> 
	Log.trace "Ssl.output_string(%s) : %s" (string_of_socket socket) (string_of_error inner) ; 
	raise exn
      | exn -> 
	Log.trace "Ssl.output_string(%s) : %s" (string_of_socket socket) (Printexc.to_string exn) ; 
	raise exn 
	  
