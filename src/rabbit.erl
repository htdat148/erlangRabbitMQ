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
-export([send_msg/2]).

%% this function is used to send msg to default exchange
%% msg is atom for direct and fanout types
%% msg is a {Topic, Content} for topic type
send_msg(TypeAtom, Msg) ->

  [_Worker, Exchange, Type, RoutingKey ] = [list_to_binary(Element) ||
                                            Element <- application:get_env(rabbit, TypeAtom, [])],

  {RoutingKey_1, Payload} =
    case TypeAtom of
      topic ->
        % TODO handles the case MSg not a tuple
        {Topic, Content} = Msg,
        {list_to_binary(Topic), list_to_binary(Content)};
      _OtherType ->
        {RoutingKey, list_to_binary(Msg)}
    end,

  %% start a connection
  %% default amqp_params_network host is localhost
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  %% To send/publish a message
  %% publish(Channel, Exchange, Routing Key, Payload)
  Declare = #'exchange.declare'{exchange = Exchange,
                                type = Type},
  amqp_channel:call(Channel, Declare),

  Publish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey_1},
  amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),

  amqp_channel:close(Channel),
  amqp_connection:close(Connection),
  ok.

