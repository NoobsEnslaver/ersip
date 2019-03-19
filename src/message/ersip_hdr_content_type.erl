%%
%% Copyright (c) 2018 Dmitry Poroh
%% All rights reserved.
%% Distributed under the terms of the MIT License. See the LICENSE file.
%%
%% SIP Content-type header
%%

-module(ersip_hdr_content_type).

-export([new/1,
         new/2,
         make_mime_type/2,
         mime_type/1,
         params/1,
         make/1,
         parse/1,
         build/2,
         assemble/1
        ]).

-export_type([content_type/0,
              mime_type/0
             ]).

%%%===================================================================
%%% Types
%%%===================================================================

-record(content_type, {
          type    :: mime_type(),
          params  :: params()
         }).
-type mime_type() :: {mime, Type :: binary(), SubType :: binary()}.
-type content_type() :: #content_type{}.
-type params() :: [pair()].
-type pair() :: {Key :: binary(), Value :: binary()}.

%%%===================================================================
%%% API
%%%===================================================================
-spec new(mime_type()) -> content_type().
new(MimeType) ->
    new(MimeType, []).

-spec new(mime_type(), params()) -> content_type().
new(MimeType, Params) ->
    #content_type{type = MimeType,
                  params = Params}.


-spec make_mime_type(binary(), binary()) -> mime_type().
make_mime_type(Type, SubType) ->
    {mime, Type, SubType}.

-spec mime_type(content_type()) -> mime_type().
mime_type(#content_type{type = T}) ->
    T.

-spec params(content_type()) -> params().
params(#content_type{params = P}) ->
    P.

-spec make(ersip_hdr:header() | binary()) -> content_type().
make(Bin) when is_binary(Bin) ->
    case parse_content_type(Bin) of
        {ok, Content_Type} ->
            Content_Type;
        Error ->
            error(Error)
    end;
make(Header) ->
    case parse(Header) of
        {ok, Content_Type} ->
            Content_Type;
        Error ->
            error(Error)
    end.

-spec parse(ersip_hdr:header()) -> Result when
      Result :: {ok, content_type()}
              | {error, Error},
      Error :: no_content_type
             | {invalid_content_type, binary()}.
parse(Header) ->
    case ersip_hdr:raw_values(Header) of
        [] ->
            {error, no_content_type};
        [Content_TypeIOList]  ->
            parse_content_type(iolist_to_binary(Content_TypeIOList));
        _ ->
            {error, multiple_content_types}
    end.

-spec build(HeaderName :: binary(), content_type()) -> ersip_hdr:header().
build(HdrName, #content_type{} = ContentType) ->
    Hdr = ersip_hdr:new(HdrName),
    ersip_hdr:add_value([assemble(ContentType)], Hdr).

-spec assemble(content_type()) -> iolist().
assemble(#content_type{} = ContentType) ->
    {mime, Type, SubType} = mime_type(ContentType),
    [Type, <<"/">>, SubType,
     lists:map(fun({Key, Value}) ->
                       [$;, Key, $=, Value]
               end,
               params(ContentType))
    ].

%%%===================================================================
%%% Internal implementation
%%%===================================================================

%% media-type     =  m-type SLASH m-subtype *(SEMI m-parameter)
%% m-type           =  discrete-type / composite-type
%% discrete-type    =  "text" / "image" / "audio" / "video"
%%                     / "application" / extension-token
%% composite-type   =  "message" / "multipart" / extension-token
%% extension-token  =  ietf-token / x-token
%% ietf-token       =  token
%% x-token          =  "x-" token
%% m-subtype        =  extension-token / iana-token
%% iana-token       =  token
%% m-parameter      =  m-attribute EQUAL m-value
%% m-attribute      =  token
%% m-value          =  token / quoted-string
-spec parse_content_type(binary()) -> Result when
      Result :: {ok, content_type()}
              | {error, Error},
      Error  :: {invalid_content_type, binary()}.
parse_content_type(Binary) ->
    Parsers = [fun ersip_parser_aux:parse_token/1,
               fun ersip_parser_aux:parse_slash/1,
               fun ersip_parser_aux:parse_token/1,
               fun ersip_parser_aux:trim_lws/1,
               fun parse_params/1
              ],
    case ersip_parser_aux:parse_all(Binary, Parsers) of
        {ok, [ Type, _, SubType, _, ParamsList], <<>>} ->
            {ok,
             #content_type{type    = {mime,
                                      ersip_bin:to_lower(Type),
                                      ersip_bin:to_lower(SubType)},
                           params  = ParamsList
                          }
            };
        _ ->
            {error, {invalid_content_type, Binary}}
    end.

parse_params(<<$;, Bin/binary>>) ->
    parse_params(Bin);
parse_params(<<>>) ->
    {ok, [], <<>>};
parse_params(Bin) ->
    ersip_parser_aux:parse_params($;, Bin).
