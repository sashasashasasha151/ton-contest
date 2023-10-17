import "@stdlib/deploy";
/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

struct Info {
    aAmount: Int;
    bAmount: Int;
    jettonAddressA: Address;
    jettonAddressB: Address;
}

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task3 with Deployable {
    owner: Address;
    info: Info;
    const decimal: Int = 1000000000;
    init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address){
        self.owner = admin;
        self.info = Info{
            aAmount: 0,
            bAmount: 0,
            jettonAddressA: newJettonAddressA,
            jettonAddressB: newJettonAddressB
        };
    }

    receive(msg: TokenNotification){
        let tokenAddress: Address = sender();
        let info: Info = self.info;
        require(tokenAddress == info.jettonAddressA || tokenAddress == info.jettonAddressB, "Token address is not supported");
        // let tokenAddressA: Address = self.jettonAddressA;
        // let tokenAddressB: Address = self.jettonAddressB;
        let userAddress: Address = msg.from;
        if (userAddress == self.owner) {
            if (tokenAddress == info.jettonAddressA) {
                self.info.aAmount = info.aAmount + msg.amount;
            } else if (tokenAddress == info.jettonAddressB) {
                self.info.bAmount = info.bAmount + msg.amount;
            }
            return;
        }
        let fromContractAmount: Int = 0;
        let toContractAmount: Int = 0;
        let toTokenAddress: Address = tokenAddress;
        if (tokenAddress == info.jettonAddressA) {
            fromContractAmount = info.aAmount;
            toContractAmount = info.bAmount;
            toTokenAddress = info.jettonAddressB;
        } else if (tokenAddress == info.jettonAddressB) {
            fromContractAmount = info.bAmount;
            toContractAmount = info.aAmount;
            toTokenAddress = info.jettonAddressA;
        }
        let fromUserAmount: Int = msg.amount;
        let toUserAmount: Int =
            (toContractAmount * self.decimal / fromContractAmount) * fromUserAmount / self.decimal;
        if (toUserAmount > toContractAmount) {
            send(SendParameters{to: tokenAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: true,
                    body: TokenTransfer{queryId: 0,
                        amount: fromUserAmount,
                        destination: userAddress,
                        responseDestination: myAddress(),
                        customPayload: null,
                        forwardTonAmount: ton("0.01"),
                        forwardPayload: emptySlice()
                    }.toCell()
                }
            );
        } else {
            send(SendParameters{to: toTokenAddress,
                    value: 0,
                    mode: SendRemainingValue,
                    bounce: true,
                    body: TokenTransfer{queryId: 0,
                        amount: toUserAmount,
                        destination: userAddress,
                        responseDestination: myAddress(),
                        customPayload: null,
                        forwardTonAmount: ton("0.01"),
                        forwardPayload: emptySlice()
                    }.toCell()
                }
            );
            if (tokenAddress == info.jettonAddressA) {
                self.info.bAmount = info.bAmount - toUserAmount;
                self.info.aAmount = info.aAmount + fromUserAmount;
            } else if (tokenAddress == info.jettonAddressB) {
                self.info.aAmount = info.aAmount - toUserAmount;
                self.info.bAmount = info.bAmount + fromUserAmount;
            }
        }
    }

    get fun price(jetton: Address): Int {
        let info: Info = self.info;
        if (jetton == info.jettonAddressA) {
            return info.bAmount * self.decimal / info.aAmount;
        } else if (jetton == info.jettonAddressB) {
            return info.aAmount * self.decimal / info.bAmount;
        }
        return 0;
    }

    get fun balance(jetton: Address): Int {
        let info: Info = self.info;
        if (jetton == info.jettonAddressA) {
            return info.aAmount;
        } else if (jetton == info.jettonAddressB) {
            return info.bAmount;
        }
        return 0;
    }
}
