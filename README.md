# Data Marketplace: A decentralized implementation with Ethereum and IOTA

This is a decentralized data marketplace that allows data consumers
to place bids on auctions for high-value sensor/IoT devices to compensate
for invaluable data.

Data Marketplace is governed by specific contracts deployed on Ethereum
network, allowing data curators to register new data sets and users to
subscribe to existing data sets, in conjunction with IOTA network to preserve
and validate data source.

Data Marketplace contract is publicly available and can be used by any other
contract in the network. The smart contract stores each of the data sets
metadata (owner, price, number of subscriptions, etc.) and information about
each subscription to any data set (price, start time and end time).

## Registration

Registration is the process through which data providers can offer their
datasets on the Data Marketplace. Data providers are paid for their dataset
after the subscription period ends for any given subscriber, through
a withdraw transaction.

## Subscriptions

A Subscription holds the reference to instances of user-defined Contracts.

The subscribers are the users in the Data Marketplace that pay for data.
Every payment is first made to the Marketplace contract and is held until
the Subscription is expired or the Data curator is punished (should their
data stop being available). In case the data provider was punished then
and only then, the subscriber will able to ask for a refund. The refund is
prorated on the fraction of the monthly subscription when the data was
available, and will be deposited back to the subscriber's address.

## Contracts
Contracts are the custom and user defined artifact that describe a data
subscription service. These are custom contracts that the buyer interacts with.
The existence of these contracts live within subscriptions. Additional client
code accompanies Contracts, where either the consumer and service provider
run a custom client and server.

## Get started

### Prerequisites
* Ganache
* solc compiler
* Truffle

### Setup dependency
```shell
npm install
npm install truffle -g
npm install ganache-cli -g
```

### Setup test environment
```shell
ganache-cli --account 4
```

### Build and Run
```shell
truffle compile
truffle test
```
