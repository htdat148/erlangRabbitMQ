# My experiment from [Erlang RabbitMQ Client library](https://www.rabbitmq.com/erlang-client-user-guide.html)

This repo using rebar3 for managing Erlang applications
## Installation

Clone the repo and start the application
```bash
git clone https://github.com/htdat148/erlangRabbitMQ.git
cd erlangRabbitMQ
rebar3 shell
```

## Default configuration
Be default, the `rabbit` application will create 3 exchanges corresponding to 3 type: direct, fanout and topic.
Each exchange is a running process supervise by `rabbit_sup.erl`.
The exchange types and name are get from `config/sys.config`

For example with "direct" exchange: `[{name, <<"direct">>}, {type, <<"direct">>}, {process, "direct_exchange_handler"}]`
 