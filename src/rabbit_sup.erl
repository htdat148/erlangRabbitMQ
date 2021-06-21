%%%-------------------------------------------------------------------
%% @doc rabbit top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(rabbit_sup).

-behaviour(supervisor).

-export([start_link/0, add_exchange/2]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    % maximum 10 restarts in 60 seconds
    SupFlags = #{strategy => one_for_all,
                 intensity => 10,
                 period => 60},
    %% by default, 3types are enabled with the same name
    %% create exchange handler: ExchangeName, Type

    ChildSpecs = [get_rabbit_default_child(Type) || Type <- application:get_env(rabbit, exchange_type, [])],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
get_rabbit_default_child(Type) ->

  ModeArgs = application:get_env(rabbit, Type, []),

  ExchangeName = proplists:get_value(exchange_name, ModeArgs),
  ExchangeType = proplists:get_value(exchange_type, ModeArgs),

  #{id => list_to_atom(ExchangeName ++ "_exchange_handler"),
    start => {exchange_handler, start_link, [ExchangeName, ExchangeType]},
    restart => transient, %% only if it stops abnormally
    shutdown => brutal_kill,
    type => supervisor,
    modules => [exchange_handler]}.

add_exchange(Name, Type) ->
  ChildSpec =   #{id => list_to_atom(Name ++ "_exchange_handler"),
                  start => {exchange_handler, start_link, [Name, Type]},
                  restart => transient, %% only if it stops abnormally
                  shutdown => brutal_kill,
                  type => supervisor,
                  modules => [exchange_handler]},
  supervisor:start_child(?MODULE, ChildSpec).