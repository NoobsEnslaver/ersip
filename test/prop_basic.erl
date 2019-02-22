-module(prop_basic).
-include_lib("proper/include/proper.hrl").
-include("ersip_sip_abnf.hrl").
-include("ersip_uri.hrl").
-include("ersip_headers.hrl").
-compile([export_all]).

%%%%%%%%%%%%%%%%%%
%%% Properties %%%
%%%%%%%%%%%%%%%%%%

prop_is_assemble_parse_equal() ->
    ?FORALL(Msg, message(),
        begin
            Bin1 = ersip_sipmsg:assemble_bin(Msg),
            {ok, Msg1} = ersip_sipmsg:parse(Bin1, all),
            Bin2 = ersip_sipmsg:assemble_bin(Msg1),
            Bin1 == Bin2
        end).

%%%%%%%%%%%%%%%
%%% Helpers %%%
%%%%%%%%%%%%%%%
with_headers(Msg) ->
    ?LET({Headers1, Headers2, Via},
         {required_headers(ersip_sipmsg:method(Msg)), optional_headers(), hdr_via()},
         begin
             SipMsg0 = lists:foldl(fun({Key, Val}, Acc) ->
                                           ersip_sipmsg:set(Key, Val, Acc)
                                   end, Msg, Headers1 ++ Headers2),

             NewRawMsg = ersip_msg:set_header(Via, ersip_sipmsg:raw_message(SipMsg0)),
             ersip_sipmsg:set_raw_message(NewRawMsg, SipMsg0)
         end).

%%%%%%%%%%%%%%%%%%
%%% Generators %%%
%%%%%%%%%%%%%%%%%%
message() ->
    oneof([message_req(), message_resp()]).

message_req() ->
    ?LET({Method, RURI},
         {method(), uri()},
         with_headers(ersip_sipmsg:new_request(Method, RURI))).

message_resp() ->
    ?LET({Status, Reason, Method},
         {range(100, 699), utf8(), method()},
         with_headers(ersip_sipmsg:new_reply(Status, Reason, Method))).

method() ->
    oneof([ersip_method:options(),
           ersip_method:invite(),
           ersip_method:ack(),
           ersip_method:bye(),
           ersip_method:cancel(),
           ersip_method:subscribe(),
           ersip_method:notify(),
           ersip_method:refer(),
           ersip_method:register()]).

%% ---- HEADERS Gen ----
required_headers(Method) ->
    ?LET({From, To, CallId, CSeq, Event},
         {hdr_from(), hdr_to(), hdr_callid(), hdr_cseq(Method), hdr_event()},
         begin
             Common = [From, To, CallId, CSeq],
             Specific = case Method == ersip_method:subscribe() orelse
                             Method == ersip_method:notify() of
                            true -> [Event];
                            _    -> []
                        end,
             Common ++ Specific
         end).

optional_headers() ->
    list(optional_header()).

optional_header() ->
    oneof([hdr_maxforwards()]).     %TODO: add all headers

fromto_hd() ->
    ?LET({DN, URI, Tag},
         {display_name(), uri(), token()},
         begin
             FromTo1 = ersip_hdr_fromto:set_display_name(DN, ersip_hdr_fromto:new()),
             FromTo2 = ersip_hdr_fromto:set_uri(URI, FromTo1),
             ersip_hdr_fromto:set_tag({tag, Tag}, FromTo2)
         end).


hdr_from() ->
    ?LET(From, fromto_hd(), {from, From}).
hdr_to() ->
    ?LET(To, fromto_hd(), {to, To}).
hdr_callid() ->
    {callid, ersip_hdr_callid:make_random(10)}.
hdr_via() ->
    ?LET({Host,   Port,   Transp},
         {host(), port(), transport()},
         begin
             Via = ersip_hdr_via:new(Host, Port, Transp),
             ViaH = ersip_hdr:new(<<"Via">>),
             ersip_hdr:add_topmost(ersip_hdr_via:assemble(Via), ViaH)
         end) .
hdr_cseq(Method) ->
    ?LET(N, non_neg_integer(),
         {cseq, ersip_hdr_cseq:make(Method, N)}).
hdr_maxforwards() ->
    ?LET(N, non_neg_integer(),
         {maxforwards, ersip_hdr_maxforwards:make(N)}).
hdr_event() ->
    ?LET({Event, Id}, {alphanum(), alphanum()},
         {event, ersip_hdr_event:new(Event, Id)}).

%% ------- Complex data Gen -----------------
uri() ->
    ?LET({Scheme,       Data      },
         {uri_scheme(), uri_data()},
         #uri{scheme = Scheme,
              data = Data}).

uri_scheme() ->
    {scheme, oneof([sip, sips])}.

uri_data() ->
    oneof([sip_uri_data(), absolute_uri_data()]).

sip_uri_data() ->
    #sip_uri_data{user = oneof([undefined, {user, alphanum()}]),
                  host = host(),
                  port = maybe(port()),
                  params = uri_params(),
                  headers = uri_headers()}.

absolute_uri_data() ->
    ?LET({Host, Domain}, {alpha(), alpha()}, #absolute_uri_data{opaque = <<Host/binary, $., Domain/binary>>}).

host() ->
    oneof([hostname(), address()]).

address() ->
    oneof([ip4_address(), ip6_address()]).

hostname() ->
    ?LET({Host, Domain}, {alpha(), alpha()}, {hostname, <<Host/binary, $., Domain/binary>>}).

port() ->
    range(1, 65535).

maybe(Gen) ->
    oneof([undefined, Gen]).

ip4_address() ->
    {ipv4, {range(0,255), range(0,255), range(0,255), range(0,255)}}.

ip6_address() ->
    {ipv6, {range(0,65535), range(0,65535),
            range(0,65535), range(0,65535),
            range(0,65535), range(0,65535),
            range(0,65535), range(0,65535)}}.

uri_params() ->
    ?LET({Transport,   Maddr,  Ttl,          User,                           Method,     Lr       },
         {transport(), host(), range(0,255), oneof([phone, ip, alphanum()]), alphanum(), boolean()},
         #{transport => Transport,
           maddr     => Maddr,
           ttl       => Ttl,
           user      => User,
           method    => Method,
           lr        => Lr}).

uri_headers() ->
    ?LET(List, list({alphanum(), alphanum()}), maps:from_list(List)).

transport() ->
    oneof([known_transport()%% , other_transport()
          ]).

known_transport() ->
    {transport, oneof([udp,tcp,tls,ws,wss])}.

other_transport() ->
    {other_transport, alphanum()}.

display_name() ->
    {display_name, oneof([alphanum(), list(alphanum())])}.


%% ------- Primitive data Gen -----------------
token() ->
    ?LET(T, non_empty(list(token_char())), iolist_to_binary(T)).
token_char() ->
    ?SUCHTHAT(C, byte(), ?is_token_char(C)).

alphanum() ->
    ?LET(A, non_empty(list(alphanum_char())), iolist_to_binary(A)).
alphanum_char() ->
    ?SUCHTHAT(C, byte(), ?is_alphanum(C)).

alpha() ->
    ?LET(A, non_empty(list(alpha_char())), iolist_to_binary(A)).
alpha_char() ->
    ?SUCHTHAT(C, byte(), ?is_ALPHA(C)).
