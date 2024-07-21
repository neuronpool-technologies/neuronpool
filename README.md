# `NeuronPool()`

Stake your ICP, join the pool and win big rewards!

## How does it work?

Users add to the stake of the NNS neuron (the pool), which is controlled by the canister. The canister-controlled neuron has a 6 month dissolve delay and accumulates staking rewards by voting on governance proposals on the NNS and periodically distributes all the accumulated rewards to one lucky user, selected at random and taking into consideration the weight of their deposit.

## Key features
- Staking rewards from the pool are disbursed to one lucky winner.
- Minimum stake of 0.1 ICP ensures a low barrier of entry.
- Fully automated - Users just stake and check if they won.
- Start the 6-month withdrawal process anytime and leave with your full stake.

## Real-World Comparisons

Users can stake small amounts of ICP and potentially win large rewards in return. NeuronPool is akin to a positive-sum lottery or a prize bond. Users do not lose anything by entering the protocol; they can withdraw at any time and only stand to gain if they win a reward. The rewards could be substantial if a significant amount of ICP is staked in the protocol.

### 1. Positive-sum lottery

In contrast to a typical lottery, where the reward pool is solely funded by participants' contributions, a positive-sum lottery distributes total winnings that exceed the amount collectively contributed by participants. This can occur through additional funding, such as sponsorships or government incentives like grants.

NeuronPool, for example, derives its rewards from the staking rewards earned by the neuron through voting on governance proposals on the NNS. This mechanism creates a positive-sum lottery where participants, on average, gain more than their initial contributions.

### 2. Prize bonds

Depositing ICP into NeuronPool also shares similarities with buying prize bonds. A prize bond is a type of lottery bond that, instead of paying regular interest to holders as a typical bond does, offers larger prizes to lucky winners at different intervals.

For example, the state of Ireland offers such prize bonds to its citizens, featuring weekly prize draws of up to €50,000 and monthly draws of up to €500,000. See [State Savings](https://www.statesavings.ie/prize-bonds).

## Staking example

Below is an example of what the rewards might look like if you staked 100 ICP directly on the NNS or in NeuronPool, with the staking reward amounts determined by the [ICP Neuron Calculator](https://networknervoussystem.com/). Because NeuronPool functions very differently from directly staking on the NNS, we will set up some simple prerequisites:

- Initial stake amount: 100 ICP.
- Total NeuronPool stake amount: 10,000 ICP.
- NeuronPool rewards disbursed once a month.
  
Although it is not guaranteed that we will win any prize reward on NeuronPool, with a bit of luck, let's assume we will win **only one** reward in year 3 of staking on NeuronPool and compare it to the NNS:


|              | NNS     | NeuronPool |
|:-------------|:-------|:------------|
| 1 Year       | 110 ICP | 100 ICP    |
| 2 Years      | 120 ICP | 100 ICP    |
| 3 Years      | 129 ICP | 176 ICP    |

In the above example, we win the reward in the third year. We might win the reward in the first year or maybe even the tenth; there are no guarantees. Staking on the NNS provides a more consistent and reliable stream of staking rewards compared to NeuronPool. However, with a bit of luck and without losing any of your principal staked amount, staking on NeuronPool might still allow you to come out ahead. We like the odds for smaller stake amounts, but as always, users should conduct their own research (DYOR) before making any staking decisions.

## Design considerations

- The [mops neuro](https://mops.one/neuro) package is used to interact with the neuron.
- The main logic has been unit tested using the [mops test](https://mops.one/test) package.
- The smart contract is hosted on an ICP [fiduciary subnet](https://internetcomputer.org/docs/current/concepts/subnet-types/#fiduciary-subnets) for added security.
- All operations are stored in a vector that maintains a full transaction log, modelled after the [ICRC-1](https://github.com/dfinity/ICRC-1) standard.
- Users only pay the ICP transaction fee (currently 0.0001 ICP) when entering and leaving the protocol. The protocol earns fees by taking 10% of the staking rewards.

## Found a bug?

This Motoko smart contract has been open-sourced with the intention of making the entire protocol a public good. Transparency is essential for fairness and for enabling users to conduct thorough due diligence. By exposing the smart contract code, we can grow the Motoko eco-system and ensure that users can fully trust and understand the protocol.

If you discover any security vulnerabilities, especially those that could compromise user funds or balances, please contact hello@neuronpool.com with the details of the exploit. Compensation will be provided through direct payment in ICP or through an allocation of future fees generated by the contract.

## Overview of the tech stack

- [Motoko](https://react.dev/](https://internetcomputer.org/docs/current/motoko/main/motoko?source=nav)) is used for the smart contract programming language.
- The IC SDK: [DFX](https://internetcomputer.org/docs/current/developer-docs/setup/install) is used to make this an ICP project.

### If you want to clone onto your local machine

Make sure you have `git` and `dfx` installed
```bash
# clone the repo
git clone #<get the repo ssh>

# change directory
cd neuronpool

# set up the dfx local server
dfx start --background --clean

# deploy the canister locally
dfx deploy

# ....
# when you are done make sure to stop the local server:
dfx stop
```

## License

The `NeuronPool()` code is distributed under the terms of the MIT License.

See LICENSE for details.
