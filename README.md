# promise-contracts
Promise (Token: WORD) is a blockchain reputation token written in Solidity.
Very beta, but functional on Rinkeby testnet - http://promiseto.me for info.

How to play?

- a Promiser makes a promise to a promisee:
"I promise to [promisee] that [the promise description] until [expiry] with [amount] PMRS tokens".

- Promisee can accept or reject.
If rejected, contract ends, nothing happend, game over.

- Promisee accepted - game is on.
If the expiry date reached, and the Promisee didn't dispute the promise, it means the promise was kept - that's a win!
The tokens are returned to the promiser, and the PromiseGenie mints new tokens (50% of the amount of the promise) and distributes them equally between the promiser and promisee as a reward for a "kept promise".

- Promisee can dispute!
Before the expiry date, the promisee can claim the promiser broke the promise and dispute it.

- Promiser can agree or not...
if agreed - the tokens are sent to the promisee, but the PromiseGenie keeps 10% as punishment...
(the promisee can also change their minds and agree that the promise was kept after all)

- Promise could get burned!
if a promise is disputed for 7 days without resolution - the PromiseGenie burns all the tokens and no one wins!
