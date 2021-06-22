%%%-------------------------------------------------------------------
%%% @author dhuynh
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. Jun 2021 22:39
%%%-------------------------------------------------------------------
-module(rabbit_client_api).
-author("dhuynh").

-include_lib("amqp_client/include/amqp_client.hrl").

%% API
-export([send_msg/3, add_queue_to_exchange/2,
         add_routing_key_to_queue/2, get_queue_info/1]).

%% this function is used to send msg to default exchange
%% msg is atom for direct and fanout types
%% msg is a {Topic, Content} for topic type
send_msg(ExchangeStr, RoutingKeyStrs, MsgStr) ->
  %% start a connection
  %% default amqp_params_network host is localhost
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  Exchange = list_to_binary(ExchangeStr),
  RoutingKeys = str_to_bin(RoutingKeyStrs),
  Msg = list_to_binary(MsgStr),

  lists:map(fun(RoutingKey) ->

                  Publish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
                  amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Msg})
            end, RoutingKeys),

  amqp_channel:close(Channel),
  amqp_connection:close(Connection),
  ok.

add_queue_to_exchange(Exchange, Queue) ->
  supervisor:start_child(list_to_atom(Exchange ++ "_exchange_handler"), [ Queue]).

%% If queue not exist, create queue
add_routing_key_to_queue(RoutingKeys, Queue) ->
  Reply = gen_server:call(list_to_atom(Queue ++ "_queue_handler"),
                  {add_routing_key_to_queue, str_to_bin(RoutingKeys), list_to_binary(Queue)}),
  Reply.

get_queue_info(Queue) ->
  Reply = gen_server:call(list_to_atom(Queue ++ "_queue_handler"), get_queue_info),
  Reply.

str_to_bin(List) ->
  lists:map(fun(X) -> list_to_binary(X) end, List).