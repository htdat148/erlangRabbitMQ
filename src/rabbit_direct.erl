%%%-------------------------------------------------------------------
%%% @author dhuynh
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. Jun 2021 19:46
%%%-------------------------------------------------------------------
-module(rabbit_direct).
-author("dhuynh").

-include_lib("amqp_client/include/amqp_client.hrl").
%% API
-export([send_msg/1, receive_msg/0]).

send_msg(Msg) ->
  %% start a connection
  %% default amqp_params_network host is localhost
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  %% To send/publish a message
  %% publish(Channel, Exchange, Routing Key, Payload)
  Exchange = <<"direct_logs">>,
  RoutingKey = <<"info">>,
  Declare = #'exchange.declare'{exchange = Exchange,
                                type = <<"direct">>},
  amqp_channel:call(Channel, Declare),

  Payload = list_to_binary(Msg),
  Publish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
  amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),

  amqp_channel:close(Channel),
  amqp_connection:close(Connection),
  ok.

receive_msg() ->
  %%  start a connection
  %% default amqp_params_network host is localhost
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host = "localhost"}),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  %% declare exchange
  Exchange = <<"direct_logs">>,
  amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange,
                                               type = <<"direct">>}),
  %% declare a queue
  #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel,
                                                          #'queue.declare'{exclusive = true}),

  %% binding to queue to routing key
  RoutingKey = <<"info">>,
  Binding = #'queue.bind'{queue       = Queue,
                          exchange    = Exchange,
                          routing_key = RoutingKey},
  amqp_channel:call(Channel, Binding),
  amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue,
                                                     no_ack = true}, self()),

  io:format(" [*] Waiting for logs. To exit press CTRL+C~n"),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    loop(Channel).


loop(Channel) ->
    receive
        {#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload = Body}} ->
            io:format(" [x] ~p:~p~n", [RoutingKey, Body]),
            loop(Channel)
    end.