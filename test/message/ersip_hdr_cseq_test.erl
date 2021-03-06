%%
%% Copyright (c) 2018 Dmitry Poroh
%% All rights reserved.
%% Distributed under the terms of the MIT License. See the LICENSE file.
%%
%% SIP CSeq header tests 
%%

-module(ersip_hdr_cseq_test).

-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% Cases
%%%===================================================================

parse_test() ->
    {ok, CSeq} = ersip_hdr_cseq:parse(create(<<"314159 INVITE">>)),
    ?assertEqual(ersip_method:make(<<"INVITE">>), ersip_hdr_cseq:method(CSeq)),
    ?assertEqual(314159, ersip_hdr_cseq:number(CSeq)),
    ?assertEqual(ersip_hdr_cseq:make_key(make(<<"1 REGISTER">>)), make(<<"1  REGISTER">>)),
    ?assertError({error, _}, ersip_hdr_cseq:make(create(<<"Not valid">>))).

parse_fail_test() ->
    ?assertMatch({error, _}, ersip_hdr_cseq:parse(create(<<"314159 INVITE x">>))),
    ?assertMatch({error, _}, ersip_hdr_cseq:parse(create(<<"314159 INVITE, 31 ACK">>))),
    ?assertMatch({error, _}, ersip_hdr_cseq:parse(create(<<"123 INV@TE">>))),
    ?assertMatch({error, _}, ersip_hdr_cseq:parse(create(<<"abc INVITE">>))),
    NoValue = ersip_hdr:new(<<"CSeq">>),
    ?assertMatch({error, _}, ersip_hdr_cseq:parse(NoValue)).

reassemble_test() ->
    reassemble(<<"314159 INVITE">>),
    reassemble(<<"1 REGISTER">>),
    reassemble(<<"99 MYMETHOD">>).

assemble_bin_test() ->
    ?assertEqual(<<"314159 INVITE">>, ersip_hdr_cseq:assemble_bin(make(<<"314159 INVITE">>))),
    ok.

build_test() ->
    CSeqH = create(<<"314159 INVITE">>),
    CSeqHValues = [iolist_to_binary(IOListVal) || IOListVal <- ersip_hdr:raw_values(CSeqH)],
    {ok, CSeq} = ersip_hdr_cseq:parse(CSeqH),
    BuiltCSeqH = ersip_hdr_cseq:build(<<"CSeq">>,  CSeq),
    BuiltCSeqHValues = [iolist_to_binary(IOListVal) || IOListVal <- ersip_hdr:raw_values(BuiltCSeqH)],
    ?assertEqual(CSeqHValues, BuiltCSeqHValues),
    ok.

%%%===================================================================
%%% Helpers
%%%===================================================================
create(Bin) ->
    H = ersip_hdr:new(<<"CSeq">>),
    ersip_hdr:add_values([Bin], H).

make(Bin) ->
    ersip_hdr_cseq:make(create(Bin)).

reassemble(Bin) ->
    CSeq = make(Bin),
    ?assertEqual(Bin, iolist_to_binary(ersip_hdr_cseq:assemble(CSeq))).
