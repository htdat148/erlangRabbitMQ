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
         bind_routing_key_to_queue/2, get_queue_info/1,
         unbind_routing_key_to_queue/2, remove_queue/1,
         remove_exchange/1]).

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
bind_routing_key_to_queue(RoutingKeys, Queue) ->
  Reply = gen_server:call(list_to_atom(Queue ++ "_queue_handler"),
                  {bind_routing_key_to_queue, str_to_bin(RoutingKeys), list_to_binary(Queue)}),
  Reply.

unbind_routing_key_to_queue(RoutingKeys, Queue) ->
  Reply = gen_server:call(list_to_atom(Queue ++ "_queue_handler"),
                  {unbind_routing_key_to_queue, str_to_bin(RoutingKeys), list_to_binary(Queue)}),
  Reply.
get_queue_info(Queue) ->
  Reply = gen_server:call(list_to_atom(Queue ++ "_queue_handler"), get_queue_info),
  Reply.

remove_queue(Queue) ->
  gen_server:stop(list_to_atom(Queue ++ "_queue_handler"), normal, 10).

remove_exchange(Exchange) ->
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  Delete = #'exchange.delete'{exchange = list_to_binary(Exchange)},
  #'exchange.delete_ok'{} = amqp_channel:call(Channel, Delete),
  supervisor:terminate_child(rabbit_sup, list_to_atom(Exchange ++ "_exchange_handler")).

str_to_bin(List) ->
  lists:map(fun(X) -> list_to_binary(X) end, List).