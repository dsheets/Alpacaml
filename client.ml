open Core.Std
open Async.Std
open Core_kernel.Binary_packing

(*

socks proxy, 
tcp server on the client side

*)

module Fd = Unix.Fd
module Inet_addr = Unix.Inet_addr
module Socket = Unix.Socket

let stdout_writer = Lazy.force Writer.stdout
let stderr_writer= Lazy.force Writer.stderr
let message s = Writer.write stdout_writer s
let warn s = Writer.write stderr_writer s

let finished () = shutdown 0

let listening_port = 61115

let remote_host = "127.0.0.1"
let remote_port = 61111 



(*
# local:
# stage 0 init
# stage 1 hello received, hello sent
# stage 2 UDP assoc
# stage 3 DNS
# stage 4 addr received, reply sent
# stage 5 remote connected

# remote:
# stage 0 init
# stage 3 DNS
# stage 4 addr received, reply sent
# stage 5 remote connected
*)

exception Error of string

type args = {
  addr : Socket.Address.Inet.t;
  r : Reader.t;
  w : Writer.t;
}

type init_req = {
  ver : int;
  nmethods : int;
  methods : int list;
}

type detail_req = {
  ver : int;
  cmd : int;
  rsv : int;
  atyp : int;
  dst_addr: string;
  dst_port: int;
}


(*

The client connects to the server, and sends a version
   identifier/method selection message:

        +----+----------+----------+
        |VER | NMETHODS | METHODS  |
        +----+----------+----------+
        | 1  |    1     | 1 to 255 |
        +----+----------+----------+


The server selects from one of the methods given in METHODS, and
   sends a METHOD selection message:

              +----+--------+
              |VER | METHOD |
              +----+--------+
              | 1  |   1    |
              +----+--------+


 The SOCKS request is formed as follows:

+----+-----+-------+------+----------+----------+
|VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
+----+-----+-------+------+----------+----------+
| 1  |  1  | X'00' |  1   | Variable |    2     |
+----+-----+-------+------+----------+----------+

*)




(********************** SHARED BY STAGES *********************)
(** not fully deferred *)
(** string -> int -> () *)
let view_request buf n = 
  let poses = List.range 0 n in
  let print_binary p = 
    let bin = unpack_unsigned_8 ~buf ~pos:p in
    message (Printf.sprintf "|%d| " bin)
  in message "Viewing request:\n"; List.iter poses ~f:print_binary;
  message "\nShowing port: ";
  let port = unpack_unsigned_16_big_endian ~buf ~pos:(n - 2) in
  message (Printf.sprintf "%d\n\n" port)

let read_and_review buf args =
  Deferred.create (fun finished ->
    upon (Reader.read args.r buf) (function
      |`Eof -> message "Unexpected EOF\n"; Ivar.fill finished ();
      |`Ok n ->
         message (Printf.sprintf "Read %d bytes this time\n" n);
         view_request buf n;
         Ivar.fill finished ();)
  )

(** pos should be in range *)
(** string -> int -> int Deferred.t *)
let get_bin req pos =
  let req_len = String.length req in
  if (pos < 0) || (pos >= req_len) then assert false
  else unpack_unsigned_8 ~buf:req ~pos







(********************** STAGE II *********************)
let parse_dst_addr atyp buf = 
  match () with
  | () when atyp = 1 -> 
      begin
        let addr_buf = Bigbuffer.create 16 in
        let rec build_addr s e =
          if s = e then Bigbuffer.contents addr_buf else 
            (get_bin buf s |> string_of_int |> Bigbuffer.add_string addr_buf;
             if s < (e - 1) then Bigbuffer.add_char addr_buf '.';
            build_addr (s + 1) e)
        in build_addr 4 8
      end
  | () when atyp = 3 ->
      begin 
        let addr_length = get_bin buf 4 in
        let addr_buf = Bigbuffer.create addr_length in
        let rec build_addr s e =
          if s = e then Bigbuffer.contents addr_buf else
            (get_bin buf s |> char_of_int |> Bigbuffer.add_char addr_buf;
            build_addr (s + 1) e)
          in build_addr 5 (5 + addr_length)
      end
  | _ -> raise (Error "Address type not supported yet\n")


let parse_dst_port req_len req =
  unpack_unsigned_16_big_endian ~buf:req ~pos:(req_len - 2)

let parse_stage_II req req_len args =
  Deferred.create (function r ->
    let ver = get_bin req 0
    and cmd = get_bin req 1
    and rsv = get_bin req 2
    and atyp = get_bin req 3 in
    let dst_addr = parse_dst_addr atyp req in
    let dst_port = parse_dst_port req_len req in
    let shp = Socket.Address.Inet.to_host_and_port args.addr in
    message (Printf.sprintf "Socket host : %s port : %d\n" (Host_and_port.host shp) (Host_and_port.port shp));
    message (Printf.sprintf "VER: %d, CMD: %d, ATYP: %d\n" ver cmd atyp);
    message (Printf.sprintf "ADDR:PORT -> %s : %d\n" dst_addr dst_port);
    Ivar.fill r
    {
      ver = ver;
      cmd = cmd;
      rsv = rsv;
      atyp = atyp;
      dst_addr = dst_addr;
      dst_port = dst_port;
    }
  )


let getsockname sock_addr =
    let sock_h_p = Socket.Address.Inet.to_host_and_port sock_addr in
    ((Host_and_port.host sock_h_p), (Host_and_port.port sock_h_p))

let handle_req_stage_II buf n req args =
  match () with
  | () when args.cmd = 1 -> begin
      message (Printf.sprintf "Connect %s: %d\n" req.dst_addr req.dst_port);
      return (Writer.write args.w "\x05\x00\x00\x01\x00\x00\x00\x00\x10\x10") >>=
      

    )


  | _ -> return ()


let stage_II buf args =
  (Reader.read args.r buf) >>= (function
    | `Eof -> raise (Error "Unexpected EOF\n")
    | `Ok n -> parse_stage_II buf n args >>= 
                (fun req -> handle_req_stage_II buf n req args)
  ) 





(********************** STAGE I *********************)
(** string -> init_req Deferred.t *)
let parse_stage_I req req_len = 
  return 
  {
    ver = get_bin req 0;
    nmethods = get_bin req 1;
    methods = List.range 2 req_len |> List.map ~f:(get_bin req);
  }


let stage_I buf n args = 
  parse_stage_I buf n >>= (fun init_req ->
    return (
      init_req.ver = 5 && 
      init_req.nmethods > 0 && 
      List.exists init_req.methods ~f:(fun x -> x = 0)
    ) >>= 
    (fun validity ->
      if validity then 
        (return (Writer.write args.w "\x05\x01"))
          >>= (fun () -> stage_II buf args)
      else raise (Error "*** Invalid request at STAGE: INIT ***\n")
    ))


(********************** MAIN PART *********************)


let start_listen addr r w =
    let buf = String.create 4096 in
    (Reader.read r buf) >>= (function
      | `Eof -> raise (Error "Unexpected EOF\n")
      | `Ok n -> begin
          let args = 
          {
            addr = addr;
            r = r;
            w = w;
          } in stage_I buf n args end)


let server () =
  message "client side server starts\n";
  Tcp.Server.create (Tcp.on_port listening_port) 
  ~on_handler_error:`Ignore start_listen



let () = server () |> ignore

let () = never_returns (Scheduler.go ())
