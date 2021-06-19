%%%-------------------------------------------------------------------
%%% @author dhuynh
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%% This module is used as a rabbit MQ consummer
%%% @end
%%% Created : 17. Jun 2021 21:20
%%%-------------------------------------------------------------------
-module(rabbit_worker).
-author("dhuynh").

-include_lib("amqp_client/include/amqp_client.hrl").

-behaviour(gen_server).

%% API
-export([start_link/4]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-export([subscribe/2]).

-define(SERVER, ?MODULE).

-record(rabbit_worker_state, {channel,type, routing_keys}).

%%%===================================================================
%%% API
%%%===================================================================

start_link(Name, Exchange, Type, RoutingKey) ->
  gen_server:start_link({local, list_to_atom(binary_to_list(Name))}, ?MODULE, [Exchange, Type, RoutingKey], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
%% @doc Initializes the server

%% Exchange, Mode, RoutingKey must be binary
init([Exchange, Type, RoutingKey]) ->

  %%  start a connection
  %%  default amqp_params_network host is localhost
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),

  %% declare exchange
  amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange,
                                                 type = Type}),
  %% declare a queue
  #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel,
                                                          #'queue.declare'{exclusive = true}),

  %% binding to queue to routing key
  Binding = #'queue.bind'{queue       = Queue,
                          exchange    = Exchange,
                          routing_key = RoutingKey},
  amqp_channel:call(Channel, Binding),

  % create a process that subscribe message with exchange and routing keys
  % in case this process crash or hang, handled by handle_info
  proc_lib:spawn_link(?MODULE, subscribe, [Channel, Queue]),

  {ok, #rabbit_worker_state{channel = Channel, type = Type, routing_keys = RoutingKey}}.

%% @private
%% @doc Handling call messages
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #rabbit_worker_state{}) ->
  {reply, Reply :: term(), NewState :: #rabbit_worker_state{}} |
  {reply, Reply :: term(), NewState :: #rabbit_worker_state{}, timeout() | hibernate} |
  {noreply, NewState :: #rabbit_worker_state{}} |
  {noreply, NewState :: #rabbit_worker_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #rabbit_worker_state{}} |
  {stop, Reason :: term(), NewState :: #rabbit_worker_state{}}).
handle_call(_Request, _From, State = #rabbit_worker_state{}) ->
  {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec(handle_cast(Request :: term(), State :: #rabbit_worker_state{}) ->
  {noreply, NewState :: #rabbit_worker_state{}} |
  {noreply, NewState :: #rabbit_worker_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #rabbit_worker_state{}}).
handle_cast(_Request, State = #rabbit_worker_state{}) ->
  {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec(handle_info(Info :: timeout() | term(), State :: #rabbit_worker_state{}) ->
  {noreply, NewState :: #rabbit_worker_state{}} |
  {noreply, NewState :: #rabbit_worker_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #rabbit_worker_state{}}).
handle_info(_Info, State = #rabbit_worker_state{}) ->
  {noreply, State}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #rabbit_worker_state{}) -> term()).
terminate(_Reason, _State = #rabbit_worker_state{}) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #rabbit_worker_state{},
    Extra :: term()) ->
  {ok, NewState :: #rabbit_worker_state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State = #rabbit_worker_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
subscribe(Channel, Queue) ->
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