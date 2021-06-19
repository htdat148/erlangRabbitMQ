%%%-------------------------------------------------------------------
%% @doc rabbit top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(rabbit_sup).

-behaviour(supervisor).

-export([start_link/0, config_rabbit_child/1]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    % maximum 10 restarts in 60 seconds
    SupFlags = #{strategy => one_for_all,
                 intensity => 10,
                 period => 60},

    ChildSpecs = [config_rabbit_child(Type) || Type <- application:get_env(rabbit, exchange_type, [])],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
config_rabbit_child(Type) ->

  {ok, ChildArgs} = application:get_env(rabbit, Type),
  ChildArgs_1 = [list_to_binary(ChildArg) || ChildArg <- ChildArgs],

  #{id => list_to_atom(atom_to_list(Type) ++ "_rabbit_worker"),
    start => {rabbit_worker, start_link, ChildArgs_1},
    restart => transient, %% only if it stops abnormally
    shutdown => brutal_kill,
    type => worker,
    modules => [rabbit_worker]}.

