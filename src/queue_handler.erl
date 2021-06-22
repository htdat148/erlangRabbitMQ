%%%-------------------------------------------------------------------
%%% @author dhuynh
%%% @copyright (C) 2021, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. Jun 2021 20:30
%%%-------------------------------------------------------------------
-module(queue_handler).
-author("dhuynh").

-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(queue_handler_state, {channel, exchange, routing_keys = [], queues = []}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Spawns the server and registers the local name (unique)
start_link(Exchange, Queue) ->
  gen_server:start_link({local, list_to_atom(Queue ++ "_queue_handler")}, ?MODULE, [Exchange,

                                                                                    list_to_binary(Queue)], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
%% @doc Initializes the server
-spec(init(Args :: term()) ->
  {ok, State :: #queue_handler_state{}} | {ok, State :: #queue_handler_state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([Exchange, Queue]) ->
  {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  %% declare a queue
  #'queue.declare_ok'{} = amqp_channel:call(Channel, #'queue.declare'{exclusive = true,
                                                                      queue = Queue}),

%%  %% binding to queue to routing key
%%  Binding = #'queue.bind'{queue       = Queue,
%%                          exchange    = Exchange,
%%                          routing_key = RoutingKey},
%%  amqp_channel:call(Channel, Binding),

  amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue,
                                                     no_ack = true}, self()),
  io:format("Queue [~p] Waiting for logs. To exit press CTRL+C~n", [Queue]),
  {ok, #queue_handler_state{channel = Channel, exchange = Exchange, queues = [Queue]}}.

%% @private
%% @doc Handling call messages
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #queue_handler_state{}) ->
  {reply, Reply :: term(), NewState :: #queue_handler_state{}} |
  {reply, Reply :: term(), NewState :: #queue_handler_state{}, timeout() | hibernate} |
  {noreply, NewState :: #queue_handler_state{}} |
  {noreply, NewState :: #queue_handler_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #queue_handler_state{}} |
  {stop, Reason :: term(), NewState :: #queue_handler_state{}}).

handle_call(get_queue_info, _From, State) ->
  Reply = State,
  {reply, Reply, State};
handle_call({add_routing_key_to_queue, NewRoutingKeys, Queue}, _From,
            State) ->
  #queue_handler_state{channel = Channel, exchange = Exchange, routing_keys = RoutingKeys} = State,

  %% binding to queue to routing key
  lists:map(fun(NewRoutingKey) ->
              Binding = #'queue.bind'{queue       = Queue,
                                      exchange    = Exchange,
                                      routing_key = NewRoutingKey},
              amqp_channel:call(Channel, Binding)
            end, NewRoutingKeys),

  {reply, {adding_successfully, NewRoutingKeys}, State#queue_handler_state{routing_keys = RoutingKeys ++ NewRoutingKeys}};

handle_call(_Request, _From, State = #queue_handler_state{}) ->
  {reply, ok, State}.

%% @private
%% @doc Handling cast messages
-spec(handle_cast(Request :: term(), State :: #queue_handler_state{}) ->
  {noreply, NewState :: #queue_handler_state{}} |
  {noreply, NewState :: #queue_handler_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #queue_handler_state{}}).


handle_cast(_Request, State = #queue_handler_state{}) ->
  {noreply, State}.

%% @private
%% @doc Handling all non call/cast messages
-spec(handle_info(Info :: timeout() | term(), State :: #queue_handler_state{}) ->
  {noreply, NewState :: #queue_handler_state{}} |
  {noreply, NewState :: #queue_handler_state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #queue_handler_state{}}).

handle_info(#'basic.consume_ok'{}, State = #queue_handler_state{}) ->
  {noreply, State};
handle_info({#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload = Body}}, State) ->
  io:format(" [x] ~p:~p~n", [RoutingKey, Body]),
  {noreply, State};
handle_info(_Info, State = #queue_handler_state{}) ->
  {noreply, State}.

%% @private
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #queue_handler_state{}) -> term()).
terminate(_Reason, _State = #queue_handler_state{}) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #queue_handler_state{},
    Extra :: term()) ->
  {ok, NewState :: #queue_handler_state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State = #queue_handler_state{}, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
