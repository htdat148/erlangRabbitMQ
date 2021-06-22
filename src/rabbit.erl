%%%-------------------------------------------------------------------
%%% @author dhuynh
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. Jun 2021 22:39
%%%-------------------------------------------------------------------
-module(rabbit).
-author("dhuynh").

-include_lib("amqp_client/include/amqp_client.hrl").

%% API
-export([send_msg/3, add_queue_to_exchange/3,
         add_routing_key_to_queue/3,
         get_worker_info/1, add_routing_keys/2]).

%% this function is used to send msg to default exchange
%% msg is atom for direct and fanout types
%% msg is a {Topic, Content} for topic type
send_msg(ExchangeStr, RoutingKeyStr, MsgStr) ->
  %% start a connection
  %% default amqp_params_network host is localhost
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  Exchange = list_to_binary(ExchangeStr),
  RoutingKey = list_to_binary(RoutingKeyStr),
  Msg = list_to_binary(MsgStr),

  Publish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
  amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Msg}),

  amqp_channel:close(Channel),
  amqp_connection:close(Connection),
  ok.

add_queue_to_exchange(Exchange, RoutingKey, Queue) ->
  supervisor:start_child(list_to_atom(Exchange ++ "_exchange_handler"), [RoutingKey, Queue]).

%% If queue not exist, create queue
add_routing_key_to_queue(Exchange, RoutingKey, Queue) ->
  Reply = gen_server:call(list_to_atom(Queue ++ "_queue_handler"),
                  {add_routing_key_to_queue, list_to_binary(RoutingKey), list_to_binary(Queue)}),
  ok.

get_worker_info(Type) ->
  WorkerRef = get_worker_ref(Type),
  Reply = gen_server:call(WorkerRef, get_worker_info),
  Reply.

add_routing_keys(Type, RoutingKeys) ->
  WorkerRef = get_worker_ref(Type),
  gen_server:cast(WorkerRef, {add_keys_to_existing_queue, RoutingKeys}).

get_worker_ref(Type) ->
  [Worker | _] = application:get_env(rabbit, Type, []),
  list_to_atom(Worker).