%%%-------------------------------------------------------------------
%% @doc rabbit public API
%% @end
%%%-------------------------------------------------------------------

-module(rabbit_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    application:ensure_started(amqp_client),
    rabbit_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
