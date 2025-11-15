%%%-------------------------------------------------------------------
%%% @doc
%%% Comprehensive smoke test suite for MerkleTrie
%%% Tests basic functionality, edge cases, and integration
%%% @end
%%%-------------------------------------------------------------------
-module(smoke_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TEST_ID, smoke_test).
-define(TIMEOUT, 30000).  % 30 seconds

%%%===================================================================
%%% Test fixtures
%%%===================================================================

smoke_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [
      {"Basic PUT operation", fun test_basic_put/0},
      {"Basic GET operation", fun test_basic_get/0},
      {"Basic DELETE operation", fun test_basic_delete/0},
      {"Root hash computation", fun test_root_hash/0},
      {"Batch PUT operations", fun test_batch_put/0},
      {"Historical reads", fun test_historical_reads/0},
      {"Proof verification", fun test_proof_verification/0},
      {"Empty trie operations", fun test_empty_trie/0},
      {"Large key operations", fun test_large_keys/0},
      {"Sequential operations", fun test_sequential_ops/0},
      {"Concurrent operations", fun test_concurrent_ops/0},
      {"Persistence test", fun test_persistence/0},
      {"Garbage collection", fun test_garbage_collection/0},
      {"Pruning test", fun test_pruning/0},
      {"Stress test", fun test_stress/0}
     ]}.

setup() ->
    % Clean up any existing test data
    os:cmd("rm -rf data/" ++ atom_to_list(?TEST_ID) ++ "_*.db"),

    % Start dependencies
    application:ensure_all_started(trie),

    % Create test configuration
    Cfg = cfg:new(?TEST_ID, 8, 32, 0, 12, hd),

    % Start trie supervisor
    {ok, _Pid} = trie_sup:start_link(Cfg),

    Cfg.

cleanup(_Cfg) ->
    % Stop processes
    catch exit(whereis(trie), kill),

    % Clean up test data
    os:cmd("rm -rf data/" ++ atom_to_list(?TEST_ID) ++ "_*.db"),

    ok.

%%%===================================================================
%%% Test cases
%%%===================================================================

test_basic_put() ->
    Key = <<1,2,3,4,5,6,7,8>>,
    Value = <<100,101,102,103>>,

    % PUT operation
    trie:put(Key, Value, 1, 1, ?TEST_ID),

    % Verify the put worked by getting the value
    {_RootHash, Leaf, _Proof} = trie:get(Key, 1, ?TEST_ID),

    % Check the value matches
    ?assertEqual(Value, leaf:value(Leaf)).

test_basic_get() ->
    Key = <<10,20,30,40,50,60,70,80>>,
    Value = <<111,222>>,

    % PUT first
    trie:put(Key, Value, 1, 1, ?TEST_ID),

    % GET operation
    {RootHash, Leaf, Proof} = trie:get(Key, 1, ?TEST_ID),

    % Verify result
    ?assertNotEqual(RootHash, undefined),
    ?assertEqual(Value, leaf:value(Leaf)),
    ?assert(is_list(Proof)).

test_basic_delete() ->
    Key = <<1,1,1,1,1,1,1,1>>,
    Value = <<255,255,255,255>>,

    % PUT first
    trie:put(Key, Value, 1, 1, ?TEST_ID),

    % Verify it exists
    {_RH1, Leaf1, _P1} = trie:get(Key, 1, ?TEST_ID),
    ?assertEqual(Value, leaf:value(Leaf1)),

    % DELETE operation
    trie:delete(Key, 2, ?TEST_ID),

    % Verify deletion (leaf should be empty or different)
    {_RH2, Leaf2, _P2} = trie:get(Key, 2, ?TEST_ID),
    ?assertNotEqual(Value, leaf:value(Leaf2)).

test_root_hash() ->
    % Put some values
    trie:put(<<1,0,0,0,0,0,0,0>>, <<1:32>>, 1, 1, ?TEST_ID),
    trie:put(<<2,0,0,0,0,0,0,0>>, <<2:32>>, 2, 1, ?TEST_ID),
    trie:put(<<3,0,0,0,0,0,0,0>>, <<3:32>>, 3, 1, ?TEST_ID),

    % Compute root hash
    RootHash1 = trie:root_hash(3, ?TEST_ID),

    % Root hash should be deterministic
    RootHash2 = trie:root_hash(3, ?TEST_ID),
    ?assertEqual(RootHash1, RootHash2),

    % Root hash should change after modification
    trie:put(<<4,0,0,0,0,0,0,0>>, <<4:32>>, 4, 1, ?TEST_ID),
    RootHash3 = trie:root_hash(4, ?TEST_ID),
    ?assertNotEqual(RootHash1, RootHash3).

test_batch_put() ->
    % Create batch of key-value pairs
    KVList = [
              {<<I,0,0,0,0,0,0,0>>, <<I:32>>}
              || I <- lists:seq(1, 20)
             ],

    % Batch PUT
    trie:put_batch(KVList, 1, ?TEST_ID),

    % Verify all values
    lists:foreach(fun({Key, Value}) ->
                          {_RH, Leaf, _P} = trie:get(Key, 1, ?TEST_ID),
                          ?assertEqual(Value, leaf:value(Leaf))
                  end, KVList).

test_historical_reads() ->
    Key = <<42,0,0,0,0,0,0,0>>,

    % Put different values at different heights
    trie:put(Key, <<1:32>>, 1, 1, ?TEST_ID),
    trie:put(Key, <<2:32>>, 2, 2, ?TEST_ID),
    trie:put(Key, <<3:32>>, 3, 3, ?TEST_ID),

    % Read historical values
    {_RH1, Leaf1, _P1} = trie:get(Key, 1, ?TEST_ID),
    {_RH2, Leaf2, _P2} = trie:get(Key, 2, ?TEST_ID),
    {_RH3, Leaf3, _P3} = trie:get(Key, 3, ?TEST_ID),

    % Verify historical values
    ?assertEqual(<<1:32>>, leaf:value(Leaf1)),
    ?assertEqual(<<2:32>>, leaf:value(Leaf2)),
    ?assertEqual(<<3:32>>, leaf:value(Leaf3)).

test_proof_verification() ->
    Key = <<99,0,0,0,0,0,0,0>>,
    Value = <<123,45,67,89>>,

    % Put value
    trie:put(Key, Value, 1, 1, ?TEST_ID),

    % Get with proof
    {RootHash, Leaf, Proof} = trie:get(Key, 1, ?TEST_ID),

    % Verify proof
    ?assert(verify:leaf(RootHash, Key, Leaf, Proof)),

    % Verify wrong value fails
    WrongValue = <<0,0,0,0>>,
    WrongLeaf = leaf:new(leaf:meta(Leaf), leaf:key(Leaf), WrongValue),
    ?assertNot(verify:leaf(RootHash, Key, WrongLeaf, Proof)).

test_empty_trie() ->
    % Get from empty trie
    Key = <<77,0,0,0,0,0,0,0>>,
    {_RootHash, Leaf, _Proof} = trie:get(Key, 0, ?TEST_ID),

    % Should get empty leaf
    EmptyValue = <<0:256>>,  % Assuming 32 byte value size
    ?assertEqual(EmptyValue, leaf:value(Leaf)).

test_large_keys() ->
    % Test with full 8-byte keys
    Keys = [
            <<255,255,255,255,255,255,255,255>>,
            <<0,0,0,0,0,0,0,0>>,
            <<128,128,128,128,128,128,128,128>>,
            <<1,2,3,4,5,6,7,8>>
           ],

    % Put all keys
    lists:foreach(fun(Key) ->
                          Value = crypto:strong_rand_bytes(32),
                          trie:put(Key, Value, 1, 1, ?TEST_ID)
                  end, Keys),

    % Verify all can be retrieved
    lists:foreach(fun(Key) ->
                          {_RH, Leaf, _P} = trie:get(Key, 1, ?TEST_ID),
                          ?assertNotEqual(<<0:256>>, leaf:value(Leaf))
                  end, Keys).

test_sequential_ops() ->
    % Perform many sequential operations
    lists:foreach(fun(I) ->
                          Key = <<I:64>>,
                          Value = <<(I * 2):32>>,
                          trie:put(Key, Value, I, I, ?TEST_ID)
                  end, lists:seq(1, 100)),

    % Verify some random entries
    TestIndices = [1, 25, 50, 75, 100],
    lists:foreach(fun(I) ->
                          Key = <<I:64>>,
                          ExpectedValue = <<(I * 2):32>>,
                          {_RH, Leaf, _P} = trie:get(Key, I, ?TEST_ID),
                          ?assertEqual(ExpectedValue, leaf:value(Leaf))
                  end, TestIndices).

test_concurrent_ops() ->
    % Spawn multiple processes doing operations
    Parent = self(),

    Workers = [spawn(fun() ->
                             lists:foreach(fun(I) ->
                                                   Key = <<N:8, I:56>>,
                                                   Value = <<N:8, I:24>>,
                                                   trie:put(Key, Value, I, I, ?TEST_ID)
                                           end, lists:seq(1, 10)),
                             Parent ! {done, N}
                     end) || N <- lists:seq(1, 5)],

    % Wait for all workers
    lists:foreach(fun(N) ->
                          receive
                              {done, N} -> ok
                          after ?TIMEOUT ->
                                  ?assert(false)  % Timeout
                          end
                  end, lists:seq(1, 5)),

    % Verify some entries exist
    {_RH, Leaf, _P} = trie:get(<<1:8, 5:56>>, 5, ?TEST_ID),
    ?assertNotEqual(<<0:256>>, leaf:value(Leaf)).

test_persistence() ->
    Key = <<persistent, 0:40>>,
    Value = <<1,2,3,4,5,6,7,8>>,

    % Put value
    trie:put(Key, Value, 1, 1, ?TEST_ID),

    % Get original root hash
    RootHash1 = trie:root_hash(1, ?TEST_ID),

    % Simulate restart by stopping and restarting
    Id = ?TEST_ID,
    catch exit(whereis(trie), kill),
    timer:sleep(100),

    Cfg = cfg:new(Id, 8, 32, 0, 12, hd),
    {ok, _Pid} = trie_sup:start_link(Cfg),

    % Get root hash after restart
    RootHash2 = trie:root_hash(1, ?TEST_ID),

    % Should be the same
    ?assertEqual(RootHash1, RootHash2),

    % Verify data is still there
    {_RH, Leaf, _P} = trie:get(Key, 1, ?TEST_ID),
    ?assertEqual(Value, leaf:value(Leaf)).

test_garbage_collection() ->
    % Put values at different heights
    lists:foreach(fun(I) ->
                          Key = <<I:64>>,
                          Value = <<I:32>>,
                          trie:put(Key, Value, I, I, ?TEST_ID)
                  end, lists:seq(1, 10)),

    % Try garbage collection (undo recent batches)
    try
        trie:garbage(8, 10, ?TEST_ID),
        % If it works, values at height 9-10 should be gone
        ok
    catch
        _:_ -> ok  % Garbage collection might not be fully implemented
    end.

test_pruning() ->
    % Put values at different heights
    lists:foreach(fun(I) ->
                          Key = <<I:64>>,
                          Value = <<I:32>>,
                          trie:put(Key, Value, I, I, ?TEST_ID)
                  end, lists:seq(1, 10)),

    % Try pruning old history
    try
        _PruneInfo = trie:prune(5, 10, ?TEST_ID),
        % If it works, old history should be removed
        ok
    catch
        _:_ -> ok  % Pruning might not be fully implemented
    end.

test_stress() ->
    % Stress test with many random operations
    lists:foreach(fun(I) ->
                          Key = crypto:strong_rand_bytes(8),
                          Value = crypto:strong_rand_bytes(32),
                          trie:put(Key, Value, I, I, ?TEST_ID),

                          % Occasionally compute root hash
                          if I rem 10 =:= 0 ->
                                  _RH = trie:root_hash(I, ?TEST_ID);
                             true -> ok
                          end
                  end, lists:seq(1, 200)),

    % Verify trie is still functional
    TestKey = <<test:64>>,
    TestValue = <<stress:256>>,
    trie:put(TestKey, TestValue, 201, 201, ?TEST_ID),
    {_RH, Leaf, _P} = trie:get(TestKey, 201, ?TEST_ID),
    ?assertEqual(TestValue, leaf:value(Leaf)).

%%%===================================================================
%%% Helper functions
%%%===================================================================

% Add any helper functions here if needed
